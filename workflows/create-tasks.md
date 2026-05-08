# Workflow: /createTasks

## Goal
From the user's requirement, create:
1. `docs/plans/task{N}.md` — detailed task breakdown doc
2. `docs/plans/progress{N}.md` — progress tracking doc

## Steps
1. **Initialize directories**:
   - If `docs/plans/` doesn't exist, create it
   - If `docs/history/` doesn't exist, create it

2. **Find current number N**:
   - Scan `docs/plans/` for existing `task*.md`/`progress*.md`
   - Extract the max number N (e.g., task1.md → N=1)
   - New docs will be `task{N+1}.md` and `progress{N+1}.md`

3. **Read previous format (if any)**:
   - If there was a previous `task{N}.md`/`progress{N}.md`, read and follow the same structure

4. **Break down the requirement**:
   - Split work into logical modules
   - Each module has 1-6 tasks (1-2h each)
   - Each task includes:
     - File paths affected
     - Implementation bullet points
     - Clear acceptance criteria

5. **Generate `task{N+1}.md`**:
   - Use `templates/task-template.md` as reference
   - Fill in project name, modules, tasks, implementation points, acceptance criteria

6. **Generate `progress{N+1}.md`**:
   - Use `templates/progress-template.md` as reference
   - Mirror exactly the task structure from `task{N+1}.md`
   - Initialize all tasks to `[ ]`
   - Calculate total task count in the stats section

7. **Confirm completion**:
   - Show both file names to the user
   - Briefly summarize the module breakdown

## Hard Constraints
- Do **not** start executing tasks in this workflow
- Keep each task to <2h estimated effort
- All acceptance criteria must be objectively pass/fail

## Acceptance Criteria
- [ ] Both `task{N+1}.md` and `progress{N+1}.md` are created
- [ ] Task structure matches exactly between task doc and progress doc
- [ ] Each task has >1 acceptance criteria
- [ ] Total task count is calculated correctly in progress doc
