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
const FLASH_SECONDS := 0.3  # how long a hit/block flash stays visible, independent of ACTIVE_TICKS

const COLOR_NEUTRAL := Color(0.75, 0.72, 0.65)   # skin tone, nothing happening
const COLOR_GUARD := Color(0.25, 0.45, 0.9)      # this region is being guarded
const COLOR_TELEGRAPH := Color(0.95, 0.85, 0.15) # an incoming punch is winding up toward this region
const COLOR_HIT := Color(0.9, 0.15, 0.15)        # this region was just hit
const COLOR_BLOCKED := Color(0.2, 0.8, 0.35)     # an incoming punch here was just blocked

var player := Fighter.new()
var dummy := Fighter.new()
var tick: int = 0
var _tick_accum: float = 0.0
var _match_over := false

var _player_health_bar: ProgressBar
var _dummy_health_bar: ProgressBar
var _status_label: Label
var _result_panel: Control

# {region: int, color: Color, time_left: float} or {} when nothing to show.
var _player_flash := {}
var _dummy_flash := {}

var _player_head: ColorRect
var _player_torso: ColorRect
var _dummy_head: ColorRect
var _dummy_torso: ColorRect

func _ready() -> void:
	_build_ui()
	randomize()
	_schedule_next_dummy_action()

func _process(delta: float) -> void:
	if _match_over:
		_decay_flash(_player_flash, delta)
		_decay_flash(_dummy_flash, delta)
		_render_regions()
		return
	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		_advance_tick()
	_decay_flash(_player_flash, delta)
	_decay_flash(_dummy_flash, delta)
	_update_visuals()

func _advance_tick() -> void:
	tick += 1
	if player.advance(tick):
		_resolve(player, dummy, "You", _dummy_flash)
	if dummy.advance(tick):
		_resolve(dummy, player, "Dummy", _player_flash)

	if player.health == 0 or dummy.health == 0:
		_end_match()

func _resolve(attacker: Fighter, target: Fighter, attacker_label: String, target_flash: Dictionary) -> void:
	var outcome := attacker.resolve_against(target)
	if outcome == "hit":
		_status_label.text = "%s landed a hit!" % attacker_label
		_set_flash(target_flash, attacker.punch_region, COLOR_HIT)
	elif outcome == "blocked":
		_status_label.text = "%s's punch was blocked." % attacker_label
		_set_flash(target_flash, attacker.punch_region, COLOR_BLOCKED)

func _set_flash(flash: Dictionary, region: int, color: Color) -> void:
	flash["region"] = region
	flash["color"] = color
	flash["time_left"] = FLASH_SECONDS

func _decay_flash(flash: Dictionary, delta: float) -> void:
	if flash.is_empty():
		return
	flash["time_left"] -= delta
	if flash["time_left"] <= 0.0:
		flash.clear()

func _end_match() -> void:
	_match_over = true
	var won := dummy.health == 0
	_status_label.text = "YOU WIN" if won else "YOU LOSE"
	_result_panel.visible = true

func _update_visuals() -> void:
	_player_health_bar.value = player.health
	_dummy_health_bar.value = dummy.health
	_render_regions()

## Each fighter is a head (HIGH region) + torso (MID region). Per region,
## priority is: an active hit/block flash > a guard color if the fighter is
## blocking that region > a yellow telegraph if the OPPONENT is winding up a
## punch aimed at that region (this tells the player which block to press) >
## neutral.
func _render_regions() -> void:
	_render_fighter(player, dummy, _player_flash, _player_head, _player_torso)
	_render_fighter(dummy, player, _dummy_flash, _dummy_head, _dummy_torso)

func _render_fighter(self_f: Fighter, foe: Fighter, flash: Dictionary, head: ColorRect, torso: ColorRect) -> void:
	head.color = _region_color(Combat.Region.HIGH, self_f, foe, flash)
	torso.color = _region_color(Combat.Region.MID, self_f, foe, flash)

func _region_color(region: int, self_f: Fighter, foe: Fighter, flash: Dictionary) -> Color:
	if not flash.is_empty() and flash["region"] == region:
		return flash["color"]
	if self_f.block == region:
		return COLOR_GUARD
	if foe.punch_phase == Combat.PunchPhase.WINDUP and foe.punch_region == region:
		return COLOR_TELEGRAPH
	return COLOR_NEUTRAL

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

## --- UI construction (placeholder art: head/torso ColorRects, per Phase 2 scope) ---

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

	var legend := Label.new()
	legend.text = "Yellow = incoming attack, block it! Blue = guarding. Green = blocked. Red = hit."
	legend.position = Vector2(320, 640)
	root.add_child(legend)

	# Opponent — was rendering on the wrong side, so this x is swapped from
	# the original "left" value; verify on-screen and flip back if needed.
	var dummy_parts := _build_fighter_body(root, 900)
	_dummy_head = dummy_parts[0]
	_dummy_torso = dummy_parts[1]

	var dummy_label := Label.new()
	dummy_label.text = "DUMMY"
	dummy_label.position = Vector2(920, 150)
	root.add_child(dummy_label)

	_dummy_health_bar = ProgressBar.new()
	_dummy_health_bar.min_value = 0
	_dummy_health_bar.max_value = Combat.MAX_HEALTH
	_dummy_health_bar.value = Combat.MAX_HEALTH
	_dummy_health_bar.size = Vector2(240, 24)
	_dummy_health_bar.position = Vector2(840, 560)
	root.add_child(_dummy_health_bar)

	# Local player — swapped for the same reason as the dummy above.
	var player_parts := _build_fighter_body(root, 260)
	_player_head = player_parts[0]
	_player_torso = player_parts[1]

	var player_label := Label.new()
	player_label.text = "YOU"
	player_label.position = Vector2(280, 150)
	root.add_child(player_label)

	_player_health_bar = ProgressBar.new()
	_player_health_bar.min_value = 0
	_player_health_bar.max_value = Combat.MAX_HEALTH
	_player_health_bar.value = Combat.MAX_HEALTH
	_player_health_bar.size = Vector2(240, 24)
	_player_health_bar.position = Vector2(200, 560)
	root.add_child(_player_health_bar)

	# LEFT thumb: blocks (HIGH = face, MID = body) — mutually exclusive by
	# construction (set_block just overwrites the single `block` field).
	root.add_child(_make_button("BLOCK\nHIGH", Vector2(60, 200), _on_block_high))
	root.add_child(_make_button("BLOCK\nMID", Vector2(60, 380), _on_block_mid))

	# RIGHT thumb: punches (HIGH, MID) — mutually exclusive via the
	# one-punch-at-a-time rule in Fighter.throw_punch.
	root.add_child(_make_button("PUNCH\nHIGH", Vector2(1060, 200), _on_punch_high))
	root.add_child(_make_button("PUNCH\nMID", Vector2(1060, 380), _on_punch_mid))

	_render_regions()

	_result_panel = _build_result_panel()
	root.add_child(_result_panel)

## Builds a simple head (HIGH region) over torso (MID region) shape at the
## given x — makes it obvious at a glance which color belongs to which
## attack/block region, unlike a single flat-color block.
func _build_fighter_body(root: Control, x: float) -> Array[ColorRect]:
	var head := ColorRect.new()
	head.color = COLOR_NEUTRAL
	head.size = Vector2(80, 80)
	head.position = Vector2(x + 20, 180)
	root.add_child(head)

	var torso := ColorRect.new()
	torso.color = COLOR_NEUTRAL
	torso.size = Vector2(120, 160)
	torso.position = Vector2(x, 260)
	root.add_child(torso)

	return [head, torso]

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
