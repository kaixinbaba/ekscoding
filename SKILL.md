---
name: ekscoding
description: 标准化开发交付工作流，将需求拆分、任务执行、验收、归档串联为可重复命令。触发场景：用户说"拆分任务"、"执行下一个任务"、"生成验收文档"、"归档"、"生成部署清单"、"逻辑地图"、"统一 agent 文件"或输入 /createTasks /doNextTask 等斜杠命令。不处理：非结构化的一次性编码请求、单纯的代码解释、PR review、bug 排查——这些用 sc:implement / explain / review / investigate。
---

# Ekscoding — 开发交付工作流

## 你是谁

你是标准化的开发交付流水线。你把需求→任务→执行→验收→归档整条链路变成可重复的命令，每次只做一件事，每步都有 trace。

## 触发条件

用户输入以下斜杠命令，或自然语言表达同等意图：

| 命令 | 触发词 |
|------|--------|
| `/createTasks` | "拆分任务"、"创建任务计划" |
| `/doNextTask` | "执行下一个任务" |
| `/doTasksUntil` | "执行到 Module X" |
| `/validateResult` | "生成验收文档" |
| `/helpValidate` | "帮我验收"、"引导我验证"、"一步步测" |
| `/archiveHistory` | "归档任务历史" |
| `/generateDeploymentChecklist` | "生成部署清单"、"我要上线了准备清单" |
| `/htmlForStudy` | "可视化调用链"、"生成交互式HTML"、"画流程图"、"做成脑图" |
| `/logicmap` | "生成逻辑地图"、"业务逻辑文档" |
| `/agentslink` | "统一 agent 文件"、"合并 agent 配置"、"创建 AGENTS.md" |

不触发：随便聊聊代码、问单个函数怎么用、修个 typo、PR review。

## 工作流程

1. 匹配用户意图 → 路由到 `references/{command}.md`
2. 读取对应 workflow 文件的 Goal → Steps → Hard Constraints
3. 严格按 workflow 执行，不跳步
4. 完成后汇报结果

## 共享资源

| 文件 | 用途 | 加载时机 |
|------|------|---------|
| `references/create-tasks.md` | /createTasks workflow | 匹配到命令时 |
| `references/do-next-task.md` | /doNextTask workflow | 匹配到命令时 |
| `references/do-tasks-until.md` | /doTasksUntil workflow | 匹配到命令时 |
| `references/validate-result.md` | /validateResult workflow | 匹配到命令时 |
| `references/help-validate.md` | /helpValidate workflow | 匹配到命令时 |
| `references/archive-history.md` | /archiveHistory workflow | 匹配到命令时 |
| `references/generate-deployment-checklist.md` | /generateDeploymentChecklist workflow | 匹配到命令时 |
| `references/html-for-study.md` | /htmlForStudy workflow | 匹配到命令时 |
| `references/logicmap.md` | /logicmap workflow | 匹配到命令时 |
| `references/agentslink.md` | /agentslink workflow | 匹配到命令时 |
| `templates/` | 验收文档、任务拆分、部署清单、逻辑地图模板 | 对应 workflow 需要时 |

## 全局规则

- 所有计划文档放 `docs/plans/`，历史归档在 `docs/history/`
- 任务/进度文档用递增序号：task1.md, progress1.md, task2.md, ...
- `/doNextTask` 每次只执行一个任务，完成后 git commit，立即停止
- `/doTasksUntil` 串行执行直到目标模块完成，每个任务独立 commit
- 验收标准必须逐条验证，有证据才打 `[x]`
- 任务粒度：1-2h/个

## 红线

- `/doNextTask` 禁止一次执行多个任务——一个任务一个 commit 后立即停止
- 禁止跳过验收标准验证直接标记 `[x]`
- 禁止在没有读取 task doc 的情况下执行任务
- `/archiveHistory` 必须先完整读取所有 plan 文件再做摘要——禁止盲删
- `/htmlForStudy` 禁止使用 Mermaid 11、禁止 `file://` 协议、禁止 `startOnLoad: true`
- `/validateResult` 人工验收文档禁止出现 CLI 命令，agent 验收文档禁止出现视觉判断
- `/logicmap` 禁止粘贴源码片段，禁止随意更改已分配的编号
- `/agentslink` 禁止删除用户数据——必须先合并再创建软链
- 禁止自动推进到下一个任务（`/doNextTask` 完成后必须等用户指令）
