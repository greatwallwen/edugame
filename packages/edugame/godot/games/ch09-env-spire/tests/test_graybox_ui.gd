extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_viewport(Vector2i(1280, 720))
	await _verify_viewport(Vector2i(390, 844))
	await _verify_live_resize()
	_finish()


func _verify_live_resize() -> void:
	var desktop_size := Vector2i(1280, 720)
	var mobile_size := Vector2i(390, 844)
	DisplayServer.window_set_size(desktop_size)
	get_root().size = desktop_size
	await process_frame
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(desktop_size)
	await process_frame
	await process_frame
	game._start_tutorial_briefing()
	game._start_tutorial_encounter()
	_assert(game.confirm_tutorial_intent(), "live resize setup should reach the guided defense step")
	await process_frame
	var tutorial_step_before_resize = game.tutorial_step

	DisplayServer.window_set_size(mobile_size)
	get_root().size = mobile_size
	game.size = Vector2(mobile_size)
	await process_frame
	await process_frame
	var hand_row = game.find_child("HandRow", true, false)
	var end_turn = game.find_child("EndTurnButton", true, false)
	var footer = game.get_node_or_null("Shell/RunFooter")
	var required_card = game.find_child("TutorialRequiredCard", true, false) as Control
	_assert(hand_row != null and hand_row.get_child_count() > 0, "live resize should retain the rendered hand")
	_assert(game.tutorial_step == tutorial_step_before_resize, "live resize should preserve the tutorial step")
	_assert(required_card != null, "live resize should retain the active tutorial card target")
	if required_card != null:
		_assert(Rect2(Vector2.ZERO, Vector2(mobile_size)).encloses(required_card.get_global_rect()), "live resize should keep the active tutorial card inside the viewport")
	if hand_row != null and hand_row.get_child_count() > 0:
		_assert((hand_row.get_child(0) as Control).custom_minimum_size.y <= 200.0, "live resize should compact existing cards")
	if end_turn != null and footer != null:
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "live resize should keep combat actions above the footer")
	_assert_tutorial_bounds(game, Rect2(Vector2.ZERO, Vector2(mobile_size)), footer, "sliding_average", "live resize defense")
	game.queue_free()
	await process_frame


func _verify_viewport(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	get_root().size = size
	await process_frame
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(size)
	await process_frame
	await process_frame

	var header = game.get_node_or_null("Shell/RunHud")
	var map_view = game.get_node_or_null("Shell/SceneStage/MapView")
	var combat_view = game.get_node_or_null("Shell/SceneStage/CombatView")
	var choice_view = game.get_node_or_null("Shell/SceneStage/ChoiceView")
	var result_view = game.get_node_or_null("Shell/SceneStage/ResultView")
	var footer = game.get_node_or_null("Shell/RunFooter")
	var run_hud = game.find_child("RunHud", true, false)
	var scene_stage = game.find_child("SceneStage", true, false)
	var run_footer = game.find_child("RunFooter", true, false)
	var hand_row = game.find_child("HandRow", true, false)
	var end_turn = game.find_child("EndTurnButton", true, false)
	var log_label = game.get_node_or_null("Shell/RunFooter/LogLabel")
	var repair_bar = game.find_child("RepairBar", true, false)
	var map_composition = game.find_child("MapComposition", true, false)
	var map_route_scroll = game.find_child("MapRouteScroll", true, false)
	var map_route = game.find_child("MapRoute", true, false)
	var map_enter = game.find_child("MapEnterButton", true, false)
	var mission_summary = game.find_child("MapMissionSummary", true, false)
	var next_detail = game.find_child("MapNextDetail", true, false)
	var choice_list = game.find_child("ChoiceList", true, false)
	var choice_scroll = game.find_child("ChoiceScroll", true, false) as ScrollContainer
	var choice_description = game.find_child("ChoiceDescription", true, false)
	var gate_label = game.find_child("GateLabel", true, false)
	var restart_button = game.find_child("RestartButton", true, false)
	var arena = game.find_child("EncounterArena", true, false)
	var device_unit = game.find_child("DeviceUnit", true, false)
	var evidence_bridge = game.find_child("EvidenceBridge", true, false)
	var fault_unit = game.find_child("FaultUnit", true, false)
	var enemy_intent = game.find_child("EnemyIntent", true, false)
	var fault_intent_row = game.find_child("FaultIntentRow", true, false) as Label
	var fault_rule_row = game.find_child("FaultRuleRow", true, false) as Label
	var fault_counter_row = game.find_child("FaultCounterRow", true, false) as Label
	var fault_rule_state = game.find_child("FaultRuleState", true, false) as Label
	var hand_dock = game.find_child("HandDock", true, false)
	var hand_scroll = game.find_child("HandScroll", true, false) as Control
	var combat_actions = game.find_child("CombatActions", true, false) as Control
	var point_counter = game.find_child("ProcessingPointCounter", true, false)
	var chain_strip = game.find_child("EngineeringChainStrip", true, false) as Control
	var chain_collect = game.find_child("ChainCollect", true, false) as Control
	var chain_interface = game.find_child("ChainInterface", true, false) as Control
	var chain_process = game.find_child("ChainProcess", true, false) as Control
	var chain_output = game.find_child("ChainOutput", true, false) as Control
	var chain_current_status = game.find_child("ChainCurrentStatus", true, false) as Label
	var chain_next_status = game.find_child("ChainNextStatus", true, false) as Label
	var chain_reward_status = game.find_child("ChainRewardStatus", true, false) as Label
	var reroute_button = game.find_child("RerouteButton", true, false) as Button
	var reroute_cancel_button = game.find_child("RerouteCancelButton", true, false) as Button
	var reward_cards = game.find_child("RewardCards", true, false)
	var reward_skip = game.find_child("RewardSkipButton", true, false)
	var tutorial_view = game.find_child("TutorialView", true, false)
	var tutorial_route = game.find_child("TutorialRouteSummary", true, false)
	var tutorial_start = game.find_child("TutorialStartButton", true, false)
	var tutorial_coach = game.find_child("TutorialCoachLayer", true, false)
	var tutorial_text = game.find_child("TutorialCoachText", true, false)
	var tutorial_skip = game.find_child("TutorialSkipButton", true, false)
	var tutorial_intent = game.find_child("TutorialIntentButton", true, false)
	var tutorial_data_values = game.find_child("TutorialDataValues", true, false)
	var question_frame = game.find_child("QuestionEventFrame", true, false) as Control
	var question_tag = game.find_child("QuestionKnowledgeTag", true, false) as Label
	var question_prompt = game.find_child("QuestionPrompt", true, false) as Label
	var question_interaction = game.find_child("QuestionInteraction", true, false) as Control
	var question_submit = game.find_child("QuestionSubmit", true, false) as Button
	var question_explanation = game.find_child("QuestionExplanation", true, false) as Label
	var question_consequence = game.find_child("QuestionConsequence", true, false) as Control
	var question_continue = game.find_child("QuestionContinue", true, false) as Button
	game._start_clean_formal_run()
	await process_frame

	_assert(header != null, "header should exist at %s" % size)
	_assert(map_view != null and combat_view != null and choice_view != null and result_view != null, "all state views should exist")
	_assert(run_hud != null, "normal flow should expose a stable RunHud")
	_assert(scene_stage != null, "normal flow should expose a stable SceneStage")
	_assert(run_footer != null, "normal flow should expose a stable RunFooter")
	_assert(run_hud.theme == game.ui_theme, "RunHud should use the bundled UI theme")
	_assert(hand_row != null and end_turn != null and log_label != null and repair_bar != null, "combat controls, repair progress, and log should exist")
	_assert(choice_list != null, "choice states should expose a stable choice grid")
	_assert(choice_scroll != null, "choice states should expose a stable vertical scroll container")
	_assert(gate_label != null and restart_button != null, "boss gate and result action should expose stable controls")
	_assert(arena != null, "combat should expose an encounter arena")
	_assert(device_unit != null and evidence_bridge != null and fault_unit != null, "combat should render device, evidence, and fault zones")
	_assert(enemy_intent != null, "fault intent should have a stable visual anchor")
	_assert(hand_dock != null and point_counter != null, "combat should expose a fixed action dock")
	_assert(chain_strip != null and chain_collect != null and chain_interface != null and chain_process != null and chain_output != null, "combat should expose stable engineering-chain anchors")
	_assert(reroute_button != null and reroute_cancel_button != null, "combat should expose stable reroute controls")
	_assert(map_route != null and map_route.get_child_count() == 12, "map climb should render twelve route nodes")
	_assert(map_enter != null and map_enter.custom_minimum_size.y >= 44.0, "map enter should be a full touch target")
	_assert(mission_summary != null and next_detail != null, "map should expose mission and next-node context")
	_assert(map_composition != null and map_route_scroll != null, "map should expose its responsive route composition")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
	_assert(tutorial_view != null, "tutorial should expose a dedicated scene view")
	_assert(tutorial_route != null, "tutorial briefing should explain the route")
	_assert(tutorial_start != null, "tutorial briefing should expose its start command")
	_assert(tutorial_coach != null and tutorial_text != null, "tutorial should expose coach guidance")
	_assert(tutorial_skip != null, "tutorial skip should remain available")
	_assert(tutorial_intent != null, "tutorial intent should be an actionable target")
	_assert(tutorial_data_values != null, "tutorial should expose the data values that receive guided focus")
	_assert(
		question_frame != null and question_tag != null and question_prompt != null and question_interaction != null
		and question_submit != null and question_explanation != null and question_consequence != null and question_continue != null,
		"question events should expose all stable UI anchors"
	)

	game._start_tutorial_briefing()
	game._render_state()
	await process_frame
	_assert(tutorial_view.visible, "tutorial briefing should be visible when active")
	_assert(viewport_rect.encloses(tutorial_start.get_global_rect()), "tutorial start should fit the viewport")
	_assert(viewport_rect.encloses(tutorial_skip.get_global_rect()), "tutorial skip should fit the viewport")
	_assert(tutorial_start.custom_minimum_size.y >= 44.0, "tutorial start should be a touch target")
	_assert_tutorial_bounds(game, viewport_rect, footer, "", "briefing")

	game._start_tutorial_encounter()
	await process_frame
	for fault_row in [fault_intent_row, fault_rule_row, fault_counter_row, fault_rule_state]:
		_assert(fault_row != null and !fault_row.is_visible_in_tree(), "%s should stay hidden during tutorial combat at %s" % [fault_row.name if fault_row != null else "fault row", size])
	if reroute_button != null:
		_assert(!reroute_button.visible and reroute_button.disabled, "tutorial practice should hide and disable reroute")
	if reroute_cancel_button != null:
		_assert(!reroute_cancel_button.visible and reroute_cancel_button.disabled, "tutorial practice should hide and disable reroute cancellation")
	_assert_tutorial_bounds(game, viewport_rect, footer, "", "intent")
	_assert_tutorial_focus(enemy_intent as Control, "intent step should strongly focus the actual fault intent")
	_assert(game.confirm_tutorial_intent(), "tutorial intent should advance to guided defense")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "sliding_average", "defense")
	_assert(game.play_card(0), "tutorial defense should be playable for layout verification")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "", "end turn")
	_assert_tutorial_focus(end_turn as Control, "end-turn step should strongly focus the end-turn target")
	_assert(game.end_turn(), "tutorial end turn should advance to data-chain practice")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "mq2_sample", "sample")
	_assert(game.play_card(0), "tutorial sample should be playable for layout verification")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "adc_convert", "convert")
	_assert_tutorial_focus(tutorial_data_values as Control, "conversion step should strongly focus the changed raw data")
	_assert(game.play_card(0), "tutorial conversion should be playable for layout verification")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "led_alarm", "output")
	_assert_tutorial_focus(tutorial_data_values as Control, "output step should strongly focus the changed trusted data")
	_assert(game.play_card(0), "tutorial output should be playable for layout verification")
	await process_frame
	_assert_tutorial_bounds(game, viewport_rect, footer, "", "complete")
	_assert_tutorial_focus(evidence_bridge as Control, "completion should strongly focus the resolved evidence values")
	var completion_summary := game.find_child("TutorialCompletionSummary", true, false) as Label
	_assert(completion_summary != null and completion_summary.is_visible_in_tree(), "completion should expose its full loop summary")
	if completion_summary != null:
		_assert(completion_summary.has_method("get_visible_line_count"), "completion summary should expose visible-line layout for responsive verification")
		if completion_summary.has_method("get_visible_line_count"):
			var required_completion_lines := 4 if size.x < 720 else 3
			_assert(int(completion_summary.call("get_visible_line_count")) >= required_completion_lines, "completion summary should show the wrapped loop, node, and LED notes without clipping")
	game._start_clean_formal_run()
	await process_frame
	_assert(viewport_rect.encloses(run_hud.get_global_rect()), "RunHud should stay in the viewport")
	_assert(viewport_rect.intersects(map_enter.get_global_rect()), "Available map action should remain visible")
	_assert_visible_primary_command_heights(game)
	if size.x < 720 and map_composition != null and map_route_scroll != null:
		_assert(map_composition.vertical, "compact map composition should stack vertically")
		_assert(!mission_summary.visible, "compact map should hide the mission summary")
		_assert(next_detail.get_global_rect().position.y >= map_route_scroll.get_global_rect().end.y, "compact next-node detail should follow the route")
		for marker in map_route.get_children():
			_assert((marker as Control).custom_minimum_size.y >= 44.0, "compact route markers should be full touch targets")
	if header != null:
		_assert(header.theme != null and header.theme.default_font != null, "bundled Chinese font should be installed")
		_assert(game.ui_font.resource_path == game.UI_FONT_PATH, "UI font should use the imported resource for Web export")
		_assert(game.ui_font.has_char("选".unicode_at(0)), "UI font should contain Chinese glyphs")
	_assert(map_view != null and map_view.visible, "map view should be visible after reset")
	_assert(combat_view != null and !combat_view.visible, "combat view should be hidden on map")
	if map_route != null and map_route.get_child_count() == 12:
		var next_marker := map_route.get_child(0) as Button
		var hidden_third_marker := map_route.get_child(2) as Button
		var hidden_fourth_marker := map_route.get_child(3) as Button
		_assert(!next_marker.disabled and next_marker.text.contains("MQ-2 预热不足"), "the accessible next node should retain its map label")
		_assert(hidden_third_marker.visible and hidden_fourth_marker.visible, "future route nodes should remain visibly present")
		_assert(
			hidden_third_marker.text.contains("未揭示")
			and !hidden_third_marker.text.contains("BH1750 读数停留")
			and hidden_fourth_marker.text.contains("未揭示")
			and !hidden_fourth_marker.text.contains("阶段维护"),
			"future route nodes should conceal their labels and details by default"
		)
		game._begin_question_event((game.event_defs.get("basic_adc_spike", {}) as Dictionary).duplicate(true))
		_assert(game.submit_event_answer("spike_noise"), "map reveal UI setup should accept the answer ID")
		_assert(game.choose_event_reward(1), "map reveal UI setup should apply the node reward")
		_assert(game.continue_event(), "map reveal UI setup should return to the route")
		game._render_state()
		await process_frame
		_assert(map_route.get_child_count() == 12, "revealing content should preserve the single twelve-node route")
		hidden_third_marker = map_route.get_child(2) as Button
		hidden_fourth_marker = map_route.get_child(3) as Button
		_assert(hidden_third_marker.text.contains("BH1750 读数停留") and hidden_third_marker.text.contains("普通故障"), "revealed node 3 should show its label and type details")
		_assert(hidden_fourth_marker.text.contains("阶段维护") and hidden_fourth_marker.text.contains("整备"), "revealed node 4 should show its label and type details")
	game.current_layer = 10
	game._render_state()
	await process_frame
	await process_frame
	if map_route != null and map_route.get_child_count() == 12:
		_assert((map_route.get_child(10) as Button).text.contains("整备"), "node 11 should render the service label")
		if size.x < 720 and map_route_scroll != null:
			var route_view: Rect2 = map_route_scroll.get_global_rect()
			for marker_index in [9, 10, 11]:
				var marker_rect: Rect2 = (map_route.get_child(marker_index) as Control).get_global_rect()
				_assert(marker_rect.position.y >= route_view.position.y and marker_rect.end.y <= route_view.end.y, "compact route should reveal the available node and neighboring node %d" % (marker_index + 1))
	game.current_layer = 11
	game._render_state()
	await process_frame
	if map_route != null and map_route.get_child_count() == 12:
		var boss_marker := map_route.get_child(11) as Button
		_assert(boss_marker.text.contains("综合验收"), "node 12 should render the boss label")
		var boss_style := boss_marker.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(boss_style != null and boss_style.border_color.is_equal_approx(Color("#725c91")), "available Boss should retain violet styling")
	game.current_layer = 0
	game._render_state()
	await process_frame

	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()
	await process_frame
	_assert(combat_view.visible and !map_view.visible, "combat state should show only combat view")
	_assert(hand_row.get_child_count() == game.hand.size(), "hand row should render one button per card")
	_assert(fault_intent_row != null and fault_rule_row != null and fault_counter_row != null and fault_rule_state != null, "combat should expose stable fault-rule labels")
	if fault_intent_row != null and fault_rule_row != null and fault_counter_row != null and fault_rule_state != null:
		var fault_rows := [fault_intent_row, fault_rule_row, fault_counter_row, fault_rule_state]
		for row in fault_rows:
			_assert(row.is_visible_in_tree() and !row.text.is_empty(), "%s should have readable non-empty fault text at %s" % [row.name, size])
		for index in range(fault_rows.size()):
			for other_index in range(index + 1, fault_rows.size()):
				_assert(!(fault_rows[index] as Control).get_global_rect().intersects((fault_rows[other_index] as Control).get_global_rect()), "%s and %s should not overlap at %s" % [fault_rows[index].name, fault_rows[other_index].name, size])
		if fault_unit != null:
			var fault_panel_rect := (fault_unit as Control).get_global_rect().grow(0.5)
			for row in [fault_intent_row, fault_rule_row, fault_counter_row]:
				_assert(fault_panel_rect.encloses(row.get_global_rect()), "%s should fit inside the fault panel at %s" % [row.name, size])
	game.chain_count = 0
	game.last_stage = "collect"
	game.chain_rewards_claimed.clear()
	game.hand = [
		game._card_copy("adc_convert"),
		{
			"id": "neutral_preview",
			"name": "Neutral preview",
			"type": "utility",
			"cost": 0,
			"stage": "",
			"tags": [],
			"effectText": "Preview only",
			"effects": []
		},
		game._card_copy("uart_log")
	]
	game._render_state()
	await process_frame
	if point_counter != null:
		_assert(point_counter.text.contains(str(game.processing_points)), "processing point counter should render the live point total")
	if arena != null and hand_dock != null:
		_assert(hand_dock.get_global_rect().position.y >= arena.get_global_rect().end.y, "hand dock should remain below the encounter arena at %s" % size)
	if footer != null and hand_dock != null:
		_assert(hand_dock.get_global_rect().end.y <= footer.get_global_rect().position.y, "hand dock should remain above the footer at %s: dock=%s footer=%s" % [size, hand_dock.get_global_rect(), footer.get_global_rect()])
	if size == Vector2i(1280, 720) and arena != null and hand_dock != null and run_hud != null and run_footer != null:
		var playable_height: float = run_footer.get_global_rect().position.y - run_hud.get_global_rect().end.y
		var dock_proportion: float = hand_dock.size.y / playable_height
		_assert(dock_proportion >= 0.27 and dock_proportion <= 0.33, "desktop hand dock should use approximately 30%% of playable height, got %.1f%%" % (dock_proportion * 100.0))
		_assert(arena.size.y > hand_dock.size.y, "desktop encounter arena should be taller than the hand dock")
	if size.x < 720 and fault_unit != null and evidence_bridge != null and device_unit != null:
		_assert(fault_unit.get_global_rect().position.y <= evidence_bridge.get_global_rect().position.y and evidence_bridge.get_global_rect().position.y <= device_unit.get_global_rect().position.y, "compact arena should stack fault, evidence, then device")
	elif size.x >= 720 and device_unit != null and evidence_bridge != null and fault_unit != null:
		_assert(device_unit.get_global_rect().position.x <= evidence_bridge.get_global_rect().position.x and evidence_bridge.get_global_rect().position.x <= fault_unit.get_global_rect().position.x, "desktop arena should order device, evidence, then fault")
		if enemy_intent != null:
			_assert(enemy_intent.get_global_rect().end.y <= game.encounter_name_label.get_global_rect().position.y, "desktop enemy intent should sit above the fault details")
	if hand_row.get_child_count() > 0:
		var minimum_card_height := 180.0 if size.x < 720 else 112.0
		_assert((hand_row.get_child(0) as Control).custom_minimum_size.y >= minimum_card_height, "cards should use the available work area")
	if !viewport_rect.encloses(end_turn.get_global_rect()):
		print("END_TURN_RECT %s VIEWPORT %s" % [end_turn.get_global_rect(), viewport_rect])
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "end turn button should stay inside viewport at %s" % size)
	_assert(end_turn.custom_minimum_size.y >= 44.0, "primary touch target should be at least 44 px high")
	_assert(end_turn.get_global_rect().end.y <= run_footer.get_global_rect().position.y, "End turn should stay above the footer")
	if chain_strip != null and chain_collect != null and chain_interface != null and chain_process != null and chain_output != null:
		_assert(chain_strip.is_visible_in_tree(), "engineering-chain strip should stay visible at %s" % size)
		_assert(chain_collect.is_visible_in_tree() and chain_interface.is_visible_in_tree() and chain_process.is_visible_in_tree() and chain_output.is_visible_in_tree(), "engineering-chain stages should stay visible at %s" % size)
		_assert(chain_current_status != null and chain_current_status.text.contains("collect"), "chain strip should show the current stage at %s" % size)
		_assert(chain_next_status != null and chain_next_status.text.contains("interface"), "chain strip should show the next stage at %s" % size)
		_assert(chain_reward_status != null and chain_reward_status.text.contains("+3 block"), "chain strip should show the pending threshold reward at %s" % size)
		var minimum_status_widths := [52.0, 64.0, 88.0] if size.x < 720 else [64.0, 72.0, 100.0]
		var status_nodes := [chain_current_status, chain_next_status, chain_reward_status]
		for status_index in range(status_nodes.size()):
			var status_node := status_nodes[status_index] as Label
			_assert(
				status_node != null
				and status_node.is_visible_in_tree()
				and status_node.get_global_rect().size.x >= minimum_status_widths[status_index],
				"%s should reserve visible text width at %s" % [status_node.name if status_node != null else "chain status", size]
			)
			_assert(status_node != null and viewport_rect.encloses(status_node.get_global_rect()), "%s should remain viewport-contained at %s" % [status_node.name if status_node != null else "chain status", size])
		var advancing_card = game.find_child("HandCard_adc_convert_0", true, false) as Button
		var preserving_card = game.find_child("HandCard_neutral_preview_1", true, false) as Button
		var breaking_card = game.find_child("HandCard_uart_log_2", true, false) as Button
		_assert(advancing_card != null and advancing_card.text.contains("advances") and advancing_card.text.contains("+3 block"), "interface card should explicitly preview advancement and its reward at %s" % size)
		_assert(preserving_card != null and preserving_card.text.contains("preserves"), "neutral card should explicitly preview chain preservation at %s" % size)
		_assert(breaking_card != null and breaking_card.text.contains("breaks"), "out-of-order output card should explicitly preview a chain break at %s" % size)
		if hand_scroll != null:
			_assert(chain_strip.get_global_rect().end.y <= hand_scroll.get_global_rect().position.y, "engineering-chain strip should sit above the horizontal hand dock at %s" % size)
	if size.x < 720 and combat_actions != null and hand_scroll != null:
		_assert(
			combat_actions.get_global_rect().end.y <= hand_scroll.get_global_rect().position.y,
			"compact processing and combat actions should sit above the horizontal hand at %s: actions=%s[%d] hand=%s[%d]" % [
				size,
				combat_actions.get_global_rect(),
				combat_actions.get_index(),
				hand_scroll.get_global_rect(),
				hand_scroll.get_index()
			]
		)
		_assert(point_counter != null and point_counter.get_parent() == combat_actions, "compact processing counter should share the reroute and end-turn row at %s" % size)
		if point_counter != null:
			_assert(viewport_rect.encloses(point_counter.get_global_rect()), "compact processing counter should remain fully visible at %s" % size)
	if reroute_button != null and reroute_cancel_button != null:
		_assert(reroute_button.is_visible_in_tree() and !reroute_button.disabled, "reroute should be available before the first card at %s" % size)
		_assert(reroute_button.size.y >= 44.0 and end_turn.size.y >= 44.0, "reroute and end turn should be at least 44 px high at %s" % size)
		_assert(!reroute_button.get_global_rect().intersects(end_turn.get_global_rect()), "reroute and end turn should be disjoint at %s" % size)
		_assert(game.begin_reroute(), "reroute should enter selection mode for UI verification")
		await process_frame
		_assert(reroute_cancel_button.is_visible_in_tree() and !reroute_cancel_button.disabled, "reroute cancellation should be visible during selection at %s" % size)
		_assert(reroute_button.custom_minimum_size.y >= 44.0 and reroute_cancel_button.custom_minimum_size.y >= 44.0, "reroute controls should use 44 px touch targets at %s" % size)
		_assert(!reroute_button.get_global_rect().intersects(end_turn.get_global_rect()) and !reroute_cancel_button.get_global_rect().intersects(end_turn.get_global_rect()), "reroute controls should not overlap end turn at %s" % size)
		if size.x < 720:
			for action in [point_counter, reroute_button, reroute_cancel_button, end_turn]:
				_assert(viewport_rect.encloses((action as Control).get_global_rect()), "%s should remain fully visible during compact reroute selection at %s" % [action.name, size])
		_assert(game.cancel_reroute(), "reroute should cancel after UI verification")
	_assert_visible_primary_command_heights(game)
	var resolved_fault_name := str(game.current_encounter.get("name", ""))
	var resolved_stability: int = game.stability
	game.encounter_evidence_tags = {"smoke": true, "adc": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._render_state()
	await process_frame
	var resolved_backdrop := game.find_child("ResolvedEncounterBackdrop", true, false) as Control
	var resolved_device := game.find_child("ResolvedDeviceContext", true, false) as Label
	var resolved_evidence := game.find_child("ResolvedEvidenceContext", true, false) as Label
	var resolved_fault := game.find_child("ResolvedFaultContext", true, false) as Label
	_assert(resolved_backdrop != null and resolved_backdrop.visible, "reward should retain a visible resolved encounter backdrop")
	if resolved_backdrop != null:
		_assert(resolved_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "resolved encounter backdrop should be non-interactive")
		_assert(resolved_backdrop.find_children("*", "Button", true, false).is_empty(), "resolved encounter backdrop should not expose commands")
	_assert(resolved_device != null and resolved_device.text.contains(str(resolved_stability)), "reward backdrop should retain the resolved device stability")
	_assert(resolved_evidence != null and resolved_evidence.text.contains("smoke") and resolved_evidence.text.contains("adc"), "reward backdrop should retain collected encounter evidence")
	_assert(resolved_fault != null and !resolved_fault_name.is_empty() and resolved_fault.text.contains(resolved_fault_name), "reward backdrop should retain the actual resolved fault")
	_assert(choice_description != null and choice_description.text.contains("调试报告"), "reward state should expose the latest debugging report")
	_assert(reward_cards != null and reward_cards.get_child_count() == 3, "normal completed encounter should render three reward cards")
	if reward_cards != null and reward_skip != null and reward_cards.get_child_count() > 0:
		_assert((reward_cards as GridContainer).columns == (1 if size.x < 720 else 3), "normal reward cards should adapt their column count")
		for reward_card in reward_cards.get_children():
			_assert((reward_card as Control).custom_minimum_size.y >= 88.0, "normal reward cards should remain visually scannable")
			_assert(viewport_rect.intersects((reward_card as Control).get_global_rect()), "normal reward card should remain visible at %s" % size)
			var reward_text := (reward_card as Button).text
			_assert(reward_text.contains("协同") or reward_text.contains("补链") or reward_text.contains("反制"), "normal reward cards should display their composition reason")
		_assert((reward_skip as Control).custom_minimum_size.y < (reward_cards.get_child(0) as Control).custom_minimum_size.y, "reward skip should be visually secondary to reward cards")
	_assert_visible_primary_command_heights(game)

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 1
	game._apply_boss_phase()
	game._render_state()
	await process_frame
	if gate_label != null:
		_assert(gate_label.text.contains("filter/calibration"), "boss phase two should expose its filter-or-calibration gate")
	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	await process_frame
	for fault_row in [fault_intent_row, fault_rule_row, fault_counter_row, fault_rule_state]:
		_assert(fault_row != null and !fault_row.is_visible_in_tree(), "%s should stay hidden during Boss combat at %s" % [fault_row.name if fault_row != null else "fault row", size])
	if gate_label != null:
		_assert(gate_label.text.contains("distinct outputs") and gate_label.text.contains("0 / 2"), "boss phase three should expose its two-distinct-output gate")
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "boss phase three actions should stay inside viewport at %s" % size)
	if footer != null:
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "boss phase three action should not be covered by the footer at %s" % size)

	game.state = game.RunState.REWARD
	game.reward_choices = []
	game._render_state()
	await process_frame
	_assert(choice_view.visible and !combat_view.visible, "reward state should show choice view")
	var choice_backdrop = game.find_child("SceneChoiceBackdrop", true, false)
	var choice_context = game.find_child("SceneChoiceContext", true, false)
	_assert(choice_backdrop != null and choice_context != null, "choice states should retain scene context")
	_assert(reward_cards != null, "reward should expose a dedicated card row")
	if choice_list != null:
		_assert(choice_list is GridContainer, "choice states should use a responsive grid")
		_assert((choice_list as GridContainer).columns == (1 if size.x < 720 else 2), "choice grid should adapt its column count")
	if reward_cards != null:
		_assert(reward_cards.get_child_count() == 0, "empty reward fallback should render no blank reward cards")
	_assert(reward_skip != null and reward_skip.visible, "empty reward fallback should retain the skip command")
	_assert_visible_primary_command_heights(game)

	await _verify_question_type_rendering(
		game,
		size,
		choice_scroll,
		question_frame,
		question_tag,
		question_prompt,
		question_interaction
	)
	await _verify_question_resolution_scrolling(
		game,
		size,
		choice_scroll,
		question_explanation,
		question_consequence
	)
	_assert_visible_primary_command_heights(game)

	var reward_fallback_deck: Array = game.deck.duplicate(true)
	var reward_fallback_relics: Array = game.relics.duplicate(true)
	game.deck.clear()
	game.relics = ["window_n8"]
	game._begin_question_event((game.event_defs.get("advanced_moving_average", {}) as Dictionary).duplicate(true))
	_assert(game.submit_event_answer("reduce_spike_add_delay"), "unavailable-reward UI fixture should accept the correct answer")
	game._render_state()
	await process_frame
	var reward_fallback = game.find_child("QuestionRewardFallback", true, false) as Label
	_assert(reward_fallback != null and reward_fallback.is_visible_in_tree() and reward_fallback.text.contains("继续"), "unavailable event rewards should expose a visible continuation fallback at %s" % size)
	_assert(question_continue != null and question_continue.is_visible_in_tree() and question_continue.text.contains("继续"), "unavailable event rewards should expose a visible continue command at %s" % size)
	if question_continue != null:
		_assert(viewport_rect.encloses(question_continue.get_global_rect()), "unavailable-reward continue command should fit the viewport at %s" % size)
	_assert(game.continue_event(), "unavailable-reward UI fixture should continue")
	game.deck = reward_fallback_deck
	game.relics = reward_fallback_relics

	var missing_waveform := (game.event_defs.get("basic_adc_spike", {}) as Dictionary).duplicate(true)
	missing_waveform.erase("waveform")
	game._begin_question_event(missing_waveform)
	game._render_state()
	await process_frame
	var waveform_fallback = game.find_child("QuestionWaveformFallback", true, false) as Label
	_assert(waveform_fallback != null and waveform_fallback.is_visible_in_tree() and !waveform_fallback.text.strip_edges().is_empty(), "missing waveform payload should render a nonblank reading table")

	game.current_event = {
		"id": "ui_malformed_event",
		"tier": "basic",
		"questionType": "diagnosis",
		"options": [],
		"correctAnswer": "missing",
		"rewardChoices": [],
		"penalty": {"op": "budget", "amount": -99, "minimum": 0}
	}
	game.state = game.RunState.EVENT
	game.event_answer_locked = false
	game.event_result.clear()
	game._render_state()
	await process_frame
	_assert(question_explanation != null and question_explanation.visible and question_explanation.text.contains("事件数据无效"), "malformed event should display its safe data-error explanation immediately")
	_assert(question_continue != null and question_continue.visible, "malformed event should expose a safe continue command")

	var event_selection_budget: int = game.budget
	game.current_event = {
		"id": "event_selection_overlay",
		"options": [{
			"effects": [
				{"op": "select_card", "cardIds": ["logic_probe"]},
				{"op": "budget", "amount": 3}
			]
		}]
	}
	game.state = game.RunState.EVENT
	game._render_state()
	await process_frame
	_assert(choice_list != null and choice_list.is_visible_in_tree() and choice_list.get_child_count() == 1, "legacy simple event should retain its backward-compatible option UI")
	_assert(game.choose_event_option(0), "event selection setup should open an event-owned card choice")
	game._render_state()
	await process_frame
	var selection_modal = game.find_child("CardSelectionModal", true, false) as Control
	var selection_options = game.find_child("CardSelectionOptions", true, false)
	_assert(game.state == game.RunState.EVENT, "event-owned selection should preserve the EVENT view")
	_assert(selection_modal != null and selection_modal.is_visible_in_tree(), "shared card-selection overlay should be visible during EVENT")
	_assert(selection_modal != null and selection_modal.get_parent() == scene_stage, "shared card-selection overlay should live above the state-specific views")
	_assert(selection_options != null and selection_options.get_child_count() == 1, "event-owned selection should render its available choice")
	_assert(combat_view != null and !combat_view.visible and end_turn != null and !end_turn.is_visible_in_tree(), "event-owned selection should not expose combat actions")
	_assert(game.choose_pending_card(0), "event-owned overlay should dispatch to its declared owner")
	game._render_state()
	await process_frame
	_assert(game.state == game.RunState.MAP and game.budget == event_selection_budget + 3, "event-owned overlay should resume its event continuation")
	_assert(selection_modal != null and !selection_modal.is_visible_in_tree(), "shared overlay should close after its event continuation resolves")
	for deck_index in range(game.deck.size() - 1, -1, -1):
		if str((game.deck[deck_index] as Dictionary).get("id", "")) == "logic_probe":
			game.deck.remove_at(deck_index)

	game._open_shop()
	game._render_state()
	await process_frame
	_assert(choice_list != null and choice_list.get_child_count() > 1, "normal shop should render stock and leave commands")
	_assert_visible_primary_command_heights(game)

	game.state = game.RunState.REST
	game.current_layer = 10
	game._render_state()
	await process_frame
	var service_bench = game.find_child("ServiceBench", true, false)
	_assert(service_bench != null and service_bench.visible, "service should present the engineering maintenance bench")
	if service_bench != null and choice_list != null:
		for action in choice_list.get_children():
			_assert((action as Control).custom_minimum_size.y >= 44.0, "service actions should remain at least 44 px high")
	game.state = game.RunState.RESULT
	game._render_state()
	await process_frame
	_assert(service_bench != null and !service_bench.visible, "service bench should hide outside the service state")

	game.state = game.RunState.MAP
	game.current_layer = 5
	var event_history_before_node_six: int = game.event_history.size()
	_assert(game.choose_node(0), "node 6 should launch its advanced question event")
	game._render_state()
	await process_frame
	_assert(choice_view.visible and game.state == game.RunState.EVENT, "node 6 should use the question-event choice view")
	_assert(str(game.current_event.get("tier", "")) == "advanced", "node 6 should select an advanced question event")
	_assert(game.event_history.size() == event_history_before_node_six + 1, "node 6 should record its selected question event")
	_assert(question_frame.is_visible_in_tree() and question_prompt.is_visible_in_tree() and question_interaction.is_visible_in_tree(), "node 6 should render the advanced question UI")
	_assert_visible_primary_command_heights(game)

	game.score = 87
	game.current_layer = 12
	game.stability = 55
	game.checkpoints_passed = 2
	game.state = game.RunState.RESULT
	game._render_state()
	await process_frame
	_assert(result_view.visible and !choice_view.visible, "result state should show result view")
	var result_heading = game.find_child("RunResultHeading", true, false)
	var result_metrics = game.find_child("RunResultMetrics", true, false)
	var learning_summary = game.find_child("RunLearningSummary", true, false)
	_assert(result_heading != null and result_metrics != null and learning_summary != null, "result state should expose the refreshed result hierarchy")
	if learning_summary != null:
		_assert(learning_summary.text.contains("调试报告"), "result state should retain the run's debugging report summary")
	if result_metrics != null:
		_assert(result_metrics.text.contains("得分 87 / 100"), "result state should retain the score metric")
		_assert(result_metrics.text.contains("到达节点 12 / 12"), "result state should retain the node-count metric")
		_assert(result_metrics.text.contains("稳定度 55 / 70"), "result state should retain the stability metric")
		_assert(result_metrics.text.contains("检查点 2 / 2"), "result state should retain the checkpoint metric")
		_assert(result_metrics.text.contains("牌组 12 张"), "result state should retain the deck-size metric")
	if restart_button != null:
		_assert(restart_button.size.x <= 360.0, "desktop result action should not stretch across the work area")
		_assert(viewport_rect.encloses(restart_button.get_global_rect()), "result action should stay inside viewport at %s" % size)
	_assert_visible_primary_command_heights(game)

	if !game.has_method("_enter_node_lab"):
		_assert(false, "game should expose the hidden node lab launcher")
	else:
		game._enter_node_lab()
		await process_frame
		var lab_catalog = game.find_child("NodeLabCatalog", true, false)
		var lab_return = game.find_child("NodeLabReturn", true, false)
		var lab_restart = game.find_child("NodeLabRestart", true, false)
		var lab_toolbar = game.find_child("NodeLabToolbar", true, false) as Control
		var lab_scenario = game.find_child("NodeLabScenario_mq2_warmup", true, false)
		var lab_root = game.find_child("NodeLabRoot", true, false)
		_assert(lab_catalog != null and lab_catalog.visible, "node lab catalog should be visible at %s" % size)
		_assert(lab_root != null and lab_root.theme == game.ui_theme, "node lab should inherit the bundled UI font theme")
		_assert(!game.shell.visible, "node lab catalog should hide the normal shell")
		_assert(lab_return != null and lab_restart != null, "node lab should expose stable scenario controls")
		_assert(lab_toolbar != null and lab_toolbar.is_visible_in_tree(), "node lab should expose a stable toolbar")
		_assert(lab_scenario != null, "node lab should render generated scenario buttons")
		if lab_toolbar != null:
			for toolbar_control in lab_toolbar.find_children("*", "Button", true, false):
				if (toolbar_control as Control).is_visible_in_tree():
					_assert(viewport_rect.encloses((toolbar_control as Control).get_global_rect()), "%s should fit the Node Lab catalog toolbar at %s" % [toolbar_control.name, size])
			_assert(lab_catalog.get_global_rect().position.y >= lab_toolbar.get_global_rect().end.y, "Node Lab catalog offset should follow the responsive toolbar at %s" % size)
		if lab_scenario != null:
			_assert((lab_scenario as Control).custom_minimum_size.y >= 44.0, "lab scenario touch target should be at least 44 px")
			_assert(viewport_rect.intersects((lab_scenario as Control).get_global_rect()), "first lab scenario should be visible at %s" % size)
			if lab_toolbar != null:
				_assert(lab_toolbar.get_global_rect().end.y <= (lab_scenario as Control).get_global_rect().position.y, "Node Lab toolbar should sit above catalog scenario content at %s" % size)
		game.start_lab_scenario({
			"id": "basic_mq2_warmup",
			"kind": "question_event",
			"contentId": "basic_mq2_warmup",
			"seedId": 777
		})
		await process_frame
		_assert(!lab_catalog.visible, "starting a lab scenario should hide the catalog")
		_assert(game.state == game.RunState.EVENT and game.run_seed == 777, "Node Lab should launch the requested question event with an overridable seed")
		_assert(!run_hud.visible and game.shell.visible and game.shell.offset_top == lab_toolbar.size.y, "scenario shell offset should follow the responsive Node Lab toolbar")
		_assert(lab_return.visible and lab_restart.visible, "scenario controls should remain visible during lab play")
		if lab_toolbar != null:
			if size.x < 720:
				_assert(lab_toolbar.size.y > 58.0, "compact question toolbar should use a second row at %s" % size)
			for toolbar_control in lab_toolbar.find_children("*", "Button", true, false):
				if (toolbar_control as Control).is_visible_in_tree():
					_assert(viewport_rect.encloses((toolbar_control as Control).get_global_rect()), "%s should fit the Node Lab question toolbar at %s" % [toolbar_control.name, size])
			_assert(lab_toolbar.get_global_rect().end.y <= question_frame.get_global_rect().position.y, "Node Lab toolbar should not overlap the question event at %s" % size)
		_assert(viewport_rect.encloses(lab_return.get_global_rect()), "lab return control should stay inside viewport at %s" % size)
		_assert(viewport_rect.encloses(lab_restart.get_global_rect()), "lab restart control should stay inside viewport at %s" % size)
		_assert_visible_primary_command_heights(game)
		var lab_runtime_calls: Array = []
		game.runtime.bridge.outbound_payload.connect(func(payload: Dictionary) -> void: lab_runtime_calls.append(payload))
		game.start_lab_scenario({
			"id": "mq2_warmup",
			"kind": "enemy",
			"contentId": "mq2_warmup",
			"tier": "ordinary"
		}, "coverage")
		await process_frame
		_assert(!header.visible, "lab toolbar should replace the normal game header during scenarios")
		if lab_toolbar != null:
			_assert(game.shell.offset_top == lab_toolbar.size.y, "combat shell offset should follow the responsive Node Lab toolbar at %s" % size)
			for toolbar_control in lab_toolbar.find_children("*", "Button", true, false):
				if (toolbar_control as Control).is_visible_in_tree():
					_assert(viewport_rect.encloses((toolbar_control as Control).get_global_rect()), "%s should fit the Node Lab combat toolbar at %s" % [toolbar_control.name, size])
			_assert(lab_toolbar.get_global_rect().end.y <= arena.get_global_rect().position.y, "Node Lab toolbar should not overlap combat scenario content at %s" % size)
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "lab combat action should stay above the footer at %s" % size)
		_assert(arena.is_visible_in_tree() and hand_dock.is_visible_in_tree(), "lab combat should expose the redesigned arena and hand dock")
		_assert(bool(game.restart_lab_scenario()), "lab restart should relaunch the current scenario")
		await process_frame
		_assert(lab_runtime_calls.is_empty(), "lab restart should not call the runtime")
		game.return_to_node_lab()
		await process_frame
		_assert(lab_catalog.visible and !game.shell.visible and run_hud.visible and game.shell.offset_top == 0.0, "lab return should restore the catalog")
		_assert_visible_primary_command_heights(game)

	game.queue_free()
	await process_frame


func _verify_question_type_rendering(
	game,
	size: Vector2i,
	choice_scroll: ScrollContainer,
	question_frame: Control,
	question_tag: Label,
	question_prompt: Label,
	question_interaction: Control
) -> void:
	var cases: Array[Dictionary] = [
		{"type": "diagnosis", "event_id": "basic_mq2_warmup"},
		{"type": "ordering", "event_id": "basic_signal_order"},
		{"type": "code_trace", "event_id": "basic_i2c_result"},
		{"type": "parameter", "event_id": "basic_sample_period"},
		{"type": "waveform", "event_id": "basic_adc_spike"},
		{"type": "tradeoff", "event_id": "basic_raw_trusted"}
	]
	for case in cases:
		var event_id := str(case.get("event_id", ""))
		var question_type := str(case.get("type", ""))
		var event := (game.event_defs.get(event_id, {}) as Dictionary).duplicate(true)
		_assert(!event.is_empty(), "%s fixture should exist for %s rendering" % [event_id, size])
		if event.is_empty():
			continue
		choice_scroll.scroll_vertical = 0
		game._begin_question_event(event)
		game._render_state()
		await process_frame
		await process_frame
		var scroll_rect := choice_scroll.get_global_rect()
		_assert(game.state == game.RunState.EVENT, "%s should enter the event state at %s" % [question_type, size])
		_assert(str(game.current_event.get("questionType", "")) == question_type, "%s fixture should preserve its question type at %s" % [event_id, size])
		_assert(question_frame.is_visible_in_tree(), "%s should render the question frame at %s" % [question_type, size])
		_assert(question_tag.is_visible_in_tree() and !question_tag.text.strip_edges().is_empty(), "%s should render nonblank knowledge tags at %s" % [question_type, size])
		_assert(question_prompt.is_visible_in_tree() and !question_prompt.text.strip_edges().is_empty(), "%s should render a visible prompt at %s" % [question_type, size])
		_assert(question_interaction.is_visible_in_tree() and question_interaction.get_child_count() > 0, "%s should render a visible interaction at %s" % [question_type, size])
		_assert(scroll_rect.intersects(question_prompt.get_global_rect()), "%s prompt should be visible in the event scroll area at %s" % [question_type, size])
		_assert(scroll_rect.intersects(question_interaction.get_global_rect()), "%s interaction should be visible in the event scroll area at %s" % [question_type, size])
		if question_type == "ordering":
			var order_up := game.find_child("QuestionOrderUp_0", true, false) as Button
			var order_down := game.find_child("QuestionOrderDown_0", true, false) as Button
			var last_order_down := game.find_child("QuestionOrderDown_3", true, false) as Button
			_assert(order_up != null and order_down != null and last_order_down != null, "ordering should render stable up/down controls at %s" % size)
			if order_up != null and order_down != null and last_order_down != null:
				_assert(order_up.custom_minimum_size.x >= 44.0 and order_up.custom_minimum_size.y >= 44.0, "ordering move-up control should use a 44 px target at %s" % size)
				_assert(order_down.custom_minimum_size.x >= 44.0 and order_down.custom_minimum_size.y >= 44.0, "ordering move-down control should use a 44 px target at %s" % size)
				_assert(choice_scroll.is_ancestor_of(order_up) and choice_scroll.is_ancestor_of(last_order_down), "ordering controls should remain inside the event scroll area at %s" % size)
				_assert(scroll_rect.intersects(order_up.get_global_rect()) and scroll_rect.intersects(order_down.get_global_rect()), "ordering up/down controls should be initially reachable at %s" % size)
				choice_scroll.ensure_control_visible(last_order_down)
				await process_frame
				_assert(scroll_rect.intersects(last_order_down.get_global_rect()), "ordering final move-down control should be reachable by scrolling at %s" % size)
		elif question_type == "waveform":
			var waveform_plot := game.find_child("QuestionWaveformPlot", true, false) as Control
			var waveform_fallback := game.find_child("QuestionWaveformFallback", true, false) as Label
			var waveform_readings := game.find_child("QuestionWaveformReadings", true, false) as Label
			var waveform_nonblank := false
			if waveform_plot != null and waveform_plot.is_visible_in_tree():
				var waveform_lines := waveform_plot.find_children("*", "Line2D", true, false)
				waveform_nonblank = !waveform_lines.is_empty() and (waveform_lines[0] as Line2D).points.size() > 1
				waveform_nonblank = waveform_nonblank and waveform_readings != null and !waveform_readings.text.strip_edges().is_empty()
			elif waveform_fallback != null:
				waveform_nonblank = waveform_fallback.is_visible_in_tree() and !waveform_fallback.text.strip_edges().is_empty()
			_assert(waveform_nonblank, "waveform should render a nonblank plot or fallback table at %s" % size)


func _verify_question_resolution_scrolling(
	game,
	size: Vector2i,
	choice_scroll: ScrollContainer,
	question_explanation: Label,
	question_consequence: Control
) -> void:
	var event := (game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).duplicate(true)
	var explanation := str(event.get("explanation", ""))
	event["id"] = "ui_scroll_diagnosis"
	event["explanation"] = (explanation + "\n").repeat(14)
	choice_scroll.scroll_vertical = 0
	game._begin_question_event(event)
	game._render_state()
	await process_frame
	_assert(game.submit_event_answer(event.get("correctAnswer")), "scroll fixture should accept its correct answer at %s" % size)
	game._render_state()
	await process_frame
	await process_frame
	_assert(question_explanation.is_visible_in_tree() and !question_explanation.text.strip_edges().is_empty(), "resolved question explanation should be visible at %s" % size)
	_assert(question_consequence.is_visible_in_tree() and question_consequence.get_child_count() > 0, "resolved question consequence should be visible at %s" % size)
	_assert(choice_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "resolved question content should retain vertical scrolling at %s" % size)
	_assert(choice_scroll.is_ancestor_of(question_explanation) and choice_scroll.is_ancestor_of(question_consequence), "explanation and consequence should remain inside the event scroll area at %s" % size)
	var scroll_bar := choice_scroll.get_v_scroll_bar()
	_assert(scroll_bar.max_value > scroll_bar.page, "long explanation and consequence should overflow into scrolling rather than clip at %s" % size)
	choice_scroll.ensure_control_visible(question_explanation)
	await process_frame
	_assert(choice_scroll.get_global_rect().intersects(question_explanation.get_global_rect()), "question explanation should be reachable by scrolling at %s" % size)
	choice_scroll.ensure_control_visible(question_consequence)
	await process_frame
	_assert(choice_scroll.get_global_rect().intersects(question_consequence.get_global_rect()), "question consequence should be reachable by scrolling at %s" % size)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _assert_visible_primary_command_heights(root: Node) -> void:
	for raw_button in root.find_children("*", "Button", true, false):
		var button := raw_button as Button
		if button != null and button.is_visible_in_tree():
			_assert(button.size.y >= 44.0, "%s should be at least 44 px high when visible" % button.name)


func _assert_tutorial_focus(control: Control, message: String) -> void:
	_assert(control != null, message)
	if control == null:
		return
	var style := control.get_theme_stylebox("normal") as StyleBoxFlat
	_assert(style != null and style.border_width_left >= 3 and style.border_color == Color("#2f7f8d"), message)


func _assert_tutorial_bounds(game, viewport_rect: Rect2, footer: Control, expected_card_id: String, step_name: String) -> void:
	var tutorial_coach = game.find_child("TutorialCoachLayer", true, false) as Control
	var tutorial_text = game.find_child("TutorialCoachText", true, false) as Label
	var tutorial_skip = game.find_child("TutorialSkipButton", true, false) as Control
	_assert(tutorial_coach != null, "%s tutorial state should expose the coach" % step_name)
	_assert(tutorial_text != null and tutorial_text.is_visible_in_tree(), "%s coach text should remain visible" % step_name)
	if tutorial_text != null:
		_assert(tutorial_text.get_global_rect().size.y > 0.0, "%s coach text should reserve readable space" % step_name)
	_assert(tutorial_skip != null, "%s tutorial state should expose skip" % step_name)
	_assert(footer != null, "%s tutorial state should expose the footer boundary" % step_name)
	if tutorial_coach != null and footer != null:
		_assert(viewport_rect.encloses(tutorial_coach.get_global_rect()), "%s coach should fit the viewport" % step_name)
		_assert(tutorial_coach.get_global_rect().end.y <= footer.get_global_rect().position.y, "%s coach should stay above the footer" % step_name)
	if tutorial_skip != null:
		_assert(viewport_rect.encloses(tutorial_skip.get_global_rect()), "%s skip should remain reachable" % step_name)
	if !expected_card_id.is_empty():
		var required_cards: Array[Node] = game.find_children("TutorialRequiredCard", "", true, false)
		_assert(required_cards.size() == 1, "%s active tutorial card should expose exactly one stable target" % step_name)
		if required_cards.size() == 1:
			var required_card := required_cards[0] as Button
			var expected_card_text := _expected_tutorial_card_text(game, expected_card_id)
			_assert(required_card != null, "%s required card target should be a button" % step_name)
			_assert(!expected_card_text.is_empty(), "%s should render the expected tutorial card id %s" % [step_name, expected_card_id])
			if required_card != null:
				_assert(required_card.is_visible_in_tree(), "%s required card should be visible" % step_name)
				_assert(required_card.text == expected_card_text, "%s required card should render the expected tutorial card id %s" % [step_name, expected_card_id])
				_assert(viewport_rect.encloses(required_card.get_global_rect()), "%s required card should be fully visible" % step_name)
				if footer != null:
					_assert(required_card.get_global_rect().end.y <= footer.get_global_rect().position.y, "%s required card should stay above the footer" % step_name)
				if tutorial_coach != null:
					_assert(!tutorial_coach.get_global_rect().intersects(required_card.get_global_rect()), "%s coach should not cover the required card: coach=%s card=%s" % [step_name, tutorial_coach.get_global_rect(), required_card.get_global_rect()])
	if step_name == "end turn":
		var end_turn = game.find_child("EndTurnButton", true, false) as Control
		_assert(end_turn != null and end_turn.is_visible_in_tree(), "end turn tutorial state should expose the end-turn target")
		if end_turn != null:
			_assert(viewport_rect.encloses(end_turn.get_global_rect()), "end turn tutorial target should fit the viewport")
			if footer != null:
				_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "end turn tutorial target should stay above the footer")
			if tutorial_coach != null:
				_assert(!tutorial_coach.get_global_rect().intersects(end_turn.get_global_rect()), "end turn coach should not cover the end-turn target")


func _expected_tutorial_card_text(game, expected_card_id: String) -> String:
	for raw_card in game.hand:
		var card := raw_card as Dictionary
		if str(card.get("id", "")) != expected_card_id:
			continue
		var effect_text := str(card.get("upgradedEffectText", "") if bool(card.get("upgraded", false)) else card.get("effectText", ""))
		var chain_preview := game._chain_preview_for_stage(str(card.get("stage", ""))) as Dictionary
		return "[%d] %s · %s\n%s\nChain %s · pending %s" % [
			game._card_cost_preview(card),
			card.get("name", ""),
			card.get("type", ""),
			effect_text,
			chain_preview.get("decision", "preserves"),
			chain_preview.get("pendingReward", "none")
		]
	return ""


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 graybox UI tests passed")
		quit(0)
