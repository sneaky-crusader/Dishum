extends Node2D
## Dishum — post-login home/menu screen.
##
## The real 4-button combat HUD now lives in Combat.tscn (Phase 2); this
## screen is just navigation: identity, logout, find players, and practice.

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.text = "DISHUM"
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
		PresenceClient.disconnect_presence()
		AuthClient.sign_out()
		get_tree().change_scene_to_file("res://scenes/Login.tscn")
	)
	root.add_child(logout)

	var find_players := Button.new()
	find_players.text = "Find Players"
	find_players.position = Vector2(24, 112)
	find_players.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/UserSearch.tscn")
	)
	root.add_child(find_players)

	if AuthClient.is_logged_in():
		PresenceClient.connect_and_track(AuthClient.current_user_id(), AuthClient.current_username())

	var practice := Button.new()
	practice.text = "Practice (vs Dummy)"
	practice.position = Vector2(24, 144)
	practice.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Combat.tscn")
	)
	root.add_child(practice)
