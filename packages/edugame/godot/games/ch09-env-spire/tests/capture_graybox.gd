extends SceneTree

const OUT_DIR := "C:/Users/sy/Desktop/dgbook-ref-main/dgbook-ref/.superpowers/visual-qa/ch09-env-spire"
const DESKTOP_SIZE := Vector2i(1280, 720)
const MOBILE_SIZE := Vector2i(390, 844)
const QUESTION_CAPTURE_CASES := [
	{
		"event_id": "basic_mq2_warmup",
		"question_type": "diagnosis",
		"desktop": "30-desktop-event-diagnosis.png",
		"mobile": "50-mobile-event-diagnosis.png"
	},
	{
		"event_id": "basic_signal_order",
		"question_type": "ordering",
		"desktop": "31-desktop-event-ordering.png",
		"mobile": "51-mobile-event-ordering.png"
	},
	{
		"event_id": "basic_i2c_result",
		"question_type": "code_trace",
		"desktop": "32-desktop-event-code-trace.png",
		"mobile": "52-mobile-event-code-trace.png"
	},
	{
		"event_id": "basic_sample_period",
		"question_type": "parameter",
		"desktop": "33-desktop-event-parameter.png",
		"mobile": "53-mobile-event-parameter.png"
	},
	{
		"event_id": "basic_adc_spike",
		"question_type": "waveform",
		"desktop": "34-desktop-event-waveform.png",
		"mobile": "54-mobile-event-waveform.png"
	},
	{
		"event_id": "basic_raw_trusted",
		"question_type": "tradeoff",
		"desktop": "35-desktop-event-trade-off.png",
		"mobile": "55-mobile-event-trade-off.png"
	}
]

var capture_failed := false
var capture_size := Vector2i.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var mobile := OS.get_cmdline_user_args().has("--mobile")
	capture_size = MOBILE_SIZE if mobile else DESKTOP_SIZE
	DisplayServer.window_set_size(capture_size)
	get_root().size = capture_size
	var scene := load("res://scenes/main.tscn")
	if !_expect(scene != null, "main scene should load"):
		quit(1)
		return

	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(capture_size)
	await _settle()
	print("capture viewport=", get_root().size, " control=", game.size, " window=", DisplayServer.window_get_size())

	if !(await _capture_tutorial(game, mobile)):
		await _finish_capture_run(game)
		return
	if !(await _capture_core_flow(game, mobile)):
		await _finish_capture_run(game)
		return
	if !(await _capture_combat_depth(game, mobile)):
		await _finish_capture_run(game)
		return
	if !(await _capture_question_events(game, mobile)):
		await _finish_capture_run(game)
		return
	if !(await _capture_node_lab(game, mobile)):
		await _finish_capture_run(game)
		return
	await _finish_capture_run(game)


func _capture_tutorial(game, mobile: bool) -> bool:
	game._start_tutorial_briefing()
	game._render_state()
	if !(await _capture_checked(
		game,
		"39-mobile-tutorial-briefing.png" if mobile else "19-desktop-tutorial-briefing.png",
		game.RunState.WAITING,
		["TutorialView", "TutorialStartButton"],
		game.TutorialStep.BRIEFING
	)):
		return false

	game._start_tutorial_encounter()
	if !(await _capture_checked(
		game,
		"40-mobile-tutorial-intent.png" if mobile else "20-desktop-tutorial-intent.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialIntentButton"],
		game.TutorialStep.READ_INTENT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.confirm_tutorial_intent(), game.TutorialStep.PLAY_DEFENSE, "confirm intent"):
		return false
	if !(await _capture_checked(
		game,
		"41-mobile-tutorial-defense.png" if mobile else "21-desktop-tutorial-defense.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_DEFENSE
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.END_TURN, "play defense"):
		return false
	if !(await _capture_checked(
		game,
		"42-mobile-tutorial-end-turn.png" if mobile else "22-desktop-tutorial-end-turn.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "EndTurnButton"],
		game.TutorialStep.END_TURN
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.end_turn(), game.TutorialStep.PLAY_SAMPLE, "end turn"):
		return false
	if !(await _capture_checked(
		game,
		"43-mobile-tutorial-sample.png" if mobile else "23-desktop-tutorial-sample.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_SAMPLE
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_CONVERT, "play sample"):
		return false
	if !(await _capture_checked(
		game,
		"44-mobile-tutorial-convert.png" if mobile else "24-desktop-tutorial-convert.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_CONVERT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_OUTPUT, "play conversion"):
		return false
	if !(await _capture_checked(
		game,
		"45-mobile-tutorial-output.png" if mobile else "25-desktop-tutorial-output.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_OUTPUT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.COMPLETE, "play output"):
		return false
	return await _capture_checked(
		game,
		"46-mobile-tutorial-complete.png" if mobile else "26-desktop-tutorial-complete.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialCompletionSummary"],
		game.TutorialStep.COMPLETE
	)


func _capture_core_flow(game, mobile: bool) -> bool:
	game._reset_run()
	game._render_state()
	if !(await _capture_checked(
		game,
		"21-mobile-map.png" if mobile else "01-desktop-map.png",
		game.RunState.MAP,
		["MapView", "MapRoute", "MapEnterButton"]
	)):
		return false

	if !_expect(game.choose_node(0), "normal combat capture should enter route node 1"):
		return false
	game._render_state()
	if !(await _capture_checked(
		game,
		"22-mobile-combat.png" if mobile else "02-desktop-combat.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "EngineeringChainStrip", "HandRow", "EndTurnButton"]
	)):
		return false

	game.encounter_evidence_tags = {"smoke": true, "adc": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._render_state()
	if !_expect(game.state == game.RunState.REWARD, "completed combat should reach reward state"):
		return false
	if !(await _capture_checked(
		game,
		"23-mobile-reward.png" if mobile else "03-desktop-reward.png",
		game.RunState.REWARD,
		["ChoiceView", "RewardCards", "RewardSkipButton"]
	)):
		return false

	game._open_shop()
	game._render_state()
	if !(await _capture_checked(
		game,
		"24-mobile-shop.png" if mobile else "04-desktop-shop.png",
		game.RunState.SHOP,
		["ChoiceView", "ChoiceList"]
	)):
		return false

	game.state = game.RunState.REST
	game._render_state()
	if !(await _capture_checked(
		game,
		"25-mobile-rest.png" if mobile else "05-desktop-rest.png",
		game.RunState.REST,
		["ChoiceView", "ServiceBench", "ChoiceList"]
	)):
		return false

	game.current_node = {"type": "checkpoint_sensor", "contentId": "sensor_checkpoint"}
	game._start_checkpoint(true)
	game._render_state()
	if !(await _capture_checked(
		game,
		"26-mobile-checkpoint-sensor.png" if mobile else "06-desktop-checkpoint-sensor.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "HandRow"]
	)):
		return false

	game.current_node = {"type": "checkpoint_trust", "contentId": "trust_checkpoint"}
	game._start_checkpoint(false)
	game._render_state()
	if !(await _capture_checked(
		game,
		"27-mobile-checkpoint-trust.png" if mobile else "07-desktop-checkpoint-trust.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "HandRow"]
	)):
		return false

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game._render_state()
	if !(await _capture_checked(
		game,
		"28-mobile-boss-phase-1.png" if mobile else "08-desktop-boss-phase-1.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton"]
	)):
		return false
	game.boss_phase = 1
	game._apply_boss_phase()
	game._render_state()
	if !_expect(game.boss_phase == 1, "Boss phase 2 capture should retain phase index 1"):
		return false
	if !(await _capture_checked(
		game,
		"29-mobile-boss-phase-2.png" if mobile else "09-desktop-boss-phase-2.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton"]
	)):
		return false
	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	if !_expect(game.boss_phase == 2, "Boss phase 3 capture should retain phase index 2"):
		return false
	if !(await _capture_checked(
		game,
		"30-mobile-boss-phase-3.png" if mobile else "10-desktop-boss-phase-3.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton"]
	)):
		return false

	game.current_layer = 12
	game.checkpoints_passed = 2
	game._finish_run(true)
	game._render_state()
	if !(await _capture_checked(
		game,
		"31-mobile-result.png" if mobile else "11-desktop-result.png",
		game.RunState.RESULT,
		["ResultView", "RunResultHeading", "RestartButton"]
	)):
		return false

	game._reset_run()
	var legacy_event := (game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).duplicate(true)
	if !_expect(!legacy_event.is_empty(), "retained event capture should use a valid question fixture"):
		return false
	game.current_node = {"type": "event", "contentId": "basic_mq2_warmup"}
	game._begin_question_event(legacy_event)
	game._render_state()
	if !(await _capture_checked(
		game,
		"35-mobile-event.png" if mobile else "15-desktop-event.png",
		game.RunState.EVENT,
		["ChoiceView", "QuestionEventFrame", "QuestionPrompt", "QuestionInteraction"]
	)):
		return false

	game._reset_run()
	game.current_node = {"type": "component", "label": "工程组件"}
	game._open_component_choice()
	game._render_state()
	if !_expect(game.component_choices.size() == 3, "component capture should offer three choices"):
		return false
	if !(await _capture_checked(
		game,
		"36-mobile-component.png" if mobile else "16-desktop-component.png",
		game.RunState.COMPONENT,
		["ChoiceView", "ChoiceList"]
	)):
		return false

	game._reset_run()
	game.current_layer = 11
	game.current_node = {"type": "service", "label": "节点 11 · Boss 前整备"}
	game.state = game.RunState.REST
	game._render_state()
	if !(await _capture_checked(
		game,
		"37-mobile-service-node-11.png" if mobile else "17-desktop-service-node-11.png",
		game.RunState.REST,
		["ChoiceView", "ServiceBench", "ChoiceList"]
	)):
		return false

	game._reset_run()
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game.reward_choices.clear()
	game.state = game.RunState.REWARD
	game._render_state()
	return await _capture_checked(
		game,
		"38-mobile-reward-fallback.png" if mobile else "18-desktop-reward-fallback.png",
		game.RunState.REWARD,
		["ChoiceView", "RewardSkipButton"]
	)


func _capture_combat_depth(game, mobile: bool) -> bool:
	game._reset_run()
	if !_expect(game.choose_node(0), "reroute capture should enter route node 1"):
		return false
	game._render_state()
	if !_expect(game.begin_reroute(), "reroute capture should enter selection mode"):
		return false
	if !_expect(game.reroute_mode, "reroute selection mode should be active"):
		return false
	if !(await _capture_checked(
		game,
		"47-mobile-reroute-selection.png" if mobile else "27-desktop-reroute-selection.png",
		game.RunState.COMBAT,
		["CombatView", "RerouteButton", "RerouteCancelButton", "HandRow"]
	)):
		return false
	if !_expect(game.cancel_reroute() and !game.reroute_mode, "reroute capture should cancel back to normal combat"):
		return false

	if !_prepare_fault_fixture(game):
		return false
	if !_expect(game.play_card(0), "fault-trigger capture should play the first smoke card"):
		return false
	if !_expect(game.play_card(0), "fault-trigger capture should play the second smoke card"):
		return false
	var triggered_preview := game._fault_rule_preview() as Dictionary
	if !_expect(bool(triggered_preview.get("triggered", false)) and !bool(triggered_preview.get("suppressed", false)), "fault-trigger capture should reach the exact triggered result"):
		return false
	game._render_state()
	var fault_state := game.find_child("FaultRuleState", true, false) as Label
	if !_expect(fault_state != null and fault_state.text == "已触发", "fault-trigger capture should render the triggered label"):
		return false
	if !(await _capture_checked(
		game,
		"48-mobile-fault-triggered.png" if mobile else "28-desktop-fault-triggered.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "FaultRuleRow", "FaultCounterRow", "FaultRuleState"]
	)):
		return false

	if !_prepare_fault_fixture(game):
		return false
	if !_expect(game.play_card(2), "fault-suppressed capture should play the diagnosis counter"):
		return false
	var suppressed_preview := game._fault_rule_preview() as Dictionary
	if !_expect(bool(suppressed_preview.get("suppressed", false)) and !bool(suppressed_preview.get("triggered", false)), "fault-suppressed capture should reach the exact counter result"):
		return false
	game._render_state()
	fault_state = game.find_child("FaultRuleState", true, false) as Label
	if !_expect(fault_state != null and fault_state.text == "本回合已抑制", "fault-suppressed capture should render the suppression label"):
		return false
	return await _capture_checked(
		game,
		"49-mobile-fault-suppressed.png" if mobile else "29-desktop-fault-suppressed.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "FaultRuleRow", "FaultCounterRow", "FaultRuleState"]
	)


func _capture_question_events(game, mobile: bool) -> bool:
	for raw_case in QUESTION_CAPTURE_CASES:
		var capture_case := raw_case as Dictionary
		var event_id := str(capture_case.get("event_id", ""))
		var question_type := str(capture_case.get("question_type", ""))
		game._reset_run()
		var event := (game.event_defs.get(event_id, {}) as Dictionary).duplicate(true)
		if !_expect(!event.is_empty(), "%s capture fixture should exist" % event_id):
			return false
		game._begin_question_event(event)
		game._render_state()
		await _settle()
		if !_expect(str(game.current_event.get("id", "")) == event_id and str(game.current_event.get("questionType", "")) == question_type, "%s capture should retain its exact event and question type" % event_id):
			return false
		var prompt := game.find_child("QuestionPrompt", true, false) as Label
		var interaction := game.find_child("QuestionInteraction", true, false) as Control
		if !_expect(prompt != null and prompt.is_visible_in_tree() and !prompt.text.strip_edges().is_empty(), "%s capture should render a nonblank prompt" % event_id):
			return false
		if !_expect(interaction != null and interaction.is_visible_in_tree() and interaction.get_child_count() > 0, "%s capture should render a nonblank interaction" % event_id):
			return false
		if question_type == "ordering":
			if !_expect(game.find_child("QuestionOrderUp_0", true, false) != null and game.find_child("QuestionOrderDown_0", true, false) != null, "ordering capture should expose up/down controls"):
				return false
		elif question_type == "waveform":
			var plot := game.find_child("QuestionWaveformPlot", true, false) as Control
			var fallback := game.find_child("QuestionWaveformFallback", true, false) as Label
			var waveform_valid := plot != null and !plot.find_children("*", "Line2D", true, false).is_empty()
			waveform_valid = waveform_valid or (fallback != null and !fallback.text.strip_edges().is_empty())
			if !_expect(waveform_valid, "waveform capture should expose a nonblank plot or fallback"):
				return false
		var filename := str(capture_case.get("mobile" if mobile else "desktop", ""))
		if !(await _capture_checked(
			game,
			filename,
			game.RunState.EVENT,
			["ChoiceView", "QuestionEventFrame", "QuestionPrompt", "QuestionInteraction", "QuestionSubmit"]
		)):
			return false

	game._reset_run()
	var result_event := (game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).duplicate(true)
	game._begin_question_event(result_event)
	if !_expect(game.submit_event_answer(result_event.get("correctAnswer")), "correct-result capture should submit the exact answer"):
		return false
	game._render_state()
	await _settle()
	if !_expect(game.event_answer_locked and bool(game.event_result.get("correct", false)) and bool(game.event_result.get("rewardPending", false)), "correct-result capture should expose explanation and pending reward"):
		return false
	if !_expect(!game.find_children("QuestionReward_*", "Button", true, false).is_empty(), "correct-result capture should render reward choices"):
		return false
	if !(await _capture_checked(
		game,
		"56-mobile-event-correct-reward.png" if mobile else "36-desktop-event-correct-reward.png",
		game.RunState.EVENT,
		["ChoiceView", "QuestionExplanation", "QuestionConsequence"]
	)):
		return false

	game._reset_run()
	result_event = (game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).duplicate(true)
	var stability_before: int = game.stability
	game._begin_question_event(result_event)
	if !_expect(game.submit_event_answer("adc_resolution"), "wrong-result capture should submit a valid wrong answer"):
		return false
	game._render_state()
	await _settle()
	if !_expect(game.event_answer_locked and !bool(game.event_result.get("correct", true)), "wrong-result capture should expose the wrong explanation"):
		return false
	if !_expect(game.stability < stability_before, "wrong-result capture should apply its stability penalty"):
		return false
	return await _capture_checked(
		game,
		"57-mobile-event-wrong-penalty.png" if mobile else "37-desktop-event-wrong-penalty.png",
		game.RunState.EVENT,
		["ChoiceView", "QuestionExplanation", "QuestionConsequence", "QuestionContinue"]
	)


func _capture_node_lab(game, mobile: bool) -> bool:
	game._enter_node_lab()
	await _settle()
	var required_catalog_ids := [
		"basic_mq2_warmup",
		"basic_signal_order",
		"basic_i2c_result",
		"basic_sample_period",
		"basic_adc_spike",
		"basic_raw_trusted"
	]
	for event_id in required_catalog_ids:
		if !_expect(game.find_child("NodeLabScenario_%s" % event_id, true, false) != null, "Node Lab catalog should expose %s" % event_id):
			return false
	if !(await _capture_checked(
		game,
		"32-mobile-node-lab.png" if mobile else "12-desktop-node-lab.png",
		game.RunState.WAITING,
		["NodeLabRoot", "NodeLabToolbar", "NodeLabCatalog"]
	)):
		return false
	if !(await _capture_checked(
		game,
		"58-mobile-node-lab-event-catalog.png" if mobile else "38-desktop-node-lab-event-catalog.png",
		game.RunState.WAITING,
		["NodeLabRoot", "NodeLabToolbar", "NodeLabCatalog"]
	)):
		return false

	if !_expect(game.start_lab_scenario({
		"id": "basic_mq2_warmup",
		"label": "MQ-2 预热诊断",
		"kind": "question_event",
		"contentId": "basic_mq2_warmup"
	}, "starter"), "retained Node Lab event capture should launch a valid question event"):
		return false
	if !(await _capture_checked(
		game,
		"33-mobile-node-lab-event.png" if mobile else "13-desktop-node-lab-event.png",
		game.RunState.EVENT,
		["NodeLabToolbar", "NodeLabReturn", "QuestionEventFrame", "QuestionPrompt"]
	)):
		return false

	if !_expect(game.start_lab_scenario({
		"id": "mq2_warmup",
		"label": "MQ-2 预热不足",
		"kind": "enemy",
		"contentId": "mq2_warmup",
		"tier": "ordinary"
	}, "coverage"), "retained Node Lab combat capture should launch its enemy"):
		return false
	return await _capture_checked(
		game,
		"34-mobile-node-lab-combat.png" if mobile else "14-desktop-node-lab-combat.png",
		game.RunState.COMBAT,
		["NodeLabToolbar", "NodeLabReturn", "CombatView", "EncounterArena", "HandRow"]
	)


func _prepare_fault_fixture(game) -> bool:
	game._reset_run()
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	if !_expect(str(game._fault_rule_preview().get("id", "")) == "mq2_uncalibrated", "fault capture should start the MQ-2 rule"):
		return false
	if !_expect(game._prepare_lab_fault_rule_hand(), "fault capture should prepare deterministic trigger and counter cards"):
		return false
	game._render_state()
	return true


func _capture_checked(
	game,
	filename: String,
	expected_state: int,
	visible_node_names: Array,
	expected_tutorial_step: int = -1
) -> bool:
	if capture_failed:
		return false
	await _settle()
	if !_expect(game.state == expected_state, "%s reached wrong state: expected %d, got %d" % [filename, expected_state, game.state]):
		return false
	if expected_tutorial_step >= 0 and !_expect(game.tutorial_step == expected_tutorial_step, "%s reached wrong tutorial step: expected %d, got %d" % [filename, expected_tutorial_step, game.tutorial_step]):
		return false
	for raw_name in visible_node_names:
		var node_name := str(raw_name)
		var node: Node = game.find_child(node_name, true, false)
		if !_expect(node != null, "%s is missing required node %s" % [filename, node_name]):
			return false
		if node is CanvasItem and !_expect((node as CanvasItem).is_visible_in_tree(), "%s requires visible node %s" % [filename, node_name]):
			return false
	return _capture_image(filename)


func _capture_image(filename: String) -> bool:
	var image := get_root().get_texture().get_image()
	if !_expect(image != null, "could not capture %s: a rendered viewport is required" % filename):
		return false
	if !_expect(Vector2i(image.get_width(), image.get_height()) == capture_size, "%s has wrong dimensions: expected %s, got %dx%d" % [filename, capture_size, image.get_width(), image.get_height()]):
		return false
	if !_expect(_image_has_variation(image), "%s is blank or visually uniform" % filename):
		return false
	var result := image.save_png(OUT_DIR.path_join(filename))
	return _expect(result == OK, "could not save capture: %s" % filename)


func _image_has_variation(image: Image) -> bool:
	var reference := image.get_pixel(0, 0)
	var step_x := maxi(int(image.get_width() / 32.0), 1)
	var step_y := maxi(int(image.get_height() / 32.0), 1)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var color := image.get_pixel(x, y)
			var difference := absf(color.r - reference.r) + absf(color.g - reference.g) + absf(color.b - reference.b) + absf(color.a - reference.a)
			if difference > 0.08:
				return true
	return false


func _settle() -> void:
	await create_timer(0.25).timeout
	for _index in range(3):
		await process_frame


func _advance_tutorial(game, action: Callable, expected_step: int, action_name: String) -> bool:
	if !_expect(bool(action.call()), "tutorial capture action failed: %s" % action_name):
		return false
	return _expect(game.tutorial_step == expected_step, "tutorial capture action reached the wrong step: %s" % action_name)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	capture_failed = true
	push_error(message)
	return false


func _finish_capture_run(game) -> void:
	game.queue_free()
	await process_frame
	if !capture_failed:
		print("Ch09 graybox captures written to: " + OUT_DIR)
	quit(1 if capture_failed else 0)
