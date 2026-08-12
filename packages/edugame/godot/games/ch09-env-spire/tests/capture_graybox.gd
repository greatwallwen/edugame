extends SceneTree

const OUT_DIR_PROJECT_PATH := "res://../../../../../.superpowers/visual-qa/ch09-env-spire"
const DESKTOP_SIZE := Vector2i(1280, 720)
const CAPTURE_SAVE_PATH := "user://ch09_capture_run.json"
const CAPTURE_SETTINGS_PATH := "user://ch09_capture_settings.cfg"
const QUESTION_CAPTURE_CASES := [
	{
		"event_id": "basic_mq2_warmup",
		"question_type": "diagnosis",
		"desktop": "30-desktop-event-diagnosis.png",
	},
	{
		"event_id": "basic_signal_order",
		"question_type": "ordering",
		"desktop": "31-desktop-event-ordering.png",
	},
	{
		"event_id": "basic_i2c_result",
		"question_type": "code_trace",
		"desktop": "32-desktop-event-code-trace.png",
	},
	{
		"event_id": "basic_sample_period",
		"question_type": "parameter",
		"desktop": "33-desktop-event-parameter.png",
	},
	{
		"event_id": "basic_adc_spike",
		"question_type": "waveform",
		"desktop": "34-desktop-event-waveform.png",
	},
	{
		"event_id": "basic_raw_trusted",
		"question_type": "tradeoff",
		"desktop": "35-desktop-event-trade-off.png",
	}
]

var capture_failed := false
var capture_size := Vector2i.ZERO
var out_dir := ProjectSettings.globalize_path(OUT_DIR_PROJECT_PATH)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_clean_previous_captures()
	capture_size = DESKTOP_SIZE
	DisplayServer.window_set_size(capture_size)
	get_root().size = capture_size
	var scene := load("res://scenes/main.tscn")
	if !_expect(scene != null, "main scene should load"):
		quit(1)
		return

	var game = scene.instantiate()
	game.run_save_path = CAPTURE_SAVE_PATH
	game.settings_path = CAPTURE_SETTINGS_PATH
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(capture_size)
	await _settle()
	print("capture viewport=", get_root().size, " control=", game.size, " window=", DisplayServer.window_get_size())

	if !(await _capture_menu_and_codex(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_release_flow(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_tutorial(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_core_flow(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_combat_depth(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_boss_gate_gallery(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_encounter_gallery(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_question_events(game)):
		await _finish_capture_run(game)
		return
	if !(await _capture_node_lab(game)):
		await _finish_capture_run(game)
		return
	await _finish_capture_run(game)


func _clean_previous_captures() -> void:
	var output_dir := DirAccess.open(out_dir)
	if output_dir == null:
		return
	for file_name in output_dir.get_files():
		if file_name.get_extension().to_lower() == "png":
			output_dir.remove(file_name)


func _capture_menu_and_codex(game) -> bool:
	game.show_start_menu()
	if !(await _capture_checked(game, "00-desktop-start-menu.png", game.RunState.MENU, ["StartMenuView", "StartMenuRun", "StartMenuCodex"])):
		return false
	game.codex_progress = {"version": 1, "cards": [], "faults": []}
	if !_expect(game.select_start_menu_command("codex"), "codex capture should open from the menu"):
		return false
	if !(await _capture_checked(game, "01-desktop-codex-locked.png", game.RunState.CODEX, ["CodexView", "CodexDetailTitle", "CodexBack"])):
		return false
	var card_ids: Array = game.card_defs.keys()
	card_ids.sort()
	var fault_ids: Array = game.enemy_defs.keys()
	fault_ids.sort()
	game.codex_progress = {"version": 1, "cards": card_ids, "faults": fault_ids}
	game._refresh_codex()
	game.codex_view.select_tab("cards")
	game.codex_view.select_entry(0)
	if !(await _capture_checked(game, "02-desktop-codex-cards.png", game.RunState.CODEX, ["CodexDetailTitle", "CodexProgress"])):
		return false
	game.codex_view.select_tab("faults")
	game.codex_view.select_entry(0)
	if !(await _capture_checked(game, "03-desktop-codex-faults.png", game.RunState.CODEX, ["CodexDetailBody", "CodexProgress"])):
		return false
	return true


func _capture_tutorial(game) -> bool:
	game._start_tutorial_briefing()
	game._render_state()
	if !(await _capture_checked(
		game,
		"19-desktop-tutorial-briefing.png",
		game.RunState.WAITING,
		["TutorialView", "TutorialStartButton"],
		game.TutorialStep.BRIEFING
	)):
		return false

	game._start_tutorial_encounter()
	if !(await _capture_checked(
		game,
		"20-desktop-tutorial-intent.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "EnemyIntent"],
		game.TutorialStep.READ_INTENT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.confirm_tutorial_intent(), game.TutorialStep.PLAY_DEFENSE, "confirm intent"):
		return false
	if !(await _capture_checked(
		game,
		"21-desktop-tutorial-defense.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_DEFENSE
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.END_TURN, "play defense"):
		return false
	if !(await _capture_checked(
		game,
		"22-desktop-tutorial-end-turn.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "EndTurnButton"],
		game.TutorialStep.END_TURN
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.end_turn(), game.TutorialStep.PLAY_SAMPLE, "end turn"):
		return false
	if !(await _capture_checked(
		game,
		"23-desktop-tutorial-sample.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_SAMPLE
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_CONVERT, "play sample"):
		return false
	if !(await _capture_checked(
		game,
		"24-desktop-tutorial-convert.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_CONVERT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_OUTPUT, "play conversion"):
		return false
	if !(await _capture_checked(
		game,
		"25-desktop-tutorial-output.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialRequiredCard"],
		game.TutorialStep.PLAY_OUTPUT
	)):
		return false

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.COMPLETE, "play output"):
		return false
	return await _capture_checked(
		game,
		"26-desktop-tutorial-complete.png",
		game.RunState.COMBAT,
		["CombatView", "TutorialCoachLayer", "TutorialCompletionSummary"],
		game.TutorialStep.COMPLETE
	)


func _capture_release_flow(game) -> bool:
	game._reset_run()
	game.formal_run_active = true
	game.current_layer = 2
	game._save_run_now()
	game.show_start_menu()
	if !(await _capture_checked(game, "40-desktop-menu-resume.png", game.RunState.MENU, ["StartMenuResume", "StartMenuSettings"])):
		return false
	if !_expect(game.select_start_menu_command("settings"), "settings should open from the start menu"):
		return false
	if !(await _capture_checked(game, "41-desktop-settings.png", game.RunState.MENU, ["SettingsView", "SettingsSfxToggle", "SettingsAnimationSpeed", "SettingsReducedFlash"])):
		return false
	game._close_settings()
	if !_expect(game.select_start_menu_command("resume"), "resume should load the capture run"):
		return false
	game._open_run_menu()
	if !(await _capture_checked(game, "42-desktop-run-menu.png", game.RunState.MAP, ["RunMenuPanel", "RunMenuSaveReturn", "RunMenuAbandon"])):
		return false
	game._close_run_menu()
	var report_cases := [
		{"file": "43-desktop-report-victory.png", "victory": true, "tags": {"mq2": {"positive": 2, "errors": 0}}, "correct": 4, "total": 4, "weak": 40, "repair": 50, "review": []},
		{"file": "44-desktop-report-failure.png", "victory": false, "tags": {"i2c": {"positive": 0, "errors": 2}}, "correct": 1, "total": 3, "weak": 8, "repair": 30, "review": ["mq2_warmup"]},
		{"file": "45-desktop-report-mixed.png", "victory": true, "tags": {"adc": {"positive": 1, "errors": 0}, "filter": {"positive": 2, "errors": 1}}, "correct": 3, "total": 5, "weak": 24, "repair": 48, "review": ["adc_spike"]}
	]
	for raw_case in report_cases:
		var report_case := raw_case as Dictionary
		game.knowledge_stats = {
			"tags": report_case.get("tags", {}),
			"questionCorrect": report_case.get("correct", 0),
			"questionTotal": report_case.get("total", 0),
			"weaknessRepair": report_case.get("weak", 0),
			"totalRepair": report_case.get("repair", 0),
			"reviewFaultIds": report_case.get("review", [])
		}
		game.victory = bool(report_case.get("victory", false))
		game.completed = true
		game.score = 92 if game.victory else 38
		game.state = game.RunState.RESULT
		game._render_state()
		var required_nodes := ["RunResultHeading", "RunResultMetrics", "RunLearningSummary"]
		if !(report_case.get("review", []) as Array).is_empty():
			required_nodes.append("ResultReviewButton")
		if !(await _capture_checked(game, str(report_case.get("file", "")), game.RunState.RESULT, required_nodes)):
			return false
	return true


func _capture_core_flow(game) -> bool:
	game._reset_run()
	game._render_state()
	if !(await _capture_checked(
		game,
		"01-desktop-map.png",
		game.RunState.MAP,
		["MapView", "MapRoute", "MapEnterButton"]
	)):
		return false
	game.current_layer = 6
	game.map_energy_overlay.call("set_layer_immediate", 6)
	game._render_state()
	if !(await _capture_checked(
		game,
		"01a-desktop-map-charged-six.png",
		game.RunState.MAP,
		["MapView", "MapEnergyOverlay", "MapStep07"]
	)):
		return false
	game.map_energy_overlay.call("set_layer_immediate", 0)
	game.current_layer = 1
	var original_motion_scale: float = game.motion_duration_scale
	game.motion_duration_scale = 2.0
	game._render_state()
	game._animate_map_charge_entry(1)
	await create_timer(0.28).timeout
	await process_frame
	if !_expect(bool(game.map_charge_snapshot().get("active", false)), "mid-charge capture should occur while the floor pulse is moving"):
		return false
	if !_capture_image("01b-desktop-map-charge-pulse.png"):
		return false
	await create_timer(0.65).timeout
	game.motion_duration_scale = original_motion_scale
	game.current_layer = 0
	game.map_energy_overlay.call("set_layer_immediate", 0)
	game._render_state()

	if !_expect(game.choose_node(0), "normal combat capture should enter route node 1"):
		return false
	game._render_state()
	if !(await _capture_checked(
		game,
		"02-desktop-combat.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "EngineeringChainStrip", "HandRow", "EndTurnButton"]
	)):
		return false

	game.encounter_evidence_tags.clear()
	for raw_group in game.current_encounter.get("evidenceGroups", []) as Array:
		var group := raw_group as Array
		if !group.is_empty():
			game.encounter_evidence_tags[str(group[0])] = true
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._render_state()
	if !_expect(game.state == game.RunState.REWARD, "completed combat should reach reward state"):
		return false
	if !(await _capture_checked(
		game,
		"03-desktop-reward.png",
		game.RunState.REWARD,
		["ChoiceView", "RewardCards", "RewardSkipButton"]
	)):
		return false

	game.current_node = {"type": "service", "label": "工程整备室"}
	game.current_layer = 9
	game.state = game.RunState.REST
	game._render_state()
	if !(await _capture_checked(
		game,
		"04-desktop-service-room.png",
		game.RunState.REST,
		["ChoiceView", "ServiceBench", "ChoiceList"]
	)):
		return false

	if !_expect(game.choose_service("add"), "service capture should open card supply selection"):
		return false
	game._render_state()
	if !(await _capture_checked(
		game,
		"05-desktop-service-card-selection.png",
		game.RunState.REST,
		["CardSelectionModal", "CardSelectionOptions"]
	)):
		return false
	if !_expect(game.choose_pending_card(0), "service capture should resolve the selected card"):
		return false

	game.current_node = {"type": "checkpoint_sensor", "contentId": "sensor_checkpoint"}
	game._start_checkpoint(true)
	game._render_state()
	if !(await _capture_checked(
		game,
		"06-desktop-checkpoint-sensor.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "HandRow"]
	)):
		return false

	game.current_node = {"type": "checkpoint_trust", "contentId": "trust_checkpoint"}
	game._start_checkpoint(false)
	game._render_state()
	if !(await _capture_checked(
		game,
		"07-desktop-checkpoint-trust.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "HandRow"]
	)):
		return false

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game._render_state()
	if !(await _capture_checked(
		game,
		"08-desktop-boss-phase-1.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton", "BossPhaseOverlay"]
	)):
		return false
	game.boss_phase = 1
	game._apply_boss_phase()
	game._announce_boss_phase()
	game._render_state()
	if !_expect(game.boss_phase == 1, "Boss phase 2 capture should retain phase index 1"):
		return false
	if !(await _capture_checked(
		game,
		"09-desktop-boss-phase-2.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton", "BossPhaseOverlay"]
	)):
		return false
	game.boss_phase = 2
	game._apply_boss_phase()
	game._announce_boss_phase()
	game._render_state()
	if !_expect(game.boss_phase == 2, "Boss phase 3 capture should retain phase index 2"):
		return false
	if !(await _capture_checked(
		game,
		"10-desktop-boss-phase-3.png",
		game.RunState.COMBAT,
		["CombatView", "EncounterArena", "EndTurnButton", "BossPhaseOverlay"]
	)):
		return false

	game.current_layer = 12
	game.checkpoints_passed = 2
	game._finish_run(true)
	game._render_state()
	if !(await _capture_checked(
		game,
		"11-desktop-result.png",
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
		"15-desktop-event.png",
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
		"16-desktop-component.png",
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
		"17-desktop-service-node-11.png",
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
		"18-desktop-reward-fallback.png",
		game.RunState.REWARD,
		["ChoiceView", "RewardSkipButton"]
	)


func _capture_combat_depth(game) -> bool:
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
		"27-desktop-reroute-selection.png",
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
		"28-desktop-fault-triggered.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "FaultRuleRow", "FaultCounterRow", "FaultRuleState", "CombatFeedbackBanner"]
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
		"29-desktop-fault-suppressed.png",
		game.RunState.COMBAT,
		["CombatView", "FaultIntentRow", "FaultRuleRow", "FaultCounterRow", "FaultRuleState", "CombatFeedbackBanner"]
	)


func _capture_encounter_gallery(game) -> bool:
	var encounters := [
		{"id": "mq2_warmup", "tier": "ordinary", "filename": "60-desktop-fault-mq2.png"},
		{"id": "bh1750_stale", "tier": "ordinary", "filename": "61-desktop-fault-bh1750.png"},
		{"id": "adc_spike", "tier": "ordinary", "filename": "62-desktop-fault-adc.png"},
		{"id": "lcd_blocking", "tier": "ordinary", "filename": "63-desktop-fault-lcd.png"},
		{"id": "alarm_jitter", "tier": "ordinary", "filename": "64-desktop-fault-alarm.png"},
		{"id": "i2c_congestion", "tier": "elite", "filename": "65-desktop-fault-i2c.png"},
		{"id": "mq2_baseline_drift", "tier": "ordinary", "filename": "70-desktop-fault-mq2-baseline.png"},
		{"id": "bh1750_early_read", "tier": "ordinary", "filename": "71-desktop-fault-bh1750-early.png"},
		{"id": "hdc1080_conversion_wait", "tier": "ordinary", "filename": "72-desktop-fault-hdc1080-wait.png"},
		{"id": "i2c_address_collision", "tier": "ordinary", "filename": "73-desktop-fault-address-collision.png"},
		{"id": "uart_frame_overrun", "tier": "ordinary", "filename": "74-desktop-fault-uart-overrun.png"},
		{"id": "multi_sensor_race", "tier": "elite", "filename": "75-desktop-fault-sensor-race.png"},
		{"id": "display_bus_deadlock", "tier": "elite", "filename": "76-desktop-fault-display-deadlock.png"},
	]
	for raw_encounter in encounters:
		var encounter := raw_encounter as Dictionary
		var encounter_id := str(encounter.get("id", ""))
		var tier := str(encounter.get("tier", "ordinary"))
		game._reset_run()
		game.current_node = {"type": tier, "contentId": encounter_id}
		game._start_encounter(encounter_id, tier)
		game._render_state()
		if !(await _capture_checked(
			game,
			str(encounter.get("filename", "")),
			game.RunState.COMBAT,
			["CombatView", "DeviceTelemetryVisual", "EvidenceSignalVisual", "FaultCoreVisual"]
		)):
			return false

	game._reset_run()
	game.relics = ["trace_probe"]
	game._activate_relic("trace_probe")
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("logic_probe")]
	game.processing_points = 3
	if !_expect(game.play_card(0), "component capture should play its diagnosis card"):
		return false
	await process_frame
	for _wait_index in range(360):
		if !game.pending_card_selection.is_empty():
			game.choose_pending_card(0)
		if !game._card_actions_pending():
			break
		await process_frame
	if !_expect(game.block == 5, "component capture should apply trace-probe block"):
		return false
	var component_feedback_found := false
	for raw_event in game.combat_feedback_snapshot():
		if str((raw_event as Dictionary).get("kind", "")) == "component":
			component_feedback_found = true
	if !_expect(component_feedback_found, "component capture should record component feedback"):
		return false
	game._render_state()
	game.clear_combat_feedback_history()
	game._emit_component_feedback("总线追踪探头", "首张诊断牌：获得 5 防护")
	for _fade_frame in range(10):
		await process_frame
	if !_expect(game.combat_feedback_banner.is_visible_in_tree(), "component capture should render its feedback banner"):
		return false
	if !_capture_image("77-desktop-component-trigger.png"):
		return false

	game._reset_run()
	game.current_node = {"type": "ordinary", "contentId": "adc_spike"}
	game._start_encounter("adc_spike", "ordinary")
	var condition_cases := [
		{"ratio": 0.0, "condition": "unstable", "filename": "66-desktop-fault-condition-unstable.png"},
		{"ratio": 0.40, "condition": "isolated", "filename": "67-desktop-fault-condition-isolated.png"},
		{"ratio": 0.72, "condition": "stabilizing", "filename": "68-desktop-fault-condition-stabilizing.png"},
		{"ratio": 1.0, "condition": "restored", "filename": "69-desktop-fault-condition-restored.png"}
	]
	for raw_case in condition_cases:
		var condition_case := raw_case as Dictionary
		game.repair_progress = int(round(float(game.repair_target) * float(condition_case.get("ratio", 0.0))))
		game._render_state()
		var fault_visual = game.find_child("FaultCoreVisual", true, false)
		if !_expect(fault_visual != null and fault_visual.fault_condition() == str(condition_case.get("condition", "")), "%s capture should bind the expected repair condition" % condition_case.get("condition", "")):
			return false
		if !(await _capture_checked(
			game,
			str(condition_case.get("filename", "")),
			game.RunState.COMBAT,
			["CombatView", "DeviceTelemetryVisual", "EvidenceSignalVisual", "FaultCoreVisual"]
		)):
			return false
	return true


func _capture_boss_gate_gallery(game) -> bool:
	var gates := [
		{"id": "two_sources", "phase": 0},
		{"id": "three_sources", "phase": 0},
		{"id": "trusted_and_filter", "phase": 1},
		{"id": "trusted_and_calibration", "phase": 1},
		{"id": "two_output_types", "phase": 2},
		{"id": "acceptance_output", "phase": 2}
	]
	for raw_gate in gates:
		var gate := raw_gate as Dictionary
		var gate_id := str(gate.get("id", ""))
		if !_expect(game.start_lab_scenario({
			"id": "capture_%s" % gate_id,
			"kind": "boss_gate",
			"contentId": "warehouse_acceptance",
			"tier": "boss",
			"phase": int(gate.get("phase", 0)),
			"gateId": gate_id
		}, "coverage"), "Boss gate capture should launch %s" % gate_id):
			return false
		game._render_state()
		if !(await _capture_checked(
			game,
			"boss-gate-%s.png" % gate_id,
			game.RunState.COMBAT,
			["CombatView", "GateLabel", "FaultCoreVisual"]
		)):
			return false
	return true


func _capture_question_events(game) -> bool:
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
		var filename := str(capture_case.get("desktop", ""))
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
		"36-desktop-event-correct-reward.png",
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
		"37-desktop-event-wrong-penalty.png",
		game.RunState.EVENT,
		["ChoiceView", "QuestionExplanation", "QuestionConsequence", "QuestionContinue"]
	)


func _capture_node_lab(game) -> bool:
	game._enter_node_lab()
	await _settle()
	var legacy_catalog_filename := "12-desktop-node-lab.png"
	var event_catalog_filename := "38-desktop-node-lab-event-catalog.png"
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
		legacy_catalog_filename,
		game.RunState.WAITING,
		["NodeLabRoot", "NodeLabToolbar", "NodeLabCatalog"]
	)):
		return false
	var event_button := game.find_child("NodeLabScenario_basic_mq2_warmup", true, false) as Control
	if !_expect(event_button != null, "Node Lab event catalog capture should find basic_mq2_warmup"):
		return false
	var catalog_scroll: ScrollContainer = null
	var ancestor := event_button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			catalog_scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	if !_expect(catalog_scroll != null, "Node Lab event catalog capture should find the catalog viewport"):
		return false
	catalog_scroll.ensure_control_visible(event_button)
	await _settle()
	var event_rect := event_button.get_global_rect()
	var catalog_viewport_rect := catalog_scroll.get_global_rect()
	if !_expect(event_rect.intersects(catalog_viewport_rect), "Node Lab basic_mq2_warmup should intersect the catalog viewport"):
		return false
	var event_visible_rect := event_rect.intersection(catalog_viewport_rect)
	var toolbar := game.find_child("NodeLabToolbar", true, false) as Control
	if !_expect(toolbar != null and event_visible_rect.position.y >= toolbar.get_global_rect().end.y, "Node Lab basic_mq2_warmup visible rect should stay below the toolbar"):
		return false
	if !(await _capture_checked(
		game,
		event_catalog_filename,
		game.RunState.WAITING,
		["NodeLabRoot", "NodeLabToolbar", "NodeLabCatalog"]
	)):
		return false
	if !_expect_capture_files_differ(event_catalog_filename, legacy_catalog_filename):
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
		"13-desktop-node-lab-event.png",
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
	if !(await _capture_checked(
		game,
		"14-desktop-node-lab-combat.png",
		game.RunState.COMBAT,
		["NodeLabToolbar", "NodeLabReturn", "CombatView", "EncounterArena", "HandRow"]
	)):
		return false
	if !_expect(game.lab_add_card_to_hand("logic_probe"), "Node Lab debug capture should inject a selected card"):
		return false
	if !_expect(game.lab_set_stability(23), "Node Lab debug capture should set stability"):
		return false
	if !_expect(game.lab_set_fault_remaining(6), "Node Lab debug capture should set remaining fault value"):
		return false
	game.node_lab_overlay.show_debug_panel()
	game.node_lab_overlay.refresh_debug_panel()
	return await _capture_checked(
		game,
		"39-desktop-node-lab-debug.png",
		game.RunState.COMBAT,
		[
			"NodeLabDebugPanel",
			"NodeLabCardSelector",
			"NodeLabStabilityInput",
			"NodeLabFaultRemainingInput",
			"NodeLabHandList"
		]
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
	var result := image.save_png(out_dir.path_join(filename))
	return _expect(result == OK, "could not save capture: %s" % filename)


func _expect_capture_files_differ(filename: String, reference_filename: String) -> bool:
	var capture_path := out_dir.path_join(filename)
	var reference_path := out_dir.path_join(reference_filename)
	if !_expect(FileAccess.file_exists(capture_path), "capture comparison is missing %s" % filename):
		return false
	if !_expect(FileAccess.file_exists(reference_path), "capture comparison is missing %s" % reference_filename):
		return false
	var capture_bytes := FileAccess.get_file_as_bytes(capture_path)
	var reference_bytes := FileAccess.get_file_as_bytes(reference_path)
	return _expect(capture_bytes != reference_bytes, "%s should differ from %s" % [filename, reference_filename])


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
	for path in [CAPTURE_SAVE_PATH, CAPTURE_SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	if !capture_failed:
		print("Ch09 graybox captures written to: " + out_dir)
	quit(1 if capture_failed else 0)
