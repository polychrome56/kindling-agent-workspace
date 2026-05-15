---
name: git-commit-message
description: 生成、修改或检查 Git commit message，并按团队约定使用 Conventional Commits 与中文提交说明。Use when the user asks to create a git commit, write or refine a commit message, review staged changes, summarize git diffs for commit, or mentions feat, fix, chore, Conventional Commits, 提交信息, 提交说明, git commit, staged changes.
---

# Git 提交信息

## 触发场景

仅在用户请求与 Git 提交直接相关时使用本 skill，例如创建提交、编写提交信息、整理 staged changes、根据 diff 生成 commit message、检查提交标题是否规范。

日常问答、代码阅读、普通实现任务、PR 之外的说明文案，不要主动套用或提醒本提交格式。

## 提交格式

默认使用 Conventional Commits：

```text
type(scope): 中文描述
```

- `type` 使用小写英文，优先选择：`feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`。
- 标题用中文说明改动目的，避免只罗列文件名。
- `scope` 可选；只有能提升可读性时才加。
- 需要正文时，正文也使用中文，说明为什么改、影响范围、验证方式或风险。
- 不要使用 `update`、`misc`、`wip` 这类含义模糊的类型。
- 若用户写了 `chrome` 作为类型，先判断是否实际想表达标准类型 `chore`；除非确实是 Chrome 浏览器相关改动，否则使用 `chore`。

## 示例

```text
feat: 增加工作区发布命令
fix(kindling): 修复虚拟网卡关闭时的资源泄漏
docs: 补充 Git 发布配置说明
chore: 调整 Cursor 规则目录结构
```
