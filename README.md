# kindling-agent-workspace

这是一个给 **Cursor / Claude Code（CC）** 使用的 Agent 协作配置资产仓库，用来沉淀可复用的 rule、skill、sub-agent、command 和 hook。

本仓库不是业务源码仓库。`agent-libs/`、`kindling/` 这类目录可以作为本地工作区源码存在，但它们属于用户自行放入的业务代码，默认被 `.gitignore` 排除，不应提交到本仓库。

## 它解决什么问题

1. **继承之前好的 prompt**
   把在过往项目里调试出来、被验证有效的 system prompt、协作原则、风格约束沉淀下来，下一个新项目直接挂上即可，不用从零开始反复试。

2. **节省 token**
   通用约束统一放进 `alwaysApply: true` 的 rule、专用 skill、sub-agent 或 command，避免每次对话再把背景、约定、风格手动贴一遍。

3. **更安全**
   通过 rule 与 hook 显式限制模型的工具调用范围、危险操作（批量 `rm`、`git push --force`、改 `~/.ssh` 等），把"该不该做"的判断从 prompt 里前置到配置里。

4. **Cursor / CC 双栈复用**
   两种工具的配置可以并存于同一目录，便于团队在两者之间切换或同时使用，也方便把一份协作约定迁移到不同 Agent 工具。

## 设计原则：仓库只保留规则与新特性，不带业务代码

> 工作区下可以存在 `agent-libs/`、`kindling/` 这类子项目源码目录，但它们属于
> **用户自行拷贝进来的业务代码**，不属于本 git 仓库的内容。

只保留 Cursor / CC 用得到的"协作配置类"内容，典型包括：

- **Cursor 侧**：`.cursor/rules/`、`.cursor/agents/`、`.cursor/commands/`、`.cursor/hooks/`、`.cursor/skills/` 等。
- **Claude Code 侧**：`CLAUDE.md`、`AGENTS.md`、`.claude/agents/`、`.claude/commands/`、`.claude/hooks/` 等需要时再添加。

这样做的好处：

- **下载体积小**：分发只带规则文件，不带源码与构建产物。
- **不与业务仓库强耦合**：每个子目录的规则可以被对应业务仓库以 submodule、拷贝或软链方式引入。
- **聚焦 Agent 协作经验本身**：规则更新与业务代码演进解耦，不会被某次具体实现绑死。

## 当前目录

```text
kindling-agent-workspace/
├─ README.md
├─ .gitignore
├─ config/
│  └─ git-publish.env.example                 # 本地发布配置模板
├─ .cursor/
│  ├─ agents/
│  │  └─ workspace-git-publisher.md           # 发布本 workspace 的专用 sub-agent
│  ├─ commands/
│  │  └─ publish-workspace.md                 # 调用发布 sub-agent 的命令入口
│  ├─ hooks.json                              # Cursor hook 配置
│  ├─ hooks/
│  │  └─ protect-workspace-publish.sh         # git / gh 操作前的安全检查
│  ├─ skills/
│  │  ├─ git-commit-message/
│  │  │  └─ SKILL.md                          # Conventional Commits + 中文提交说明
│  │  ├─ kindling-project-map/
│  │  │  └─ SKILL.md                          # kindling / agent-libs 项目结构地图
│  │  ├─ modern-cpp/
│  │  │  └─ SKILL.md                          # C/C++ 工程实践辅助
│  │  ├─ traffic-forwarding/
│  │  │  └─ SKILL.md                          # 流量转发路径 / 防环 / 排障骨架
│  │  └─ publish-workspace/
│  │     └─ SKILL.md                          # workspace-git-publisher 专用发布流程
│  └─ rules/
│     ├─ workspace-overview.mdc               # workspace 级 alwaysApply 放置约定
│     ├─ agent-rules/
│     │  └─ workspace-git-publish.mdc         # 发布 sub-agent 专用规则
│     ├─ agent-libs/
│     │  └─ bpf-kernel-tc-conventions.mdc     # agent-libs 专属规则
│     └─ kindling/
│        ├─ collaboration-principles.mdc      # kindling 协作规则
│        └─ cpp-engineering.mdc               # kindling C/C++ 工程规则
├─ docs/
│  └─ traffic-forwarding/                     # 流量转发协作文档（可提交）
├─ agent-libs/                                # 本地源码目录，git 不跟踪
└─ kindling/                                  # 本地源码目录，git 不跟踪
```

`config/git-publish.env` 是本地发布配置文件，已被 `.gitignore` 忽略；只提交 `config/git-publish.env.example`。

## 资产分层

| 路径 | 用途 |
| --- | --- |
| `.cursor/rules/*.mdc` | 跨整个 workspace 生效的通用规则，可使用 `alwaysApply: true`。 |
| `.cursor/rules/agent-rules/*.mdc` | 只供特定 sub-agent 显式引用，不作为全局规则。 |
| `.cursor/rules/agent-libs/*.mdc` | 只面向 `agent-libs/`，必须用 `globs` 限定范围。 |
| `.cursor/rules/kindling/*.mdc` | 只面向 `kindling/`，必须用 `globs` 限定范围。 |
| `.cursor/skills/*/SKILL.md` | 可复用的任务技能；专用 skill 应在说明中标明触发边界。 |
| `.cursor/agents/*.md` | Cursor 项目级 sub-agent 定义。 |
| `.cursor/commands/*.md` | 面向用户的 Cursor command 入口。 |
| `.cursor/hooks/*` | 操作前后的安全检查或自动化脚本。 |
| `docs/traffic-forwarding/` | 流量转发协作长文（可提交）；配合 `traffic-forwarding` skill。 |

子项目专属规则不要设置 `alwaysApply: true`，必须靠 `globs` 约束到对应目录。不要在 `agent-libs/` 或 `kindling/` 子项目里再建 `.cursor/rules/`；规则统一放在 workspace 根的 `.cursor/rules/`。

## 如何使用

1. 如需让规则作用于 `agent-libs/` 或 `kindling/`，先把对应业务仓库源码放到 workspace 根下同名目录。
2. 在 Cursor / CC 中以 `kindling-agent-workspace` 为根打开，Cursor 会按 `.cursor/rules/` 中的 `alwaysApply` 和 `globs` 加载规则。
3. 修改 README、rule、skill、sub-agent、hook 提示文案时，默认优先使用中文；命令、配置键、环境变量和工具字段保持原样。
4. 新增通用规则放 `.cursor/rules/` 根级；新增子项目规则放对应子目录并配置 `globs`；新增 sub-agent 专用规则放 `.cursor/rules/agent-rules/` 并由 sub-agent 显式 `@` 引用。
5. 如需兼容 Claude Code，可按需要新增 `CLAUDE.md`、`AGENTS.md` 或 `.claude/` 资产；当前仓库主要资产集中在 Cursor 目录。

## 发布到 GitHub

发布本 workspace 时，优先使用 `.cursor/commands/publish-workspace.md` 或直接调用 `.cursor/agents/workspace-git-publisher.md` 中的 `workspace-git-publisher` sub-agent。

发布链路包括：

- `.cursor/agents/workspace-git-publisher.md`：负责检查 git 状态、确认提交身份、remote 和 GitHub 仓库信息。
- `.cursor/skills/publish-workspace/SKILL.md`：发布 sub-agent 专用流程，不作为全局自动触发 skill。
- `.cursor/rules/agent-rules/workspace-git-publish.mdc`：发布 sub-agent 专用安全约束。
- `.cursor/hooks/protect-workspace-publish.sh`：在 `git` / `gh` 命令前拦截源码目录、个人配置和疑似密钥。

首次发布前可复制本地配置：

```bash
cp config/git-publish.env.example config/git-publish.env
```

常用变量：

```bash
GITHUB_OWNER=your-github-user-or-org
GITHUB_REPO=kindling-agent-workspace
GITHUB_VISIBILITY=private
GIT_REMOTE_NAME=origin
GIT_AUTHOR_NAME=your-git-author-name
GIT_AUTHOR_EMAIL=your-git-author-email
GH_TOKEN=your-temporary-token
```

`config/git-publish.env` 只能作为本机配置使用，不要提交。`GH_TOKEN` 如需临时使用，也只能放在这个被忽略的本地文件中；不要输出 token 原文或写入被版本控制追踪的文件。

无论使用 `gh` 还是手动配置 remote，都不要提交 `agent-libs/`、`kindling/`、`config/git-publish.env`、`.env*`、token、私钥或其它凭据。

## 不做的事

- 不在本仓库提交业务代码、构建产物、二进制或 IDE 缓存。
- 不把本地个人配置、GitHub token、私钥或临时凭据提交进来。
- 不让子项目专属规则全局生效。
- 不把 Cursor / CC 的私有约定混进同一个文件；需要双栈复用时，按各自目录约定分别维护。
