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
	_assert(game.tutorial_step == game.TutorialStep.BRIEFING, "tutorial briefing should set the briefing step")
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

	_enter_practice(game)
	_assert(
		game.tutorial_step == game.TutorialStep.READ_INTENT,
		"practice should begin by reading intent"
	)
	_assert(!game.play_card(0), "cards should be locked before intent confirmation")
	_assert(!game._tutorial_end_turn_allowed(), "end turn should be locked before defense")
	_assert(game.confirm_tutorial_intent(), "intent target should advance the tutorial")
	_assert(
		game.tutorial_step == game.TutorialStep.PLAY_DEFENSE,
		"confirmed intent should unlock defense"
	)
	_assert(
		str((game.hand[0] as Dictionary).get("id", "")) == "sliding_average",
		"first scripted hand should contain sliding average"
	)
	_assert(game.play_card(0), "required defense card should be playable")
	_assert(game.block == 7, "defense card should create seven real block")
	_assert(
		game.tutorial_step == game.TutorialStep.END_TURN,
		"defense should unlock end turn"
	)

	var stability_before: int = game.stability
	_assert(game.end_turn(), "guided end turn should resolve")
	_assert(game.stability == stability_before, "seven block should absorb six damage")
	_assert(game.block == 0, "defense should reset when the next turn begins")
	_assert(game.tutorial_step == game.TutorialStep.PLAY_SAMPLE, "turn two should begin at sampling")

	_assert(!game.play_card(1), "ADC conversion should be rejected before sampling")
	_assert(game.play_card(0), "MQ-2 sampling should succeed")
	_assert(int(game.raw_data.get("smoke", 0)) == 1, "sampling should create raw smoke data")

	_assert(game.play_card(0), "ADC conversion should succeed after sampling")
	_assert(int(game.raw_data.get("smoke", 0)) == 0, "conversion should consume raw smoke")
	_assert(int(game.trusted_data.get("smoke", 0)) == 1, "conversion should create trusted smoke")

	_assert(game.play_card(0), "LED output should consume trusted smoke")
	_assert(int(game.trusted_data.get("smoke", 0)) == 0, "output should consume trusted smoke")
	_assert(game.tutorial_step == game.TutorialStep.COMPLETE, "output should complete the practice")

	game.queue_free()
	await process_frame
	_finish()


func _enter_practice(game) -> void:
	game._start_tutorial_briefing()
	game._start_tutorial_encounter()


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
