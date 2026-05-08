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
   - Create a step-by-step checklist for manual verification
   - Format: table with `| 状态 | 步骤 | 操作 | 通过标准 |`

3. **Generate agent acceptance doc**:
   - Use `templates/acceptance-agent-template.md` as reference
   - Save to `docs/plans/acceptance-{FEATURE}-agent.md`
   - Define **executable checks**:
     - CLI commands to run
     - Expected output/behavior
     - Where to find evidence

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

## Acceptance Criteria
- [ ] Both acceptance docs are created
- [ ] Agent doc has executable checks with expected results
- [ ] Agent checks are executed and documented with evidence
- [ ] Acceptance result summary is filled
