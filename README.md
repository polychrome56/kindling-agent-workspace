# kindling-agent-workspace

为 **Claude Code（CC）** 与 **Cursor** 等主流 Coding Agent 提供 *可继承、可复用* 的
**prompt / rule / sub-agent 资产仓库**。

本工作区不是一个传统业务代码仓库，而是一个"Agent 协作配置"的集中存放点。

---

## 它解决什么问题

1. **继承之前好的 prompt**
   把在过往项目里调试出来、被验证有效的 system prompt、协作原则、风格约束沉淀下来，
   下一个新项目直接挂上即可，不用从零开始反复试。

2. **节省 token**
   通用约束统一放进 `alwaysApply: true` 的 rule（Cursor）/ `CLAUDE.md`（CC），
   避免每次对话再把背景、约定、风格手动贴一遍。

3. **更安全**
   通过 rule 与 hook 显式限制模型的工具调用范围、危险操作（批量 `rm`、
   `git push --force`、改 `~/.ssh` 等），把"该不该做"的判断从 prompt 里前置到配置里。

4. **CC / Cursor 双栈复用**
   两种工具的配置可以并存于同一目录，便于团队在两者之间切换或同时使用，
   也方便把一份规则同时分发到两种 Agent 工具。

---

## 设计原则：仓库只保留规则与新特性，不带业务代码

> 工作区下可以存在 `agent-libs/`、`kindling/` 这类子项目源码目录，但它们属于
> **用户自行拷贝进来的业务代码**，不属于本 git 仓库的内容。

只保留 CC / Cursor 用得到的"协作配置类"内容，典型包括：

- **Cursor 侧**
  - `.cursor/rules/*.mdc` — 项目级规则（支持 `globs` / `alwaysApply`）
  - `.cursor/agents/` — Cursor 项目级 sub-agents
  - `.cursor/commands/`、`.cursor/hooks/`、`.cursor/skills/` 等新特性目录
- **Claude Code 侧**
  - `CLAUDE.md` / `AGENTS.md` — 项目级常驻指令
  - `.claude/agents/` — Claude Code 兼容的 sub-agents 定义（需要时再添加）
  - `.claude/commands/`、`.claude/hooks/` 等新特性目录

这样做的好处：

- **下载体积小**：分发只带规则文件，不带源码与构建产物；
- **不与业务仓库强耦合**：每个子目录的规则可以被对应业务仓库以 submodule / 拷贝 / 软链方式引入；
- **聚焦 Agent 协作经验本身**：规则更新与业务代码演进解耦，不会被某次具体实现绑死。

---

## 目录结构

```text
kindling-agent-workspace/
├─ .gitignore                                  # 忽略源码目录与本地个人配置
├─ README.md                                  # 本文件
├─ .cursor/
│  ├─ agents/
│  │  └─ workspace-git-publisher.md           # Cursor 发布 sub-agent
│  ├─ hooks.json                              # Cursor hook 配置
│  ├─ hooks/
│  │  └─ protect-workspace-publish.sh         # 发布前安全检查
│  ├─ skills/
│  │  └─ publish-workspace/
│  │     └─ SKILL.md                          # 发布 sub-agent 专用 skill
│  └─ rules/
│     ├─ workspace-overview.mdc               # workspace 级 alwaysApply：放置约定
│     ├─ agent-rules/
│     │  └─ workspace-git-publish.mdc         # 发布 sub-agent 专用规则（非全局）
│     ├─ agent-libs/
│     │  └─ bpf-kernel-tc-conventions.mdc     # globs: agent-libs/driver/**
│     └─ kindling/
│        └─ collaboration-principles.mdc      # globs: kindling/**
├─ config/
│  └─ git-publish.env.example                 # 本地发布配置模板
├─ agent-libs/                                # 用户自行拷贝进来的源码目录（git 不带）
└─ kindling/                                  # 用户自行拷贝进来的源码目录（git 不带）
```

所有规则集中放在 workspace 根 `.cursor/rules/`，按"作用对象"用子目录分类。
子项目目录里**不再放** `.cursor/rules/`。

---

## 规则分层（按作用对象分子目录）

| 路径                                       | 作用范围                                          |
| ------------------------------------------ | ------------------------------------------------- |
| `.cursor/rules/*.mdc`                      | 跨所有子项目通用，可 `alwaysApply: true`          |
| `.cursor/rules/agent-rules/*.mdc`         | 只供对应 sub-agent，通常 `alwaysApply: false`，由 `.cursor/agents/` 定义 `@` 引用（与 agent 定义目录区分） |
| `.cursor/rules/agent-libs/*.mdc`           | 只对 `agent-libs/`，必须配 `globs: agent-libs/**` |
| `.cursor/rules/kindling/*.mdc`             | 只对 `kindling/`，必须配 `globs: kindling/**`     |

**约束**：子项目专属规则禁止开 `alwaysApply: true`，必须靠 `globs` 限定路径，
否则会污染其它子项目。

> 取舍说明：所有规则集中在 workspace 根的代价是——若**单独打开** `agent-libs/` 或
> `kindling/` 这两个 git 仓库作为工作区，本仓库的规则不会被加载。如需在那种场景也生效，
> 请改用 git submodule 或软链方式把对应规则带入对应仓库。

---

## 如何使用

1. **先准备源码目录**：如需让规则作用于 `agent-libs/` 或 `kindling/`，请先把对应业务仓库源码
   自行拷贝到这两个目录；它们不是本仓库自带内容。
2. **作为 workspace 打开**：在 Cursor / CC 里直接以本目录为根打开，
   `.cursor/rules/` 下的所有规则会按各自的 `globs` / `alwaysApply` 被自动加载。
3. **新增规则的位置选择**：
   - 通用约束 → `.cursor/rules/` 根级，`alwaysApply: true`
   - sub-agent 专用 → `.cursor/rules/agent-rules/`，`alwaysApply: false`，并在对应 `.cursor/agents/*.md` 里 `@` 引用
   - 子项目专属 → `.cursor/rules/<sub>/`，**必须**配 `globs: <sub>/**`，不要开 `alwaysApply: true`
4. **新增 sub-agent**：Cursor 项目级 sub-agent 放到 `.cursor/agents/`，
   按用途命名（如 `workspace-git-publisher.md`）。如需兼容 Claude Code，再额外放到 `.claude/agents/`。

---

## 发布到 GitHub

本仓库提供专门的 Cursor 发布 sub-agent，用来把 **kindling-agent-workspace 本身**提交到 GitHub：

- 入口：使用 `.cursor/agents/workspace-git-publisher.md` 中的 `workspace-git-publisher` sub-agent。
- 专用 skill：`.cursor/skills/publish-workspace/SKILL.md`，只供 `workspace-git-publisher` 采用，不作为全局自动触发 skill。
- 专用 rule：`.cursor/rules/agent-rules/workspace-git-publish.mdc`，只供 `workspace-git-publisher` 采用，不作为全局 alwaysApply 规则。
- 安全保护：`.cursor/hooks/protect-workspace-publish.sh` 会在 agent 执行 git / gh 命令前拦截源码目录、个人配置和疑似密钥。

首次发布前，先准备本地配置：

```bash
cp config/git-publish.env.example config/git-publish.env
```

然后在 `config/git-publish.env` 里填写：

```bash
GITHUB_OWNER=your-github-user-or-org
GITHUB_REPO=kindling-agent-workspace
GITHUB_VISIBILITY=private
GIT_REMOTE_NAME=origin
```

`config/git-publish.env` 已被 `.gitignore` 忽略，里面可以放个人 GitHub owner、仓库名和可见性；不要在里面放 token。GitHub 认证请使用 `gh auth login` 或本机已有的 git 凭据管理。

发布助手会优先使用 GitHub CLI：

```bash
gh repo create "$GITHUB_OWNER/$GITHUB_REPO" --"$GITHUB_VISIBILITY" --source=. --remote="${GIT_REMOTE_NAME:-origin}" --push
```

如果没有 `gh`，就先在 GitHub 网页创建空仓库，再添加远程并推送：

```bash
git branch -M main
git remote add "${GIT_REMOTE_NAME:-origin}" "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git"
git push -u "${GIT_REMOTE_NAME:-origin}" main
```

无论哪种方式，都不要提交 `agent-libs/`、`kindling/`、`config/git-publish.env`、`.env*`、token 或私钥。

---

## 不做的事

- 不在本仓库放业务代码、构建产物、二进制。
- 不在子项目目录里再建 `.cursor/rules/`——规则一律放 workspace 根。
- 不把不同 Agent 工具的私有约定混进同一个文件，CC 与 Cursor 各走各自的目录约定。
- 不提交个人 GitHub 账号配置、访问 token、私钥或本地发布配置。
