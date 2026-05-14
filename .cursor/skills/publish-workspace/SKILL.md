---
name: publish-workspace
description: workspace-git-publisher sub-agent 专用的 GitHub 发布流程说明。不要作为全局自动触发 skill 使用。
disable-model-invocation: true
---

# 发布 Workspace

这个 skill 只用于 `kindling-agent-workspace`，也就是 CC / Cursor 协作配置资产仓库。

它不是全局 skill，只供 `.cursor/agents/workspace-git-publisher.md` 中的 `workspace-git-publisher` sub-agent 采用。用户要求发布本仓库时，入口应是 `workspace-git-publisher` sub-agent，而不是直接触发本 skill。

## 本地配置

如果存在 `config/git-publish.env`，可以读取其中的本地配置。这个文件必须保持未追踪状态。

需要的变量：

```bash
GITHUB_OWNER=your-github-user-or-org
GITHUB_REPO=kindling-agent-workspace
GITHUB_VISIBILITY=private
GIT_REMOTE_NAME=origin
```

可选变量：

```bash
GIT_AUTHOR_NAME=your-git-author-name
GIT_AUTHOR_EMAIL=your-git-author-email
GH_TOKEN=your-temporary-token
```

`GIT_AUTHOR_NAME` 与 `GIT_AUTHOR_EMAIL` 只用于本次提交身份确认；留空时读取仓库或系统 git config。`GH_TOKEN` 只允许放在被忽略的 `config/git-publish.env` 中，供 `gh` 或 git over HTTPS 读取；不要在本仓库保存真实 GitHub token。

## 安全检查清单

执行任何 commit、push 或 `gh repo create` 前：

1. 确认 workspace 根目录是 `kindling-agent-workspace`。
2. 读取 `config/git-publish.env`（如果存在），并只把它作为本地配置使用。
3. 运行 `git status --short`。
4. 查看已暂存和未暂存 diff。
5. 确认 `config/git-publish.env`、`.env*`、私钥和 token 没有被暂存。
6. 确认提交身份、GitHub owner/repo、remote 名称、remote URL 和仓库可见性是否符合用户预期。
7. 遇到 force push 或破坏性 git 命令前，必须停止并询问用户。
8. 文档、规则、skill、sub-agent 和 hook 的用户提示文案默认使用中文；命令、变量名和工具字段保持原样。

## 发布流程

如果仓库还没有初始化：

```bash
git init
git branch -M main
```

只暂存仓库资产，不暂存被忽略的源码目录：

```bash
git add README.md .gitignore .cursor config/git-publish.env.example
```

根据本次 diff 自动生成简短 commit message，并在执行 `git commit` 前向用户展示确认信息：

- 将要提交的文件列表和变更摘要。
- 拟定的 commit message。
- 使用的提交用户名和邮箱。
- GitHub owner/repo、remote 名称、remote URL 与可见性。
- 是否检测到 `GH_TOKEN`，只报告“已配置/未配置”，不要输出 token 内容。

只有用户明确确认后，才允许执行 `git commit` 和后续 `git push`。如果用户要求调整 commit message、提交身份或 remote 配置，应先调整并再次确认。

如果 `GIT_AUTHOR_NAME` 和 `GIT_AUTHOR_EMAIL` 都已配置，提交时使用一次性环境变量，不修改全局 git config：

```bash
GIT_AUTHOR_NAME="$GIT_AUTHOR_NAME" GIT_AUTHOR_EMAIL="$GIT_AUTHOR_EMAIL" \
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
git commit -m "$COMMIT_MESSAGE"
```

如果提交身份配置为空，则直接使用当前仓库或系统 git config 执行 `git commit -m "$COMMIT_MESSAGE"`，并在确认信息里如实展示读取到的用户名和邮箱。

首次发布优先使用 GitHub CLI：

```bash
gh auth status
gh repo create "$GITHUB_OWNER/$GITHUB_REPO" --"$GITHUB_VISIBILITY" --source=. --remote="${GIT_REMOTE_NAME:-origin}" --push
```

如果没有 `gh`，请让用户先创建空 GitHub 仓库，然后使用：

```bash
git remote add "${GIT_REMOTE_NAME:-origin}" "https://github.com/$GITHUB_OWNER/$GITHUB_REPO.git"
git push -u "${GIT_REMOTE_NAME:-origin}" main
```

## 结果汇报

完成后必须向用户汇报：

- commit 是否成功；成功时给出 commit SHA 和 commit message。
- push 是否成功；成功时给出 remote、branch 和 GitHub 仓库地址。
- 本次使用的提交用户名和邮箱。
- 使用的 GitHub owner/repo、remote 名称和可见性。
- `GH_TOKEN` 是否参与认证，但绝不输出 token 内容。
