extends Node
class_name DGBRuntime

signal initialized(session: Dictionary)
signal reset_requested
signal pause_requested
signal resume_requested
signal custom_command_received(type: String, payload: Dictionary)

const Protocol = preload("res://addons/dgbook_runtime/protocol.gd")
const Bridge = preload("res://addons/dgbook_runtime/bridge.gd")
const KnowledgeProvider = preload("res://addons/dgbook_runtime/knowledge_provider.gd")
const SessionConfig = preload("res://addons/dgbook_runtime/session_config.gd")
const ResultReporter = preload("res://addons/dgbook_runtime/result_reporter.gd")

var bridge: Node
var _options: Dictionary = {}
var _session: Dictionary = {}
var _reporter
var _configured := false


func setup(options: Dictionary) -> void:
	_options = options.duplicate(true)
	_configured = str(_options.get("game_id", "")) != ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if !_configured:
		push_error("DGBRuntime.setup() must be called with game_id before adding it to the tree.")
		return
	bridge = Bridge.new()
	bridge.init_received.connect(_on_init_received)
	bridge.pause_requested.connect(func() -> void: pause_requested.emit())
	bridge.resume_requested.connect(func() -> void: resume_requested.emit())
	bridge.reset_requested.connect(_on_reset_requested)
	bridge.custom_command_received.connect(func(type: String, payload: Dictionary) -> void: custom_command_received.emit(type, payload))
	_reporter = ResultReporter.new(bridge)
	add_child(bridge)


func report_progress(progress: float, hint := "", stats := {}) -> bool:
	return _reporter != null and _reporter.report_progress(progress, hint, stats)


func complete(score: float, stars := -1, duration_ms := 0, stats := {}) -> bool:
	return _reporter != null and _reporter.complete(score, stars, duration_ms, stats)


func begin_attempt() -> bool:
	if _reporter == null or _session.is_empty():
		return false
	_reporter.reset()
	_reporter.mark_initialized()
	return true


func log_info(message: String) -> void:
	if bridge != null:
		bridge.send_log(message, "info")


func log_warning(message: String) -> void:
	if bridge != null:
		bridge.send_log(message, "warn")


func log_error(message: String) -> void:
	if bridge != null:
		bridge.send_log(message, "error")


func current_session() -> Dictionary:
	return _session.duplicate(true)


func _on_init_received(level: Dictionary, data: Dictionary, version) -> void:
	if !Protocol.is_supported_version(version):
		log_error("Unsupported Godot bridge version: %s" % str(version))
		return
	var configured_game_id := str(_options.get("game_id", ""))
	var incoming_game_id := str(data.get("gameId", ""))
	if incoming_game_id != "" and incoming_game_id != configured_game_id:
		log_error("Game ID mismatch: expected %s, received %s" % [configured_game_id, incoming_game_id])
		return
	var local_preview: bool = !bridge.is_web_runtime()
	var knowledge: Dictionary = KnowledgeProvider.resolve(data, _options.get("fallbacks", {}), local_preview)
	var config: Dictionary = SessionConfig.build(level, data, _options.get("defaults", {}))
	_session = {
		"game_id": configured_game_id,
		"level": level.duplicate(true),
		"data": data.duplicate(true),
		"config": config,
		"knowledge": knowledge,
		"source": knowledge.get("source", "local_preview" if local_preview else "embedded")
	}
	_reporter.reset()
	_reporter.mark_initialized()
	initialized.emit(_session.duplicate(true))


func _on_reset_requested() -> void:
	if _reporter != null:
		_reporter.reset()
		if !_session.is_empty():
			_reporter.mark_initialized()
	reset_requested.emit()
