extends RefCounted
class_name Fighter
## One fighter's combat state + pure state-machine logic.
##
## This is a GDScript port of the server's authoritative logic in
## server/src/rooms/MatchRoom.ts (advancePunch/resolveHit) — kept in lockstep
## deliberately so local practice (Phase 2) behaves identically to real
## matches once Phase 3 wires this up to Colyseus instead of a local dummy.

const Combat := preload("res://shared/CombatConstants.gd")

var health: int = Combat.MAX_HEALTH
var block: int = Combat.Region.NONE
var punch_region: int = Combat.Region.NONE
var punch_phase: int = Combat.PunchPhase.NONE
var punch_start_tick: int = 0
## Guards against resolving the same punch twice — the resolve tick and the
## ACTIVE->RECOVERY tick are no longer the same event (see BLOCK_GRACE_TICKS),
## so advance() needs to remember it already fired the resolve signal.
var _resolved: bool = false

func set_block(region: int) -> void:
	block = region

## Starts a punch only if not already mid-punch (mirrors the server's
## "one punch at a time" rule).
func throw_punch(region: int, current_tick: int) -> void:
	if punch_phase == Combat.PunchPhase.NONE:
		punch_region = region
		punch_phase = Combat.PunchPhase.WINDUP
		punch_start_tick = current_tick
		_resolved = false

## Advances this fighter's punch through WINDUP -> ACTIVE -> RECOVERY -> NONE.
## Returns true on the tick the hit should be resolved by the caller against
## the opponent — this is BLOCK_GRACE_TICKS after the punch turns ACTIVE, not
## the same tick, so a block pressed shortly after the punch visually goes
## active still has a chance to land before the outcome is locked in.
func advance(current_tick: int) -> bool:
	if punch_phase == Combat.PunchPhase.NONE:
		return false
	var elapsed := current_tick - punch_start_tick
	var resolve_at := Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS

	if punch_phase == Combat.PunchPhase.WINDUP and elapsed >= Combat.WINDUP_TICKS:
		punch_phase = Combat.PunchPhase.ACTIVE
	elif punch_phase == Combat.PunchPhase.ACTIVE and elapsed >= resolve_at and not _resolved:
		_resolved = true
		return true
	elif punch_phase == Combat.PunchPhase.ACTIVE and elapsed >= resolve_at + Combat.ACTIVE_TICKS:
		punch_phase = Combat.PunchPhase.RECOVERY
	elif punch_phase == Combat.PunchPhase.RECOVERY and elapsed >= resolve_at + Combat.ACTIVE_TICKS + Combat.RECOVERY_TICKS:
		punch_phase = Combat.PunchPhase.NONE
		punch_region = Combat.Region.NONE

	return false

## Resolves this fighter's active punch against a target. Returns "hit",
## "blocked", or "" if there's nothing to resolve.
func resolve_against(target: Fighter) -> String:
	if punch_phase != Combat.PunchPhase.ACTIVE:
		return ""
	if target.block != punch_region:
		target.health = max(0, target.health - Combat.PUNCH_DAMAGE)
		return "hit"
	return "blocked"
