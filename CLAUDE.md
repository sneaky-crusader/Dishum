# Dishum — instructions for Claude

- **Progress tracking is mandatory.** `docs/PROGRESS.md` is the single source
  of truth for phase status, decisions, and misc/ad-hoc work. Whenever you:
  - complete a phase checklist item → check it off in `docs/PROGRESS.md` and update that phase's %
  - make an architectural/tooling decision → add a row to the Decision log
  - do ad-hoc work outside the phase checklists (bug fixes, investigations, one-off tasks) → add a row to the Misc/ad-hoc task log
  - learn of or cause a timeline/estimate change → add an entry to Timeline notes (old estimate → new estimate → reason)

  Do this **in the same turn** the work happens, not as a separate cleanup step.

- Use the `/progress` skill (`.claude/skills/progress/`) to answer any question
  about project status — it reads `docs/PROGRESS.md` and reports per-phase and
  overall completion. Don't answer progress questions from memory; read the file.

- See `docs/PROPOSAL.md` for the full architecture/roadmap this tracker follows.
