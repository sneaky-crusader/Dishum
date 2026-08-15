extends Control
## Username search screen. Queries the profiles table directly (public-read
## via RLS) and overlays live online/offline status from PresenceClient.

const Config := preload("res://shared/SupabaseConfig.gd")
const MIN_QUERY_LENGTH := 2

@onready var _search_edit: LineEdit = $Center/Box/SearchEdit
@onready var _debounce_timer: Timer = $Center/Box/DebounceTimer
@onready var _results_list: VBoxContainer = $Center/Box/ResultsList
@onready var _back_button: Button = $Center/Box/BackButton

var _last_results: Array = [] # [{id, username}, ...]

func _ready() -> void:
	_search_edit.text_changed.connect(func(_t): _debounce_timer.start())
	_debounce_timer.timeout.connect(_run_search)
	_back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	PresenceClient.presence_changed.connect(_refresh_online_dots)

func _run_search() -> void:
	var query := _search_edit.text.strip_edges()
	if query.length() < MIN_QUERY_LENGTH:
		_last_results = []
		_render_results()
		return

	var url := Config.URL + "/rest/v1/profiles" \
		+ "?username=ilike.*" + query.uri_encode() + "*" \
		+ "&id=neq." + AuthClient.current_user_id() \
		+ "&select=id,username&limit=20"

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code: int, _headers, raw_body: PackedByteArray):
		if code >= 200 and code < 300:
			var json: Variant = JSON.parse_string(raw_body.get_string_from_utf8())
			_last_results = json if typeof(json) == TYPE_ARRAY else []
			_render_results()
		http.queue_free()
	)
	http.request(url, [
		"apikey: " + Config.PUBLISHABLE_KEY,
		"Authorization: Bearer " + AuthClient.access_token(),
	], HTTPClient.METHOD_GET, "")

func _render_results() -> void:
	for child in _results_list.get_children():
		child.queue_free()

	for entry in _last_results:
		var row := HBoxContainer.new()

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = Color(0.3, 1, 0.3) if PresenceClient.is_online(entry.get("id", "")) else Color(0.5, 0.5, 0.5)
		row.add_child(dot)

		var label := Label.new()
		label.text = String(entry.get("username", ""))
		row.add_child(label)

		_results_list.add_child(row)

func _refresh_online_dots() -> void:
	# Cheap full re-render -- result lists are small (limit 20), no need for
	# incremental dot updates.
	_render_results()
