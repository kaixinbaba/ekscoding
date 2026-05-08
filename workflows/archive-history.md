# Workflow: /archiveHistory

## Goal
Archive **all** files under `docs/plans/` into `docs/history/`, generate a summary, then **clear** `docs/plans/`. After archiving, `docs/plans/` should be empty (or only contain `.gitkeep`).

## Steps

1. **Verify source has content**:
   - List all files in `docs/plans/`
   - If empty (or only `.gitkeep`), report: "docs/plans/ is already empty, nothing to archive"

2. **Initialize history dir**:
   - If `docs/history/` doesn't exist, create it

3. **Create archive subdirectory**:
   - Get today's date as `YYYY-MM-DD`
   - Create `docs/history/YYYY-MM-DD/`
   - This keeps each archive run isolated

4. **Move all files from `docs/plans/` to `docs/history/YYYY-MM-DD/`**:
   - Move every file: `task*.md`, `progress*.md`, `acceptance-*.md`, `deployment-checklist-*.md`, etc.
   - Use `git mv` for each file to preserve git history

5. **Generate summary** (`docs/history/YYYY-MM-DD/README.md`):
   - Read all moved files
   - Summarize:
     - Task completion status (which tasks done, which remaining, which blocked)
     - Total tasks / completed / blocked breakdown
     - Key decisions or notes from progress docs
     - Acceptance results summary (if acceptance docs exist)
     - Deployment readiness summary (if checklist exists)
   - Write summary to `docs/history/YYYY-MM-DD/README.md`

6. **Clean up `docs/plans/`**:
   - Delete all remaining files in `docs/plans/` (if any were not caught by move)
   - Ensure the directory is empty (`.gitkeep` allowed for git tracking)

7. **Git commit**:
   - Stage all changes (moves + new summary + deletions)
   - Commit with message: `chore: archive plans to history/YYYY-MM-DD`
   - Push to remote: `git push origin {CURRENT_BRANCH}`

8. **Report completion**:
   - Show archive path: `docs/history/YYYY-MM-DD/`
   - Show summary of what was archived (file count, task stats)
   - Confirm `docs/plans/` is now empty

## Hard Constraints
- **MOVE, NOT COPY**: Use `git mv` to move files into history, then delete any stragglers. No full snapshot copies kept in `docs/plans/`.
- **CLEAR AFTER ARCHIVE**: `docs/plans/` must be empty when done (except `.gitkeep`)
- **ALWAYS SUMMARIZE**: Every archive run generates a `README.md` summary inside the archive dir
- **ONE COMMIT PER ARCHIVE**: All moves + summary + cleanup in a single commit

## Acceptance Criteria
- [ ] All files from `docs/plans/` moved to `docs/history/YYYY-MM-DD/`
- [ ] Summary `README.md` generated in archive dir with task completion stats
- [ ] `docs/plans/` is empty (except `.gitkeep`)
- [ ] A single git commit is created for the entire archive operation
- [ ] Git history is preserved via `git mv`
