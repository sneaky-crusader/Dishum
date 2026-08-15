extends Node2D
## Dishum — Phase 0 placeholder main scene.
##
## Draws the intended landscape HUD so we can validate the touch layout on a
## real device early: blocks on the LEFT thumb, punches on the RIGHT thumb,
## local fighter on the RIGHT, opponent facing from the LEFT.
## Real combat + netcode arrive in Phases 2–3.

const Combat := preload("res://shared/CombatConstants.gd")

func _ready() -> void:
	_build_placeholder_hud()
	print("Dishum client up. Tick rate = %d Hz" % Combat.TICK_RATE_HZ)

func _build_placeholder_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.text = "DISHUM — landscape HUD (placeholder)"
	title.position = Vector2(24, 16)
	root.add_child(title)

	# Phase 1 identity check: confirms the login flow actually authenticated
	# the right user. Replaced by a real menu/home screen in a later phase.
	var identity := Label.new()
	identity.text = "Logged in as %s" % AuthClient.current_username()
	identity.position = Vector2(24, 48)
	root.add_child(identity)

	var logout := Button.new()
	logout.text = "Log out"
	logout.position = Vector2(24, 80)
	logout.pressed.connect(func():
		AuthClient.sign_out()
		get_tree().change_scene_to_file("res://scenes/Login.tscn")
	)
	root.add_child(logout)

	# LEFT thumb: blocks (HIGH = face, MID = body) — mutually exclusive.
	root.add_child(_make_button("BLOCK\nHIGH", Vector2(60, 200)))
	root.add_child(_make_button("BLOCK\nMID", Vector2(60, 380)))

	# RIGHT thumb: punches (HIGH, MID) — mutually exclusive.
	root.add_child(_make_button("PUNCH\nHIGH", Vector2(1060, 200)))
	root.add_child(_make_button("PUNCH\nMID", Vector2(1060, 380)))

func _make_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 140)
	b.position = pos
	return b
