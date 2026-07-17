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
	await process_frame
	await process_frame
	var runtime = game.get("runtime")
	_assert(runtime != null, "Ch11 should expose the shared runtime")
	if runtime != null:
		var outbound_payloads: Array = []
		runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: outbound_payloads.append(payload))
		_assert(game.questions.size() == 30, "the generated local-preview question mirror should load")
		_assert(game.waves.size() == 9, "three embedded wave files should remain available")
		runtime.bridge.receive_payload({
			"type": "DGB_GODOT_INIT",
			"version": 1,
			"level": {"levelId": "test-level"},
			"data": {
				"gameId": "ch11-band-defense",
				"maxLeaks": 2,
				"questions": [{"id": "injected-question", "level": 1}],
				"waves": [{"level": 1, "wave": 1, "enemies": []}]
			}
		})
		_assert(game.questions.size() == 1 and game.questions[0].id == "injected-question", "injected questions should replace fallbacks")
		_assert(game.waves.size() == 1, "injected waves should replace embedded waves")
		_assert(game.get("max_leaks") == 2, "session maxLeaks should update the gameplay leak limit")
		_assert(game._leak_warning_threshold() == 1, "a two-leak limit should warn after the first leak")
		_assert(game.process_mode == Node.PROCESS_MODE_PAUSABLE, "Ch11 root should stop processing while the tree is paused")
		runtime.bridge.receive_payload({"type": "DGB_GODOT_PAUSE", "version": 1})
		_assert(paused, "host pause should pause the scene tree")
		_assert(!game.can_process(), "Ch11 gameplay should not process during host pause")
		_assert(runtime.can_process(), "shared runtime should keep processing so it can receive resume")
		runtime.bridge.receive_payload({"type": "DGB_GODOT_RESUME", "version": 1})
		_assert(!paused and game.can_process(), "host resume should reactivate Ch11 gameplay")
		var custom_connected := false
		for connection in runtime.custom_command_received.get_connections():
			var callable: Callable = connection.get("callable", Callable())
			custom_connected = custom_connected or callable.get_method() == "_on_custom_command"
		_assert(custom_connected, "recording demo should remain connected through the custom command signal")
		game.state = "wave_running"
		game.completed = false
		game.current_wave = 1
		game.leaks = 0
		game._on_enemy_leaked({"type": "test", "pos": Vector2.ZERO})
		_assert(!game.completed, "one leak should stay below an injected limit of two")
		game._on_enemy_leaked({"type": "test", "pos": Vector2.ZERO})
		_assert(game.completed, "the injected second leak should finish the run")
		var completions := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
		_assert(completions.size() == 1, "the first run should emit one completion")
		if completions.size() == 1:
			_assert(!completions[0].has("stars"), "Ch11 should let the host derive stars")
			_assert(int(completions[0].get("stats", {}).get("wavesCleared", -1)) == 0, "a shutdown should not count the in-progress wave")
		game.start_game()
		game.finish_game(false)
		completions = outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
		_assert(completions.size() == 2, "an internal restart should allow a second completion")
		game.state = "result"
		runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
		_assert(game.state == "main_menu", "host reset should return to main menu")
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
		print("Ch11 runtime integration tests passed")
		quit(0)
