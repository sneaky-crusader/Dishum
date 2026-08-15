---
name: progress
description: Reports Dishum's implementation progress — per-phase completion percentage, current active phase, recent decisions, recent ad-hoc tasks, and any timeline changes. Use whenever the user asks about project status, how much is done, what phase we're on, or "progress".
---

# Progress report

Source of truth: `docs/PROGRESS.md` in the repo root. Never answer a progress
question from memory or from what you recall doing earlier in the
conversation — always re-read the file, since it may have been updated in a
different session.

## Steps

1. Read `docs/PROGRESS.md`.
2. For each phase section, count `- [x]` vs `- [ ]` checklist items and
   compute % = checked ÷ total. Cross-check against the "at a glance" table
   at the top; if they disagree, trust the checklist counts (recompute) and
   flag the mismatch so the table can be fixed.
3. Identify the **currently active phase**: the first phase (in order 0→6)
   that is not 100% complete.
4. Report:
   - One-line overall status: active phase + its %.
   - The full per-phase % table.
   - If the user asked about one specific phase, expand that phase's
     checklist in detail (what's done, what's left) instead of/in addition
     to the table.
   - The last 3–5 rows of the Decision log and Misc/ad-hoc log (most recent
     first), so the user gets context on *what just happened*, not just a number.
   - Anything in Timeline notes if it's non-empty beyond the default
     "no deadlines set" line.
5. Keep the report terse — a table plus a few bullet points, not prose paragraphs.

## If asked to update progress instead of just reporting it

If the user's request implies work was just completed (not just a status
query), don't just report — update `docs/PROGRESS.md` first (check off items,
add log rows, recompute %s and the at-a-glance table, bump "Last updated"),
then report the new state.
