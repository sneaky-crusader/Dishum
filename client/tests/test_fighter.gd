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
	var became_active := false
	for t in range(1, Combat.WINDUP_TICKS + 1):
		if attacker.advance(t):
			became_active = true
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "hit", "unguarded punch resolves as hit")
	_assert(became_active, "punch becomes active after WINDUP_TICKS")
	_assert(target.health == Combat.MAX_HEALTH - Combat.PUNCH_DAMAGE, "target takes PUNCH_DAMAGE")

func test_guarded_punch_is_blocked() -> void:
	print("test_guarded_punch_is_blocked")
	var attacker := Fighter.new()
	var target := Fighter.new()
	target.block = Combat.Region.HIGH  # guarding the same region

	attacker.throw_punch(Combat.Region.HIGH, 0)
	for t in range(1, Combat.WINDUP_TICKS + 1):
		if attacker.advance(t):
			var outcome := attacker.resolve_against(target)
			_assert(outcome == "blocked", "guarded punch resolves as blocked")
	_assert(target.health == Combat.MAX_HEALTH, "blocked target takes no damage (CHIP_DAMAGE=0)")

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
	var total_ticks := Combat.WINDUP_TICKS + Combat.ACTIVE_TICKS + Combat.RECOVERY_TICKS
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
	for t in range(1, Combat.WINDUP_TICKS + 1):
		if attacker.advance(t):
			attacker.resolve_against(target)
	_assert(target.health == 0, "health clamps at 0, never negative")
