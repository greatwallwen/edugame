extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	var runtime = game.get("runtime")
	_assert(runtime != null, "Ch12 should expose the shared runtime")
	if runtime != null:
		var initial_time_left: float = game.time_left
		_assert(game.phase == game.Phase.WAITING, "Ch12 should wait for host INIT before starting")
		_assert(game.time_left == initial_time_left, "Ch12 timer should not run before host INIT")
		_assert(runtime.current_session().is_empty(), "Ch12 should have no session before host INIT")
		await process_frame
		await process_frame
		_assert(game.phase == game.Phase.PLAYING, "local preview should start through the deferred runtime INIT")
		var outbound_payloads: Array = []
		runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: outbound_payloads.append(payload))
		_assert(str(runtime.get_script().resource_path).ends_with("addons/dgbook_runtime/runtime.gd"), "Ch12 should use the generated runtime")
		runtime.bridge.receive_payload({
			"type": "DGB_GODOT_INIT",
			"version": 1,
			"level": {"levelId": "test-level"},
			"data": {
				"gameId": "ch12-solar-survivor",
				"durationSec": 90,
				"maxFaults": 3,
				"questionTimeSec": 8,
				"questions": [{"id": "injected-question"}],
				"upgrades": [{"id": "injected-upgrade"}],
				"bindings": {"source": "course"}
			}
		})
		_assert(game.phase == game.Phase.PLAYING, "Ch12 should start after a valid host INIT")
		_assert(game.questions.size() == 1 and game.questions[0].id == "injected-question", "injected questions should be used")
		_assert(game.upgrades.size() == 1 and game.upgrades[0].id == "injected-upgrade", "injected upgrades should be used")
		_assert(game.knowledge_bindings.source == "course", "injected bindings should be used")
		_assert(game.duration_sec == 90.0 and game.max_faults == 3 and game.question_time_sec == 8.0, "session config should update gameplay limits")
		game._finish_run(false)
		var completions := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
		_assert(completions.size() == 1, "the first run should emit one completion")
		if completions.size() == 1:
			_assert(!completions[0].has("stars"), "Ch12 should let the host derive stars")
		game._reset_run()
		game._finish_run(false)
		completions = outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
		_assert(completions.size() == 2, "an internal restart should allow a second completion")
		game.energy = 42.0
		runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
		_assert(game.energy == 0.0, "host reset should reset the run")
		_assert(game.time_left == 90.0, "reset should use injected duration")
	game.queue_free()
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
		print("Ch12 runtime integration tests passed")
		quit(0)
