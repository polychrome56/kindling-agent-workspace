---
description: 使用 workspace-git-publisher 安全提交或发布当前 workspace
---

# 发布 Workspace

请调用 `workspace-git-publisher` sub-agent 来处理用户请求，不要由当前主 Agent 直接执行 commit、push 或 GitHub 仓库创建。

用户请求：

```text
$ARGUMENTS
```

如果用户没有提供参数，默认意图是“提交当前状态”。执行时必须遵守：

1. 只处理 `kindling-agent-workspace` 这个协作配置资产仓库。
2. 按 `workspace-git-publisher` 的说明读取它引用的 skill 和 rule。
3. 提交或推送前先完成安全检查，并向用户展示待确认信息。
4. 等用户明确确认后，才允许创建 commit、配置 remote、创建 GitHub 仓库或 push。
5. 绝不提交 `agent-libs/`、`kindling/`、`config/git-publish.env`、`.env*`、私钥、token 或凭据文件。
6. 不输出 `GH_TOKEN` 原文；只报告是否已配置。
