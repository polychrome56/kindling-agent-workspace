#!/usr/bin/env bash
set -u

input="$(cat)"

json_field() {
  HOOK_INPUT="$input" python3 - "$1" <<'PY' 2>/dev/null || true
import json
import os
import sys

field = sys.argv[1]
try:
    data = json.loads(os.environ.get("HOOK_INPUT", "{}"))
except Exception:
    data = {}
value = data.get(field, "")
print(value if isinstance(value, str) else "")
PY
}

emit() {
  local permission="$1"
  local user_message="${2:-}"
  local agent_message="${3:-}"
  python3 - "$permission" "$user_message" "$agent_message" <<'PY'
import json
import sys

payload = {"permission": sys.argv[1]}
if sys.argv[2]:
    payload["user_message"] = sys.argv[2]
if sys.argv[3]:
    payload["agent_message"] = sys.argv[3]
print(json.dumps(payload, ensure_ascii=False))
PY
}

deny() {
  emit "deny" "$1" "$2"
  exit 0
}

allow() {
  emit "allow" "" ""
  exit 0
}

command="$(json_field command)"
[ -n "$command" ] || allow

case "$command" in
  *"git push --force"*|*"git push -f"*)
    deny "已拦截 force push。只有在用户明确要求并理解风险后，才允许执行 force push。" \
      "workspace 发布 hook 已拦截 force push。"
    ;;
  *"git config --global"*)
    deny "已拦截全局 git config 修改。发布本 workspace 不应修改全局 git 配置。" \
      "workspace 发布 hook 已拦截全局 git config 修改。"
    ;;
esac

# 对「禁止片段」只做结构/路径类检查：`git commit -m` 的说明文字不应触发误拦。
# 仍依赖下方对暂存区路径与 diff 的检查，防止把业务目录与凭据写入索引。
command_scan="$(COMMAND="$command" python3 - <<'PY'
import os
import shlex
import sys

cmd = os.environ.get("COMMAND", "")


def git_executable_index(parts):
    for idx, t in enumerate(parts):
        if t == "git" or t.endswith("/git"):
            return idx
    return -1


def strip_git_commit_message_args(parts):
    gi = git_executable_index(parts)
    if gi < 0:
        return parts
    j = gi + 1
    while j < len(parts) and parts[j].startswith("-"):
        if parts[j] in ("-c", "-C"):
            j += 2
            continue
        if "=" in parts[j]:
            j += 1
            continue
        j += 1
    if j >= len(parts) or parts[j] != "commit":
        return parts
    head = parts[: j + 1]
    tail = []
    k = j + 1
    while k < len(parts):
        tok = parts[k]
        if tok in ("&&", "||", ";"):
            break
        if tok in ("-m", "--message"):
            k += 2 if k + 1 < len(parts) else 1
            continue
        if tok.startswith("--message="):
            k += 1
            continue
        if tok.startswith("-m") and len(tok) > 2:
            k += 1
            continue
        tail.append(tok)
        k += 1
    return head + tail


def normalize_one_segment(seg):
    if not seg:
        return seg
    parts = list(seg)
    out = []
    i = 0
    while i < len(parts):
        if parts[i] in ("&&", "||", ";"):
            out.append(parts[i])
            i += 1
            continue
        j = i
        while j < len(parts) and parts[j] not in ("&&", "||", ";"):
            j += 1
        chunk = parts[i:j]
        out.extend(strip_git_commit_message_args(chunk))
        i = j
    return out


try:
    tokens = shlex.split(cmd, posix=True)
except ValueError:
    print(cmd, end="")
    sys.exit(0)

normalized = normalize_one_segment(tokens)
print(" ".join(normalized), end="")
PY
)"

if COMMAND_SCAN="$command_scan" python3 - <<'PY'; then
import os
import shlex
import sys

cmd = os.environ.get("COMMAND_SCAN", "")
try:
    tokens = shlex.split(cmd, posix=True)
except ValueError:
    tokens = cmd.split()


def normalize_path(token):
    token = token.strip()
    while token.startswith("./"):
        token = token[2:]
    return token


def is_forbidden_path(token):
    path = normalize_path(token)
    return (
        path == "agent-libs" or path.startswith("agent-libs/")
        or path == "kindling" or path.startswith("kindling/")
        or path == "config/git-publish.env"
        or path == ".env" or path.startswith(".env.")
        or path.endswith(".pem") or path.endswith(".key")
        or path.endswith(".p12") or path.endswith(".pfx")
        or path.endswith("id_rsa") or path.endswith("id_ed25519")
    )


sys.exit(1 if any(is_forbidden_path(token) for token in tokens) else 0)
PY
  :
else
  deny "已拦截引用源码目录或本地凭据的 git/GitHub 命令。" \
    "workspace 发布 hook 已拦截包含禁止路径的命令。"
fi

workspace_name="$(basename "$PWD")"
[ "$workspace_name" = "kindling-agent-workspace" ] || allow

case "$command" in
  *git\ init*|*git\ status*|*git\ diff*|*git\ log*|*git\ remote*|*gh\ auth\ status*)
    allow
    ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  allow
fi

status_output="$(git status --porcelain --untracked-files=all 2>/dev/null || true)"
staged_files="$(git diff --cached --name-only 2>/dev/null || true)"

scan_paths() {
  SCAN_TEXT="$1" python3 - <<'PY'
import os
import re
import sys

text = os.environ.get("SCAN_TEXT", "")
patterns = [
    r"(^|\n)..\s+agent-libs/",
    r"(^|\n)..\s+kindling/",
    r"(^|\n)..\s+config/git-publish\.env($|\n)",
    r"(^|\n)..\s+\.env(\.|$)",
    r"(^|\n)..\s+.*\.(pem|key|p12|pfx)($|\n)",
    r"(^|\n)..\s+.*id_(rsa|ed25519)($|\n)",
    r"(^|\n)(agent-libs/|kindling/|config/git-publish\.env$|\.env(\.|$)|.*\.(pem|key|p12|pfx)$|.*id_(rsa|ed25519)$)",
]
if any(re.search(pattern, text, re.MULTILINE) for pattern in patterns):
    sys.exit(2)
PY
}

if ! scan_paths "$status_output"$'\n'"$staged_files"; then
  deny "已拦截：git 状态或暂存区中出现源码目录或本地凭据文件。" \
    "workspace 发布 hook 在 git status 或 index 中发现禁止路径。"
fi

case "$command" in
  *git\ commit*|*git\ push*|*gh\ repo\ create*)
    staged_diff="$(git diff --cached --no-ext-diff 2>/dev/null || true)"
    if STAGED_DIFF="$staged_diff" python3 - <<'PY'; then
import os
import re
import sys

text = os.environ.get("STAGED_DIFF", "")
secret_patterns = [
    r"GITHUB_TOKEN\s*=",
    r"ghp_[A-Za-z0-9_]{20,}",
    r"github_pat_[A-Za-z0-9_]+",
    r"BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY",
    r"AKIA[0-9A-Z]{16}",
]
sys.exit(1 if any(re.search(pattern, text) for pattern in secret_patterns) else 0)
PY
      :
    else
      deny "已拦截：暂存内容疑似包含 token 或私钥。" \
        "workspace 发布 hook 在暂存 diff 中发现疑似密钥。"
    fi
    ;;
esac

allow
