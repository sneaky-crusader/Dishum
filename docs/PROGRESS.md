# Dishum — Progress Tracker

This file is the **single source of truth** for project status. It is updated
every time a phase task, decision, or ad-hoc task happens, or a timeline
estimate changes. Query it any time with the `/progress` skill.

Checklist convention: `- [x]` done, `- [ ]` not done. Phase % = checked ÷ total
items in that phase's checklist.

Last updated: **2026-08-15** (bumped again same day)

---

## Phase status at a glance

| Phase | Name | % complete |
|---|---|---|
| 0 | Foundations | 83% |
| 1 | Accounts & directory | 100% |
| 2 | Core combat (local) | 0% |
| 3 | Authoritative multiplayer | 0% |
| 4 | Matchmaking | 0% |
| 5 | Results & polish | 0% |
| 6 | Ship | 0% |

**Currently active: Phase 2 — Core combat, local first.**

---

## Phase 0 — Foundations (83%)

- [x] Write technical proposal (`docs/PROPOSAL.md`)
- [x] Install Godot 4 + verify Node.js tooling
- [x] Scaffold Godot 4 client (landscape lock, placeholder 4-button HUD, shared combat constants)
- [x] Scaffold Colyseus server (MatchRoom, 30Hz tick loop, punch state machine stub)
- [x] Git-init repo + first commit
- [ ] Archive/remove legacy Android-only `app/` scaffold (deferred until Godot Android export is verified)

## Phase 1 — Accounts & directory (100%) ✅

- [x] Write Supabase SQL migrations (`profiles`, `matches`, RLS, search index, `apply_match_result()`)
- [x] Create Supabase project (account + provisioning) — project ref `griglxichqiwdffajwtz`
- [x] Push migrations to the live project (`supabase db push`) — all 5 applied and verified live
- [x] Godot: register/login screens against Supabase Auth — `AuthClient.gd` autoload (REST via
      `HTTPRequest`, no native SDK) + `Login.tscn`/`Register.tscn`; verified end-to-end against
      the live project (real signup, real confirmation email, real login, session persistence)
- [x] Godot: username-search screen with online status — `UserSearch.tscn`/`.gd`, debounced
      query against `profiles` REST endpoint; **verified live from the actual Godot client**
      (not just headless) — searched a real second account by partial username and got the
      right result with correct presence status
- [x] Wire presence (online/offline/in-match) — `PresenceClient.gd`, hand-rolled Supabase
      Realtime protocol; a Node prototype confirmed real join/track/presence_state/presence_diff/leave
      against the live project, and the live Godot client confirmed a real second account
      showing online, then automatically flipping to offline within seconds of disconnecting
      (no re-search needed — proves the live `presence_diff` → UI update path). "In-match"
      status still deferred to Phase 4 (needs `MatchRoom` lifecycle, per the original plan)

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

## Pre-ship checklist (cross-cutting, not tied to one phase)

- [ ] **Patent/IP check** — decide whether the game concept/mechanics are worth
      filing for or otherwise protecting before any public/wide release.
      Needs a real decision (likely with a lawyer), not just a Claude opinion —
      flag this again as ship approaches, don't let it get missed.
- [ ] **Security review before shipping** — at minimum: RLS policy audit on
      `profiles`/`matches`, confirm `sb_secret_`/`service_role` key never left
      the server, Colyseus input validation (a malicious client can send
      arbitrary `setBlock`/`throwPunch` messages — server must not trust
      anything it doesn't itself compute), auth token handling on the client,
      rate limiting / abuse potential on matchmaking and auth endpoints.
- [ ] **Fix transactional email (custom SMTP)** — currently running on Supabase's
      *default* mailer (severe rate limits, unsuitable for real users). Attempted
      Resend as custom SMTP; credentials/host/port verified 100% correct via a
      standalone nodemailer test, and the config was confirmed correctly persisted
      via both the Management API and the dashboard UI — but Supabase's auth
      service still fails with `Error sending confirmation email` (HTTP 500) on
      every real signup attempt while custom SMTP is enabled, with **zero**
      corresponding attempts ever appearing in Resend's own delivery logs
      (i.e. GoTrue fails before it even reaches Resend). Disabled custom SMTP
      for now to unblock testing (reverted to default mailer). Needs a proper
      investigation before shipping — likely a Supabase support ticket or
      community search for this exact error, not more blind config tweaking.
- [ ] **Test coverage** — write automated tests as real logic lands (combat
      state machine, `MatchRoom` hit resolution, `AuthClient` error
      translation, RLS/constraint behavior) and **re-run them regularly**,
      not just once at write-time — user's explicit standing instruction,
      also captured in `CLAUDE.md`.

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
| 2026-08-15 | Registration = email + password + username, with mandatory email confirmation before login | User decision; confirmed the live project already enforces this by default (`mailer_autoconfirm: false`) |
| 2026-08-15 | Auth via plain `HTTPRequest` REST calls to Supabase Auth, not a native GDExtension SDK | Keeps the iOS-compatibility guarantee — zero native plugin dependency, identical code path on Android/iOS/desktop |
| 2026-08-15 | Client uses the `sb_publishable_...` key only; `sb_secret_...`/`service_role` never touches the client | Publishable key is designed to be public (RLS is the real boundary); secret key is reserved for the Colyseus server in Phase 5 |
| 2026-08-15 | Presence = real Supabase Realtime (hand-rolled Phoenix-channel protocol), not a simpler last-seen timestamp | User's explicit choice over the recommended simpler alternative, accepting the extra protocol-implementation work |
| 2026-08-15 | Protocol details for Realtime presence sourced from `realtime-js` SDK source, not Supabase's public docs | Docs only cover SDK usage, not the wire format (confirmed by fetching the docs page directly) — the source is the only accurate reference |
| 2026-08-15 | Prototyped the presence protocol in a throwaway Node script against the live project before writing any GDScript | New protocol work is easy to get subtly wrong; caught a real bug this way (see Misc log) that would've been much slower to find inside Godot |
| 2026-08-15 | Custom SMTP (Resend) disabled, reverted to Supabase's default mailer for now | Spent significant effort debugging a `500 Error sending confirmation email` with verified-correct credentials/config and no resolution; unblocking actual feature work took priority over continuing to debug Supabase's infra — tracked in the Pre-ship checklist to revisit properly |

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
| 2026-08-15 | Linked and pushed to GitHub remote `github.com/sneaky-crusader/Dishum` (`origin/master`) | Repo was empty on GitHub, so pushed all local history with no conflicts; existing Git Credential Manager handled auth |
| 2026-08-15 | Verified auth error-message translation against real API responses, not assumptions | Duplicate-username-via-trigger returns HTTP 500 with `message` (not `msg`) containing `"unique constraint \"username_unique\""` — confirmed `AuthClient._translate_signup_error` catches it; confirmed the failed transaction leaves zero orphan `auth.users` rows; confirmed unconfirmed-email login returns `{"msg":"Email not confirmed"}`; confirmed re-signup on an unconfirmed email hits a resend rate-limit (429) rather than a hard duplicate error |
| 2026-08-15 | Ran a full real register → confirm-email → login → fetch-profile cycle against the live project via curl (same calls `AuthClient.gd` makes), then deleted the test account | Proved the whole auth chain works end-to-end, not just "no error thrown"; cleanup confirmed the FK cascade removes the profile too |
| 2026-08-15 | Added a standing pre-ship checklist (patent/IP check, security review, ongoing test coverage) | User instruction — don't let these get forgotten in the rush of feature work; tracked cross-phase since none of them belong to a single phase |
| 2026-08-15 | Found and fixed a track-retrigger bug in the presence protocol prototype before it reached GDScript | Matched "any ok `phx_reply`" instead of specifically the join reply, so every `track` ack re-triggered another `track`, flooding the channel until the server returned `"Client presence rate limit exceeded"` and closed the connection. This is exactly why the plan called for prototyping in Node first — fixed there in seconds, would have been much slower to diagnose inside Godot |
| 2026-08-15 | Confirmed a real protocol quirk: `presence_state` can arrive empty even when other members are already present | The subsequent `presence_diff` backfills them, so `PresenceClient.gd`'s merge logic (replace-on-state, merge-on-diff) already converges correctly — no code change needed, just confirms the design assumption was right |
| 2026-08-15 | Extensive SMTP/Resend debugging session (see Decision log + Pre-ship checklist for the outcome) | Chronology: (1) direct nodemailer test proved Resend credentials 100% valid; (2) discovered the Management API's `config/auth` PATCH does **not** partial-merge — a single-field PATCH (`rate_limit_email_sent` alone) silently nulled every other SMTP field, which explains several of the earlier "still nothing" reports; (3) discovered repeated "test" signups to the *same* email were silent no-ops the whole time, since Supabase won't re-send confirmation for an already-confirmed identity (by design, anti-enumeration) — several rounds of "fix and retest" were actually retesting nothing; (4) with a genuinely fresh email and a complete atomic config write, got a real `500 Error sending confirmation email` with zero corresponding attempts in Resend's logs, meaning Supabase's auth service fails before ever reaching Resend; (5) discovered custom SMTP failure makes signup itself hard-fail (not just the email), blocking account creation entirely; (6) disabled custom SMTP to restore account creation via the default mailer, then used the already-approved manual-SQL-confirm pattern to unblock real testing |
| 2026-08-15 | Ran the full live two-account search + presence test from the actual Godot client (not just curl/Node) | Registered `dishum_probe` via the (restored) default mailer, confirmed it via SQL, pointed the Node presence prototype at its *real* profile id (an earlier attempt used a fake id, which correctly found nothing — not a bug), then confirmed from the running Godot editor: search found it, presence dot showed online, and killing the prototype flipped the dot to offline automatically within seconds with no re-search — proving the live `presence_diff` → UI path works |

## Timeline notes

No calendar deadlines have been set yet — progress is tracked by phase/task
completion, not dates. If a deadline or estimate is ever given, it will be
logged here as: **date set → original estimate → revised estimate → reason**.
