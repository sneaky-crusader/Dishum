extends Node
## Autoload singleton — hand-rolled Supabase Realtime presence client.
##
## Godot has no Supabase SDK, and Supabase's own docs only cover SDK usage,
## not the wire protocol. This implementation was reverse-engineered from
## the realtime-js source and validated with a throwaway Node prototype
## against the live project before being ported here — see docs/PROGRESS.md
## decision log for what that caught (a track-retrigger bug that got the
## prototype rate-limited).
##
## Uses Godot's built-in WebSocketPeer — no native deps, so this runs
## identically on Android/iOS/desktop, same reasoning as AuthClient's choice
## of plain HTTPRequest over a native SDK.

const Config := preload("res://shared/SupabaseConfig.gd")

signal presence_changed

const TOPIC := "realtime:online-players"
const HEARTBEAT_INTERVAL := 25.0
const RECONNECT_DELAY := 3.0

var _socket: WebSocketPeer
var _ref := 1
var _join_sent := false
var _tracked := false
var _should_be_connected := false
var _heartbeat_accum := 0.0
var _reconnect_accum := 0.0

var _own_user_id := ""
var _own_username := ""
var _online := {} # user_id -> {username, status}

func connect_and_track(user_id: String, username: String) -> void:
	_own_user_id = user_id
	_own_username = username
	_should_be_connected = true
	_open_socket()

func disconnect_presence() -> void:
	_should_be_connected = false
	if _socket:
		_socket.close()
	_socket = null
	_online.clear()
	_join_sent = false
	_tracked = false

func is_online(user_id: String) -> bool:
	return _online.has(user_id)

func _open_socket() -> void:
	_socket = WebSocketPeer.new()
	var ws_url := Config.URL.replace("https://", "wss://") \
		+ "/realtime/v1/websocket?apikey=" + Config.PUBLISHABLE_KEY + "&vsn=1.0.0"
	var err := _socket.connect_to_url(ws_url)
	if err != OK:
		push_warning("PresenceClient: failed to start connection (%d)" % err)
		return
	_ref = 1
	_join_sent = false
	_tracked = false

func _process(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_reconnect_accum = 0.0
		if not _join_sent:
			_send_join()

		_heartbeat_accum += delta
		if _heartbeat_accum >= HEARTBEAT_INTERVAL:
			_heartbeat_accum = 0.0
			_send({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _next_ref()})

		while _socket.get_available_packet_count() > 0:
			_handle_message(_socket.get_packet().get_string_from_utf8())

	elif state == WebSocketPeer.STATE_CLOSED and _should_be_connected:
		_reconnect_accum += delta
		if _reconnect_accum >= RECONNECT_DELAY:
			_reconnect_accum = 0.0
			_open_socket()

func _send_join() -> void:
	_join_sent = true
	_send({
		"topic": TOPIC,
		"event": "phx_join",
		"payload": {
			"config": {
				"broadcast": {"ack": false, "self": false},
				"presence": {"key": _own_user_id, "enabled": true},
				"postgres_changes": [],
				"private": false,
			},
		},
		"ref": "1",
		"join_ref": "1",
	})

func _send_track() -> void:
	_tracked = true
	_send({
		"topic": TOPIC,
		"event": "presence",
		"payload": {
			"type": "presence",
			"event": "track",
			"payload": {"username": _own_username, "status": "online"},
		},
		"ref": _next_ref(),
		"join_ref": "1",
	})

func _next_ref() -> String:
	_ref += 1
	return str(_ref)

func _send(obj: Dictionary) -> void:
	_socket.send_text(JSON.stringify(obj))

func _handle_message(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return

	var event: String = msg.get("event", "")
	var topic: String = msg.get("topic", "")

	# Reply to our own phx_join (always ref "1") is what unlocks track --
	# matching any ok reply here re-triggers track on every ack and floods
	# the channel (this is the exact bug the Node prototype hit).
	if event == "phx_reply" and String(msg.get("ref", "")) == "1" and topic == TOPIC:
		var payload: Dictionary = msg.get("payload", {})
		if payload.get("status", "") == "ok" and not _tracked:
			_send_track()
		return

	if topic != TOPIC:
		return

	if event == "presence_state":
		# Seen empty on a fresh join even when others are already present --
		# presence_diff backfills the rest, so this is a safe reset, not the
		# sole source of truth.
		_online.clear()
		_merge_state(msg.get("payload", {}))
		presence_changed.emit()
	elif event == "presence_diff":
		var diff: Dictionary = msg.get("payload", {})
		_merge_state(diff.get("joins", {}))
		for uid in diff.get("leaves", {}).keys():
			_online.erase(uid)
		presence_changed.emit()
	elif event == "system" and msg.get("payload", {}).get("status", "") == "error":
		push_warning("PresenceClient: server error: %s" % msg.get("payload", {}).get("message", ""))

func _merge_state(state_dict: Dictionary) -> void:
	for uid in state_dict.keys():
		var metas: Array = state_dict[uid].get("metas", [])
		if metas.size() > 0:
			var meta: Dictionary = metas[0]
			_online[uid] = {"username": meta.get("username", ""), "status": meta.get("status", "online")}
