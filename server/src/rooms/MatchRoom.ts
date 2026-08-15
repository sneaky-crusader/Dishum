// Authoritative 1v1 match room. One instance = one boxing match.
// Phase 0: the tick loop, input messages, and hit resolution are stubbed with
// the real structure so Phase 3 fills in behaviour, not scaffolding.

import { Room, Client } from "colyseus";
import { MatchState, PlayerState } from "./schema/MatchState.js";
import {
  Region,
  PunchPhase,
  TICK_MS,
  WINDUP_TICKS,
  ACTIVE_TICKS,
  RECOVERY_TICKS,
  PUNCH_DAMAGE,
} from "../shared/combat.js";

export class MatchRoom extends Room<{ state: MatchState }> {
  maxClients = 2;

  onCreate(_options: unknown): void {
    this.setState(new MatchState());

    // Client → server inputs.
    this.onMessage("setBlock", (client, region: Region) => {
      const p = this.state.players.get(client.sessionId);
      if (p) p.block = region;
    });

    this.onMessage("throwPunch", (client, region: Region) => {
      const p = this.state.players.get(client.sessionId);
      if (!p) return;
      // One punch at a time: only start from NONE.
      if (p.punchPhase === PunchPhase.NONE) {
        p.punchRegion = region;
        p.punchPhase = PunchPhase.WINDUP;
        p.punchStartTick = this.state.tick;
      }
    });

    // Fixed 30Hz authoritative simulation.
    this.setSimulationInterval((_dt) => this.tick(), TICK_MS);
  }

  onJoin(client: Client, options: { username?: string }): void {
    const p = new PlayerState();
    p.sessionId = client.sessionId;
    p.username = options?.username ?? "guest";
    this.state.players.set(client.sessionId, p);
    if (this.state.players.size === 2) this.state.phase = "countdown";
  }

  onLeave(client: Client): void {
    this.state.players.delete(client.sessionId);
    if (this.state.phase === "live") this.state.phase = "ended";
  }

  private tick(): void {
    if (this.state.phase !== "live" && this.state.phase !== "countdown") return;
    this.state.tick++;

    // TODO(Phase 3): countdown → live transition on a timer.
    if (this.state.phase === "countdown") this.state.phase = "live";

    const players = Array.from(this.state.players.values());
    for (const p of players) this.advancePunch(p, players);
  }

  // Drives one player's punch through WINDUP → ACTIVE → RECOVERY → NONE and
  // resolves the hit on the first ACTIVE tick.
  private advancePunch(p: PlayerState, all: PlayerState[]): void {
    if (p.punchPhase === PunchPhase.NONE) return;
    const elapsed = this.state.tick - p.punchStartTick;

    if (p.punchPhase === PunchPhase.WINDUP && elapsed >= WINDUP_TICKS) {
      p.punchPhase = PunchPhase.ACTIVE;
      this.resolveHit(p, all);
    } else if (
      p.punchPhase === PunchPhase.ACTIVE &&
      elapsed >= WINDUP_TICKS + ACTIVE_TICKS
    ) {
      p.punchPhase = PunchPhase.RECOVERY;
    } else if (
      p.punchPhase === PunchPhase.RECOVERY &&
      elapsed >= WINDUP_TICKS + ACTIVE_TICKS + RECOVERY_TICKS
    ) {
      p.punchPhase = PunchPhase.NONE;
      p.punchRegion = Region.NONE;
    }
  }

  private resolveHit(attacker: PlayerState, all: PlayerState[]): void {
    const target = all.find((x) => x.sessionId !== attacker.sessionId);
    if (!target) return;
    // Landed unless the target is guarding the same region.
    if (target.block !== attacker.punchRegion) {
      target.health = Math.max(0, target.health - PUNCH_DAMAGE);
      this.broadcast("hit", { target: target.sessionId, region: attacker.punchRegion });
      if (target.health === 0) {
        this.state.phase = "ended";
        this.state.winner = attacker.sessionId;
        // TODO(Phase 5): persist result to Supabase `matches`, update W/L/rating.
      }
    } else {
      this.broadcast("blocked", { target: target.sessionId, region: attacker.punchRegion });
    }
  }
}
