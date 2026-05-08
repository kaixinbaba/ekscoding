# Workflow: /doNextTask

## Goal
Find the first `[ ]` task in the latest progress doc, implement it, verify acceptance criteria, update progress, git commit, STOP.

## Steps
1. **Find latest progress doc**:
   - Get highest N from `docs/plans/progress*.md`
   - Open `progress{N}.md`
   - Locate **first `[ ]` task** (that's the one we do)

2. **Read corresponding task details**:
   - Open `task{N}.md`
   - Find the exact task block
   - Read:
     - File paths affected
     - Implementation bullet points
     - Full acceptance criteria list

3. **Implement the task**:
   - Make changes to the relevant files
   - Follow implementation points from the task doc

4. **Verify acceptance criteria**:
   - Go through **every single acceptance criterion** one by one
   - For each:
     - Perform the verification action
     - Note down evidence (command output, file content, screenshot, etc.)
   - If any criterion fails: fix, then re-verify all

5. **Update progress doc**:
   - Change `[ ]` to `[x]` for the task
   - Append the completion note:
     ```
     > 完成时间：YYYY-MM-DD | 完成人：agent | 备注：{brief summary}
     ```
   - Update the completion stats at the bottom

6. **Git commit**:
   - Stage all changes
   - Commit with message: `feat: complete Task {MODULE.TASK} - {TASK_TITLE}`
   - Push to remote branch: `git push origin {CURRENT_BRANCH}`

7. **STOP**:
   - Do **not** proceed to next task automatically
   - Report completion to user
   - Show verification evidence

## Hard Constraints
- **ONE TASK ONLY**: Never execute more than one task in a single run
- **VERIFY FIRST**: Never mark a task done until all acceptance criteria are verified
- **ALWAYS COMMIT**: Always make exactly one git commit after completing the task
- **NO AUTO CONTINUE**: Stop immediately after one task

## Acceptance Criteria
- [ ] Exactly one task is completed
- [ ] All acceptance criteria for that task are verified with evidence
- [ ] Progress doc is updated correctly
- [ ] A git commit is created
- [ ] No additional tasks are touched
