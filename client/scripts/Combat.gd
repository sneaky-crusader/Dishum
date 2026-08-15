extends Node2D
## Phase 2 — local combat vs. a dummy opponent.
##
## Runs the same fixed-tick state machine (Fighter.gd) the server will run
## authoritatively in Phase 3. The dummy opponent is a simple random-timer AI,
## not a stand-in for netcode — Phase 3 replaces this scene's local tick loop
## with real Colyseus state, not the punch rules themselves.

const Combat := preload("res://shared/CombatConstants.gd")
const Fighter := preload("res://scripts/combat/Fighter.gd")

const TICK_SECONDS := 1.0 / Combat.TICK_RATE_HZ

var player := Fighter.new()
var dummy := Fighter.new()
var tick: int = 0
var _tick_accum: float = 0.0
var _match_over := false

var _player_health_bar: ProgressBar
var _dummy_health_bar: ProgressBar
var _player_rect: ColorRect
var _dummy_rect: ColorRect
var _status_label: Label
var _result_panel: Control

const PHASE_COLOR := {
	0: Color(0.3, 0.3, 0.3),  # NONE
	1: Color(0.8, 0.8, 0.2),  # WINDUP
	2: Color(0.9, 0.2, 0.2),  # ACTIVE
	3: Color(0.4, 0.4, 0.6),  # RECOVERY
}

func _ready() -> void:
	_build_ui()
	randomize()
	_schedule_next_dummy_action()

func _process(delta: float) -> void:
	if _match_over:
		return
	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		_advance_tick()
	_update_visuals()

func _advance_tick() -> void:
	tick += 1
	if player.advance(tick):
		_resolve(player, dummy, "You")
	if dummy.advance(tick):
		_resolve(dummy, player, "Dummy")

	if player.health == 0 or dummy.health == 0:
		_end_match()

func _resolve(attacker: Fighter, target: Fighter, attacker_label: String) -> void:
	var outcome := attacker.resolve_against(target)
	if outcome == "hit":
		_status_label.text = "%s landed a hit!" % attacker_label
	elif outcome == "blocked":
		_status_label.text = "%s's punch was blocked." % attacker_label

func _end_match() -> void:
	_match_over = true
	var won := dummy.health == 0
	_status_label.text = "YOU WIN" if won else "YOU LOSE"
	_result_panel.visible = true

func _update_visuals() -> void:
	_player_health_bar.value = player.health
	_dummy_health_bar.value = dummy.health
	_player_rect.color = PHASE_COLOR[player.punch_phase]
	_dummy_rect.color = PHASE_COLOR[dummy.punch_phase]

## --- Local player input (right thumb = punches, left thumb = blocks) ---

func _on_block_high() -> void:
	player.set_block(Combat.Region.HIGH)

func _on_block_mid() -> void:
	player.set_block(Combat.Region.MID)

func _on_punch_high() -> void:
	player.throw_punch(Combat.Region.HIGH, tick)

func _on_punch_mid() -> void:
	player.throw_punch(Combat.Region.MID, tick)

## --- Dummy AI: picks a random action on a random interval. Not meant to be
## smart — just enough for a human to have something to punch/block against
## while verifying the state machine and HUD end to end. ---

func _schedule_next_dummy_action() -> void:
	var wait := randf_range(0.5, 1.5)
	get_tree().create_timer(wait).timeout.connect(_do_dummy_action)

func _do_dummy_action() -> void:
	if _match_over:
		return
	if randf() < 0.5:
		dummy.set_block(Combat.Region.HIGH if randf() < 0.5 else Combat.Region.MID)
	else:
		dummy.throw_punch(Combat.Region.HIGH if randf() < 0.5 else Combat.Region.MID, tick)
	_schedule_next_dummy_action()

## --- UI construction (placeholder art: ColorRects, per Phase 2 scope) ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(24, 16)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	root.add_child(back)

	_status_label = Label.new()
	_status_label.text = "Fight!"
	_status_label.position = Vector2(560, 16)
	root.add_child(_status_label)

	# Opponent (LEFT) — dummy.
	_dummy_rect = ColorRect.new()
	_dummy_rect.color = PHASE_COLOR[0]
	_dummy_rect.size = Vector2(120, 240)
	_dummy_rect.position = Vector2(260, 240)
	root.add_child(_dummy_rect)

	var dummy_label := Label.new()
	dummy_label.text = "DUMMY"
	dummy_label.position = Vector2(280, 210)
	root.add_child(dummy_label)

	_dummy_health_bar = ProgressBar.new()
	_dummy_health_bar.min_value = 0
	_dummy_health_bar.max_value = Combat.MAX_HEALTH
	_dummy_health_bar.value = Combat.MAX_HEALTH
	_dummy_health_bar.size = Vector2(240, 24)
	_dummy_health_bar.position = Vector2(200, 480)
	root.add_child(_dummy_health_bar)

	# Local player (RIGHT).
	_player_rect = ColorRect.new()
	_player_rect.color = PHASE_COLOR[0]
	_player_rect.size = Vector2(120, 240)
	_player_rect.position = Vector2(900, 240)
	root.add_child(_player_rect)

	var player_label := Label.new()
	player_label.text = "YOU"
	player_label.position = Vector2(940, 210)
	root.add_child(player_label)

	_player_health_bar = ProgressBar.new()
	_player_health_bar.min_value = 0
	_player_health_bar.max_value = Combat.MAX_HEALTH
	_player_health_bar.value = Combat.MAX_HEALTH
	_player_health_bar.size = Vector2(240, 24)
	_player_health_bar.position = Vector2(840, 480)
	root.add_child(_player_health_bar)

	# LEFT thumb: blocks (HIGH = face, MID = body) — mutually exclusive by
	# construction (set_block just overwrites the single `block` field).
	root.add_child(_make_button("BLOCK\nHIGH", Vector2(60, 200), _on_block_high))
	root.add_child(_make_button("BLOCK\nMID", Vector2(60, 380), _on_block_mid))

	# RIGHT thumb: punches (HIGH, MID) — mutually exclusive via the
	# one-punch-at-a-time rule in Fighter.throw_punch.
	root.add_child(_make_button("PUNCH\nHIGH", Vector2(1060, 200), _on_punch_high))
	root.add_child(_make_button("PUNCH\nMID", Vector2(1060, 380), _on_punch_mid))

	_result_panel = _build_result_panel()
	root.add_child(_result_panel)

func _make_button(text: String, pos: Vector2, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 140)
	b.position = pos
	b.pressed.connect(on_pressed)
	return b

func _build_result_panel() -> Control:
	var panel := PanelContainer.new()
	panel.position = Vector2(520, 280)
	panel.visible = false

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var restart := Button.new()
	restart.text = "Rematch"
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart)

	var menu := Button.new()
	menu.text = "Back to menu"
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	vbox.add_child(menu)

	return panel
