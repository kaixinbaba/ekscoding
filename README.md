# ekscoding

标准化开发交付工作流 Skill，将需求拆分、任务执行、验收、归档、部署准备串联为可重复的命令。

## 推荐工作流程

```
1. 讨论需求  →  与 AI 充分讨论需求和目标，达成共识
2. 拆分任务  →  /ekscoding:createTasks（或说 "拆分任务"）
3. 自动化开发 →  justdoit（一键执行所有任务，自动 git commit）
4. 交互验收  →  /ekscoding:helpValidate（AI 引导逐步验收）
5. 上线清单  →  /ekscoding:generateDeploymentChecklist
6. 归档提交  →  /ekscoding:archiveHistory（归档 plans/，清空，git commit）
```

每个 phase 完成后再进入下一个，不跳步。justdoit 会自动完成 Phase 3（执行任务）、Phase 4（验收文档）、Phase 5（Agent 验收检查），但 helpValidate 的人工交互验收建议手动走一遍。

## 安装

```bash
git clone https://github.com/kaixinbaba/ekscoding.git
cd ekscoding
./install.sh
```

### 安装过程（4 步交互）

install.sh 会逐步引导你完成安装：

**Step 1 — 选择 Skill 安装目录**
- 默认：`~/.my-skills/skills/ekscoding/`
- 可选自定义路径

**Step 2 — 安装 Skill 文件 & 工具链接**
- 复制 skill 文件到安装目录
- 自动检测已安装的 AI 工具（Claude Code、Codex、OpenClaw、Gemini）
- 在检测到的工具 skills 目录下创建软链接

**Step 3 — 选择 AI CLI 工具**
- 自动检测你机器上已安装的 CLI（`command -v` 检测）
- 只显示实际安装了的工具，优先级：claude > codex > opencode > gemini
- 只有一个工具时自动确认，多个时让你选，都没有时提供全部选项
- 也支持自定义 CLI 命令

**Step 4 — 安装 justdoit 全局命令**
- 可选将 `justdoit` 安装为全局命令，在任意目录直接使用
- 推荐安装到 `~/.local/bin/`（无需 sudo）
- 自动检测 PATH 并提示添加到 shell 配置文件

### 非交互安装

```bash
./install.sh --yes    # 全部使用默认值
```

也支持 `--dir /path` 指定安装目录、`status` 查看状态、`uninstall` 卸载。

## 命令列表

命令通过 skill 名称调用，具体语法取决于你的 AI 工具：

| 工具 | 语法 | 示例 |
|------|------|------|
| Claude Code | `/ekscoding:{command}` | `/ekscoding:createTasks` |
| Codex | `$ekscoding:{command}` | `$ekscoding:createTasks` |

所有命令也支持自然语言触发，直接说 "拆分任务"、"执行下一个任务" 等即可。

| 命令 | 功能 | 自然语言触发词 |
|------|------|---------------|
| `createTasks` | 创建任务计划和进度跟踪文档 | "拆分任务"、"帮我分解这个需求" |
| `doNextTask` | 执行第一个未完成的任务，更新进度，提交代码 | "执行下一个任务"、"做下一个" |
| `doTasksUntil` | 从第一个未完成任务开始，一直执行到指定 Module 全部完成 | "执行到 Module X"、"做到第三个模块" |
| `validateResult` | 生成双验收文档并运行 Agent 检查 | "生成验收文档"、"验证结果" |
| `helpValidate` | 交互式引导验收，逐步走查验收清单，排查问题 | "帮我验收"、"引导我验证"、"一步步测" |
| `archiveHistory` | 将 `docs/plans/` 下所有文件归档到 `docs/history/`，生成摘要，清空 plans | "归档任务历史"、"保存历史" |
| `generateDeploymentChecklist` | 生成部署清单 | "生成部署清单"、"我要上线了准备清单" |

## justdoit — 一键自动化

安装为全局命令后，在任意项目目录直接使用：

```bash
justdoit              # 当前目录
justdoit ~/my-project # 指定项目
```

三阶段全自动执行：
- **Phase 1**: 逐个执行所有未完成任务（每个任务独立 git commit）
- **Phase 2**: 生成双轨验收文档（人工 + Agent）
- **Phase 3**: 执行 Agent 验收检查（自动运行 CLI 命令验证）

前置条件：项目目录下必须有 `docs/plans/`（通过 `createTasks` 创建）。

### 更换 AI CLI 工具

justdoit 使用的 CLI 工具由安装目录下的 `.justdoitrc` 文件控制：

```bash
cat ~/.my-skills/skills/ekscoding/.justdoitrc
# AGENT_CLI="claude -p --permission-mode bypassPermissions"
```

编辑此文件即可切换工具（如改为 `codex exec` 或 `gemini -p`）。

## 文件结构

```
ekscoding/
├── SKILL.md                          # Skill 入口定义
├── README.md                         # 本文件
├── justdoit.sh                       # 一键任务执行 + 验收脚本
├── install.sh                        # 安装脚本
├── workflows/
│   ├── create-tasks.md               # 任务拆分工作流
│   ├── do-next-task.md               # 执行下一个任务工作流
│   ├── do-tasks-until.md             # 执行到目标 Module 工作流
│   ├── validate-result.md            # 结果验证工作流
│   ├── help-validate.md             # 交互式验收引导工作流
│   ├── archive-history.md            # 历史归档工作流
│   └── generate-deployment-checklist.md  # 部署清单生成工作流
└── templates/
    ├── task-template.md              # 任务文档模板
    ├── progress-template.md          # 进度文档模板
    ├── acceptance-human-template.md  # 人工验收模板
    ├── acceptance-agent-template.md  # Agent 验收模板
    └── deployment-checklist-template.md  # 部署清单模板
```

## 文档命名约定

| 文档类型 | 路径模式 |
|----------|----------|
| 任务拆分 | `docs/plans/task{N}.md` |
| 进度跟踪 | `docs/plans/progress{N}.md` |
| 人工验收 | `docs/plans/acceptance-{FEATURE}.md` |
| Agent 验收 | `docs/plans/acceptance-{FEATURE}-agent.md` |
| 历史归档 | `docs/history/YYYY-MM-DD/` |
| 部署清单 | `docs/plans/deployment-checklist-{PROJECT}.md` |

## 状态标记（通用）

| 标记 | 含义 |
|------|------|
| [ ] | 未开始 |
| [x] | 已完成并验证通过 |
| [~] | 阻塞中，**必须**包含原因 |

## 全局规则

- 所有计划文档在 `docs/plans/`；历史在 `docs/history/`
- 任务和进度文档始终使用序号（task1.md、progress1.md、task2.md、...）
- 有疑问时，保持文档格式与之前的一致
- **绝不**在一次运行中执行多个任务（`/doNextTask`）
- **始终**在完成一个任务后提交 Git 更改
- `/doTasksUntil` 会顺序执行多个任务，每个任务独立提交
- **始终**在标记任务完成前验证验收标准

## License

MIT
