# Workflow: /doTasksUntil

## Goal
Find the first `[ ]` task in the latest progress doc, then execute tasks **sequentially** until all tasks in the target module are completed (including all prerequisite tasks in earlier modules).

## Steps

1. **Find latest progress doc**:
   - Get highest N from `docs/plans/progress*.md`
   - Open `progress{N}.md`

2. **Identify target module and task list**:
   - User specifies target module (e.g., "Module 2" or "2")
   - Scan progress doc to identify:
     - The first `[ ]` task (starting point)
     - All tasks under the target module (ending boundary)
   - Build the ordered list of tasks from first `[ ]` through the last task in the target module

3. **Validate boundary**:
   - If target module has no tasks → error: "Module N has no tasks"
   - If all tasks up to target module are already `[x]` → report: "All tasks up to Module N already completed"

4. **For each task in the ordered list** (loop):
   a. **Read corresponding task details**:
      - Open `task{N}.md`
      - Find the exact task block
      - Read: file paths, implementation points, acceptance criteria

   b. **Implement the task**:
      - Make changes to the relevant files
      - Follow implementation points from the task doc

   c. **Verify acceptance criteria**:
      - Go through **every single acceptance criterion** one by one
      - For each: perform verification, note evidence
      - If any criterion fails: fix, then re-verify all

   d. **Update progress doc**:
      - Change `[ ]` to `[x]` for the completed task
      - Append completion note:
        ```
        > 完成时间：YYYY-MM-DD | 完成人：agent | 备注：{brief summary}
        ```
      - Update completion stats at bottom

   e. **Git commit**:
      - Stage all changes
      - Commit with message: `feat: complete Task {MODULE.TASK} - {TASK_TITLE}`
      - Push to remote: `git push origin {CURRENT_BRANCH}`

   f. **Check if target module is fully done**:
      - If all tasks under target module are `[x]` → exit loop, report completion
      - Otherwise → continue to next task

5. **Report completion**:
   - Show summary: X tasks completed across Y modules
   - Show final verification evidence for all tasks
   - Confirm target module is fully done

## Multi-Task Rules
- Each task gets its own git commit
- Each task gets its own verification pass
- Never skip acceptance criteria verification for any task
- If a task fails verification mid-way, fix it before proceeding to next task
- Do not touch tasks beyond the target module

## Acceptance Criteria
- [ ] All tasks from first `[ ]` through last task in target module are completed
- [ ] All acceptance criteria for each task are verified with evidence
- [ ] Progress doc is updated correctly for each task
- [ ] A separate git commit is created for each task
- [ ] No tasks beyond the target module are touched
