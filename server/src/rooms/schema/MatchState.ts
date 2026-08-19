// Colyseus synced state — automatically diffed and streamed to both clients.
// Keep this MINIMAL: only what a client must render. Live match state lives
// here in room memory only; final results are written to Supabase (Phase 5).

import { Schema, MapSchema, type } from "@colyseus/schema";
import { Region, PunchPhase, MAX_HEALTH } from "../../shared/combat.js";

export class PlayerState extends Schema {
  @type("string") sessionId = "";
  @type("string") username = "";
  @type("uint8") health = MAX_HEALTH;

  // Which region this player is currently guarding.
  @type("uint8") block: Region = Region.NONE;

  // Current punch (region + phase + when it started, in ticks).
  @type("uint8") punchRegion: Region = Region.NONE;
  @type("uint8") punchPhase: PunchPhase = PunchPhase.NONE;
  @type("uint32") punchStartTick = 0;

  // Server-internal bookkeeping, not synced to clients: guards against
  // resolving the same punch twice now that the resolve tick and the
  // ACTIVE->RECOVERY tick are separate events (see BLOCK_GRACE_TICKS).
  punchResolved = false;
}

export class MatchState extends Schema {
  @type("uint32") tick = 0;
  @type("string") phase = "waiting"; // waiting | countdown | live | ended
  @type("string") winner = "";
  @type({ map: PlayerState }) players = new MapSchema<PlayerState>();
}
