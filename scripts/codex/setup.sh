#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo '用法：bash scripts/codex/setup.sh [--build-dir DIR] [--extra-db JSON]'
  echo '安装固定版本 Serena 到 .local/codex；需要 uv、Python3 和 Go >=1.23。'
  echo 'CODEX_GO_BINARY 可指定 Go；有可用的 gopls v0.20.0 时复用，否则安装到本地。'
  exit 0
fi
command -v uv >/dev/null || { echo '请先安装 uv：https://docs.astral.sh/uv/getting-started/installation/' >&2; exit 1; }
command -v python3 >/dev/null || { echo '需要 python3' >&2; exit 1; }
go_binary="${CODEX_GO_BINARY:-$(command -v go || true)}"
[[ -x "$go_binary" ]] || { echo '需要 Go >=1.23；可用 CODEX_GO_BINARY 指定。' >&2; exit 1; }
runtime="$root/.local/codex"
mkdir -p "$runtime/bin"
# 避免继承与所选 go 二进制不匹配的 GOROOT。
python3 - "$go_binary" "$runtime/go.env" <<'PY'
import os,re,shlex,subprocess,sys
from pathlib import Path
binary=Path(sys.argv[1]).resolve()
prefix=binary.parent.parent
env=dict(os.environ)
if (prefix/'src/runtime').is_dir():env['GOROOT']=str(prefix)
result=subprocess.check_output([str(binary),'version'],env=env,text=True)
version=re.search(r'go(\d+)\.(\d+)',result)
if not version or tuple(map(int,version.groups()))<(1,23):
 raise SystemExit('需要 Go >=1.23，当前：'+result.strip()+'；请设置 CODEX_GO_BINARY')
goroot=env.get('GOROOT') or subprocess.check_output([str(binary),'env','GOROOT'],env=env,text=True).strip()
Path(sys.argv[2]).write_text('export GOROOT='+shlex.quote(goroot)+'\nexport PATH='+shlex.quote(str(binary.parent))+':"$PATH"\n')
print(result.strip())
PY
source "$runtime/go.env"
export UV_CACHE_DIR="$runtime/uv-cache"
export UV_PYTHON_INSTALL_DIR="$runtime/python"
export GOCACHE="$runtime/go-cache"
if [[ ! -x "$runtime/venv/bin/python" ]]; then
  uv venv --python 3.13 "$runtime/venv"
fi
uv pip install --python "$runtime/venv/bin/python" -r "$root/config/codex/requirements.txt"
if [[ ! -x "$runtime/bin/gopls" ]]; then
  existing="$(command -v gopls || true)"
  if [[ -n "$existing" ]] && "$existing" version | grep -q 'v0\.20\.0'; then
    ln -s -- "$existing" "$runtime/bin/gopls"
  else
    GOBIN="$runtime/bin" GOMODCACHE="$runtime/go-mod-cache" go install golang.org/x/tools/gopls@v0.20.0
  fi
fi
python3 "$root/scripts/codex/export_compile_commands.py" "$@"
bash "$root/scripts/codex/serena.sh" --help >/dev/null
printf '%s\n' '安装完成。重启 Codex 后检查 /mcp 中的 serena。' 'clangd 由 Serena 管理，首次启动 C/C++ 服务时可能下载。' '首次索引预热（可选）：bash scripts/codex/serena.sh project index'
