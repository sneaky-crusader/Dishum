extends Control
## Login screen. Pure UI — all Supabase Auth calls go through the AuthClient
## autoload; this script only reacts to its signals.

@onready var _email: LineEdit = $Center/Box/EmailEdit
@onready var _password: LineEdit = $Center/Box/PasswordEdit
@onready var _error: Label = $Center/Box/ErrorLabel
@onready var _login_button: Button = $Center/Box/LoginButton
@onready var _resend_button: Button = $Center/Box/ResendButton
@onready var _register_link: Button = $Center/Box/RegisterLink

func _ready() -> void:
	AuthClient.signed_in.connect(_on_signed_in)
	AuthClient.auth_error.connect(_on_auth_error)
	AuthClient.resend_sent.connect(_on_resend_sent)

	_login_button.pressed.connect(_on_login_pressed)
	_resend_button.pressed.connect(_on_resend_pressed)
	_register_link.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Register.tscn"))

	AuthClient.try_restore_session()

func _on_login_pressed() -> void:
	_error.visible = false
	_resend_button.visible = false
	var email := _email.text.strip_edges()
	var password := _password.text

	if email == "" or password == "":
		_show_message("Enter your email and password.", true)
		return

	_set_busy(true)
	AuthClient.sign_in(email, password)

func _on_signed_in(_username: String) -> void:
	_set_busy(false)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_auth_error(message: String) -> void:
	_set_busy(false)
	_show_message(message, true)
	if message.to_lower().find("confirm your email") != -1:
		_resend_button.visible = true

func _on_resend_pressed() -> void:
	var email := _email.text.strip_edges()
	if email == "":
		return
	_resend_button.disabled = true
	AuthClient.resend_confirmation(email)

func _on_resend_sent() -> void:
	_show_message("Confirmation email sent. Check your inbox.", false)
	# Simple cooldown so the button can't be hammered.
	await get_tree().create_timer(15.0).timeout
	_resend_button.disabled = false

func _show_message(message: String, is_error: bool) -> void:
	_error.text = message
	_error.visible = true
	_error.modulate = Color(1, 0.4, 0.4, 1) if is_error else Color(0.5, 1, 0.5, 1)

func _set_busy(busy: bool) -> void:
	_login_button.disabled = busy
	_email.editable = not busy
	_password.editable = not busy
