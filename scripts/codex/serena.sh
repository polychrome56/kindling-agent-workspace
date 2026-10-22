#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
runtime="$root/.local/codex"
if [[ ! -x "$runtime/venv/bin/serena" ]]; then
  echo "尚未安装项目索引工具，请在根目录运行：bash scripts/codex/setup.sh" >&2
  exit 1
fi
# 本机生成的工具链路径，不进入版本控制。
if [[ -f "$runtime/go.env" ]]; then source "$runtime/go.env"; fi
export PATH="$runtime/bin:$PATH"
export SERENA_HOME="$runtime/serena"
export XDG_CACHE_HOME="$runtime/cache"
export GOCACHE="$runtime/go-cache"
export SERENA_USAGE_REPORTING=false
cd -- "$root"
exec "$runtime/venv/bin/serena" "$@"
