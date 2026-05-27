# Workflow: /archiveHistory

## Goal
Read all files under `docs/plans/`, **condense task & progress docs** into a summary, **delete acceptance & deployment checklist docs** (no summary needed), then **clear** `docs/plans/`. Write summary to `docs/history/YYYY-MM-DD.md`. If that file already exists (multiple archives in one day), **append** to it.

## Steps

1. **Verify source has content**:
   - List all files in `docs/plans/`
   - If empty (or only `.gitkeep`), report: "docs/plans/ is already empty, nothing to archive"

2. **Read all plan files thoroughly**:
   - Read every `task*.md` and `progress*.md` — these will be condensed
   - Skim `acceptance-*.md` and `deployment-checklist-*.md` — note key results for the summary, but these docs will be deleted without full summarization

3. **Generate condensed summary**:
   - Target file: `docs/history/YYYY-MM-DD.md` (single markdown file, NOT a subdirectory)
   - If the file already exists, **append** to it (with a `---` separator between archive batches)
   - Cover:

   ### Required sections for each archive batch:

   **a) Archive batch header** — timestamp (`HH:MM`)
   - If appending to existing file, start with `---` then `## Archive {HH:MM}`

   **b) Overview** (2-3 sentences)
   - What was this body of work about? What problem was being solved?

   **c) What was built / accomplished**
   - Concrete deliverables, features implemented, modules completed
   - Synthesize tasks into outcomes, not a task list

   **d) Key technical decisions & rationale**
   - Architecture choices, technology selections, design patterns used
   - WHY each decision was made

   **e) Problems solved & how**
   - Non-obvious bugs fixed, tricky issues resolved, root causes and solutions

   **f) Lessons learned / patterns established**
   - What would you do differently? What conventions were established?

   **g) Task completion stats** (brief table)
   - Total tasks / completed / blocked breakdown

   **h) Acceptance & deployment notes** (if relevant)
   - Brief note from acceptance/checklist docs, just key takeaways

4. **Delete all plan files**:
   - Delete ALL files in `docs/plans/` (except `.gitkeep`): task, progress, acceptance, checklist — everything
   - Use `git rm` for each file

5. **Git commit**:
   - Stage all changes (deletions + new/appended summary)
   - Commit with message: `chore: archive plans to history/YYYY-MM-DD`
   - Push to remote: `git push origin {CURRENT_BRANCH}`

6. **Report completion**:
   - Show archive path: `docs/history/YYYY-MM-DD.md`
   - Note whether it was created new or appended to existing
   - Confirm `docs/plans/` is now empty

## Summary Quality Standard
- **Task/progress docs → condensed**: Synthesize into outcomes, decisions, lessons. Don't enumerate tasks.
- **Acceptance/checklist docs → noted & deleted**: Capture key takeaways in the summary notes section, then delete.
- **Capture the "why"**: Task docs capture "what". The summary must capture "why".
- **Standalone**: Someone reading `docs/history/YYYY-MM-DD.md` 6 months later should understand what happened and why.

## Hard Constraints
- **READ FIRST, THEN SUMMARIZE**: Never generate summary without reading all task/progress files
- **DELETE ACCEPTANCE & CHECKLIST**: These are not summarized in detail, just key notes captured, then deleted
- **SINGLE FILE PER DATE**: `docs/history/YYYY-MM-DD.md`, not a subdirectory
- **APPEND IF EXISTS**: Multiple archives in one day append to same file with `---` separator
- **ONE COMMIT PER ARCHIVE**: All deletions + summary in a single commit

## Acceptance Criteria
- [ ] All plan files read and understood
- [ ] Condensed summary written to `docs/history/YYYY-MM-DD.md` (created or appended)
- [ ] Summary captures: overview, deliverables, decisions, problems solved, lessons learned, stats
- [ ] Summary is standalone — readable and useful 6 months from now
- [ ] All files deleted from `docs/plans/` (except `.gitkeep`)
- [ ] Single git commit created for the entire operation
