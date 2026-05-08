# ekscoding

标准化开发交付工作流 Skill，用于 SaaS 产品开发的任务管理、进度跟踪、验收和部署准备。

## 功能特性

- **任务拆分**：将需求拆解为 1-2 小时的可执行任务
- **任务执行**：逐个执行未完成任务，自动更新进度和 Git 提交
- **双轨验收**：生成人工 + Agent 双验收文档
- **交互验收**：逐步引导走查验收清单，排查问题，解释每个测试的 "why"
- **历史归档**：将完成的进度归档到历史文件夹
- **部署清单**：生成三类部署检查项（Agent 可直接做、需凭据、用户必须做）
- **一键自动化**：`justdoit.sh` 脚本全流程自动执行

## 快速开始

### 安装

```bash
git clone https://github.com/kaixinbaba/ekscoding.git
cd ekscoding
./install.sh
```

install.sh 会自动检测已安装的 AI 工具（Claude Code、Codex、OpenClaw、Gemini），将 skill 复制到 `~/.my-skills/skills/ekscoding/` 并创建软链接。

### 命令列表

| 命令 | 功能 | 自然语言触发词 |
|------|------|---------------|
| `/createTasks` | 创建任务计划和进度跟踪文档 | "拆分任务"、"帮我分解这个需求" |
| `/doNextTask` | 执行第一个未完成的任务，更新进度，提交代码 | "执行下一个任务"、"做下一个" |
| `/doTasksUntil` | 从第一个未完成任务开始，一直执行到指定 Module 全部完成 | "执行到 Module X"、"做到第三个模块" |
| `/validateResult` | 生成双验收文档并运行 Agent 检查 | "生成验收文档"、"验证结果" |
| `/helpValidate` | 交互式引导验收，逐步走查验收清单，排查问题 | "帮我验收"、"引导我验证"、"一步步测" |
| `/archiveHistory` | 将 `docs/plans/` 下所有文件归档到 `docs/history/`，生成摘要，清空 plans | "归档任务历史"、"保存历史" |
| `/generateDeploymentChecklist` | 生成部署清单 | "生成部署清单"、"我要上线了准备清单" |

### justdoit.sh 一键执行

```bash
./justdoit.sh [project_dir]
```

三阶段全自动执行：
- **Phase 1**: 逐个执行所有未完成任务
- **Phase 2**: 生成双轨验收文档
- **Phase 3**: 执行 Agent 验收检查

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

| 文档类型 | 路径模式 | 示例 |
|----------|----------|------|
| 任务拆分 | `docs/plans/task{N}.md` | `docs/plans/task1.md` |
| 进度跟踪 | `docs/plans/progress{N}.md` | `docs/plans/progress1.md` |
| 人工验收 | `docs/plans/acceptance-{FEATURE}.md` | `docs/plans/acceptance-milestone2.md` |
| Agent 验收 | `docs/plans/acceptance-{FEATURE}-agent.md` | `docs/plans/acceptance-milestone2-agent.md` |
| 历史归档 | `docs/history/YYYY-MM-DD/` | `docs/history/2026-05-04/` |
| 部署清单 | `docs/plans/deployment-checklist-{PROJECT}.md` | `docs/plans/deployment-checklist-psd-layer-ai.md` |

## 状态标记（通用）

| 标记 | 含义 | 用法 |
|------|------|------|
| [ ] | 未开始 | 任务/验收项待处理 |
| [x] | 已完成 | 任务已完成并验证通过 |
| [~] | 阻塞中 | 因外部问题停止；**必须**包含原因 |

## 核心原则（SaaS 产品开发）

1. **不要先做完整的 SaaS — 先做免费工具** - 把工具放在首页最显眼的位置
2. **在构建复杂 AI/功能前先验证需求** - 先获得 20+ 邮箱订阅
3. **专注于极其狭窄的用例** - "面向 B2B SaaS 创始人的 AI LinkedIn 帖子生成器"，而不是 "AI 写作工具"
4. **不要先做登录/支付** - 等到需求被验证后再做
5. **做长尾工具页面，而不是通用博客文章** - 每个页面解决一个特定用户的一个特定任务
6. **付费广告前先做社区验证** - 先在社区发布，倾听人们抱怨什么
7. **"这是一个演示！"** - 在验证需求时对用户保持诚实
8. **任务拆解为 1-2 小时的块** - 让进展可见且可达成

## 全局规则

- 所有计划文档在 `docs/plans/`；历史在 `docs/history/`
- 任务和进度文档始终使用序号（task1.md、progress1.md、task2.md、...）
- 有疑问时，保持文档格式与之前的一致
- **绝不**在一次运行中执行多个任务（`/doNextTask`）
- **始终**在完成一个任务后提交 Git 更改（`/doNextTask`）
- `/doTasksUntil` 会顺序执行多个任务直到目标 Module 完成，每个任务独立提交
- **始终**在标记任务完成前验证验收标准

## License

MIT
