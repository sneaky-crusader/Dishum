# Dishum — Cross-Platform Multiplayer Boxing Game: Technical Proposal

## Context

Dishum is a **minimalist real-time multiplayer boxing game** for Android **and** iOS.
The current repo started as an empty **Android-only** Kotlin/Gradle scaffold — it
cannot ship to iOS and has no game code. To meet the cross-platform + realtime
requirements, we are replacing that scaffold with a game-engine project plus a small
backend. This document is the agreed proposal; implementation follows the roadmap below.

### Gameplay (as specified)
- **Landscape** orientation. Two players, **stationary** (no movement/positioning).
- Local player is drawn on the **right**; opponent faces them from the **left/front**.
- **Four buttons**: blocks on the **left** thumb, punches on the **right** thumb.
  - Block: **HIGH (face)** or **MID (body)** — mutually exclusive (only one region guarded at a time).
  - Punch: **HIGH** or **MID** — mutually exclusive (only one punch resolving at a time).
- Fast-paced, reaction-based: land a punch on an unguarded region; a guarded region is blocked.

### Agreed stack
- **Client/Engine:** Godot 4 (single codebase → Android + iOS).
- **Backend:** Managed BaaS (**Supabase**: auth + Postgres + presence) **+** dedicated
  authoritative realtime server (**Colyseus** on Node.js).
- **Matchmaking:** **both** — direct challenge by unique username, and a random quick-match queue.
- **Netcode:** **server-authoritative** (server is referee; clients send inputs; server resolves & broadcasts).

---

## 1. Why this architecture fits

The entire per-player game state is tiny and **discrete**:

```
block  ∈ {NONE, HIGH, MID}      # which region is currently guarded
punch  ∈ {NONE, HIGH, MID} + phase (windup/active/recovery) + startTick
health ∈ 0..100
stamina (optional)
```

Because state is small and updates are event-like, a **server-authoritative** model is
both simple and cheat-resistant, and easily fast enough for reaction-based boxing. We do
**not** need rollback/P2P netcode (the complexity of GGPO-style netcode is unjustified here).

---

## 2. Combat state machine (drives both client and server logic)

Punch lifecycle (server-simulated at a fixed tick, e.g. **30 Hz**):

```
NONE ──press HIGH/MID──▶ WINDUP (Wf ticks) ──▶ ACTIVE (Af ticks) ──▶ RECOVERY (Rf ticks) ──▶ NONE
```

- **Windup** gives the opponent a reaction window to raise the matching block.
- **Hit resolution** happens on the first ACTIVE tick:
  - Punch region == opponent's current `block` region → **blocked** (maybe chip/stamina cost).
  - Else → **hit** (apply damage, trigger hit-reaction animation).
- Blocks are **hold** state: pressing a block button sets `block` immediately; releasing (or
  pressing the other block) changes it. Only one region guarded at a time.
- A new punch cannot start until the previous punch returns to NONE (enforces "one punch at a time").
- Win condition: opponent health ≤ 0, or higher health at time limit (round/timer TBD).

Tunable constants (`Wf`, `Af`, `Rf`, damage, timer) live in one shared config so balancing is trivial.

---

## 3. System components

```
 ┌─────────────┐        ┌──────────────────────────────┐
 │  Godot 4    │  HTTPS │  Supabase (managed BaaS)      │
 │  client     ├───────▶│  • Auth (email/pass)          │
 │ (iOS/Android)│       │  • Postgres: users, matches   │
 │             │        │  • unique username index      │
 │             │        │  • presence (online status)   │
 │             │        └──────────────────────────────┘
 │             │  WSS   ┌──────────────────────────────┐
 │             ├───────▶│  Colyseus game server (Node)  │
 └─────────────┘        │  • Match rooms (authoritative)│
                        │  • 30Hz tick simulation       │
                        │  • Quick-match queue           │
                        │  • Validates Supabase JWT      │
                        └──────────────────────────────┘
```

### 3a. Supabase (accounts, directory, history)
- **Auth**: registration/login (email+password to start; social later).
- **`profiles`** table: `id (uuid, = auth.uid)`, `username (citext, UNIQUE)`, `created_at`,
  `wins`, `losses`, `rating`. Username uniqueness enforced by a **unique index**; search via
  `ILIKE`/prefix index for the "find a user" screen.
- **Presence**: Supabase Realtime presence (or Colyseus lobby) for online/offline + "in match".
- **`matches`** table: match history/results for stats.
- **Row-Level Security** so users can only mutate their own profile.

### 3b. Colyseus realtime game server (authoritative matches)
- One **Room per match** holds authoritative state; Colyseus auto-syncs state → both clients.
- Fixed **tick loop** advances punch phases and resolves hits.
- **Client → server** messages: `setBlock(region|none)`, `throwPunch(region)`.
- **Server → clients**: authoritative state patches (health, block, punch phase, hit events).
- On connect, client presents its **Supabase JWT**; server verifies it (shared secret / JWKS)
  so match identities are trusted.
- **Quick-match queue** + **direct-challenge** room creation both live here (see §5).
- Room lifecycle: create → both joined → countdown → live → result → write to Supabase `matches`
  and update W/L/rating → close.

### 3c. Client responsiveness (feel)
- Your **own block** is applied locally on press for instant feedback (it's your own state; server confirms).
- Punches show local **windup animation immediately**; the **hit outcome is server-confirmed**
  (prevents desync/cheating). Interpolate opponent state between server patches for smoothness.
- Small input-buffer + server timestamps for basic lag tolerance. No rollback needed.

---

## 4. Data model (Supabase / Postgres)

| Table | Key columns | Notes |
|-------|-------------|-------|
| `profiles` | `id uuid PK`, `username citext UNIQUE`, `wins`, `losses`, `rating`, `created_at` | 1:1 with auth user; RLS owner-only writes |
| `matches` | `id`, `player_a`, `player_b`, `winner`, `started_at`, `ended_at`, `score` | history + stats source |
| `friends` (optional, later) | `user_id`, `friend_id`, `status` | for a friends/challenge list |

Live match state lives **in Colyseus room memory only** (not the DB) — the DB stores results.

---

## 5. Matchmaking flows

**Direct challenge (username):**
1. Player searches username → Supabase profile lookup → sees online status.
2. Sends challenge (via Colyseus lobby message or a `challenges` channel).
3. Opponent accepts → Colyseus creates a match room → both join by room id.

**Random quick-match:**
1. Player taps "Quick Match" → joins Colyseus matchmaking queue.
2. Server pairs two waiting players (optionally rating-banded) → creates room → both join.

Both paths converge on the **same match room** logic, so combat code is written once.

---

## 6. Proposed repository layout

Replace the Android-only scaffold with a monorepo:

```
Dishum/
├─ client/            # Godot 4 project (exports Android + iOS)
│  ├─ scenes/         # menu, login, user-search, match
│  ├─ scripts/        # input, netcode client, animation, UI
│  └─ shared/         # combat constants (mirror of server tuning)
├─ server/            # Colyseus (Node.js/TypeScript)
│  ├─ rooms/MatchRoom.ts
│  ├─ rooms/Lobby.ts  # search/challenge/quick-match
│  └─ schema/         # synced state schema
├─ supabase/          # SQL migrations, RLS policies, seed
└─ docs/PROPOSAL.md   # this document, committed into the repo
```

*(The existing `app/` Android scaffold can be archived/removed once Godot Android export is verified.)*

---

## 7. Implementation roadmap (phased)

**Phase 0 — Foundations**
- Stand up Supabase project (auth + `profiles` + unique username + RLS).
- Scaffold Godot 4 project (landscape lock, both export presets), and Colyseus server skeleton.

**Phase 1 — Accounts & directory**
- Godot: register/login screens against Supabase; username-search screen with online status.

**Phase 2 — Core combat (local first)**
- Build the 4-button landscape HUD (blocks left, punches right), fighters (right=local, left=opponent).
- Implement the combat state machine + animations against a local/dummy opponent (no network yet).

**Phase 3 — Authoritative multiplayer**
- Colyseus `MatchRoom` with 30Hz tick, input messages, hit resolution, state sync.
- Wire Godot to Colyseus; JWT auth; two real devices fighting over the internet.

**Phase 4 — Matchmaking**
- Direct challenge-by-username + random quick-match queue → both create match rooms.

**Phase 5 — Results & polish**
- Persist match results, update W/L/rating; round timer, win screen; latency/feel tuning.

**Phase 6 — Ship**
- Android build + iOS build (needs a Mac/Xcode for iOS signing), store setup.

---

## 8. Verification (how we prove each phase works)

- **Backend unit/integration:** Colyseus room tests (simulate two clients throwing punches/blocks;
  assert hit vs blocked outcomes and health). Supabase: test username uniqueness + RLS via SQL/API.
- **Combat correctness:** headless test that drives the state machine through windup→active→recovery
  and checks block-vs-region resolution for all 4 combinations.
- **End-to-end:** run the Colyseus server locally, launch **two** Godot clients, log in as two users,
  match via username **and** via quick-match, and confirm real-time punch/block/hit sync and the
  final result is written to Supabase.
- **Mobile:** export debug APK (Android) early to validate landscape + touch layout on a real device;
  validate iOS export once a Mac/Xcode is available.

---

## 9. Open items to decide during build (not blocking)

- **iOS build machine:** iOS export/signing requires macOS + Xcode + Apple Developer account — confirm access.
- **Hosting for Colyseus:** Fly.io / a small VM / Colyseus Cloud (pick in Phase 3).
- **Round format:** single life-bar vs timed rounds; exact damage/windup tuning (Phase 5 balancing).
- **Art:** two fighter sprites + block/punch/hit animations (placeholder art acceptable through Phase 5).
- **Social scope:** friends list / rematch / leaderboards (post-MVP).
