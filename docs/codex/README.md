# Codex 项目配置与代码索引

这些配置随根仓库提交。团队成员克隆后，以 `kindling-agent-workspace` 为根打开 Codex，技能即可被发现；首次使用代码索引时运行安装脚本。

## 技能、规则与 MCP 的区别

- `AGENTS.md`：每次进入工作区时的共同约定，包含仓库边界、语言、修改和验证要求。
- `.agents/skills/*/SKILL.md`：按任务加载的技能，可以在 Codex 中输入 `$` 选择。
- `.agents/references/`：从 Cursor 的专项规则迁移的工程约定，由 AGENTS/技能按需引用。
- `.codex/config.toml`：项目级 MCP 配置。Serena 是实际提供符号查询工具的本地进程。
- `.serena/project.yml`：共享索引配置；本机路径和编译参数不写进这个文件。

技能告诉 Agent 怎样工作；MCP 给它查询定义、引用等能力。Serena 使用语言服务的符号分析，不是 Cursor 的 embedding 语义搜索，也不能保证找到宏、跨语言注册或未编译代码中的所有关系。

## 首次安装

依赖：Bash、Python3、[uv](https://docs.astral.sh/uv/getting-started/installation/)、Go >=1.23。若从已有 Ninja 构建导出编译命令，还需要 Ninja。

在根目录运行：

```bash
bash scripts/codex/setup.sh --build-dir /path/to/kindling/probe/build
```

没有业务源码/构建目录时也可先安装：

```bash
bash scripts/codex/setup.sh
```

脚本会：

1. 在忽略的 `.local/codex/` 下安装 Python 环境与固定版本 `serena-agent==2.1.0`。
2. 使用指定 Go 工具链；已有 `gopls v0.20.0` 时复用，否则安装到本地目录。
3. 从已有 CMake 编译数据库或 Ninja 编译规则导出参数，不执行 CMake 配置、clean 或业务编译。
4. 保存本机工具路径、数据库与覆盖报告；不修改全局 Codex、Cursor、Git 或系统包配置。

Serena 首次启动 C/C++ 服务时会下载其管理的 clangd，需要网络。首次安装 uv/Python/Go/Serena 依赖同样需要网络；这不是无需依赖安装的离线索引。

如系统 Go 过旧，指定二进制：

```bash
CODEX_GO_BINARY=/path/to/go/bin/go bash scripts/codex/setup.sh \
  --build-dir /path/to/kindling/probe/build
```

之后重启 Codex 或重新加载扩展，信任本项目配置，在 `/mcp` 中检查 `serena` 是否连接。仅有 TOML 文件不代表当前已运行的会话立即获得工具；索引安装也不等于所有符号都已解析成功。

可选预热：

```bash
bash scripts/codex/serena.sh project index
```

首次索引可能占用 CPU/内存，按需执行；不要在性能基线采样时同时预热索引。日常代码变更由 Serena/语言服务更新索引。

## 选择业务版本和编译配置

默认安装脚本只在常见根目录或单层版本目录寻找 `kindling/probe` 已有构建。多个业务版本都有构建时，要求用 `--build-dir` 明确选择，不混在一起猜测。

```bash
python3 scripts/codex/export_compile_commands.py \
  --build-dir /path/to/selected/kindling/probe/build
```

输出到根目录 `compile_commands.json`，覆盖说明写入 `.local/codex/coverage.json`。已有数据库不会被无参数运行覆盖，显式传入构建目录才刷新。

首次导出会根据真实源码位置生成忽略的 `.serena/project.local.yml`，已有文件保持不动。可自行指定当前版本：

```yaml
ls_workspace_folders:
  - "4.1.0/agent-libs"
  - "4.1.0/kindling/probe"
  - "4.1.0/kindling/collector"
```

若源码就在根目录，去掉 `4.1.0/`。这些路径必须实际存在；切换版本后调整本地配置、重新导出编译数据库并重启 Serena。

根仓库 `.gitignore` 排除业务源码，Serena 则设置 `ignore_all_files_in_gitignore: false` 并单独排除缓存、构建产物等，否则 Git 忽略规则也会使业务源码完全不参与检索。

### BPF、Lua 和 CGO 的边界

普通 probe 构建通常不包含独立的 BPF 编译和未启用的 Lua/chisel 文件。导出脚本会报告这些缺口，不会把覆盖范围说成全部源码。

可以追加已有的真实编译数据库：

```bash
python3 scripts/codex/export_compile_commands.py \
  --build-dir /path/to/probe/build \
  --extra-db /path/to/bpf/compile_commands.json \
  --extra-db /path/to/lua-enabled/compile_commands.json
```

- 每个数据库的 `directory` 应是该命令实际执行的绝对目录，不能随意把内核头路径换成当前目录。
- BPF 必须使用目标内核头、架构和宏。raw/non-raw 是不同编译视图；同一文件只保留一个视图，另一个需切换参数后单独核对。
- CGO、Lua 字符串注册和宏展开不能假定形成完整的跨语言调用图。索引之外仍需定向补查；“零引用”不是删代码的充分依据。
- 构建宏或依赖路径变化后，重新导出数据库。旧参数下的索引不能证明新构建行为。

## 从 Cursor 迁移的内容

原 `.cursor/` 保留不变。Codex 技能包括：

- `concrete-technical-explanation`：保留原解释方法。
- `git-commit-message`：保留中文 Conventional Commits 约定。
- `kindling-project-map`：保留分层地图，增加版本根路径辨认。
- `modern-cpp`：保留原专项工作流，规则引用改为 Codex 路径。
- `traffic-forwarding`：保留流量转发骨架和现有文档入口。
- `publish-workspace`：改成 Codex 的显式调用入口，使用 `agents/openai.yaml` 的 `allow_implicit_invocation: false`。
- `code-navigation`：新增符号索引工作流和覆盖范围核对。

Cursor 的 alwaysApply 约定进入根 AGENTS；globs 限定的专项规则进入 `.agents/references/`，由 AGENTS 按业务类型加载。不是把所有 C++ 规则无条件套在内核 C 上。

Cursor command 对应 Codex 的 `$publish-workspace`，没有复制 `/publish-workspace` 的私有语法。原 Cursor sub-agent 的 composer 模型和 `beforeShellExecution` hook 也没有假装成 Codex 配置；Codex 发布技能调用独立的只读检查脚本实现发布前检查。

Cursor 与 Codex 的技能分别维护；改动某一套约定时应判断是否也适用于另一套，不自动删除或覆盖原文件。

## 发布本框架仓库

只提交 `AGENTS.md`、`.agents/`、`.codex/config.toml`、`.serena/project.yml`、`scripts/`、依赖版本、README 等协作资产。不提交业务源码、本机绝对路径、编译数据库、缓存或现场资料。

检查暂存内容：

```bash
python3 scripts/codex/check_workspace_publish.py
```

Codex 中显式使用 `$publish-workspace`。检查脚本不创建提交、不推送，也不是已安装的自动 hook；它不替代人工核对 diff、提交身份和 remote。无需安装这套索引，也可以使用迁移的技能。

## 上游依据

- [Codex 项目技能位置和格式](https://learn.chatgpt.com/docs/build-skills)
- [Codex 项目级 MCP 配置](https://learn.chatgpt.com/docs/extend/mcp)
- [Serena 的 Codex 接入](https://oraios.github.io/serena/02-usage/030_clients)
- [Serena 项目索引与本地覆盖](https://oraios.github.io/serena/02-usage/040_workflow.html)
- [clangd 编译命令和索引](https://clangd.llvm.org/installation)
