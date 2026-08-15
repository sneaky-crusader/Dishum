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
| 2 | Core combat (local) | 100% |
| 3 | Authoritative multiplayer | 0% |
| 4 | Matchmaking | 0% |
| 5 | Results & polish | 0% |
| 6 | Ship | 0% |

**Currently active: Phase 2 wrap-up — needs a final live playtest to confirm feel/readability before moving to Phase 3.**

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

## Phase 2 — Core combat, local first (100%) ✅

- [x] Real 4-button landscape HUD (replaces Phase 0 placeholder) — `Combat.tscn`/`.gd`,
      wired to real punch/block logic (Phase 0's HUD in `Main.gd` was decorative only);
      `Main.gd` is now a plain post-login menu (identity, logout, find players, practice)
- [x] Fighter art/placeholders (right = local, left = opponent) — `ColorRect` placeholders
      with labels, positioned per the agreed layout (local RIGHT, opponent LEFT)
- [x] Client-side combat state machine vs. a local/dummy opponent — `Fighter.gd` is a
      direct GDScript port of `MatchRoom.ts`'s `advancePunch`/`resolveHit`, deliberately
      kept in lockstep so Phase 3 swaps in real server state without changing the rules;
      dummy opponent is a simple random-interval AI, not meant to be smart
- [x] Hit/block/windup animations — `FighterModel.gd`, a procedural humanoid
      (head/torso/arms/legs drawn via `_draw()`, no external art) whose arm pose
      animates by punch phase (chambered back on WINDUP, extended on ACTIVE,
      retracting on RECOVERY) and block state (raised for HIGH guard, crossed
      for MID guard), layered with the existing head/torso region coloring
- [x] Health bar UI — `ProgressBar` per fighter, live-bound to `Fighter.health`, plus a
      win/lose end screen with Rematch/Back-to-menu

**Not yet live-verified** — headless smoke tests (`--import`, `--quit-after`) pass with
no script/scene errors, and the state machine itself has unit tests (see below), but the
assistant has no GUI access, so actual feel/playability needs the user to run it via
`open-editor.bat` → Practice (vs Dummy).

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
| 2026-08-15 | Client's `Fighter.gd` is a deliberate line-for-line GDScript port of `MatchRoom.ts`'s state machine, not an independent implementation | Phase 3 needs local prediction/animation timing to match the server exactly; writing it as a port now (and testing both against the same tick math) makes divergence a merge-conflict-style diff to catch later instead of a silent gameplay bug |
| 2026-08-15 | Phase 2 fighter models are procedural (drawn via `_draw()` primitives), not sprite art | User asked directly how to create player models; offered procedural-now / free-CC0-pack / hand-drawn-later as options, user chose procedural — zero cost, fits the project's stated minimalist scope, buildable immediately without external tools. Revisit with real art before shipping if desired |
| 2026-08-15 | Fighters upgraded to real 3D characters via a SubViewport composited into the existing 2D Combat screen, not a full 3D scene conversion or pre-baked 2D sprites | User's explicit pick among three options with real tradeoffs; keeps the HUD/buttons/combat state machine entirely untouched, only swaps what renders the body. Region-state feedback (telegraph/guard/hit/blocked) moved from body fill color to small overlay indicator dots, since a real mesh has no "head color" to set |
| 2026-08-15 | Character/animation source recommended: Mixamo (free) + Blender (free) to merge character + animations into one `.glb`, imported into Godot via `character_scene` | Zero-cost, well-documented community pipeline, includes ready-made punch/guard animations; Godot 4.3+'s native glTF import needs no extra plugin. Godot's own FBX importer was considered but multi-file animation merging is much better documented via the Blender NLA route |

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
| 2026-08-15 | Added `client/tests/test_fighter.gd`, a headless GDScript test suite for the punch state machine | Run via `godot --headless --path client --script tests/test_fighter.gd`; 9 assertions across 5 scenarios (unguarded hit, guarded block, one-punch-at-a-time, full WINDUP→ACTIVE→RECOVERY→NONE lifecycle + re-throw, KO health clamp), all passing. Per the standing test-writing instruction — written alongside the logic, not after |
| 2026-08-15 | Verified `Combat.tscn`/`Main.tscn` headlessly (`--import` + `--quit-after`) — no script/scene errors | Confirms the scenes load and run without crashing; does **not** confirm feel/playability, since the assistant has no GUI access — flagged in the Phase 2 checklist as needing the user's own live playtest |
| 2026-08-15 | User playtest feedback on `Combat.tscn`: player fighter rendered on the LEFT instead of the intended RIGHT; flat-color `ColorRect`s were unreadable (couldn't tell HIGH vs MID or what to do) | Swapped the player/dummy x-positions (couldn't reproduce/verify visually myself — assistant has no GUI access, so this is a direct response to the user's report rather than independently re-derived); replaced single flat rects with head (HIGH) + torso (MID) shapes per fighter, with a color legend (yellow=incoming attack telegraphed on the region to block, blue=guarding, green=blocked, red=hit) so the user can see which attack is coming and which button to press |
| 2026-08-15 | Second playtest round: still couldn't tell which region was blocked, and testing on a non-touch laptop meant a single mouse cursor couldn't hold a block button and press a punch button at the same time (the game is designed for two-thumb touch input) | Added an explicit "Blocking: HIGH/MID/none" text label under each fighter (unambiguous regardless of color perception); added keyboard shortcuts (Q/A = block high/mid, O/L = punch high/mid) purely so the intended simultaneous block+punch input is actually testable on a mouse-only dev machine — mobile input stays button-only, this doesn't change the design |
| 2026-08-15 | Built `FighterModel.gd` — procedural humanoid fighters (head/torso/arms/legs via `_draw()`) replacing the flat head/torso `ColorRect`s, closing out the last open Phase 2 checklist item | Verified headless (`--import` + `--quit-after`, no errors) and the Fighter state-machine tests still pass (untouched logic); visual feel/readability still needs the user's own live playtest since the assistant has no GUI access |
| 2026-08-15 | User asked for real 3D-looking characters with punch/block animations; built `Fighter3D.gd` (SubViewport-composited 3D character, capsule placeholder + `character_scene`/animation-name export hooks) and `CombatColors.gd` (shared color constants so 2D and 3D renderers agree) | Chose live-3D-via-SubViewport over full 3D scene conversion or pre-baked 2D sprites (user's explicit pick — see decision log); caught a real bug in headless testing (`Camera3D.look_at()` called before the node was in the tree, `--quit-after` run threw immediately) and fixed it before considering this done |

## Timeline notes

No calendar deadlines have been set yet — progress is tracked by phase/task
completion, not dates. If a deadline or estimate is ever given, it will be
logged here as: **date set → original estimate → revised estimate → reason**.
