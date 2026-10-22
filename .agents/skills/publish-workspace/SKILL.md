---
name: publish-workspace
description: 显式请求提交或发布 kindling-agent-workspace 协作配置仓库时使用；检查暂存范围、身份和远端，排除业务源码、索引缓存与凭据，不用于发布嵌套业务仓库。
---
# 提交或发布 Workspace

这是原 Cursor 发布技能的 Codex 适配。Codex 使用 `$publish-workspace` 作为入口；不依赖 Cursor 的 `/publish-workspace` 命令、composer 模型或 beforeShellExecution hook。

1. 确认 Git 根目录是本协作配置仓库；查看根仓库与嵌套业务仓库的状态，分清本次提交范围。
2. 查看 diff，明确暂存文件，不使用 `git add .`/`git add -A`。业务目录、`.local/`、索引数据库、现场资料、`config/git-publish.env` 和凭据不得提交。
3. 运行 `python3 scripts/codex/check_workspace_publish.py`；失败时修正暂存内容，不绕过检查。
4. 读取本地发布配置（如果存在）或 Git 配置，只报告 token 是否配置，绝不输出凭据。不要修改全局 Git 配置。
5. 根据实际 diff 使用 `$git-commit-message` 生成中文 Conventional Commit 标题。创建提交前展示文件列表、摘要、标题、提交身份和目标仓库；没有这些具体内容的授权时先获得确认，已有明确确认不重复询问。
6. 用户明确授权发布时再核对 remote、branch、GitHub owner/repo 及可见性，然后推送。不要把“准备提交”“给个提交名”当作 push 授权，不做 force push。
7. 如环境支持且用户授权委派，可交给专门的发布代理；否则直接遵守本技能流程。不要假定已安装 Cursor sub-agent 或 hook。

沿用 `config/git-publish.env.example`，本地配置不提交。需要指定身份时使用一次性环境变量，不把 token 拼入 URL 或命令输出。

发布检查脚本是显式检查，不是已自动挂载的 Codex hook。Cursor 既有 hook 保持原样，不能宣称它会自动拦截 Codex 的命令。

报告实际结果：提交 SHA/标题、是否推送、目标 remote/branch。未提交或未推送时明确说明。
