# Dishum — Progress Tracker

This file is the **single source of truth** for project status. It is updated
every time a phase task, decision, or ad-hoc task happens, or a timeline
estimate changes. Query it any time with the `/progress` skill.

Checklist convention: `- [x]` done, `- [ ]` not done. Phase % = checked ÷ total
items in that phase's checklist.

Last updated: **2026-08-15**

---

## Phase status at a glance

| Phase | Name | % complete |
|---|---|---|
| 0 | Foundations | 83% |
| 1 | Accounts & directory | 50% |
| 2 | Core combat (local) | 0% |
| 3 | Authoritative multiplayer | 0% |
| 4 | Matchmaking | 0% |
| 5 | Results & polish | 0% |
| 6 | Ship | 0% |

**Currently active: Phase 1 — Accounts & directory.**

---

## Phase 0 — Foundations (83%)

- [x] Write technical proposal (`docs/PROPOSAL.md`)
- [x] Install Godot 4 + verify Node.js tooling
- [x] Scaffold Godot 4 client (landscape lock, placeholder 4-button HUD, shared combat constants)
- [x] Scaffold Colyseus server (MatchRoom, 30Hz tick loop, punch state machine stub)
- [x] Git-init repo + first commit
- [ ] Archive/remove legacy Android-only `app/` scaffold (deferred until Godot Android export is verified)

## Phase 1 — Accounts & directory (50%)

- [x] Write Supabase SQL migrations (`profiles`, `matches`, RLS, search index, `apply_match_result()`)
- [x] Create Supabase project (account + provisioning) — project ref `griglxichqiwdffajwtz`
- [x] Push migrations to the live project (`supabase db push`) — all 5 applied and verified live
- [ ] Godot: register/login screens against Supabase Auth
- [ ] Godot: username-search screen with online status
- [ ] Wire presence (online/offline/in-match)

## Phase 2 — Core combat, local first (0%)

- [ ] Real 4-button landscape HUD (replaces Phase 0 placeholder)
- [ ] Fighter art/placeholders (right = local, left = opponent)
- [ ] Client-side combat state machine vs. a local/dummy opponent
- [ ] Hit/block/windup animations
- [ ] Health bar UI

## Phase 3 — Authoritative multiplayer (0%)

- [ ] Full `MatchRoom` tick + hit resolution, hardened past the Phase 0 stub
- [ ] Verify Supabase JWT on client connect
- [ ] Wire Godot client to Colyseus (join room, send inputs, receive state)
- [ ] Interpolation/smoothing of opponent state
- [ ] Two real devices fighting over the internet, end to end

*Note: the tick-loop and hit-resolution logic already exists as a stub from
Phase 0 scaffolding — this phase is about hardening + wiring it to real
clients, not writing it from scratch.*

## Phase 4 — Matchmaking (0%)

- [ ] Direct challenge-by-username flow
- [ ] Random quick-match queue
- [ ] Colyseus `Lobby` room

## Phase 5 — Results & polish (0%)

- [ ] Server writes `matches` row when a room ends
- [ ] Server calls `apply_match_result()` (SQL fn already written in Phase 1)
- [ ] Round timer / win screen
- [ ] Latency & feel tuning

## Phase 6 — Ship (0%)

- [ ] Android build + Play Store setup
- [ ] iOS build + App Store setup (needs macOS + Xcode + Apple Developer account)

---

## Decision log

| Date | Decision | Why |
|---|---|---|
| 2026-08-15 | Godot 4 as single cross-platform engine (not Unity) | Free/OSS, lightweight, sufficient for a minimalist 2D boxing game, one codebase for Android + iOS |
| 2026-08-15 | Supabase (Postgres) + Colyseus, not pure Firebase | Usernames need real uniqueness + search — relational fundamentals fit better than Firestore's NoSQL model; avoids extra paid search service |
| 2026-08-15 | Server-authoritative netcode, no rollback/P2P | Per-player state is tiny and discrete; rollback complexity is unjustified for this game |
| 2026-08-15 | GL Compatibility renderer for the Godot client | Widest device support across Android + iOS |
| 2026-08-15 | Colyseus pinned to `0.17.10` / `@colyseus/schema` `4.0.7` | `^0.16.0` resolved to a broken publish with unresolvable `workspace:` deps; 0.17 is current stable and required an API update (`Room<{state}>` generic, `WebSocketTransport`) |
| 2026-08-15 | Supabase account creation deferred until migrations were fully written | Stay at $0 spend as long as possible; validate the schema on paper first |
| 2026-08-15 | Supabase CLI auth via personal access token (not browser login flow) | This shell is non-TTY, so `supabase login`'s browser flow errors (`LegacyLoginMissingTokenError`); user generated a token and exported it themselves to keep it out of the chat transcript where possible |

## Misc / ad-hoc task log

*(Work that happened outside the phase checklists above — bugs hit, side fixes, small investigations.)*

| Date | Task | Outcome |
|---|---|---|
| 2026-08-15 | Diagnosed `npm install` failure (`EUNSUPPORTEDPROTOCOL workspace:`) | Root-caused to a bad `^0.16.0` Colyseus resolution; repinned to `0.17.10`, verified `tsc --noEmit` and a real server boot on `ws://localhost:2567` |
| 2026-08-15 | Verified Godot project imports headless with no script errors | Confirmed before first commit |
| 2026-08-15 | Replaced legacy Android-only `.gitignore` with one covering Godot + Node + legacy Android | Needed before first `git init` |
| 2026-08-15 | Fixed `supabase link` creating a nested `supabase/supabase/` dir | Ran it from inside `supabase/` instead of the repo root, so `supabase/migrations` resolved to a nonexistent nested path and `db push` silently found nothing; removed the bad nesting and re-linked from `D:\Dishum` |
| 2026-08-15 | Verified live schema post-push (not just trusted the "success" message) | Confirmed via `supabase migration list --linked` (all 5 timestamps match local↔remote) and direct SQL queries: `profiles`/`matches` tables exist, RLS is enabled, and `username_unique`/`username_format` constraints are active |
| 2026-08-15 | Added `supabase/.temp/` to `.gitignore` | Local CLI cache (project ref, cached version info) created by `supabase link`; not meant to be committed |
| 2026-08-15 | Moved `SUPABASE_ACCESS_TOKEN` from ad-hoc shell exports into a gitignored root `.env` (+ tracked `.env.example` documenting the var) | User flagged that re-pasting/re-exporting the token every session was pointless busywork once it was already in the chat transcript; `.env` lets the CLI auth without re-asking, while `.env.example` documents the var for anyone else setting up the repo |

## Timeline notes

No calendar deadlines have been set yet — progress is tracked by phase/task
completion, not dates. If a deadline or estimate is ever given, it will be
logged here as: **date set → original estimate → revised estimate → reason**.
