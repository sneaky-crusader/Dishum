extends SceneTree
## Headless test for Fighter's punch state machine (client/scripts/combat/Fighter.gd).
## Run with: godot --headless --path client --script tests/test_fighter.gd
## Exits with code 0 on all-pass, 1 on any failure (so it's CI/scriptable).

const Combat := preload("res://shared/CombatConstants.gd")
const Fighter := preload("res://scripts/combat/Fighter.gd")

var _failures := 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		_failures += 1
		print("  FAIL: %s" % msg)

func _init() -> void:
	test_full_unguarded_punch_lands()
	test_guarded_punch_is_blocked()
	test_late_block_within_grace_window_still_counts()
	test_block_after_grace_window_is_too_late()
	test_block_region_must_match_punch_region()
	test_cannot_throw_second_punch_mid_flight()
	test_recovery_returns_to_none_and_allows_new_punch()
	test_ko_clamps_health_at_zero()

	print("")
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("%d FAILURE(S)" % _failures)
		quit(1)

func test_full_unguarded_punch_lands() -> void:
	print("test_full_unguarded_punch_lands")
	var attacker := Fighter.new()
	var target := Fighter.new()
	target.block = Combat.Region.MID  # guarding the wrong region

	attacker.throw_punch(Combat.Region.HIGH, 0)
	var resolved := false
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		if attacker.advance(t):
			resolved = true
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "hit", "unguarded punch resolves as hit")
	_assert(resolved, "punch resolves after WINDUP_TICKS + BLOCK_GRACE_TICKS")
	_assert(target.health == Combat.MAX_HEALTH - Combat.PUNCH_DAMAGE, "target takes PUNCH_DAMAGE")

func test_guarded_punch_is_blocked() -> void:
	print("test_guarded_punch_is_blocked")
	var attacker := Fighter.new()
	var target := Fighter.new()
	target.block = Combat.Region.HIGH  # guarding the same region

	attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		if attacker.advance(t):
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "blocked", "guarded punch resolves as blocked")
	_assert(target.health == Combat.MAX_HEALTH, "blocked target takes no damage (CHIP_DAMAGE=0)")

## Blocking that starts AFTER the punch visually turns ACTIVE, but within
## BLOCK_GRACE_TICKS of it, should still count — the whole point of the
## grace window (a real human can't react within WINDUP_TICKS alone).
func test_late_block_within_grace_window_still_counts() -> void:
	print("test_late_block_within_grace_window_still_counts")
	var attacker := Fighter.new()
	var target := Fighter.new()

	attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		# Block first registers on the tick right after the punch turns
		# ACTIVE — i.e. after the exact moment the old code would have
		# already resolved a hit, but still within the grace window.
		if t == Combat.WINDUP_TICKS + 1:
			target.set_block(Combat.Region.HIGH)
		if attacker.advance(t):
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "blocked", "block pressed just after ACTIVE still lands within the grace window")
	_assert(target.health == Combat.MAX_HEALTH, "late-but-in-window block takes no damage")

## A block that only arrives AFTER the grace window has fully elapsed is too
## late — the punch must still be able to land, or blocking would be free.
func test_block_after_grace_window_is_too_late() -> void:
	print("test_block_after_grace_window_is_too_late")
	var attacker := Fighter.new()
	var target := Fighter.new()

	attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 5):
		if t == Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 2:
			target.set_block(Combat.Region.HIGH)
		if attacker.advance(t):
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "hit", "block pressed after the grace window has elapsed is too late to help")

## A block only stops a punch aimed at that exact region — blocking HIGH
## never stops a MID punch, and vice versa. No cross-region blocking.
func test_block_region_must_match_punch_region() -> void:
	print("test_block_region_must_match_punch_region")

	var mid_attacker := Fighter.new()
	var high_blocker := Fighter.new()
	high_blocker.block = Combat.Region.HIGH
	mid_attacker.throw_punch(Combat.Region.MID, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		if mid_attacker.advance(t):
			var outcome := mid_attacker.resolve_against(high_blocker)
			_assert(outcome == "hit", "MID punch lands against a HIGH block (no cross-blocking)")

	var high_attacker := Fighter.new()
	var mid_blocker := Fighter.new()
	mid_blocker.block = Combat.Region.MID
	high_attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		if high_attacker.advance(t):
			var outcome := high_attacker.resolve_against(mid_blocker)
			_assert(outcome == "hit", "HIGH punch lands against a MID block (no cross-blocking)")

func test_cannot_throw_second_punch_mid_flight() -> void:
	print("test_cannot_throw_second_punch_mid_flight")
	var f := Fighter.new()
	f.throw_punch(Combat.Region.HIGH, 0)
	f.throw_punch(Combat.Region.MID, 1)  # should be ignored, still mid-punch
	_assert(f.punch_region == Combat.Region.HIGH, "second throw_punch call is ignored while not NONE")

func test_recovery_returns_to_none_and_allows_new_punch() -> void:
	print("test_recovery_returns_to_none_and_allows_new_punch")
	var f := Fighter.new()
	var dummy_target := Fighter.new()
	f.throw_punch(Combat.Region.HIGH, 0)
	var total_ticks := Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + Combat.ACTIVE_TICKS + Combat.RECOVERY_TICKS
	for t in range(1, total_ticks + 1):
		if f.advance(t):
			f.resolve_against(dummy_target)
	_assert(f.punch_phase == Combat.PunchPhase.NONE, "punch phase returns to NONE after full lifecycle")
	_assert(f.punch_region == Combat.Region.NONE, "punch region resets to NONE")

	f.throw_punch(Combat.Region.MID, total_ticks + 1)
	_assert(f.punch_phase == Combat.PunchPhase.WINDUP, "a new punch can be thrown once back at NONE")

func test_ko_clamps_health_at_zero() -> void:
	print("test_ko_clamps_health_at_zero")
	var attacker := Fighter.new()
	var target := Fighter.new()
	target.health = 5  # less than PUNCH_DAMAGE

	attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + Combat.BLOCK_GRACE_TICKS + 1):
		if attacker.advance(t):
			attacker.resolve_against(target)
	_assert(target.health == 0, "health clamps at 0, never negative")
