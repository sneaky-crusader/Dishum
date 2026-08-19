# Dishum — Progress Tracker

This file is the **single source of truth** for project status. It is updated
every time a phase task, decision, or ad-hoc task happens, or a timeline
estimate changes. Query it any time with the `/progress` skill.

Checklist convention: `- [x]` done, `- [ ]` not done. Phase % = checked ÷ total
items in that phase's checklist.

Last updated: **2026-08-20**

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

**Currently active: Phase 2 is closed (live-playtested and fixed). Next session starts Phase 3 — see Timeline notes for the concrete starting plan.**

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

**Live-verified by the user in the editor (2026-08-19/20)** — the user played
Practice (vs Dummy) directly via `open-editor.bat` across several rounds and
reported real bugs from actual play, all since found and fixed (see decision
log + misc log for each): block not releasing when the key/button was
released, punches visibly cutting off mid-swing, hit-reactions sometimes not
rendering, the head/torso indicator dots and the later "HIT!"/"BLOCKED!" text
floating far from the actual on-screen character (measured and corrected
against a real pixel scan, not guessed), fighters standing almost a full
body-width apart so punches visibly swung through air, and — the last and
most gameplay-significant one — blocking a punch you'd correctly reacted to
still counting as a hit, because resolution happened on the exact tick the
punch turned active, giving a human only ~200ms from telegraph-appears to
input-must-already-be-in. That last one is now a `BLOCK_GRACE_TICKS` window
(200ms of extra reaction time after the punch turns active, mirrored on both
client and server). Phase 2 is now genuinely closed, not just checklist-complete.

**Animation reset, then re-sourced and wired the same day (2026-08-19):** the
first round of Mixamo clips was deleted as too crude to keep patching (see
decision log) and `Combat.gd` reverted to the capsule placeholder. The user
then sourced a full second round against the agreed 8-state list — one
consistent character/rig across all 8 downloads (`idle`, `upperblock`,
`midblock`, `upperpunch`, `midpunch`, `upperhitreaction`, `midhitreaction`,
`ko`) — and all 8 are now wired into `Combat.gd`/`Fighter3D.gd`:
- Idle/guard-high/guard-mid loop continuously while active (all three are
  stance-bounce clips, not single held poses — simpler than the first
  round's freeze-mid-clip hack, and looks right)
- Punch-high/punch-mid play once on the punch's NONE→triggered transition,
  same mechanism as before, but this time the fist actually reaches the
  opponent on screen (the first round's `Punching.fbx` never did)
- Hit-reaction-high/mid are new: `Fighter3D.play_hit_reaction(region)` plays
  once on the TARGET when `Combat._resolve()` sees outcome `"hit"`, then
  auto-resumes idle/guard via a one-shot timer keyed to the clip's own length
- KO is new: `Fighter3D.play_ko()` plays once and holds on `Combat._end_match()`
  for the losing fighter's model

Verified visually via a scripted, real-GPU-rendered headless run (13 PNG
screenshots stepping through idle → punch → idle-resume → block-high →
idle-resume → block-mid → hit-reaction-mid → idle-resume → hit-reaction-high
→ idle-resume → KO-triggered → KO-mid-clip → KO-final-frame) — every state is
visually distinct and transitions resume correctly. Also caught and fixed a
tooling issue along the way: `--headless` forces Godot's dummy (no-op)
renderer, so `viewport.get_texture()` is null under it — screenshotting a
real render requires dropping `--headless` and using `--quit-after` on an
otherwise-normal (GPU-backed) run instead.
`test_fighter.gd`'s 11 assertions still pass unaffected (animation changes
don't touch combat logic).

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
| 2026-08-19 | Added `BLOCK_GRACE_TICKS` (6 ticks / 200ms), decoupling hit resolution from the WINDUP→ACTIVE transition — a punch now resolves `BLOCK_GRACE_TICKS` after it turns ACTIVE, not on the same tick, using whatever block state is current at that later moment | User report: blocking a punch they'd correctly recognized and reacted to still counted as a hit. Root cause: resolution happened on the exact WINDUP→ACTIVE tick, giving a human only `WINDUP_TICKS` (200ms) from telegraph-appears to input-must-land — not enough reaction+recognition time for anyone to reliably block. Applied to both `Fighter.gd` (client) and `MatchRoom.ts`/`combat.ts` (server) to keep the mirrored implementations in lockstep per the standing decision above; added a `punchResolved` guard (non-networked field on `PlayerState`) so the now-separate resolve and RECOVERY-transition events don't double-fire. Two new tests added (`test_late_block_within_grace_window_still_counts`, `test_block_after_grace_window_is_too_late`) confirming both the fix and that blocking isn't made free by removing the deadline entirely |
| 2026-08-15 | Phase 2 fighter models are procedural (drawn via `_draw()` primitives), not sprite art | User asked directly how to create player models; offered procedural-now / free-CC0-pack / hand-drawn-later as options, user chose procedural — zero cost, fits the project's stated minimalist scope, buildable immediately without external tools. Revisit with real art before shipping if desired |
| 2026-08-15 | Fighters upgraded to real 3D characters via a SubViewport composited into the existing 2D Combat screen, not a full 3D scene conversion or pre-baked 2D sprites | User's explicit pick among three options with real tradeoffs; keeps the HUD/buttons/combat state machine entirely untouched, only swaps what renders the body. Region-state feedback (telegraph/guard/hit/blocked) moved from body fill color to small overlay indicator dots, since a real mesh has no "head color" to set |
| 2026-08-15 | Character/animation source recommended: Mixamo (free) + Blender (free) to merge character + animations into one `.glb`, imported into Godot via `character_scene` | Zero-cost, well-documented community pipeline, includes ready-made punch/guard animations; Godot 4.3+'s native glTF import needs no extra plugin. Godot's own FBX importer was considered but multi-file animation merging is much better documented via the Blender NLA route |
| 2026-08-19 | Each `Fighter3D`'s `SubViewport` sets `own_world_3d = true` | Root-caused a real rendering bug (not a logic bug): with two skinned characters animating in sibling `SubViewport`s under the GL Compatibility renderer, one of them silently failed to apply bone poses each frame (stuck near bind pose) despite `AnimationPlayer` correctly reporting `is_playing`/advancing position — the two viewports were sharing one `World3D` by default. Isolating each viewport's 3D world fixed it; confirmed via a real triggered punch through the actual game logic, not just a manual pose seek |
| 2026-08-19 | Deleted the first round of Mixamo clips (`Punching`/`MutantPunch`/`BodyBlock`/`Boxing (1).fbx`) and reverted `Combat.gd`'s character wiring back to the capsule placeholder | User judged the clips too crude/abrupt (barely-extending punches, no clean guard pose) to keep tuning incrementally; decided to plan the full animation-state list up front and source deliberately per-state instead of patching one ad-hoc download at a time. `Fighter3D.gd`'s generic mechanism (clip donation via `add_animation()`, block-hold-then-freeze, idle-resume fix) was kept since it's clip-agnostic and still correct |
| 2026-08-19 | Adopted an explicit 8-state animation list for fighters, agreed with the user before sourcing new clips: Idle (loop), Guard-High (raise+hold), Guard-Mid (raise+hold), Punch-High (single clip spanning windup→active→recovery), Punch-Mid (same), Hit-reaction-High, Hit-reaction-Mid, KO/lose pose | Maps 1:1 onto what `Fighter.gd` already tracks (`punch_phase` × 2 regions, `block` × 2 regions) plus two states the code doesn't yet drive a pose for (hit-reaction, KO) that were previously just color flashes/text; sourcing against a fixed list avoids the prior session's pattern of downloading one clip, wiring it, discovering it's wrong for the slot, and repeating |
| 2026-08-19 | Guard-high/guard-mid clips play as continuous loops while the block is held, not frozen mid-clip at a chosen timestamp (the first round's approach) | The second-round clips are ~4s stance-bounce loops just like the first round's were, but rather than re-guessing a hold timestamp per clip, looping them continuously (same treatment as idle) is simpler and reads naturally as a boxer's guard stance — confirmed visually via the screenshot verification, not just assumed |
| 2026-08-19 | Hit-reaction and KO poses added as new `Fighter3D` capabilities (`play_hit_reaction(region)`, `play_ko()`), called from `Combat.gd`'s `_resolve()`/`_end_match()` rather than threaded through the existing idle/block/punch state machine | These two are triggered by an event (a punch landing, health hitting 0), not a persistent state the fighter is "in" — hit-reaction auto-resumes idle/guard via a one-shot timer sized to the clip's own length; KO plays once and is never resumed from since the match is over |
| 2026-08-19 | Block is now a true hold (keyboard key-up and button `button_down`/`button_up`), not a press-to-toggle; punch clips resume idle/guard via their own clip length (a `_token`-guarded one-shot timer) instead of on the game logic's phase returning to NONE | User-reported bugs after the first animation pass: (1) block stayed engaged after releasing the key/button since nothing ever called `set_block(NONE)` — both keyboard (`_unhandled_key_input` only handled `pressed`) and the on-screen buttons (single-shot `pressed` signal) only ever *set* a block, never cleared one; (2) punches visibly cut off mid-swing, root-caused to the sourced clips (~1s) being longer than the punch's actual tick lifecycle (WINDUP+ACTIVE+RECOVERY ≈ 0.53s at 30Hz) — the old code forced idle/guard the instant `phase` returned to `NONE`, well before the clip finished; (3) hit-reactions sometimes silently failed to render, same root cause — if a fighter's own punch finished on the same tick they got hit, the phase-driven reset could stomp the just-triggered hit reaction before it drew a frame. Fixed by decoupling animation resume timing from game-tick phase entirely: transient clips (punch, hit-reaction) resume via their own length on a token-guarded timer, so only the most recent transient clip's timer can act, and block changes only react to actual `block` value changes, not phase transitions. Verified via scripted GPU-rendered screenshots at the exact old cutoff point (arm still mid-swing) and a forced same-tick punch/hit-reaction collision (reaction correctly takes over and resumes cleanly) |
| 2026-08-19 | Investigated a follow-up user report ("character stays in upper-block pose after an attack, even with no block pressed") — found no logic bug after exhaustive testing (11+ scripted scenarios, plus real `InputEventKey`/button-signal simulation through Godot's actual input pipeline, not just direct method calls); `player.block` and the AnimationPlayer's `current_animation` were always correct via direct engine-state inspection. Root cause instead: `idle.fbx`'s shadowboxing loop keeps hands raised near the face for its *entire* ~2.2s cycle (confirmed via an 11-frame filmstrip capture), so it looks similar to the guard pose throughout, not just momentarily — most noticeable right after an attack since that's when idle restarts from frame 0 | A "trim idle to a relaxed segment" fix (the first plan) turned out to be impossible — there's no relaxed segment in the source clip to trim to. Decided with the user to add explicit "HIT!"/"BLOCKED!" text callouts next to the affected fighter instead of trying to make body pose alone convey block state |
| 2026-08-19 | Added floating "HIT!" (red) / "BLOCKED!" (green) text callouts above whichever fighter just took a punch, alongside the existing color indicator dot; bumped the shared flash duration `FLASH_SECONDS` 0.3s → 0.6s so there's time to actually read it | Direct user request — "colors are difficult [to read]" — text spells out the outcome explicitly rather than relying on the color-coded dot alone. Reuses the existing `_player_flash`/`_dummy_flash` dictionaries (added a `"text"` key) rather than a separate mechanism, so it shares the same show/hide timing as the dot |
| 2026-08-19 | User caught (with an annotated screenshot) that the new text callouts, the head/torso indicator dots, AND the fighters' overall spacing were all wrong — dots floated in empty space above the actual head, fighters stood a full body-width apart so punches visibly swung through air, and the pair wasn't centered in the play area. Root cause: every one of these positions had been hand-guessed against assumed coordinates, never checked against where the character actually renders on screen | Fixed by measuring instead of guessing: wrote a diagnostic that scans a real rendered frame's pixel alpha channel to find the character's actual on-screen bounding box, head-row, and torso-row positions. Found the indicator dots were off by ~100px (the torso dot was sitting where the head actually is), and the idle-pose gap between fighters was ~140px — nearly a full body-width. Added `Fighter3D.HEAD_LOCAL_CENTER`/`TORSO_LOCAL_CENTER` (measured constants) that both the indicator dots and `Combat.gd`'s text-callout anchoring now derive from, instead of independent guessed offsets; moved fighters from x=220/480 to x=396/546 (closes the gap to ~30px and centers the pair between the block/punch button columns). Verified via GPU-rendered screenshots showing the fist actually in contact with the opponent's face and "HIT!"/the red dot both landing precisely on the head |

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
| 2026-08-18/19 | Multi-round debugging session wiring a real Mixamo character into `Fighter3D.gd`, closing the loop from placeholder capsule to actual animated punches | User sourced 3 different Mixamo `.fbx` downloads over the session (`Fighter.fbx`/"Punching Bag" — character only, no usable animation; `Boxing.fbx` — real motion but a crouched guard-bounce clip that read as a broken/doubled body at this viewport's resolution; `Punching.fbx` — the one that stuck, single clean punch clip). Chain of real bugs found and fixed along the way, each verified by actually rendering pixels (via a scripted headless-but-GPU-rendered Godot instance, `image.save_png()`) rather than assuming from code alone, after several rounds of guessing wrong: (1) `Fighter.fbx`'s only clip, `"Take 001"`, is a static T-pose bind-pose hold present in every Mixamo download regardless of animation chosen, not a usable idle — code was reverting to it after every punch, which is what actually caused the "stuck in T-pose" reports, not a rendering bug; (2) the "Beta" Mixamo character ships a second, invisible-by-design `*_Joints` rigging-cage mesh alongside the real skin mesh — both were rendering, causing a visible double-body ghost; (3) `_update_animation` re-triggered `AnimationPlayer.play()` on every internal WINDUP/ACTIVE/RECOVERY phase change within a single punch instead of once at punch-start, repeatedly restarting a ~1s clip that a punch resolves through in a fraction of a second; (4) the real root cause of a persistent "still looks broken" report after all of the above: two sibling `Fighter3D` `SubViewport`s (player + dummy) shared one `World3D` by default, and animating two skinned characters in it simultaneously under the GL Compatibility renderer left one stuck near bind-pose despite its `AnimationPlayer` correctly reporting `is_playing`/advancing position — fixed with `viewport.own_world_3d = true`. Also pulled `Fighter3D`'s camera back (`z=3.2→4.6`, `fov=60`) since a real punch's arm extension exceeded the old capsule-tuned frustum. Net effect: real punches now visibly animate correctly for both fighters simultaneously, verified via a real triggered punch through the actual game/combat logic (not just a manual animation seek) |
| 2026-08-19 | Cleared and rebuilt `client/.godot/imported/` mid-session as a troubleshooting step | Done while chasing the doubled-body report above, to rule out stale editor import cache as the cause before finding the real `own_world_3d` bug; turned out not to be the cause, but confirmed the editor's cache wasn't the source of confusion |
| 2026-08-19 | Fighters resized bigger and moved closer (`VIEWPORT_SIZE` 220x320→360x460, camera `z` 4.6→2.9, `fov` 60→52, positions tightened from a 640px gap to a deliberate ~100px viewport *overlap*, since backgrounds are transparent) and rotated to face each other (`rotation_degrees.y` 0/180 → 70/-70, a 3/4 stance) instead of both facing the camera dead-on | User feedback across several screenshots ("too small", "not facing each other", "hands not landing on each other"); caught and fixed a sign error on the first rotation attempt (player's punch reached away from the dummy, not toward it) by re-rendering and visually checking before calling it done. Investigated whether more closeness would fix "hands not landing" — frame-by-frame inspection of `Punching.fbx`'s clip showed the fist barely extends forward at any point (it's more of a guard bounce than a reaching jab), so no amount of distance-tuning fixes that; user chose to leave it as a placeholder rather than re-source the clip |
| 2026-08-19 | Added `Fighter3D.add_animation()` — donates one Mixamo download's baked clip into another (same-rig) character's own `AnimationPlayer` under a new name, so a full move set can be assembled from several single-clip Mixamo downloads without swapping the whole character each time | Discovered `MutantPunch.fbx` and `BodyBlock.fbx` are the same "Beta" mesh/rig as `Punching.fbx` just with different baked motion, making this viable. Wired `MutantPunch.fbx` in as a distinct punch-mid clip; verified via a real triggered mid-punch through the actual game logic (distinct pose from punch-high, hit landed on the correct MID region) |
| 2026-08-19 | Added an explicit test (`test_block_region_must_match_punch_region`) confirming a HIGH block never stops a MID punch and vice versa | Direct response to a user question about this exact behavior; the logic already existed and was implicitly covered, but wasn't named/asserted for this specific scenario — added for clarity and regression safety, not because a bug was found |
| 2026-08-19 | `BodyBlock.fbx` wired in as the HIGH-block pose, with a real transition instead of an instant snap: pressing block now plays the donor clip forward from its own start (its baked low-guard→raised-guard motion serves as the "wind up") and freezes once playback passes a chosen timestamp (`guard_high_hold_time`), via `AnimationPlayer.stop(keep_state=true)` | User explicitly asked for a transition before the held pose, and for release to be instant rather than staying frozen. Two real bugs found and fixed via actual rendered verification, not assumption: (1) setting `current_animation` directly implicitly resumes playback, so an instant `seek()`-only "freeze" actually kept drifting through the rest of the clip — fixed by using `play()` + `seek()` + `stop(true)`; (2) `stop(keep_state=true)` clears `AnimationPlayer.current_animation` to empty even though it preserves the visible pose, which silently broke the release path's `if current_animation != ""` guard — fixed by tracking the clip name in a dedicated variable instead of relying on that property. Explicitly confirmed with the user this is visual-only — block still protects instantly per `docs/PROPOSAL.md`'s documented "hold state, instant on press" design; a real gameplay wind-up/vulnerability window was considered and declined |
| 2026-08-19 | User asked for a continuous idle/shadow-boxing loop (`Boxing (1).fbx`, not the original `Boxing.fbx` from earlier in the session — a mid-session correction) whenever a fighter isn't blocking or punching, replacing the earlier "just freeze on whatever frame was last showing" behavior | Re-added a Boxing-named download since the original `Boxing.fbx` had been deleted earlier for reading as a broken/doubled body — that verdict predates the `own_world_3d` fix and may have been an unfair blame at the time, but the user pointed at a *different* file (`Boxing (1).fbx`) as the correct stance clip regardless, which was used. Confirmed same "Beta" rig (`mixamorig_Hips` bone naming matches), donated as `"idle"` via the existing `add_animation()` mechanism, set to loop. Restructured `Fighter3D._update_animation`'s block-release path to resume idle instead of freezing on the block clip's frame 0. **Not yet confirmed by a rendered screenshot** — session was cut short mid-verification; headless smoke tests and the full `test_fighter.gd` suite both pass, but re-render and visually confirm the idle→punch→idle and idle→block→idle transitions actually look right before trusting this is done |

## Timeline notes

No calendar deadlines have been set yet — progress is tracked by phase/task
completion, not dates. If a deadline or estimate is ever given, it will be
logged here as: **date set → original estimate → revised estimate → reason**.

## Next session plan (written 2026-08-20, end of the Phase 2 wrap-up session)

Phase 2 is closed. Start Phase 3 — Authoritative multiplayer. Concrete
starting points, in order:

1. **Harden `MatchRoom.ts`'s tick loop past the Phase 0 stub.** The
   `advancePunch`/`resolveHit` logic is already correct and in lockstep with
   `Fighter.gd` (including the new `BLOCK_GRACE_TICKS` window from this
   session) — this step is about production-hardening (reconnect handling,
   malformed-input rejection, malicious-client input validation per the
   pre-ship security checklist), not rewriting the rules.
2. **Verify Supabase JWT on client connect** — the server currently trusts
   any connection; needs real auth before two real clients can play.
3. **Wire the Godot client to Colyseus** — replace `Combat.gd`'s local tick
   loop + dummy AI with a real `Room<MatchState>` connection (join, send
   `setBlock`/`throwPunch` messages, render from synced `MatchState` instead
   of local `Fighter` instances). This is the biggest single chunk of work
   in the phase — `Fighter3D`'s animation-driving `set_state()` call and the
   HIT!/BLOCKED! text callouts should mostly just need to be fed from
   server state instead of local state, since they were built against the
   same `Combat.Region`/`PunchPhase` enums the server uses.
4. **Interpolation/smoothing of opponent state** — needed once real network
   latency is in the loop; local-only testing won't surface this, so budget
   time for it rather than treating it as an afterthought.
5. **Two real devices fighting over the internet, end to end** — the actual
   phase-closing milestone.

Also still open from Phase 0 (low priority, doesn't block Phase 3): archive
the legacy Android-only `app/` scaffold, deferred until Godot Android export
is verified.
