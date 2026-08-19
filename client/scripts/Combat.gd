extends Node2D
## Phase 2 — local combat vs. a dummy opponent.
##
## Runs the same fixed-tick state machine (Fighter.gd) the server will run
## authoritatively in Phase 3. The dummy opponent is a simple random-timer AI,
## not a stand-in for netcode — Phase 3 replaces this scene's local tick loop
## with real Colyseus state, not the punch rules themselves.

const Combat := preload("res://shared/CombatConstants.gd")
const Fighter := preload("res://scripts/combat/Fighter.gd")
const Fighter3D := preload("res://scripts/combat/Fighter3D.gd")
const Colors := preload("res://scripts/combat/CombatColors.gd")

const TICK_SECONDS := 1.0 / Combat.TICK_RATE_HZ
# Measured against a real render (see Fighter3D.HEAD_LOCAL_CENTER's comment)
# — closes the idle gap between fighters from ~140px to ~30px and centers
# the pair between the block buttons (right edge x=220) and punch buttons
# (left edge x=1060).
const PLAYER_X := 396.0
const DUMMY_X := 546.0
# How long a hit/block flash (and its "HIT!"/"BLOCKED!" text callout) stays
# visible, independent of ACTIVE_TICKS. Longer than the original color-only
# flash (0.3s) since text needs enough time to actually be read.
const FLASH_SECONDS := 0.6

var player := Fighter.new()
var dummy := Fighter.new()
var tick: int = 0
var _tick_accum: float = 0.0
var _match_over := false

var _player_health_bar: ProgressBar
var _dummy_health_bar: ProgressBar
var _player_block_label: Label
var _dummy_block_label: Label
var _status_label: Label
var _result_panel: Control

# {region: int, color: Color, time_left: float} or {} when nothing to show.
var _player_flash := {}
var _dummy_flash := {}

var _player_model: Fighter3D
var _dummy_model: Fighter3D

# Floating "HIT!"/"BLOCKED!" callout shown right next to whichever fighter
# just took the punch — colors alone (the region indicator dots) were hard
# to tell apart, so this spells the outcome out in text too.
var _player_result_text: Label
var _dummy_result_text: Label

func _ready() -> void:
	_build_ui()
	randomize()
	_schedule_next_dummy_action()

func _process(delta: float) -> void:
	if _match_over:
		_decay_flash(_player_flash, delta)
		_decay_flash(_dummy_flash, delta)
		_render_regions()
		_update_result_text(_player_flash, _player_result_text)
		_update_result_text(_dummy_flash, _dummy_result_text)
		return
	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		_advance_tick()
	_decay_flash(_player_flash, delta)
	_decay_flash(_dummy_flash, delta)
	_update_visuals()
	_update_result_text(_player_flash, _player_result_text)
	_update_result_text(_dummy_flash, _dummy_result_text)

func _advance_tick() -> void:
	tick += 1
	if player.advance(tick):
		_resolve(player, dummy, "You", _dummy_flash, _dummy_model)
	if dummy.advance(tick):
		_resolve(dummy, player, "Dummy", _player_flash, _player_model)

	if player.health == 0 or dummy.health == 0:
		_end_match()

func _resolve(attacker: Fighter, target: Fighter, attacker_label: String, target_flash: Dictionary, target_model: Fighter3D) -> void:
	var outcome := attacker.resolve_against(target)
	if outcome == "hit":
		_status_label.text = "%s landed a hit!" % attacker_label
		_set_flash(target_flash, attacker.punch_region, Colors.HIT, "HIT!")
		target_model.play_hit_reaction(attacker.punch_region)
	elif outcome == "blocked":
		_status_label.text = "%s's punch was blocked." % attacker_label
		_set_flash(target_flash, attacker.punch_region, Colors.BLOCKED, "BLOCKED!")

func _set_flash(flash: Dictionary, region: int, color: Color, text: String) -> void:
	flash["region"] = region
	flash["color"] = color
	flash["text"] = text
	flash["time_left"] = FLASH_SECONDS

func _decay_flash(flash: Dictionary, delta: float) -> void:
	if flash.is_empty():
		return
	flash["time_left"] -= delta
	if flash["time_left"] <= 0.0:
		flash.clear()

## Shows "HIT!"/"BLOCKED!" right next to the fighter who just took the punch,
## for as long as the flash is active — a text callout alongside the color
## indicator dots, since color alone was hard to read at a glance.
func _update_result_text(flash: Dictionary, label: Label) -> void:
	if flash.is_empty():
		label.visible = false
		return
	label.text = flash["text"]
	label.modulate = flash["color"]
	label.visible = true

func _end_match() -> void:
	_match_over = true
	var won := dummy.health == 0
	_status_label.text = "YOU WIN" if won else "YOU LOSE"
	_result_panel.visible = true
	var loser_model := _dummy_model if won else _player_model
	loser_model.play_ko()

func _update_visuals() -> void:
	_player_health_bar.value = player.health
	_dummy_health_bar.value = dummy.health
	_player_block_label.text = "Blocking: %s" % _region_name(player.block)
	_dummy_block_label.text = "Blocking: %s" % _region_name(dummy.block)
	_render_regions()

func _region_name(region: int) -> String:
	match region:
		Combat.Region.HIGH: return "HIGH"
		Combat.Region.MID: return "MID"
		_: return "none"

## Each fighter's head (HIGH region) + torso (MID region) are colored, and
## the model's arm pose reflects punch phase / block. Per-region color
## priority: an active hit/block flash > a guard color if the fighter is
## blocking that region > a yellow telegraph if the OPPONENT is winding up a
## punch aimed at that region (this tells the player which block to press) >
## neutral.
func _render_regions() -> void:
	_render_fighter(player, dummy, _player_flash, _player_model)
	_render_fighter(dummy, player, _dummy_flash, _dummy_model)

func _render_fighter(self_f: Fighter, foe: Fighter, flash: Dictionary, model: Fighter3D) -> void:
	var head_color := _region_color(Combat.Region.HIGH, self_f, foe, flash)
	var torso_color := _region_color(Combat.Region.MID, self_f, foe, flash)
	model.set_state(head_color, torso_color, self_f.punch_phase, self_f.punch_region, self_f.block)

func _region_color(region: int, self_f: Fighter, foe: Fighter, flash: Dictionary) -> Color:
	if not flash.is_empty() and flash["region"] == region:
		return flash["color"]
	if self_f.block == region:
		return Colors.GUARD
	if foe.punch_phase == Combat.PunchPhase.WINDUP and foe.punch_region == region:
		return Colors.TELEGRAPH
	return Colors.NEUTRAL

## --- Local player input (right thumb = punches, left thumb = blocks) ---
##
## A touchscreen lets you hold a block button and a punch button at the same
## time with two thumbs; a single mouse cursor can't. Keyboard keys can be
## held/pressed together, so they're added here purely so this scene is
## actually testable on a non-touch laptop — mobile input stays button-only.

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if event.pressed:
		match event.physical_keycode:
			KEY_Q: _on_block_high()
			KEY_A: _on_block_mid()
			KEY_O: _on_punch_high()
			KEY_L: _on_punch_mid()
	else:
		# Block is a hold, not a toggle — releasing the key drops back to no
		# block (and the model's idle stance) rather than staying guarded.
		# Only release if this key's region is still the active block, so
		# releasing Q after having since switched to MID via A doesn't clear
		# the MID block.
		match event.physical_keycode:
			KEY_Q: _on_release_block(Combat.Region.HIGH)
			KEY_A: _on_release_block(Combat.Region.MID)

func _on_block_high() -> void:
	player.set_block(Combat.Region.HIGH)

func _on_block_mid() -> void:
	player.set_block(Combat.Region.MID)

func _on_release_block(region: int) -> void:
	if player.block == region:
		player.set_block(Combat.Region.NONE)

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

## --- UI construction (fighters render via Fighter3D — see its header for
## how to swap the capsule placeholder for a real character) ---

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
	legend.text = "Dots: yellow = incoming attack, block it! Blue = guarding. Green = blocked. Red = hit."
	legend.position = Vector2(320, 640)
	root.add_child(legend)

	# PLAYER_X/DUMMY_X were measured against a real render, not guessed: a
	# pixel bounding-box scan of each fighter's actual on-screen body (not
	# just the viewport rect, which has a lot of empty margin around the
	# character) showed a ~140px gap between them at idle with the old
	# 220/480 positions — nearly a full body-width, which is why punches
	# never looked like they landed. These values close that to a believable
	# ~30px fighting distance and recenter the pair between the block
	# buttons (right edge x=220) and punch buttons (left edge x=1060).
	# facing_right = false: arms extend left, toward the player.
	_dummy_model = _build_fighter_model(root, DUMMY_X, false)

	var dummy_label := Label.new()
	dummy_label.text = "DUMMY"
	dummy_label.position = Vector2(DUMMY_X + 20, 90)
	root.add_child(dummy_label)

	_dummy_result_text = _build_result_text_label(_dummy_model)
	root.add_child(_dummy_result_text)

	_dummy_health_bar = ProgressBar.new()
	_dummy_health_bar.min_value = 0
	_dummy_health_bar.max_value = Combat.MAX_HEALTH
	_dummy_health_bar.value = Combat.MAX_HEALTH
	_dummy_health_bar.size = Vector2(240, 24)
	_dummy_health_bar.position = Vector2(420, 560)
	root.add_child(_dummy_health_bar)

	_dummy_block_label = Label.new()
	_dummy_block_label.text = "Blocking: none"
	_dummy_block_label.position = Vector2(420, 590)
	root.add_child(_dummy_block_label)

	# facing_right = true: arms extend right, toward the dummy.
	_player_model = _build_fighter_model(root, PLAYER_X, true)

	var player_label := Label.new()
	player_label.text = "YOU"
	player_label.position = Vector2(PLAYER_X + 20, 90)
	root.add_child(player_label)

	_player_result_text = _build_result_text_label(_player_model)
	root.add_child(_player_result_text)

	_player_health_bar = ProgressBar.new()
	_player_health_bar.min_value = 0
	_player_health_bar.max_value = Combat.MAX_HEALTH
	_player_health_bar.value = Combat.MAX_HEALTH
	_player_health_bar.size = Vector2(240, 24)
	_player_health_bar.position = Vector2(160, 560)
	root.add_child(_player_health_bar)

	_player_block_label = Label.new()
	_player_block_label.text = "Blocking: none"
	_player_block_label.position = Vector2(160, 590)
	root.add_child(_player_block_label)

	# LEFT thumb: blocks (HIGH = face, MID = body) — mutually exclusive by
	# construction (set_block just overwrites the single `block` field).
	# Blocking is a hold: pressed/released via button_down/button_up (not the
	# single-shot `pressed` signal used by the punch buttons below), so
	# lifting the thumb drops back to no block and the idle stance.
	# [Q]/[A] keyboard equivalents let you hold a block and press a punch key
	# at the same moment, which a single mouse cursor can't do.
	root.add_child(_make_hold_button("BLOCK\nHIGH [Q]", Vector2(60, 200), Combat.Region.HIGH))
	root.add_child(_make_hold_button("BLOCK\nMID [A]", Vector2(60, 380), Combat.Region.MID))

	# RIGHT thumb: punches (HIGH, MID) — mutually exclusive via the
	# one-punch-at-a-time rule in Fighter.throw_punch. [O]/[L] key equivalents.
	root.add_child(_make_button("PUNCH\nHIGH [O]", Vector2(1060, 200), _on_punch_high))
	root.add_child(_make_button("PUNCH\nMID [L]", Vector2(1060, 380), _on_punch_mid))

	_render_regions()

	_result_panel = _build_result_panel()
	root.add_child(_result_panel)

# Mixamo downloads for the 8-state animation list (see docs/PROGRESS.md
# decision log). All share the same rig/mesh (same character selected for
# every download), so clips from the non-base files donate cleanly into
# FIGHTER_CHARACTER's own AnimationPlayer via Fighter3D.add_animation().
const FIGHTER_CHARACTER := preload("res://assets/idle.fbx")
const GUARD_HIGH_SOURCE := preload("res://assets/upperblock.fbx")
const GUARD_MID_SOURCE := preload("res://assets/midblock.fbx")
const PUNCH_HIGH_SOURCE := preload("res://assets/upperpunch.fbx")
const PUNCH_MID_SOURCE := preload("res://assets/midpunch.fbx")
const HIT_HIGH_SOURCE := preload("res://assets/upperhitreaction.fbx")
const HIT_MID_SOURCE := preload("res://assets/midhitreaction.fbx")
const KO_SOURCE := preload("res://assets/ko.fbx")

## Builds a 3D fighter positioned near x, using the imported Mixamo
## character (falls back to a capsule inside Fighter3D if that import
## is ever missing/broken).
func _build_fighter_model(root: Control, x: float, facing_right: bool) -> Fighter3D:
	var model := Fighter3D.new()
	model.character_scene = FIGHTER_CHARACTER
	# idle.fbx is the base character, so its own clip ("mixamo_com") is used
	# directly as idle — no donation needed for that one.
	model.idle_animation = "mixamo_com"
	model.guard_high_animation = "guard_high"
	model.guard_mid_animation = "guard_mid"
	model.punch_high_animation = "punch_high"
	model.punch_mid_animation = "punch_mid"
	model.hit_reaction_high_animation = "hit_high"
	model.hit_reaction_mid_animation = "hit_mid"
	model.ko_animation = "ko"
	model.facing_right = facing_right
	model.position = Vector2(x, 110)
	root.add_child(model)
	model.add_animation("guard_high", GUARD_HIGH_SOURCE, "mixamo_com")
	model.add_animation("guard_mid", GUARD_MID_SOURCE, "mixamo_com")
	model.add_animation("punch_high", PUNCH_HIGH_SOURCE, "mixamo_com")
	model.add_animation("punch_mid", PUNCH_MID_SOURCE, "mixamo_com")
	model.add_animation("hit_high", HIT_HIGH_SOURCE, "mixamo_com")
	model.add_animation("hit_mid", HIT_MID_SOURCE, "mixamo_com")
	model.add_animation("ko", KO_SOURCE, "mixamo_com")
	return model

## A block button: held down while the thumb is on it, releases to NONE the
## moment it's lifted (button_down/button_up), not a single-shot press.
func _make_hold_button(text: String, pos: Vector2, region: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 140)
	b.position = pos
	b.button_down.connect(func(): player.set_block(region))
	b.button_up.connect(func(): _on_release_block(region))
	return b

## A "HIT!"/"BLOCKED!" callout label, anchored to the fighter model's actual
## measured head position (Fighter3D.HEAD_LOCAL_CENTER) rather than a guessed
## screen coordinate — fixed-width + centered alignment so "HIT!" and the
## longer "BLOCKED!" both center over the head regardless of text length.
func _build_result_text_label(model: Fighter3D) -> Label:
	var label := Label.new()
	var label_width := 160.0
	var head_screen := model.position + Fighter3D.HEAD_LOCAL_CENTER
	label.position = Vector2(head_screen.x - label_width / 2.0, head_screen.y - 55)
	label.size = Vector2(label_width, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	label.add_theme_font_size_override("font_size", 28)
	return label

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
