// Shared combat tuning — the single source of truth for balancing on the SERVER.
// Mirror of client/shared/CombatConstants.gd. The server is authoritative; keep
// the two files in lockstep when tuning.

export const TICK_RATE_HZ = 30; // one tick = 1000/30 ≈ 33.3 ms
export const TICK_MS = 1000 / TICK_RATE_HZ;

// Punch lifecycle, in ticks (see PROPOSAL.md §2)
export const WINDUP_TICKS = 6; // reaction window before the punch turns active
export const ACTIVE_TICKS = 2; // hit resolved on the first active tick
export const RECOVERY_TICKS = 8; // no new punch until recovery completes

// Damage / health
export const MAX_HEALTH = 100;
export const PUNCH_DAMAGE = 12; // unguarded hit
export const CHIP_DAMAGE = 0; // blocked hit (0 = clean block; tune later)

// Regions — must match the client enum values.
export enum Region {
  NONE = 0,
  HIGH = 1,
  MID = 2,
}

// Punch phases in the state machine.
export enum PunchPhase {
  NONE = 0,
  WINDUP = 1,
  ACTIVE = 2,
  RECOVERY = 3,
}
