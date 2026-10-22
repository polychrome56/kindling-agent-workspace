#!/usr/bin/env python3
"""只读检查配置仓库的暂存内容；不创建提交、不推送、不输出凭据。"""
import argparse
import re
import subprocess
from pathlib import Path

BUSINESS = {"agent-libs", "kindling", "4.1.0", "ahyd", "安徽移动", ".local", ".cache"}
SECRETS = [r"ghp_[A-Za-z0-9_]{20,}", r"github_pat_[A-Za-z0-9_]{20,}",
           r"BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY", r"AKIA[0-9A-Z]{16}"]


def forbidden(path):
    p = Path(path)
    return (p.parts[0] in BUSINESS or p.name.startswith(".env")
            or path in {"config/git-publish.env", ".serena/project.local.yml", "compile_commands.json"}
            or (path.startswith(".serena/") and path != ".serena/project.yml")
            or p.suffix.lower() in {".pem", ".key", ".p12", ".pfx", ".o", ".a", ".so"}
            or p.name in {"id_rsa", "id_ed25519"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    root = parser.parse_args().root.resolve()
    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args])
    actual = Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
    if actual != root:
        raise SystemExit("请选择配置仓库 Git 根目录，不能误用嵌套业务仓库")
    paths = [p for p in git("diff", "--cached", "--name-only", "--no-renames", "-z").decode().split("\0") if p]
    bad = [p for p in paths if forbidden(p)]
    for path in paths:
        status = subprocess.run(["git", "-C", str(root), "show", ":" + path], capture_output=True)
        if status.returncode:  # A staged deletion has no index blob.
            continue
        if any(re.search(pattern, status.stdout.decode(errors="replace")) for pattern in SECRETS):
            bad.append(path + "（疑似凭据，未显示内容）")
    if bad:
        raise SystemExit("不允许发布这些暂存内容：\n" + "\n".join(bad))
    print(f"发布范围检查通过：{len(paths)} 个暂存文件；仍需核对 diff、提交身份和目标 remote。")


if __name__ == "__main__":
    main()
