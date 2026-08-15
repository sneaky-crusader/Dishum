extends Node
## Autoload singleton — the only script that talks to Supabase Auth.
##
## Uses plain HTTPRequest against Supabase's REST API (no native SDK), so the
## exact same code runs on Android, iOS, and desktop. Screens (Login.gd,
## Register.gd) stay dumb UI: they call the methods below and react to the
## signals; they never touch HTTP directly.

const Config := preload("res://shared/SupabaseConfig.gd")

signal signed_in(username: String)
signal signed_up_pending_confirmation(email: String)
signal signed_out
signal auth_error(message: String)
signal resend_sent

const SESSION_PATH := "user://session.json"

var _access_token := ""
var _refresh_token := ""
var _expires_at := 0
var _user_id := ""
var _username := ""

func is_logged_in() -> bool:
	return _access_token != "" and _expires_at > Time.get_unix_time_from_system()

func current_username() -> String:
	return _username

func current_user_id() -> String:
	return _user_id

func access_token() -> String:
	return _access_token

## Call once at boot. Emits signed_in if a valid/refreshable session exists,
## otherwise leaves the caller on the login screen (no signal fired).
func try_restore_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return

	_access_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")
	_expires_at = int(data.get("expires_at", 0))
	_user_id = data.get("user_id", "")
	_username = data.get("username", "")

	if _access_token != "" and _expires_at > Time.get_unix_time_from_system():
		signed_in.emit(_username)
	elif _refresh_token != "":
		_do_token_request({"grant_type": "refresh_token", "refresh_token": _refresh_token}, true)
	else:
		_clear_session()

func sign_up(email: String, password: String, username: String) -> void:
	_request("POST", Config.AUTH_BASE + "/signup",
		{"email": email, "password": password, "data": {"username": username}},
		[], func(code: int, json: Variant, _raw: String):
			if code >= 200 and code < 300:
				signed_up_pending_confirmation.emit(email)
			else:
				auth_error.emit(_translate_signup_error(code, json))
	)

func sign_in(email: String, password: String) -> void:
	_do_token_request({"grant_type": "password", "email": email, "password": password}, false)

func resend_confirmation(email: String) -> void:
	_request("POST", Config.AUTH_BASE + "/resend",
		{"type": "signup", "email": email},
		[], func(code: int, json: Variant, _raw: String):
			if code >= 200 and code < 300:
				resend_sent.emit()
			else:
				auth_error.emit(_translate_generic_error(code, json))
	)

func sign_out() -> void:
	if _access_token != "":
		_request("POST", Config.AUTH_BASE + "/logout",
			{}, ["Authorization: Bearer " + _access_token], func(_c: int, _j: Variant, _r: String):
				pass
		)
	_clear_session()
	signed_out.emit()

## --- internals ---

func _do_token_request(body: Dictionary, is_restore: bool) -> void:
	var grant: String = body["grant_type"]
	_request("POST", Config.AUTH_BASE + "/token?grant_type=" + grant, body, [],
		func(code: int, json: Variant, _raw: String):
			if code >= 200 and code < 300 and typeof(json) == TYPE_DICTIONARY and json.has("access_token"):
				_on_token_success(json)
			elif is_restore:
				_clear_session()
			else:
				auth_error.emit(_translate_login_error(code, json))
	)

func _on_token_success(json: Dictionary) -> void:
	_access_token = json.get("access_token", "")
	_refresh_token = json.get("refresh_token", "")
	var expires_in := int(json.get("expires_in", 3600))
	_expires_at = int(json.get("expires_at", Time.get_unix_time_from_system() + expires_in))
	var user: Dictionary = json.get("user", {})
	_user_id = user.get("id", "")

	# Fetch the canonical username from profiles rather than trusting
	# auth metadata to be echoed back consistently across GoTrue versions.
	_fetch_username(func(username: String):
		_username = username
		_save_session()
		signed_in.emit(_username)
	)

func _fetch_username(on_done: Callable) -> void:
	var url := Config.URL + "/rest/v1/profiles?id=eq." + _user_id + "&select=username"
	_request("GET", url, null,
		["Authorization: Bearer " + _access_token], func(code: int, json: Variant, _raw: String):
			if code >= 200 and code < 300 and typeof(json) == TYPE_ARRAY and json.size() > 0:
				on_done.call(String(json[0].get("username", "")))
			else:
				on_done.call("")
	)

func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"expires_at": _expires_at,
		"user_id": _user_id,
		"username": _username,
	}))
	f.close()

func _clear_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_expires_at = 0
	_user_id = ""
	_username = ""
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

## Fires an HTTP request and calls back(status_code, parsed_json_or_null, raw_body).
## A fresh HTTPRequest node per call keeps concurrent requests (e.g. a resend
## fired while a sign-in is in flight) from stepping on each other.
func _request(method: String, url: String, body: Variant, extra_headers: Array, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, raw_body: PackedByteArray):
		var text := raw_body.get_string_from_utf8()
		var json: Variant = JSON.parse_string(text) if text != "" else null
		callback.call(code, json, text)
		http.queue_free()
	)

	var headers := ["apikey: " + Config.PUBLISHABLE_KEY, "Content-Type: application/json"]
	headers.append_array(extra_headers)

	var http_method := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	var body_str := JSON.stringify(body) if body != null else ""
	var err := http.request(url, headers, http_method, body_str)
	if err != OK:
		callback.call(-1, null, "")
		http.queue_free()

## --- error translation ---

func _translate_signup_error(code: int, json: Variant) -> String:
	var msg := _error_text(json)
	var lower := msg.to_lower()
	if lower.find("already registered") != -1 or lower.find("user already exists") != -1:
		return "That email is already registered."
	if lower.find("username_unique") != -1 or (lower.find("username") != -1 and lower.find("duplicate") != -1):
		return "That username is already taken."
	if lower.find("username_format") != -1:
		return "Usernames must be 3-20 characters: letters, numbers, or underscore."
	if lower.find("password") != -1:
		return "Password must be at least 6 characters."
	return "Couldn't create your account (%d). Please try again." % code if msg == "" \
		else "Couldn't create your account: %s" % msg

func _translate_login_error(code: int, json: Variant) -> String:
	var msg := _error_text(json)
	var lower := msg.to_lower()
	if lower.find("email not confirmed") != -1 or lower.find("email_not_confirmed") != -1:
		return "Please confirm your email before logging in."
	if lower.find("invalid login credentials") != -1 or lower.find("invalid_grant") != -1:
		return "Incorrect email or password."
	return "Couldn't log in (%d). Please try again." % code if msg == "" \
		else "Couldn't log in: %s" % msg

func _translate_generic_error(code: int, json: Variant) -> String:
	var msg := _error_text(json)
	return "Something went wrong (%d)." % code if msg == "" else msg

func _error_text(json: Variant) -> String:
	if typeof(json) != TYPE_DICTIONARY:
		return ""
	for key in ["msg", "message", "error_description", "error"]:
		if json.has(key) and typeof(json[key]) == TYPE_STRING:
			return String(json[key])
	return ""
