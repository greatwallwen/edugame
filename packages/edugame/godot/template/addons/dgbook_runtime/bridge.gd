extends Node
class_name DGBBridge

signal init_received(level: Dictionary, data: Dictionary, version)
signal reset_requested
signal pause_requested
signal resume_requested
signal custom_command_received(type: String, payload: Dictionary)
signal outbound_payload(payload: Dictionary)

const Protocol = preload("res://addons/dgbook_runtime/protocol.gd")

var _js_callback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_web_runtime():
		_js_callback = JavaScriptBridge.create_callback(_on_host_message)
		var window := JavaScriptBridge.get_interface("window")
		window.dgbGodotReceive = _js_callback
		JavaScriptBridge.eval("window.addEventListener('message', function(event) { if (window.dgbGodotReceive) { window.dgbGodotReceive(JSON.stringify(event.data || {})); } });", true)
		send_ready()
	else:
		call_deferred("_emit_local_init")


func is_web_runtime() -> bool:
	return OS.has_feature("web")


func receive_payload(payload: Dictionary) -> void:
	var type := str(payload.get("type", ""))
	match type:
		Protocol.INIT:
			var level = payload.get("level", {})
			var data = payload.get("data", {})
			init_received.emit(level if typeof(level) == TYPE_DICTIONARY else {}, data if typeof(data) == TYPE_DICTIONARY else {}, payload.get("version", null))
		Protocol.PAUSE:
			pause_requested.emit()
		Protocol.RESUME:
			resume_requested.emit()
		Protocol.RESET:
			reset_requested.emit()
		_:
			if type.begins_with("DGB_GODOT_"):
				custom_command_received.emit(type, payload.duplicate(true))


func send_ready() -> void:
	_post({"type": Protocol.READY, "version": Protocol.VERSION})


func send_progress(progress: float, hint := "", stats := {}) -> void:
	_post({"type": Protocol.PROGRESS, "progress": progress, "hint": hint, "stats": stats})


func send_complete(score: float, stars := -1, duration_ms := 0, stats := {}) -> void:
	var payload := {"type": Protocol.COMPLETE, "score": score, "durationMs": duration_ms, "stats": stats}
	if int(stars) >= 0:
		payload["stars"] = int(stars)
	_post(payload)


func send_log(message: String, level := "info") -> void:
	_post({"type": Protocol.LOG, "level": level, "message": message})


func _emit_local_init() -> void:
	receive_payload({"type": Protocol.INIT, "version": Protocol.VERSION, "level": {}, "data": {}})


func _on_host_message(args: Array) -> void:
	if args.is_empty():
		return
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) == TYPE_DICTIONARY:
		receive_payload(parsed as Dictionary)
	else:
		send_log("Ignored malformed host message.", "warn")


func _post(payload: Dictionary) -> void:
	outbound_payload.emit(payload.duplicate(true))
	if is_web_runtime():
		var json := JSON.stringify(payload)
		JavaScriptBridge.eval("window.parent.postMessage(%s, '*');" % json, true)
