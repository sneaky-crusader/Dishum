extends Control
## Register screen: a form panel and a "check your email" panel, toggled by
## script rather than as separate scenes. All Supabase Auth calls go through
## the AuthClient autoload.

const USERNAME_RE_PATTERN := "^[A-Za-z0-9_]{3,20}$"
const MIN_PASSWORD_LENGTH := 6

@onready var _form_panel: VBoxContainer = $Center/FormPanel
@onready var _username: LineEdit = $Center/FormPanel/UsernameEdit
@onready var _email: LineEdit = $Center/FormPanel/EmailEdit
@onready var _password: LineEdit = $Center/FormPanel/PasswordEdit
@onready var _confirm_password: LineEdit = $Center/FormPanel/ConfirmPasswordEdit
@onready var _form_error: Label = $Center/FormPanel/ErrorLabel
@onready var _register_button: Button = $Center/FormPanel/RegisterButton
@onready var _login_link: Button = $Center/FormPanel/LoginLink

@onready var _check_email_panel: VBoxContainer = $Center/CheckEmailPanel
@onready var _resend_button: Button = $Center/CheckEmailPanel/ResendButton
@onready var _status_label: Label = $Center/CheckEmailPanel/StatusLabel
@onready var _back_to_login_button: Button = $Center/CheckEmailPanel/BackToLoginButton

var _username_re := RegEx.new()
var _pending_email := ""

func _ready() -> void:
	_username_re.compile(USERNAME_RE_PATTERN)

	AuthClient.signed_up_pending_confirmation.connect(_on_signed_up_pending)
	AuthClient.auth_error.connect(_on_auth_error)
	AuthClient.resend_sent.connect(_on_resend_sent)

	_register_button.pressed.connect(_on_register_pressed)
	_login_link.pressed.connect(_go_to_login)
	_resend_button.pressed.connect(_on_resend_pressed)
	_back_to_login_button.pressed.connect(_go_to_login)

func _go_to_login() -> void:
	get_tree().change_scene_to_file("res://scenes/Login.tscn")

func _on_register_pressed() -> void:
	_form_error.visible = false
	var username := _username.text.strip_edges()
	var email := _email.text.strip_edges()
	var password := _password.text
	var confirm := _confirm_password.text

	var validation_error := _validate(username, email, password, confirm)
	if validation_error != "":
		_show_form_error(validation_error)
		return

	_set_form_busy(true)
	AuthClient.sign_up(email, password, username)

func _validate(username: String, email: String, password: String, confirm: String) -> String:
	if username == "" or email == "" or password == "" or confirm == "":
		return "Fill in all fields."
	if not _username_re.search(username):
		return "Username must be 3-20 characters: letters, numbers, or underscore."
	if email.find("@") == -1 or email.find(".", email.find("@")) == -1:
		return "Enter a valid email address."
	if password.length() < MIN_PASSWORD_LENGTH:
		return "Password must be at least %d characters." % MIN_PASSWORD_LENGTH
	if password != confirm:
		return "Passwords don't match."
	return ""

func _on_signed_up_pending(email: String) -> void:
	_set_form_busy(false)
	_pending_email = email
	_form_panel.visible = false
	_check_email_panel.visible = true

func _on_auth_error(message: String) -> void:
	if _check_email_panel.visible:
		_set_resend_busy(false)
		_show_status(message, true)
	else:
		_set_form_busy(false)
		_show_form_error(message)

func _on_resend_pressed() -> void:
	if _pending_email == "":
		return
	_set_resend_busy(true)
	AuthClient.resend_confirmation(_pending_email)

func _on_resend_sent() -> void:
	_show_status("Confirmation email sent. Check your inbox.", false)
	# Simple cooldown so the button can't be hammered.
	await get_tree().create_timer(15.0).timeout
	_set_resend_busy(false)

func _show_form_error(message: String) -> void:
	_form_error.text = message
	_form_error.visible = true

func _show_status(message: String, is_error: bool) -> void:
	_status_label.text = message
	_status_label.visible = true
	_status_label.modulate = Color(1, 0.4, 0.4, 1) if is_error else Color(0.5, 1, 0.5, 1)

func _set_form_busy(busy: bool) -> void:
	_register_button.disabled = busy
	_username.editable = not busy
	_email.editable = not busy
	_password.editable = not busy
	_confirm_password.editable = not busy

func _set_resend_busy(busy: bool) -> void:
	_resend_button.disabled = busy
