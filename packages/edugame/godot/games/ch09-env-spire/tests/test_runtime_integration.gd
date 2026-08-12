extends SceneTree

const TEST_RECORD_PATH := "user://ch09_runtime_tutorial_test.cfg"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_record()
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	game.tutorial_record_path = TEST_RECORD_PATH
	_assert(game._save_tutorial_completion(TEST_RECORD_PATH), "runtime test completion record should be writable")
	get_root().add_child(game)
	var runtime = game.get("runtime")
	_assert(runtime != null, "Ch09 should expose the shared runtime")
	if runtime == null:
		game.queue_free()
		await process_frame
		_finish()
		return
	_assert(game.state == game.RunState.WAITING, "Ch09 should wait for runtime INIT")
	_assert(runtime.current_session().is_empty(), "runtime session should be empty before INIT")
	await process_frame
	await process_frame
	_assert(game.state == game.RunState.MENU, "local preview INIT should open the start menu")
	var paused_layer: int = int(game.current_layer)
	runtime.bridge.receive_payload({"type": "DGB_GODOT_PAUSE", "version": 1})
	_assert(game.host_paused, "host PAUSE should set the explicit Ch09 pause state")
	_assert(paused, "host PAUSE should pause the scene tree")
	_assert(game.host_pause_overlay != null and game.host_pause_overlay.visible, "host PAUSE should show a blocking overlay")
	_assert(!game.choose_node(0), "map selection should be rejected while the host is paused")
	_assert(game.current_layer == paused_layer, "paused map input should not mutate run progress")
	runtime.bridge.receive_payload({"type": "DGB_GODOT_RESUME", "version": 1})
	_assert(!game.host_paused and !paused, "host RESUME should restore gameplay processing")
	_assert(game.host_pause_overlay != null and !game.host_pause_overlay.visible, "host RESUME should hide the blocking overlay")
	game.state = game.RunState.WAITING
	game.deck.clear()
	_assert(game._start_standalone_preview(true), "top-level Web preview should start with default content")
	_assert(game.state == game.RunState.MAP and game.deck.size() == 12, "standalone preview should enter the map with the starter deck")
	game.state = game.RunState.WAITING
	_assert(!game._start_standalone_preview(false), "embedded Web runtime should keep waiting for host INIT")
	_assert(game.state == game.RunState.WAITING, "embedded preview should not bypass host initialization")
	game._reset_run()

	var outbound_payloads: Array = []
	runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: outbound_payloads.append(payload))
	_assert(str(runtime.get_script().resource_path).ends_with("addons/dgbook_runtime/runtime.gd"), "Ch09 should use copied dgbook runtime")
	game._start_tutorial_briefing()
	game._start_tutorial_encounter()
	_assert(game.confirm_tutorial_intent(), "tutorial action should advance from the briefing fixture")
	_assert(game.play_card(0), "tutorial action should resolve its scripted defense")
	_assert(!game.completed, "tutorial should not mark gameplay complete")
	_assert(game.score == 0, "tutorial should not calculate a score")
	_assert(game.current_layer == 0, "tutorial should not visit formal nodes")
	_assert(int(game._run_stats().get("visitedNodes", -1)) == 0, "tutorial should not enter run stats")
	_assert(!game.formal_run_active, "tutorial should not activate the formal attempt")
	var tutorial_completions := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
	_assert(tutorial_completions.is_empty(), "tutorial should not emit completion payloads")
	_assert(game._skip_tutorial(TEST_RECORD_PATH), "tutorial skip should start the formal run")
	_assert(game.formal_run_active, "tutorial skip should activate the formal attempt")
	_assert(game.state == game.RunState.MAP, "tutorial skip should enter the formal map")
	tutorial_completions = outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
	_assert(tutorial_completions.is_empty(), "tutorial skip should not emit completion payloads")
	runtime.bridge.receive_payload({
		"type": "DGB_GODOT_INIT",
		"version": 1,
		"level": {"levelId": "test-ch09"},
		"data": {
			"gameId": "ch09-env-spire",
			"runMapId": "mvp_b",
			"maxStability": 80,
			"questions": [{
				"id": "basic_mq2_warmup",
				"name": "宿主注入题目",
				"questionType": "diagnosis",
				"knowledgeTags": ["runtime", "injected"],
				"prompt": "宿主注入的问题是否覆盖本地预览题目？",
				"options": [
					{"id": "yes", "label": "是"},
					{"id": "no", "label": "否"}
				],
				"correctAnswer": "yes",
				"explanation": "课程宿主是发布环境中的教学内容权威来源。"
			}]
		}
	})
	_assert(game.run_map_id == "mvp_b", "host should inject map id")
	_assert(game.max_stability == 80 and game.state == game.RunState.MENU, "host should inject max stability and return to the menu")
	_assert(game.select_start_menu_command("run"), "host-configured menu should start the formal run")
	_assert(game.stability == 80, "formal run should initialize with the host stability limit")
	_assert(
		str((game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).get("prompt", "")) == "宿主注入的问题是否覆盖本地预览题目？",
		"host questions should override the local preview copy by stable question id"
	)
	game.current_layer = 12
	game.visited_nodes.resize(12)
	game.checkpoints_passed = 2
	game.boss_phase = 2
	game._finish_run(true)
	var completions := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
	_assert(completions.size() == 1, "one run should emit one completion")
	if completions.size() == 1:
		var completion := completions[0] as Dictionary
		_assert(!completion.has("stars"), "host should derive stars from level thresholds")
		var stats := completion.get("stats", {}) as Dictionary
		_assert(int(stats.get("visitedNodes", 0)) == 12, "completion should report twelve visited nodes")
		_assert(int(stats.get("checkpointsPassed", 0)) == 2, "completion should report checkpoints")
		_assert(int(stats.get("bossPhase", -1)) == 2, "completion should report boss phase")
		_assert(stats.has("stability") and stats.has("deckSize") and stats.has("elapsedMs"), "completion should include core run stats")
	game._reset_run()
	game._finish_run(true)
	completions = outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE")
	_assert(completions.size() == 2, "internal restart should allow another completion")
	game.stability = 3
	runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
	_assert(game.stability == 80 and game.state == game.RunState.MAP, "host reset should restart with injected config")

	if !game.has_method("_enter_node_lab"):
		_assert(false, "game should expose node lab entry")
	else:
		var completion_count_before_lab := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE").size()
		game._enter_node_lab()
		var lab_entries: Array = game.node_lab_overlay.catalog_entries()
		var correct_fixture := _catalog_entry(lab_entries, "question_correct")
		var wrong_fixture := _catalog_entry(lab_entries, "question_wrong")
		if correct_fixture.is_empty() or wrong_fixture.is_empty():
			_assert(false, "Node Lab should expose correct and wrong result fixtures")
		else:
			_assert(game.start_lab_scenario(correct_fixture), "correct result fixture should launch")
			_assert(game.node_lab_active and !game.formal_run_active, "correct result fixture should remain isolated from formal runs")
			_assert(game.event_answer_locked and bool(game.event_result.get("correct", false)), "correct result fixture should open the forced correct outcome")
			_assert(game.choose_event_reward(0), "correct result fixture should accept its first reward")
			if !game.pending_card_selection.is_empty():
				_assert(game.choose_pending_card(0), "correct result reward should resolve its owned selection")
			_assert(game.continue_event(), "correct result fixture should continue")
			_assert(_completion_count(outbound_payloads) == completion_count_before_lab, "continuing a result fixture should not report course completion")
			_assert(game.restart_lab_scenario(), "correct result fixture should restart")
			_assert(game.node_lab_active and !game.formal_run_active, "restarted result fixture should remain isolated")
			_assert(_completion_count(outbound_payloads) == completion_count_before_lab, "restarting a result fixture should not report course completion")
			runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
			await process_frame
			_assert(game.node_lab_active and !game.formal_run_active, "reset result fixture should remain isolated")
			_assert(_completion_count(outbound_payloads) == completion_count_before_lab, "resetting a result fixture should not report course completion")
			_assert(game.start_lab_scenario(wrong_fixture), "wrong result fixture should launch")
			_assert(game.event_answer_locked and !bool(game.event_result.get("correct", true)), "wrong result fixture should open the forced wrong outcome")
			_assert(game.continue_event(), "wrong result fixture should continue")
			_assert(_completion_count(outbound_payloads) == completion_count_before_lab, "wrong result continuation should not report course completion")
		runtime.bridge.receive_payload({"type": "DGB_GODOT_RESET", "version": 1})
		await process_frame
		_assert(game.node_lab_active, "host reset should preserve Node Lab mode")
		_assert(!game.formal_run_active, "host reset inside Node Lab should not activate a formal attempt")
		game.current_layer = 12
		game.visited_nodes.resize(12)
		game.checkpoints_passed = 2
		game.boss_phase = 2
		game._finish_run(true)
		await process_frame
		var completion_count_after_host_reset := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE").size()
		_assert(completion_count_after_host_reset == completion_count_before_lab, "Node Lab host reset result should not report course completion")
		var restart_button := game.find_child("RestartButton", true, false) as Button
		_assert(restart_button != null, "Node Lab result should retain the normal restart control for regression coverage")
		if restart_button != null:
			restart_button.emit_signal("pressed")
			await process_frame
			_assert(!game.formal_run_active, "result restart inside Node Lab should not activate a formal attempt")
			game.current_layer = 12
			game.visited_nodes.resize(12)
			game.checkpoints_passed = 2
			game.boss_phase = 2
			game._finish_run(true)
			var completion_count_after_restart := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE").size()
			_assert(completion_count_after_restart == completion_count_before_lab, "Node Lab result restart should not report course completion")
		game.start_lab_scenario({
			"id": "warehouse_acceptance",
			"kind": "enemy",
			"contentId": "warehouse_acceptance",
			"tier": "boss"
		})
		game._finish_run(true)
		var completion_count_after_lab := outbound_payloads.filter(func(payload: Dictionary) -> bool: return payload.get("type") == "DGB_GODOT_COMPLETE").size()
		_assert(completion_count_after_lab == completion_count_before_lab, "node lab should not report course completion")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _catalog_entry(entries: Array, expected_id: String) -> Dictionary:
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		if str(entry.get("id", "")) == expected_id:
			return entry
	return {}


func _completion_count(payloads: Array) -> int:
	return payloads.filter(func(payload: Dictionary) -> bool:
		return payload.get("type") == "DGB_GODOT_COMPLETE"
	).size()


func _finish() -> void:
	_remove_test_record()
	if failures > 0:
		quit(1)
	else:
		print("Ch09 runtime integration tests passed")
		quit(0)


func _remove_test_record() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))
