# Codex 工作区约定

本仓库保存 Agent 协作配置，不保存业务源码。以本目录为根使用 Codex；不要把嵌套业务仓库当成本仓库的一部分提交。

## 语言与协作

- 默认使用自然、简洁的中文。标识符、API、命令和配置键保留原文；措辞细节见 [.agents/references/chinese-natural-wording.md](.agents/references/chinese-natural-wording.md)。
- 先核实真实代码和调用关系再解释。区分事实、推断与未验证部分；被质疑时重新检查证据。
- 按用户授权范围完成工作。沿用已有流程，额外重构、兼容性变更、性能优化单独提出，不混入当前实现。
- 关键歧义才询问，已有明确授权不重复确认。验证强度服从用户要求；用户只要求静态检查时，不新增或运行测试。

## 仓库与路径

- 业务源码可能位于 `agent-libs/`、`kindling/`，也可能位于 `4.1.0/`、`ahyd/` 等版本目录。先确定目标版本及每个仓库的 Git 根目录。
- 使用 `git -C <目标仓库>` 核对状态与 diff。不要擅自创建分支、提交、推送、覆盖用户改动、替换运行文件或重启服务。
- 源码、构建产物、现场 profile、索引缓存、本地配置和凭据不属于本配置仓库。禁止在根仓库执行 `git add .` 或 `git add -A`，按文件明确暂存。
- 通用约定放本文件；专项规则放 `.agents/references/`；可复用技能放 `.agents/skills/`；项目 MCP 放 `.codex/config.toml`。
- 保留 `.cursor/` 的独立格式，不让 Codex 自动迁移或删除 Cursor 资产。两套约定需要有意识地同步。

## 代码检索与修改

- 修改业务代码时使用 `$code-navigation`：先确认 Serena 项目与索引范围，用符号工具查询定义和引用，再阅读完整函数与相关调用方。
- MCP 未连接、索引不完整或语言服务报错时如实说明，使用文本搜索补查，不把检索失败当成无调用证据。
- 修改字段或接口时同时核对声明、实现、导出、调用、构造/默认初始化、open 后配置和错误路径；检查整个 diff 的语义。
- 内核宏、未参与当前编译的文件、Lua 字符串入口和 CGO 边界可能不在符号引用结果内，需要定向补查。不要仅凭引用数为零删除接口。
- 只在明确的完整函数/代码块中编辑；字符串替换必须确认所有命中位置，不能把相同赋值误改到 stop/start 等其他函数。
- 验证只报告实际完成的范围；语法通过不代表行为、默认值或现场 BPF 加载已验证。

## 按任务加载

- 阅读/修改项目代码：`.agents/skills/kindling-project-map/SKILL.md`。
- kindling 协作分析：`.agents/references/collaboration-principles.md`。
- 用户态 C/C++：`.agents/references/cpp-engineering.md`，必要时用 `$modern-cpp`；不要把现代 C++ 约定套到内核 C。
- `agent-libs/driver/` 的 kernel/BPF/tc：`.agents/references/bpf-kernel-tc-conventions.md`。
- 流量镜像/防环：`$traffic-forwarding`；需要解释机制时用 `$concrete-technical-explanation`。
- 提交信息：`$git-commit-message`。提交/发布本配置仓库：显式使用 `$publish-workspace`；先运行发布检查，不把业务仓库一起提交。

## 环境入口

- `bash scripts/codex/setup.sh`：安装本地索引组件，检查 Go 工具链，导出已有构建的编译数据库。
- `python3 scripts/codex/export_compile_commands.py --help`：指定构建目录或补充真实编译数据库。
- `bash scripts/codex/serena.sh project index`：可选的首次索引预热。
- 使用步骤、范围与限制见 [docs/codex/README.md](docs/codex/README.md)。
