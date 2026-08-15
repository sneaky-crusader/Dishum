# Supabase

Migrations are written; **no Supabase account or project exists yet** — by
design, so this has cost **$0** so far. See `docs/PROPOSAL.md` §4 for the
data model this implements.

## Migrations

| File | Purpose |
|------|---------|
| `20260815120000_extensions.sql` | `citext` (case-insensitive usernames), `pg_trgm` (fast username search) |
| `20260815120100_profiles.sql` | `profiles` table, unique/format-checked `username`, RLS, auto-create-on-signup trigger |
| `20260815120200_username_search_index.sql` | trigram GIN index backing `ILIKE '%name%'` search |
| `20260815120300_matches.sql` | `matches` table (written server-side only), RLS for read-your-own-matches |
| `20260815120400_stats_update.sql` | `apply_match_result()` — atomically updates W/L/rating after a match |

Live match state (health, block, punch phase) is **never** stored here — it
lives in Colyseus room memory only; `matches` records the final result.

## Not yet verified against a live database

These files have not been run against Postgres yet — there's no local
Postgres/Docker/`supabase` CLI on this machine to test them against. They're
written carefully against standard Postgres + Supabase syntax, but treat them
as reviewed, not proven, until the first `supabase db push` in Phase 1's next
step (once the free project is created).

## Applying them (when we create the Supabase project)

```
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db push
```

The Colyseus server will need the **service role key** (bypasses RLS) to
write `matches` rows and call `apply_match_result()` — never ship that key
to the Godot client, which only ever uses the anon/public key + user JWT.
