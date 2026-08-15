# Supabase (deferred to Phase 1)

No Supabase account or project is created yet — by design. Phases 0–2 run
entirely on the local machine at **$0**. When we reach Phase 1 (accounts &
directory), this folder will hold:

- `migrations/` — SQL for the `profiles` table (`username citext UNIQUE`),
  `matches`, and Row-Level Security policies.
- `seed.sql` — optional local seed data.

See `docs/PROPOSAL.md` §4 for the data model. Free tier covers all of
development and early launch; see the cost breakdown discussed in planning.
