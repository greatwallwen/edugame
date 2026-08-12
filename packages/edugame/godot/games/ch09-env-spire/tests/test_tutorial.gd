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
		game._select_initial_experience(false, false, 0) == "menu",
		"missing completion should open the menu with a tutorial recommendation"
	)
	_assert(
		game._select_initial_experience(false, false, game.TUTORIAL_VERSION) == "menu",
		"matching completion should still open the menu"
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
	game.pending_service_energy_penalty = -2
	game._on_runtime_reset()
	_assert(game.tutorial_active, "runtime reset should keep tutorial mode active")
	_assert(!game.formal_run_active, "runtime reset should not begin a formal attempt during tutorial")
	_assert(game.state == game.RunState.WAITING, "runtime reset should return to the tutorial briefing")
	_assert(game.pending_service_energy_penalty == -2, "runtime reset should not reset formal resources during tutorial")

	_dirty_tutorial_state(game)
	_assert(game._skip_tutorial(TEST_RECORD_PATH), "skip should enter a formal run")
	_assert_clean_formal_run(game, "skip")

	_enter_practice(game)
	_dirty_tutorial_state(game)
	_assert(game.has_method("_complete_tutorial"), "tutorial should expose a completion transition")
	if game.has_method("_complete_tutorial"):
		_assert(game._complete_tutorial(TEST_RECORD_PATH), "completion should enter a formal run")
	_assert_clean_formal_run(game, "completion")

	game._start_tutorial_briefing()
	var saved_led := (game.card_defs.get("led_alarm", {}) as Dictionary).duplicate(true)
	game.card_defs.erase("led_alarm")
	game._start_tutorial_encounter()
	_assert(
		game.state == game.RunState.MAP and game.formal_run_active,
		"missing tutorial fixture data should fall back to a formal run"
	)
	_assert(
		game._tutorial_missing_fixture_card_id() == "led_alarm",
		"missing tutorial fixture fallback should identify the exact missing card"
	)
	game.card_defs["led_alarm"] = saved_led

	_enter_practice(game)
	_assert(
		str(game.TutorialPresenter.coach_text(game.TutorialStep.READ_INTENT)).contains("敌人上方")
		and str(game.TutorialPresenter.coach_text(game.TutorialStep.READ_INTENT)).contains("点击"),
		"intent tutorial copy should direct players to click the floating enemy badge"
	)
	_assert(
		game.tutorial_step == game.TutorialStep.READ_INTENT,
		"practice should begin by reading intent"
	)
	_assert(!game.play_card(0), "cards should be locked before intent confirmation")
	_assert(!game._tutorial_end_turn_allowed(), "end turn should be locked before defense")
	var premature_state: int = game.state
	var premature_stability: int = game.stability
	var premature_hand: Array = game.hand.duplicate(true)
	_assert(!game.end_turn(), "public end turn should reject premature tutorial use")
	_assert(game.state == premature_state, "premature end turn should preserve state")
	_assert(game.stability == premature_stability, "premature end turn should preserve stability")
	_assert(game.hand == premature_hand, "premature end turn should preserve hand")
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
	await process_frame
	var completion_summary := game.find_child("TutorialCompletionSummary", true, false) as Label
	var completion_button := game.find_child("TutorialCompleteButton", true, false) as Button
	var completion_menu_button := game.find_child("TutorialMenuButton", true, false) as Button
	_assert(completion_summary != null and completion_summary.is_visible_in_tree(), "completion should show the formal loop summary")
	if completion_summary != null:
		_assert(completion_summary.text.contains("读取意图 -> 消耗处理点 -> 建立证据 -> 修复故障 -> 改善牌组"), "completion summary should explain the core loop")
		_assert(completion_summary.text.contains("战斗奖励") and completion_summary.text.contains("功能节点") and completion_summary.text.contains("LED"), "completion summary should explain rewards, utility nodes, and the practice-only LED card")
	_assert(completion_button != null and completion_button.is_visible_in_tree() and !completion_button.disabled, "completion should expose an enabled formal-run command")
	_assert(completion_menu_button != null and completion_menu_button.is_visible_in_tree() and !completion_menu_button.disabled, "completion should expose an enabled menu command")
	if completion_button != null:
		completion_button.emit_signal("pressed")
		await process_frame
		_assert(game._load_tutorial_completed_version(TEST_RECORD_PATH) == game.TUTORIAL_VERSION, "completion command should persist the tutorial version")
		_assert_clean_formal_run(game, "completion command")

	game.queue_free()
	await process_frame
	_finish()


func _enter_practice(game) -> void:
	game._start_tutorial_briefing()
	game._start_tutorial_encounter()


func _dirty_tutorial_state(game) -> void:
	game.tutorial_active = true
	game.tutorial_step = game.TutorialStep.PLAY_CONVERT
	game.stability = 13
	game.pending_service_energy_penalty = -2
	game.current_layer = 7
	game.visited_nodes = [{"type": "tutorial"}]
	game.deck = [game._card_copy("led_alarm")]
	game.debug_reports = [{"encounterId": "training_signal_chain"}]


func _assert_clean_formal_run(game, route: String) -> void:
	_assert(!game.tutorial_active, "%s should clear tutorial activity" % route)
	_assert(game.tutorial_step == game.TutorialStep.INACTIVE, "%s should clear tutorial step" % route)
	_assert(game.formal_run_active, "%s should activate a formal attempt" % route)
	_assert(game.state == game.RunState.MAP, "%s should enter the formal map" % route)
	_assert(game.current_layer == 0 and game.visited_nodes.is_empty(), "%s formal route should be untouched" % route)
	_assert(game.stability == game.max_stability, "%s should restore formal stability" % route)
	_assert(game.pending_service_energy_penalty == 0, "%s should clear queued service costs" % route)
	_assert(game.deck.size() == game.STARTER_CARD_IDS.size(), "%s should rebuild the formal deck" % route)
	_assert(game.debug_reports.is_empty(), "%s should clear tutorial reports" % route)


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
