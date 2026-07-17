extends SceneTree

var failures := 0
var initialized_sessions: Array = []
var pause_count := 0
var resume_count := 0
var reset_count := 0
var custom_commands: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime_script = load("res://addons/dgbook_runtime/runtime.gd")
	_assert(runtime_script != null, "runtime facade should load")
	if runtime_script == null:
		_finish()
		return
	var fallback_path := "user://runtime-contract-questions.json"
	var file := FileAccess.open(fallback_path, FileAccess.WRITE)
	file.store_string('[{"id":"local-question"}]')
	file.close()
	var runtime = runtime_script.new()
	runtime.setup({
		"game_id": "template-game",
		"fallbacks": {"questions": fallback_path},
		"defaults": {"duration_sec": 60.0}
	})
	runtime.initialized.connect(func(session: Dictionary) -> void: initialized_sessions.append(session))
	runtime.pause_requested.connect(func() -> void: pause_count += 1)
	runtime.resume_requested.connect(func() -> void: resume_count += 1)
	runtime.reset_requested.connect(func() -> void: reset_count += 1)
	runtime.custom_command_received.connect(func(type: String, payload: Dictionary) -> void:
		custom_commands.append({"type": type, "payload": payload})
	)
	get_root().add_child(runtime)
	await process_frame
	await process_frame
	_assert(initialized_sessions.size() == 1, "local preview should initialize once")
	if initialized_sessions.size() == 1:
		var session: Dictionary = initialized_sessions[0]
		_assert(session.game_id == "template-game", "session should expose configured game id")
		_assert(session.source == "local_preview", "local preview source should be explicit")
		_assert(session.knowledge.questions[0].id == "local-question", "local fallback should be resolved")
		_assert(session.config.duration_sec == 60.0, "session defaults should be preserved")

	runtime.bridge.receive_payload({"type": "DGB_GODOT_PAUSE", "version": 1})
	runtime.bridge.receive_payload({"type": "DGB_GODOT_RESUME", "version": 1})
	runtime.bridge.receive_payload({"type": "DGB_GODOT_RECORDING_DEMO", "version": 1, "speed": 2})
	runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
	_assert(pause_count == 1, "pause should be forwarded")
	_assert(resume_count == 1, "resume should be forwarded")
	_assert(reset_count == 1, "reset should be forwarded")
	_assert(custom_commands.size() == 1, "custom commands should be forwarded")
	_assert(custom_commands[0].type == "DGB_GODOT_RECORDING_DEMO", "custom command type should be preserved")
	_assert(runtime.complete(80.0, 2, 10, {}), "completion should work after reset")
	_assert(!runtime.complete(70.0, 1, 20, {}), "completion should remain idempotent")
	runtime.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("runtime contract tests passed")
		quit(0)
