extends SceneTree

const TEST_RECORD_PATH := "user://ch09_tutorial_test.cfg"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))
	var game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_record_path = TEST_RECORD_PATH
	get_root().add_child(game)
	await process_frame

	_assert(
		game._select_initial_experience(false, false, 0) == "tutorial",
		"missing completion should launch the tutorial"
	)
	_assert(
		game._select_initial_experience(false, false, game.TUTORIAL_VERSION) == "run",
		"matching completion should launch the formal run"
	)
	_assert(
		game._select_initial_experience(true, true, 0) == "node_lab",
		"Node Lab should take priority over forced tutorial"
	)
	_assert(
		game._select_initial_experience(false, true, game.TUTORIAL_VERSION) == "tutorial",
		"forced tutorial should override completion"
	)
	_assert(
		game._load_tutorial_completed_version(TEST_RECORD_PATH) == 0,
		"missing record should read as incomplete"
	)
	_assert(
		game._save_tutorial_completion(TEST_RECORD_PATH),
		"completion record should be writable"
	)
	_assert(
		game._load_tutorial_completed_version(TEST_RECORD_PATH) == game.TUTORIAL_VERSION,
		"saved record should contain the current completed version"
	)

	game._start_tutorial_briefing()
	game.budget = 99
	game._on_runtime_reset()
	_assert(game.tutorial_active, "runtime reset should keep tutorial mode active")
	_assert(!game.formal_run_active, "runtime reset should not begin a formal attempt during tutorial")
	_assert(game.state == game.RunState.WAITING, "runtime reset should return to the tutorial briefing")
	_assert(game.budget == 99, "runtime reset should not reset formal resources during tutorial")

	game.stability = 9
	game.current_layer = 4
	_assert(game._skip_tutorial(TEST_RECORD_PATH), "skip should persist completion")
	_assert(!game.tutorial_active, "skip should leave tutorial mode")
	_assert(game.formal_run_active, "skip should activate a formal attempt")
	_assert(game.state == game.RunState.MAP, "skip should open the formal map")
	_assert(game.current_layer == 0, "skip should reset formal route progress")
	_assert(game.stability == game.max_stability and game.budget == 30, "skip should restore formal resources")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))
	if failures == 0:
		print("Ch09 tutorial tests passed")
	quit(1 if failures > 0 else 0)
