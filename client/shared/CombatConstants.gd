extends RefCounted
## Shared combat tuning — the single source of truth for balancing on the CLIENT.
## The Colyseus server mirrors these exact values in server/src/shared/combat.ts.
## Keep the two files in lockstep; the server is authoritative, the client uses
## these only for prediction/animation timing.

# Simulation
const TICK_RATE_HZ := 30           # server tick; one tick = 1000/30 ≈ 33.3 ms

# Punch lifecycle, measured in ticks (see PROPOSAL.md §2)
const WINDUP_TICKS := 6            # reaction window before the punch turns active
const ACTIVE_TICKS := 2           # hit is resolved on the first active tick
const RECOVERY_TICKS := 8         # cannot start a new punch until this completes

# Damage / health
const MAX_HEALTH := 100
const PUNCH_DAMAGE := 12          # unguarded hit
const CHIP_DAMAGE := 0            # blocked hit (0 = clean block; tune later)

# Regions (shared enum values; must match server)
enum Region { NONE = 0, HIGH = 1, MID = 2 }

# Punch phases (shared enum values; must match server's PunchPhase)
enum PunchPhase { NONE = 0, WINDUP = 1, ACTIVE = 2, RECOVERY = 3 }
