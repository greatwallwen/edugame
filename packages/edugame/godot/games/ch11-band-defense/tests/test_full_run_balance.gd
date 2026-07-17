extends SceneTree

const MAX_SECONDS := 180.0

var failures := 0
var game: Node
var build_marks := {}
var level_summaries := []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 12.0
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	game = scene.instantiate()
	game.process_mode = Node.PROCESS_MODE_ALWAYS
	get_root().add_child(game)
	await process_frame
	game.start_game()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(MAX_SECONDS * 1000.0):
		_play_current_state()
		if str(game.state) == "result":
			break
		await create_timer(0.05).timeout
	_assert(str(game.state) == "result", "full run should reach result state")
	_assert(bool(game.completed), "full run should mark the game complete")
	_assert(int(game.current_level) == int(game._max_level_number()), "full run should reach the final level")
	_assert(int(game.correct_count) == 9, "full run should answer exactly one quiz per wave")
	_assert(int(game._waves_cleared_count(false)) == 9, "full three-level run should report nine cleared waves")
	_assert(int(game.leaks) < int(game.MAX_LEAKS), "final level should not hit the leak limit")
	_assert(int(game.band_score) >= 5000, "reasonable play should produce a passing band score")
	print(JSON.stringify({
		"state": str(game.state),
		"completed": bool(game.completed),
		"level": int(game.current_level),
		"wave": int(game.current_wave),
		"energy": int(game.energy),
		"trustedData": int(game.trusted_data),
		"leaks": int(game.leaks),
		"linkStability": int(game.link_stability),
		"spawnQueue": int(game.spawn_queue.size()),
		"spawnElapsed": float(game.spawn_elapsed),
		"diagnosticPaused": bool(game._is_diagnostic_time_paused()),
		"tutorialVisible": bool(game.diagnosis_tutorial_popup != null and game.diagnosis_tutorial_popup.visible),
		"enemyCount": int(game.enemies.size()),
		"correct": int(game.correct_count),
		"wrong": int(game.wrong_count),
		"bandScore": int(game.band_score),
		"levelSummaries": level_summaries
	}))
	_finish()


func _play_current_state() -> void:
	if game.diagnosis_tutorial_popup != null and game.diagnosis_tutorial_popup.visible:
		game._dismiss_diagnosis_tutorial_popup()
	var state := str(game.state)
	if state == "intro":
		level_summaries.append({
			"levelReady": int(game.current_level),
			"energy": int(game.energy),
			"trustedData": int(game.trusted_data),
			"lastLevelSummary": str(game.last_level_summary)
		})
		game.start_game()
	elif state == "wave_running":
		_apply_build_plan()
		_diagnose_visible_enemy_types()
	elif state == "quiz":
		var answer := int((game.active_question as Dictionary).get("answerIndex", 0))
		game.answer_quiz(answer)


func _apply_build_plan() -> void:
	var key := "%d-%d" % [int(game.current_level), int(game.current_wave)]
	if bool(build_marks.get(key, false)):
		return
	build_marks[key] = true
	var plans := {
		"1-1": [[0, "i2c"]],
		"1-2": [[2, "peak"]],
		"1-3": [[3, "power"], [0, "i2c"]],
		"2-1": [[0, "i2c"], [2, "filter"]],
		"2-2": [[3, "peak"], [5, "filter"], [2, "filter"]],
		"2-3": [[4, "peak"], [3, "power"], [1, "i2c"]],
		"3-1": [[0, "i2c"], [1, "filter"], [2, "peak"], [3, "power"], [4, "peak"], [5, "filter"]],
		"3-2": [[3, "power"], [4, "peak"], [5, "filter"], [2, "peak"]],
		"3-3": [[0, "i2c"], [1, "filter"], [2, "peak"], [3, "power"], [4, "peak"], [5, "power"]]
	}
	for raw_action in plans.get(key, []):
		var action := raw_action as Array
		game.build_tower(int(action[0]), str(action[1]))


func _diagnose_visible_enemy_types() -> void:
	for raw_enemy in game.enemies:
		var enemy := raw_enemy as Dictionary
		if bool(enemy.get("diagnosed", false)):
			continue
		if int(game.energy) < 12:
			continue
		game._open_diagnostic_menu(enemy)
		game._choose_diagnostic_method(str(enemy.get("diagnosticMethodId", "inspect_waveform")))
		game._choose_fault_type(str(enemy.get("type", "unknown")))


func _finish() -> void:
	Engine.time_scale = 1.0
	if failures > 0:
		quit(1)
	else:
		print("full run balance test passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
