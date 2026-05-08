# Workflow: /generateDeploymentChecklist

## Purpose
Generate comprehensive deployment checklists, clearly categorizing three sections:
1. Tasks the agent can do without any extra permissions
2. Tasks the agent can do, but needs user's credentials/tokens
3. Tasks that must be done by the user (detailed step-by-step with minimal mental burden)

## Steps
1. **Understand the current project stage/milestone**
   - Read task docs (task1.md, progress1.md, etc.) to understand which features are actually needed
   - Don't assume full SaaS; tailor to the milestone's actual requirements

2. **Generate the checklist structure with 3 clear sections**
   - Section 1: What I can do now (no extra permissions)
   - Section 2: What I can do with your credentials/tokens
   - Section 3: What you must do (super detailed, step-by-step, minimal mental burden)
   - Also include a clean "Copy & Paste checklist" at the end for easy use

3. **Save the checklist file**
   - Save to `docs/plans/deployment-checklist-{PROJECT}.md`
   - Commit to git

## Checklist Structure Guidelines
### Section 1: What I can do without extra permissions
- List what the agent can do right now
- E.g., check config files, optimize code, prepare docs, test builds

### Section 2: What I can do with your credentials
- List exactly what credentials are needed
- E.g., Cloudflare API Token, Resend API Key, etc.
- List what the agent can do with them

### Section 3: What you must do (DETAILED!)
- This section is CRITICAL - user needs step-by-step, no thinking
- Break down each task into sub-steps
- Include exact URLs to click
- Include exact menu items to select
- Include what to look for on each page
- Use checklists within steps for even more clarity

### Additional Sections
- Copy-paste ready checklist with checkboxes [ ]
- Suggested workflow (what order to do things)

## Hard Constraints
- ALWAYS tailor to the current milestone (don't assume full SaaS)
- ALWAYS make the "must do by user" section as simple and detailed as possible
- ALWAYS use clear visual separators between sections

## Acceptance Criteria
- [ ] Checklist has 3 clearly separated sections
- [ ] Checklist tailored to current project milestone (not full SaaS by default)
- [ ] "Must do by user" section has step-by-step instructions with exact URLs/menus
- [ ] Copy-paste ready checklist with [ ] checkboxes
- [ ] Saved to `docs/plans/deployment-checklist-{PROJECT}.md`
- [ ] Committed to git
