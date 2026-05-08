---
name: ekscoding
description: Use this when the user asks for coding task/progress planning, executing the next unchecked task, executing tasks until a target module is complete, generating human+agent acceptance docs, interactive guided validation walkthrough, archiving plan history, or generating deployment checklists. Triggers on commands like /createTasks, /doNextTask, /doTasksUntil, /validateResult, /helpValidate, /archiveHistory, /generateDeploymentChecklist, or when you says things like "拆分任务"、"执行下一个任务"、"执行到 Module X"、"生成验收文档"、"帮我验收"、"引导我验证"、"一步步测"、"归档任务历史"、"生成部署清单"、"我要上线了准备清单".
---

# Ekscoding Workflow Skill

标准化开发交付工作流 Skill，将需求拆分、任务执行、验收、归档、部署准备串联为可重复的命令。

## Core Principles (SaaS Product Development)
Based on the lessons for launching new SaaS products:
1. **Don't build a full SaaS first - build a free tool instead** - Put the tool front and center on your homepage
2. **Validate demand before building complex AI/features** - Get 20+ email signups first
3. **Focus on an extremely narrow use case** - "AI LinkedIn post generator for B2B SaaS founders", not "AI writing tool"
4. **Don't build login/payment first** - Wait until you have proven demand
5. **Build long-tail tool pages, not generic blog posts** - Each page solves one specific task for one specific user
6. **Community validation before paid ads** - Post in communities first, listen to what people complain about
7. **"This is a demo!"** - Be honest with users while you validate
8. **Task breakdown to 1-2 hour chunks** - Make progress visible and achievable

## Purpose
Standardize development delivery into repeatable command workflows:
- `/createTasks`: From a requirement, create task plan + progress tracking doc
- `/doNextTask`: Execute the first unchecked task, update progress, git commit once done
- `/doTasksUntil`: Execute tasks sequentially from first unchecked until target module is fully complete (includes all prerequisite tasks)
- `/validateResult`: Generate dual-track acceptance docs (human + agent) + run agent checks
- `/helpValidate`: Interactive guided validation — walk through acceptance checklist step-by-step with Q&A, troubleshoot issues together, explain the "why" behind each test
- `/archiveHistory`: Archive all files under `docs/plans/` into `docs/history/YYYY-MM-DD/`, generate summary, then clear `docs/plans/`
- `/generateDeploymentChecklist`: Generate deployment checklist, clearly categorizing: 1) Agent can do now (no extra permissions), 2) Agent can do with user's credentials/tokens, 3) Must be done by user (detailed steps with minimal mental burden)

## Command Router
When user intent matches one of the commands, route immediately to the workflow file:

1. `/createTasks` -> `workflows/create-tasks.md`
2. `/doNextTask` -> `workflows/do-next-task.md`
3. `/doTasksUntil` -> `workflows/do-tasks-until.md`
4. `/validateResult` -> `workflows/validate-result.md`
5. `/helpValidate` -> `workflows/help-validate.md`
6. `/archiveHistory` -> `workflows/archive-history.md`
7. `/generateDeploymentChecklist` -> `workflows/generate-deployment-checklist.md`

If the user does not type the slash command but intent is equivalent, still route to the matching workflow.

## Global Rules
- All plan docs live in `docs/plans/`; history in `docs/history/`
- Task and progress docs always use sequential numbers (task1.md, progress1.md, task2.md, ...)
- When in doubt, keep docs in the same format as the previous ones
- **Never** execute multiple tasks in one run for `/doNextTask`
- **Always** commit git changes after completing one task in `/doNextTask`
- `/doTasksUntil` executes multiple tasks sequentially until target module is complete; each task gets its own commit
- **Always** verify acceptance criteria before marking a task complete

## Required Output Quality
- Tasks must be broken down to 1-2 hour size
- Acceptance criteria must be objectively verifiable
- All status changes must include timestamp + brief comment
- Docs must be human-readable first, machine-parseable second

## File Naming Conventions
| Doc Type | Path Pattern |
|----------|--------------|
| Task Split | `docs/plans/task{N}.md` |
| Progress Tracking | `docs/plans/progress{N}.md` |
| Human Acceptance | `docs/plans/acceptance-{FEATURE}.md` |
| Agent Acceptance | `docs/plans/acceptance-{FEATURE}-agent.md` |
| Archived History | `docs/history/YYYY-MM-DD/` |
| Deployment Checklist | `docs/plans/deployment-checklist-{PROJECT}.md` |

## State Markers (Universal)
| Marker | Meaning | Usage |
|--------|---------|-------|
| [ ] | Not started | Task/acceptance item pending |
| [x] | Done | Task completed and verified |
| [~] | Blocked | Stopped due to external issue; MUST include reason |

## Deployment Checklist Categories
1. **Agent can do now** (no extra permissions)
2. **Agent can do with user's credentials/tokens**
3. **Must be done by user** — detailed step-by-step, minimize mental burden
