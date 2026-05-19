# Workflow: /validateResult

## Goal
Generate dual-track acceptance docs (human + agent) and run the agent checks.

## Steps
1. **Read latest task doc**:
   - Get highest N from `docs/plans/task*.md`
   - Open `task{N}.md`
   - Note the project/feature name

2. **Generate human acceptance doc**:
   - Use `templates/acceptance-human-template.md` as reference
   - Save to `docs/plans/acceptance-{FEATURE}.md`
   - **CRITICAL**: This is for a HUMAN to execute. Every step must describe a user action from the product UI perspective (open page, click button, upload file, visually inspect output). NO CLI commands, NO script executions, NO terminal operations — those belong in the agent doc exclusively.
   - Structure:
     1. **Pre-setup section** — what the agent does to prepare the environment (install deps, check .env, start dev server, verify build passes). The human just confirms each.
     2. **Scenario paths** — the core of the doc. Each path is a complete end-to-end user workflow (e.g. "upload ecommerce image → analyze → download PSD → open in Photoshop"). Paths cover different image types, modes, and user intents.
     3. **Cross-cutting checks** — functional verification that applies across scenarios (compatibility, degradation, auth gating). These can be checked during any scenario.
   - Each step: `| [ ] | A.1 | 打开 PSD 工具页，确认默认模式 | 下拉框显示"标准分层"+"主要文字可编辑" |`
   - Pass criteria must be visual/behavioral: what the user sees, not what the terminal outputs

3. **Generate agent acceptance doc**:
   - Use `templates/acceptance-agent-template.md` as reference
   - Save to `docs/plans/acceptance-{FEATURE}-agent.md`
   - Define **executable checks** — every single item must be a CLI command or script invocation that the agent can run and verify exit code/output
   - Include: `| 状态 | 步骤 | 检查动作（CLI 命令） | 预期结果 | 证据 |`
   - Add a "前置条件" section (e.g. `pnpm install`, `pnpm db:migrate`)
   - Add a "失败处理指南" table mapping common failure patterns to diagnostic steps
   - Include a "一次性全量验收脚本" bash block that chains all commands together
   - **RULE**: If a check requires human visual judgment (open PSD, look at layers, judge quality), it does NOT belong here — put it in the human doc

4. **Run agent acceptance checks**:
   - Go through every check item in the agent doc
   - Execute each command/action
   - Fill in:
     - `[x]`/`[ ]` for pass/fail
     - Actual result
     - Evidence (copy-paste command output, file content, etc.)
   - Update the acceptance result summary at the bottom

5. **Show results**:
   - Tell user both docs are generated
   - Summarize agent acceptance results
   - Point to human doc for manual validation

## Hard Constraints
- Agent checks must be fully automated (no human judgment required)
- Evidence must be concrete (command output, file content, etc.)
- Do **not** modify feature code in this workflow (only check)
- **Human doc = zero CLI commands**. If a step says `pnpm` or `node -e` or `curl`, it's in the wrong doc
- **Agent doc = zero visual checks**. If a step says "打开 PSD 查看" or "观察页面显示", it's in the wrong doc
- Human doc must start with a pre-setup section that the agent handles before the human touches anything
- Human doc must be organized by user scenarios, not by technical modules

## Acceptance Criteria
- [ ] Both acceptance docs are created
- [ ] Agent doc has executable checks with expected results
- [ ] Agent checks are executed and documented with evidence
- [ ] Acceptance result summary is filled
