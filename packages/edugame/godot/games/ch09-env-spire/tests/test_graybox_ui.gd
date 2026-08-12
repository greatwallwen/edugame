extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_viewport(Vector2i(1280, 720))
	await _verify_boss_reroute_ui(Vector2i(1280, 720))
	_finish()


func _verify_boss_reroute_ui(size: Vector2i) -> void:
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

	game.tutorial_active = false
	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 1
	game._apply_boss_phase()
	game._reset_turn_state(true)
	game.hand = [game._card_copy("uart_log")]
	game.draw_pile = [game._card_copy("sliding_average"), game._card_copy("mq2_sample")]
	game.discard_pile.clear()
	game.processing_points = 3
	game.reroute_available = true
	game.reroute_mode = false
	game.cards_played_this_turn = 0
	game.pending_card_selection.clear()
	game._render_state()
	await process_frame

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
	var reroute_button = game.find_child("RerouteButton", true, false) as Button
	var point_counter = game.find_child("ProcessingPointCounter", true, false) as Label
	_assert(reroute_button != null and reroute_button.text == "检索 -1", "Boss reroute should expose its targeted retrieval cost at %s" % size)
	if reroute_button != null:
		_assert(reroute_button.tooltip_text.contains("1 处理点"), "Boss reroute tooltip should explain the retrieval cost at %s" % size)
		_assert(viewport_rect.encloses(reroute_button.get_global_rect()), "Boss reroute button should stay inside the viewport at %s" % size)
	_assert(game.begin_reroute(), "Boss reroute UI fixture should enter selection mode")
	_assert(game.reroute_card(0), "Boss reroute UI fixture should retrieve the gate card")
	game._render_state()
	await process_frame
	_assert(point_counter != null and point_counter.text.contains("2"), "Boss retrieval should update the visible processing-point total at %s" % size)

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
	var visual_backdrop = game.find_child("EnvSpireBackdrop", true, false) as Control
	var ambient_left_veil = game.find_child("AmbientLeftColorVeil", true, false) as ColorRect
	var ambient_right_veil = game.find_child("AmbientRightColorVeil", true, false) as ColorRect
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
	var map_backdrop = game.find_child("MapBackdrop", true, false) as TextureRect
	var map_energy = game.find_child("MapEnergyOverlay", true, false) as TextureRect
	var map_left_veil = game.find_child("MapLeftColorVeil", true, false) as ColorRect
	var map_right_veil = game.find_child("MapRightColorVeil", true, false) as ColorRect
	var map_route_scroll = game.find_child("MapRouteScroll", true, false)
	var map_route = game.find_child("MapRoute", true, false)
	var map_enter = game.find_child("MapEnterButton", true, false)
	var mission_summary = game.find_child("MapMissionSummary", true, false)
	var next_detail = game.find_child("MapNextDetail", true, false)
	var mission_hud = game.find_child("MapMissionHUD", true, false) as MarginContainer
	var next_hud = game.find_child("MapNextHUD", true, false) as MarginContainer
	var mission_heading = game.find_child("MapMissionHeading", true, false) as Label
	var next_heading = game.find_child("MapNextHeading", true, false) as Label
	var mission_progress = game.find_child("MapMissionProgress", true, false) as ProgressBar
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
	_assert(
		hand_row != null
		and hand_row.get_theme_constant("separation") >= 12
		and hand_row.get_theme_constant("separation") <= 16,
		"hand cards should keep a slightly wider 12-16px reading gap"
	)
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
	var combat_feedback_banner = game.find_child("CombatFeedbackBanner", true, false) as Control
	var combat_feedback_flash = game.find_child("CombatFeedbackFlash", true, false) as Control
	var combat_sound_toggle = game.find_child("CombatSoundToggle", true, false) as Button
	var reward_cards = game.find_child("RewardCards", true, false)
	var reward_skip = game.find_child("RewardSkipButton", true, false)
	var tutorial_view = game.find_child("TutorialView", true, false)
	var tutorial_route = game.find_child("TutorialRouteSummary", true, false)
	var tutorial_practice_steps = game.find_child("TutorialPracticeSteps", true, false)
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
	var result_metrics = game.find_child("RunResultMetrics", true, false) as Label
	var result_metrics_panel = game.find_child("RunMetricsPanel", true, false) as PanelContainer
	var result_learning_panel = game.find_child("RunLearningPanel", true, false) as PanelContainer
	var run_menu_title = game.find_child("RunMenuTitle", true, false) as Label
	game._start_clean_formal_run()
	await process_frame

	_assert(header != null, "header should exist at %s" % size)
	_assert(visual_backdrop is TextureRect and (visual_backdrop as TextureRect).texture != null, "main shell should expose the persistent illustrated laboratory backdrop")
	_assert(visual_backdrop != null and visual_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "main shell should expose a non-interactive environmental backdrop")
	_assert(ambient_left_veil != null and ambient_right_veil != null, "main shell should soften the generic backdrop edges without covering its center")
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
	_assert(enemy_intent is Button and enemy_intent.has_method("configure_intent"), "fault intent should be a compact clickable icon-and-value badge")
	_assert(hand_dock != null and point_counter != null, "combat should expose a fixed action dock")
	_assert(chain_strip != null and chain_collect != null and chain_interface != null and chain_process != null and chain_output != null, "combat should expose stable engineering-chain anchors")
	_assert(reroute_button != null and reroute_cancel_button != null, "combat should expose stable reroute controls")
	_assert(combat_feedback_banner != null and combat_feedback_flash != null and combat_sound_toggle != null, "combat should expose stable feedback controls")
	_assert(map_route != null and map_route.get_child_count() == 12, "map climb should render twelve route nodes")
	if map_route != null and map_route.get_child_count() == 12:
		var available_step := map_route.find_child("MapStep01", false, false) as Control
		var future_step := map_route.find_child("MapStep02", false, false) as Control
		var available_node := available_step.find_child("MapNodeButton", true, false) as Button
		var connector := available_step.find_child("MapConnector", true, false) as Control
		var future_node := future_step.find_child("MapNodeButton", true, false) as Button
		var available_state := available_step.find_child("MapStateLabel", true, false) as Label
		var future_state := future_step.find_child("MapStateLabel", true, false) as Label
		_assert(available_node != null and connector != null, "single-line map steps should expose a node and route connector")
		_assert(available_node != null and available_node.custom_minimum_size.x >= 52.0 and available_node.custom_minimum_size.x <= 72.0, "route nodes should read as compact signal stations instead of wide boxes")
		_assert(available_node != null and available_node.get_theme_color("font_color") != Color.MAGENTA, "available route node should use a defined console text token")
		_assert(available_node != null and available_node.text == "01", "route node control should contain only its compact node number")
		var available_style := available_node.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(available_style != null and available_style.corner_radius_top_left <= 4, "route nodes should use compact square signal frames")
		_assert(is_equal_approx(available_node.custom_minimum_size.x, available_node.custom_minimum_size.y), "route node frame should remain square")
		_assert(available_state != null and available_state.text.contains("当前"), "available map node should expose a non-color current-state label")
		_assert(future_state != null and future_state.text.contains("待侦察"), "future map nodes should expose a non-color locked-state label")
		_assert(map_route.get_child(0).name == "MapStep12" and map_route.get_child(11).name == "MapStep01", "route should be laid out from Boss at the top to the starting node at the bottom")
	_assert(map_enter != null and map_enter.custom_minimum_size.y >= 44.0, "map enter should be a full touch target")
	_assert(mission_summary != null and next_detail != null, "map should expose mission and next-node context")
	_assert(mission_hud != null and next_hud != null, "map context should use unframed HUD rails instead of box panels")
	_assert(map_backdrop != null and map_backdrop.texture != null, "map should use a dedicated illustrated tower backdrop")
	_assert(map_energy != null and map_energy.texture == map_backdrop.texture and map_energy.material is ShaderMaterial, "map should layer a shader-driven tower charge effect over the illustrated backdrop")
	_assert(map_left_veil != null and map_right_veil != null, "map should soften both outer background zones independently")
	if map_left_veil != null and map_right_veil != null:
		_assert(map_left_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE and map_right_veil.mouse_filter == Control.MOUSE_FILTER_IGNORE, "map color veils should never intercept route input")
		_assert(map_left_veil.color.a >= 0.18 and map_left_veil.color.a <= 0.26, "map side color reduction should remain subtle")
		_assert(map_left_veil.anchor_right <= 0.32 and map_right_veil.anchor_left >= 0.68, "map side color veils should leave the central tower unobscured")
	_assert(mission_heading != null and next_heading != null and mission_progress != null, "map side panels should expose headings and a route-progress instrument")
	_assert(mission_progress != null and mission_progress.max_value == 12.0, "map progress instrument should represent the twelve-node route")
	_assert(map_composition != null and map_route_scroll != null, "map should expose its responsive route composition")
	_assert(map_route_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "map route should scroll without showing a box-like scrollbar rail")
	if map_route_scroll != null and map_route != null:
		await process_frame
		await process_frame
		var current_step := map_route.find_child("MapStep01", false, false) as Control
		var current_node := current_step.find_child("MapNodeButton", true, false) as Control if current_step != null else null
		var second_step := map_route.find_child("MapStep02", false, false) as Control
		var second_node := second_step.find_child("MapNodeButton", true, false) as Control if second_step != null else null
		_assert(current_node != null and map_route_scroll.get_global_rect().intersects(current_node.get_global_rect()), "the available map node should remain visible after deferred route layout")
		if current_node != null:
			var node_center: float = current_node.get_global_rect().get_center().x
			var route_center: float = map_route_scroll.get_global_rect().get_center().x
			var tower_center: float = map_backdrop.get_global_rect().get_center().x
			_assert(absf(node_center - route_center) <= 2.0, "every route node should stay centered on the tower's vertical circuit spine")
			_assert(absf(node_center - (tower_center + 16.0)) <= 2.0, "route nodes should overlap the illustrated tower's visual center axis")
			_assert(absf(current_node.size.x - current_node.size.y) <= 1.0, "route node should remain square after container layout")
		if current_node != null and second_node != null:
			var floor_pitch := absf(second_node.get_global_rect().get_center().y - current_node.get_global_rect().get_center().y)
			_assert(absf(floor_pitch - 81.0) <= 1.0, "route node pitch should match the illustrated tower floor spacing")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
	_assert(tutorial_view != null, "tutorial should expose a dedicated scene view")
	_assert(tutorial_route != null, "tutorial briefing should explain the route")
	_assert(tutorial_practice_steps != null and tutorial_practice_steps.get_child_count() == 4, "tutorial briefing should preview four action stages instead of relying on a text wall")
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
	_assert((tutorial_route as Label).get_theme_color("font_color").get_luminance() < 0.35, "tutorial route copy should use dark text on the light layout surface")
	_assert(question_prompt.get_theme_color("font_color").get_luminance() < 0.25, "event prompts should use the dark heading hierarchy")
	_assert(game.choice_title.get_theme_color("font_color").get_luminance() < 0.25, "choice headings should use the dark heading hierarchy")
	_assert(result_metrics != null and result_metrics.get_theme_color("font_color").get_luminance() < 0.35, "result metrics should remain legible on the light layout surface")
	_assert(run_menu_title != null and run_menu_title.get_theme_font("font") == game.ui_font_display, "run menu should use the bold display face")
	var run_menu_style := game.run_menu_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(run_menu_style != null and run_menu_style.bg_color.get_luminance() > 0.82, "run menu should use an opaque light layout panel")

	game._start_tutorial_briefing()
	game._render_state()
	await process_frame
	_assert(tutorial_view.visible, "tutorial briefing should be visible when active")
	_assert(viewport_rect.encloses(tutorial_start.get_global_rect()), "tutorial start should fit the viewport")
	_assert(viewport_rect.encloses(tutorial_skip.get_global_rect()), "tutorial skip should fit the viewport")
	_assert(tutorial_start.custom_minimum_size.y >= 44.0, "tutorial start should be a touch target")
	_assert(tutorial_start.text.contains("连接训练设备"), "tutorial briefing should begin with a concrete player action")
	_assert((tutorial_route as Label).text.count("\n") <= 2, "formal-route context should stay concise beside the action preview")
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
	if enemy_intent is Button:
		(enemy_intent as Button).pressed.emit()
	else:
		game.confirm_tutorial_intent()
	await process_frame
	_assert(game.tutorial_step == game.TutorialStep.PLAY_DEFENSE, "clicking the floating intent badge should advance the tutorial directly")
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
			_assert(int(completion_summary.call("get_visible_line_count")) >= 3, "completion summary should show the loop, node, and LED notes without clipping")
	game._start_clean_formal_run()
	await process_frame
	_assert(viewport_rect.encloses(run_hud.get_global_rect()), "RunHud should stay in the viewport")
	_assert(viewport_rect.intersects(map_enter.get_global_rect()), "Available map action should remain visible")
	_assert_visible_primary_command_heights(game)
	if map_composition != null:
		_assert(!map_composition.vertical, "desktop map composition should remain horizontal")
	if mission_summary != null:
		_assert(mission_summary.visible, "desktop map should retain the mission summary")
	if header != null:
		_assert(header.theme != null and header.theme.default_font != null, "bundled Chinese font should be installed")
		_assert(game.ui_font is FontVariation, "UI font should use a variable-weight wrapper")
		if game.ui_font is FontVariation:
			_assert((game.ui_font as FontVariation).base_font.resource_path == game.UI_FONT_PATH, "variable UI font should retain the imported Web resource")
			_assert(int((game.ui_font as FontVariation).variation_opentype.get("wght", 0)) >= 600, "body text should use the unified heavy console weight")
		_assert(game.ui_font_strong is FontVariation and int((game.ui_font_strong as FontVariation).variation_opentype.get("wght", 0)) >= 720, "important UI text should use the bold console weight")
		_assert(game.ui_font_display is FontVariation and int((game.ui_font_display as FontVariation).variation_opentype.get("wght", 0)) >= 800, "display text should use the artistic heavy console weight")
		_assert(game.ui_font.has_char("选".unicode_at(0)), "UI font should contain Chinese glyphs")
	_assert(map_view != null and map_view.visible, "map view should be visible after reset")
	_assert(combat_view != null and !combat_view.visible, "combat view should be hidden on map")
	_assert(game.map_title.get_theme_color("font_color").get_luminance() < 0.25, "map heading should use dark text on the light canvas")
	if map_route != null and map_route.get_child_count() == 12:
		var next_step := map_route.find_child("MapStep01", false, false) as Control
		var hidden_third_step := map_route.find_child("MapStep03", false, false) as Control
		var hidden_fourth_step := map_route.find_child("MapStep04", false, false) as Control
		var next_marker := next_step.find_child("MapNodeButton", true, false) as Button
		var next_detail_label := next_step.find_child("MapNodeLabel", true, false) as Label
		var hidden_third_marker := hidden_third_step.find_child("MapNodeLabel", true, false) as Label
		var hidden_fourth_marker := hidden_fourth_step.find_child("MapNodeLabel", true, false) as Label
		var first_choice := (((game.run_map.get("layers", []) as Array)[0] as Dictionary).get("choices", []) as Array)[0] as Dictionary
		_assert(!next_marker.disabled and next_detail_label.text.contains(str(first_choice.get("label", ""))), "the accessible next node should retain its resolved map label beside the control")
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
		hidden_third_marker = (map_route.find_child("MapStep03", false, false) as Control).find_child("MapNodeLabel", true, false) as Label
		hidden_fourth_marker = (map_route.find_child("MapStep04", false, false) as Control).find_child("MapNodeLabel", true, false) as Label
		var third_choice := (((game.run_map.get("layers", []) as Array)[2] as Dictionary).get("choices", []) as Array)[0] as Dictionary
		_assert(hidden_third_marker.text.contains(str(third_choice.get("label", ""))) and hidden_third_marker.text.contains("普通故障"), "revealed node 3 should show its resolved label and type details")
		_assert(hidden_fourth_marker.text.contains("工程整备室") and hidden_fourth_marker.text.contains("整备"), "revealed node 4 should show its label and type details")
	game.current_layer = 10
	game._render_state()
	await process_frame
	await process_frame
	if map_route != null and map_route.get_child_count() == 12:
		var service_marker := (map_route.find_child("MapStep11", false, false) as Control).find_child("MapNodeLabel", true, false) as Label
		_assert(service_marker != null and service_marker.text.contains("整备"), "node 11 should render the service label")
	game.current_layer = 11
	game._render_state()
	await process_frame
	if map_route != null and map_route.get_child_count() == 12:
		var boss_step := map_route.find_child("MapStep12", false, false) as Control
		var boss_marker := boss_step.find_child("MapNodeButton", true, false) as Button
		var boss_detail := boss_step.find_child("MapNodeLabel", true, false) as Label
		_assert(boss_detail.text.contains("综合验收"), "node 12 should render the boss label")
		var boss_style := boss_marker.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(boss_style != null and boss_style.border_color.is_equal_approx(Color("#8b69da")), "available Boss should retain violet styling")
	game.current_layer = 0
	game._render_state()
	await process_frame

	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()
	await process_frame
	_assert(combat_view.visible and !map_view.visible, "combat state should show only combat view")
	if combat_sound_toggle != null:
		_assert(combat_sound_toggle.is_visible_in_tree(), "combat sound toggle should be visible during combat at %s" % size)
		_assert(
			viewport_rect.encloses(combat_sound_toggle.get_global_rect()),
			"combat sound toggle should stay inside the viewport at %s: toggle=%s root=%s"
			% [size, combat_sound_toggle.get_global_rect(), combat_sound_toggle.get_parent().get_global_rect()]
		)
		_assert(combat_sound_toggle.custom_minimum_size.y >= 40.0 or combat_sound_toggle.size.y >= 40.0, "combat sound toggle should remain touchable at %s" % size)
	if combat_feedback_flash != null:
		_assert(combat_feedback_flash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "combat flash should never intercept input")
	game._emit_combat_feedback(
		"fault_triggered",
		"故障规则触发",
		"测试反馈条边界与可读性",
		Color("#b75a3a"),
		""
	)
	await process_frame
	if combat_feedback_banner != null:
		_assert(combat_feedback_banner.is_visible_in_tree(), "combat feedback banner should become visible after an event at %s" % size)
		_assert(viewport_rect.encloses(combat_feedback_banner.get_global_rect()), "combat feedback banner should stay inside the viewport at %s" % size)
		_assert(combat_feedback_banner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "combat feedback banner should never intercept input")
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
		game._card_copy("display_buffer"),
		game._card_copy("time_slice"),
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
		_assert(dock_proportion >= 0.40 and dock_proportion <= 0.48, "desktop portrait-card dock should use 40-48%% of playable height, got %.1f%%" % (dock_proportion * 100.0))
		_assert(arena.size.y >= hand_dock.size.y * 0.92, "desktop encounter arena should remain balanced with the enlarged hand dock")
	if device_unit != null and evidence_bridge != null and fault_unit != null:
		_assert(device_unit.clip_contents and evidence_bridge.clip_contents, "support frame art should stay clipped to its combat panels")
		var fault_zone = game.find_child("FaultZone", true, false) as Control
		_assert(fault_zone != null and fault_zone.clip_contents, "fault frame art should stay inside the enemy lane")
		_assert(device_unit.get_global_rect().position.x <= evidence_bridge.get_global_rect().position.x and evidence_bridge.get_global_rect().position.x <= fault_unit.get_global_rect().position.x, "desktop arena should order device, evidence, then fault")
		if enemy_intent != null:
			_assert(enemy_intent.get_parent().name == "FaultArtStack", "desktop intent should float above the enemy art rather than consume a separate row")
			_assert(enemy_intent.size.x <= 154.0 and enemy_intent.size.y <= 42.0, "desktop intent badge should stay compact")
	if hand_row.get_child_count() > 0:
		var first_card := hand_row.get_child(0) as Control
		_assert(first_card.has_method("configure_card"), "hand should use the reusable production card view at %s" % size)
		_assert(first_card.custom_minimum_size.y > first_card.custom_minimum_size.x, "hand cards should use the approved portrait format at %s, got %s" % [size, first_card.custom_minimum_size])
		_assert(first_card.size.y > first_card.size.x and first_card.size.x >= 146.0 and first_card.size.x <= 156.0, "hand cards should remain readable portraits after container layout at %s, got %s" % [size, first_card.size])
		_assert(first_card.custom_minimum_size.y >= 210.0, "desktop hand cards should reserve the production 210px artwork height")
		_assert(first_card.get_node_or_null("CardCostOrb") != null, "hand cards should expose the protruding cost orb at %s" % size)
		_assert(first_card.get_node_or_null("CardArt") != null, "hand cards should expose the approved artwork slot at %s" % size)
	if !viewport_rect.encloses(end_turn.get_global_rect()):
		print("END_TURN_RECT %s VIEWPORT %s" % [end_turn.get_global_rect(), viewport_rect])
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "end turn button should stay inside viewport at %s" % size)
	_assert(end_turn.custom_minimum_size.y >= 44.0, "primary touch target should be at least 44 px high")
	_assert(end_turn.get_global_rect().end.y <= run_footer.get_global_rect().position.y, "End turn should stay above the footer")
	if chain_strip != null and chain_collect != null and chain_interface != null and chain_process != null and chain_output != null:
		_assert(chain_strip.is_visible_in_tree(), "engineering-chain strip should stay visible at %s" % size)
		_assert(chain_collect.is_visible_in_tree() and chain_interface.is_visible_in_tree() and chain_process.is_visible_in_tree() and chain_output.is_visible_in_tree(), "engineering-chain stages should stay visible at %s" % size)
		_assert(chain_current_status != null and chain_current_status.text.contains("当前") and chain_current_status.text.contains("采集"), "chain strip should show the current stage without an unexplained abbreviation at %s" % size)
		_assert(chain_next_status != null and chain_next_status.text.contains("下一") and chain_next_status.text.contains("接口"), "chain strip should show the next stage without an unexplained abbreviation at %s" % size)
		_assert(chain_reward_status != null and chain_reward_status.text.contains("奖励") and chain_reward_status.text.contains("防护"), "chain strip should localize the pending threshold reward at %s" % size)
		var minimum_status_widths := [64.0, 72.0, 100.0]
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
			_assert(status_node != null and status_node.get_theme_font_size("font_size") >= 12, "%s should use readable desktop status text" % [status_node.name if status_node != null else "chain status"])
		var advancing_card = game.find_child("HandCard_adc_convert_0", true, false) as Button
		var preserving_card = game.find_child("HandCard_neutral_preview_1", true, false) as Button
		var preserving_power_card = game.find_child("HandCard_display_buffer_2", true, false) as Button
		var preserving_defense_card = game.find_child("HandCard_time_slice_3", true, false) as Button
		var breaking_card = game.find_child("HandCard_uart_log_4", true, false) as Button
		_assert(advancing_card != null and advancing_card.text.contains("推进") and advancing_card.text.contains("+3 防护"), "interface card should explicitly preview advancement and its reward at %s" % size)
		_assert(preserving_card != null and preserving_card.text.contains("保持"), "neutral card should explicitly preview chain preservation at %s" % size)
		_assert(preserving_power_card != null and preserving_power_card.text.contains("保持"), "out-of-order power card should explicitly preview chain preservation at %s" % size)
		_assert(preserving_defense_card != null and preserving_defense_card.text.contains("保持"), "out-of-order defense card should explicitly preview chain preservation at %s" % size)
		_assert(breaking_card != null and breaking_card.text.contains("中断"), "out-of-order output card should explicitly preview a chain break at %s" % size)
		if hand_scroll != null:
			_assert(chain_strip.get_global_rect().end.y <= hand_scroll.get_global_rect().position.y, "engineering-chain strip should sit above the horizontal hand dock at %s" % size)
	if reroute_button != null and reroute_cancel_button != null:
		_assert(reroute_button.is_visible_in_tree() and !reroute_button.disabled, "reroute should be available before the first card at %s" % size)
		_assert(reroute_button.text == "换牌", "ordinary encounter should keep the standard reroute label at %s" % size)
		_assert(reroute_button.size.y >= 44.0 and end_turn.size.y >= 44.0, "reroute and end turn should be at least 44 px high at %s" % size)
		_assert(reroute_button.size.y <= 60.0 and end_turn.size.y <= 60.0, "hand-side actions should remain compact instead of stretching with the card row at %s" % size)
		_assert(!reroute_button.get_global_rect().intersects(end_turn.get_global_rect()), "reroute and end turn should be disjoint at %s" % size)
		_assert(game.begin_reroute(), "reroute should enter selection mode for UI verification")
		await process_frame
		_assert(reroute_cancel_button.is_visible_in_tree() and !reroute_cancel_button.disabled, "reroute cancellation should be visible during selection at %s" % size)
		_assert(reroute_button.custom_minimum_size.y >= 44.0 and reroute_cancel_button.custom_minimum_size.y >= 44.0, "reroute controls should use 44 px touch targets at %s" % size)
		_assert(!reroute_button.get_global_rect().intersects(end_turn.get_global_rect()) and !reroute_cancel_button.get_global_rect().intersects(end_turn.get_global_rect()), "reroute controls should not overlap end turn at %s" % size)
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
		_assert((reward_cards as GridContainer).columns == 3, "normal reward cards should use the desktop three-column layout")
		for reward_card in reward_cards.get_children():
			_assert((reward_card as Control).custom_minimum_size.y >= 88.0, "normal reward cards should remain visually scannable")
			_assert(viewport_rect.intersects((reward_card as Control).get_global_rect()), "normal reward card should remain visible at %s" % size)
			var reward_text := (reward_card as Button).text
			_assert(reward_text.contains("协同") or reward_text.contains("补链") or reward_text.contains("反制"), "normal reward cards should display their composition reason")
		_assert((reward_skip as Control).custom_minimum_size.y < (reward_cards.get_child(0) as Control).custom_minimum_size.y, "reward skip should be visually secondary to reward cards")
	_assert_visible_primary_command_heights(game)

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game.boss_gate_ids.assign(["two_sources", "trusted_and_filter", "two_output_types"])
	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 1
	game._apply_boss_phase()
	game._render_state()
	await process_frame
	if gate_label != null:
		_assert(gate_label.text.contains("可信来源 0 / 2") and gate_label.text.contains("滤波 0 / 1"), "boss phase two should expose its selected trusted-and-filter gate")
	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	await process_frame
	for fault_row in [fault_intent_row, fault_rule_row, fault_counter_row, fault_rule_state]:
		_assert(fault_row != null and !fault_row.is_visible_in_tree(), "%s should stay hidden during Boss combat at %s" % [fault_row.name if fault_row != null else "fault row", size])
	if gate_label != null:
		_assert(gate_label.text.contains("不同输出 0 / 2"), "boss phase three should expose its selected two-distinct-output gate")
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
	_assert(choice_backdrop is ColorRect and (choice_backdrop as ColorRect).color.get_luminance() > 0.75, "choice states should use the light console canvas")
	_assert(reward_cards != null, "reward should expose a dedicated card row")
	if choice_list != null:
		_assert(choice_list is GridContainer, "choice states should use a responsive grid")
		_assert((choice_list as GridContainer).columns == 2, "choice grid should use the desktop two-column layout")
	if reward_cards != null:
		_assert(reward_cards.get_child_count() == 0, "empty reward fallback should render no blank reward cards")
	_assert(reward_skip != null and reward_skip.visible, "empty reward fallback should retain the skip command")
	_assert_visible_primary_command_heights(game)
	game.reward_choices = [game._card_copy("mq2_sample")]
	game._render_state()
	await process_frame
	var reward_card = reward_cards.get_child(0) as Button if reward_cards != null and reward_cards.get_child_count() > 0 else null
	_assert(reward_card != null and reward_card.has_method("configure_card"), "reward choices should use the reusable production card view")
	_assert(reward_card != null and reward_card.get_node_or_null("CardArt") != null, "reward choices should expose approved artwork")
	_assert(reward_card != null and reward_card.custom_minimum_size == Vector2(212, 306), "reward choices should use the complete inspection-card layout")
	_assert(_has_complete_card_face(reward_card), "reward choices should show cost, title, art, type, effect, and footer")
	_assert(reward_cards != null and reward_cards.get_global_rect().size.x <= 660.0, "reward cards should form a centered complete-card row")
	if reward_card != null:
		_assert(choice_scroll.get_global_rect().encloses(reward_card.get_global_rect()), "reward cards should show their complete face without initial clipping")
	_assert(reward_skip != null and choice_scroll != null and choice_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "reward skip should remain reachable below the complete card row")

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
		"penalty": {"op": "heal", "amount": -99, "minimum": 1}
	}
	game.state = game.RunState.EVENT
	game.event_answer_locked = false
	game.event_result.clear()
	game._render_state()
	await process_frame
	_assert(question_explanation != null and question_explanation.visible and question_explanation.text.contains("事件数据无效"), "malformed event should display its safe data-error explanation immediately")
	_assert(question_continue != null and question_continue.visible, "malformed event should expose a safe continue command")

	game.stability = 40
	var event_selection_stability: int = game.stability
	game.current_event = {
		"id": "event_selection_overlay",
		"options": [{
			"effects": [
				{"op": "select_card", "cardIds": ["logic_probe"]},
				{"op": "heal", "amount": 3}
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
	var selection_card = selection_options.get_child(0) as Button if selection_options != null and selection_options.get_child_count() > 0 else null
	_assert(selection_card != null and selection_card.has_method("configure_card"), "card-selection overlays should use the reusable production card view")
	_assert(combat_view != null and !combat_view.visible and end_turn != null and !end_turn.is_visible_in_tree(), "event-owned selection should not expose combat actions")
	_assert(game.choose_pending_card(0), "event-owned overlay should dispatch to its declared owner")
	game._render_state()
	await process_frame
	_assert(game.state == game.RunState.MAP and game.stability == event_selection_stability + 3, "event-owned overlay should resume its event continuation")
	_assert(selection_modal != null and !selection_modal.is_visible_in_tree(), "shared overlay should close after its event continuation resolves")
	for deck_index in range(game.deck.size() - 1, -1, -1):
		if str((game.deck[deck_index] as Dictionary).get("id", "")) == "logic_probe":
			game.deck.remove_at(deck_index)

	game.current_node = {"type": "service", "label": "工程整备室"}
	game.state = game.RunState.REST
	game.current_layer = 9
	game._render_state()
	await process_frame
	var service_bench = game.find_child("ServiceBench", true, false)
	var component_rack = game.find_child("ComponentRack", true, false)
	_assert(game.choice_title != null and game.choice_title.text.contains("工程整备室"), "service should render the current route-node title")
	_assert(service_bench != null and service_bench.visible, "service should present the engineering maintenance bench")
	_assert(choice_list != null and choice_list.get_child_count() == 5, "service room should expose four tradeoffs and one free skip")
	if service_bench != null and choice_list != null:
		for action in choice_list.get_children():
			_assert((action as Control).custom_minimum_size.y >= 104.0, "service actions should read as full engineering-operation tiles")
			_assert((action as Button).text.contains("\n"), "service actions should separate command and consequence")
	_assert(game.choose_service("add"), "service card supply should open its card selection")
	game._render_state()
	await process_frame
	_assert(selection_modal != null and selection_modal.is_visible_in_tree(), "service card supply should use the shared selection overlay")
	_assert(selection_options != null and selection_options.get_child_count() == 3, "service card supply should offer three cards")
	_assert(selection_options != null and selection_options.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "service card supply should center its complete-card row")
	var service_card = selection_options.get_child(0) as Button if selection_options != null and selection_options.get_child_count() > 0 else null
	_assert(service_card != null and service_card.custom_minimum_size == Vector2(212, 306), "service card supply should use complete inspection cards")
	_assert(_has_complete_card_face(service_card), "service card supply should show the complete card face")
	_assert(game.choose_pending_card(0), "service card supply fixture should resolve")
	game.component_choices = [
		{"id": "precision_reference", "name": "精密基准源", "description": "每场第一张校准牌费用为 0。"},
		{"id": "dma_channel", "name": "DMA 通道", "description": "每场第一张缓冲牌额外抽 1 张。"},
		{"id": "trace_probe", "name": "跟踪探针", "description": "每场第一张诊断牌额外获得防护。"},
	]
	game.state = game.RunState.COMPONENT
	game._render_state()
	await process_frame
	_assert(component_rack != null and component_rack.visible, "component selection should expose a persistent rack-status strip")
	_assert(service_bench != null and !service_bench.visible, "service bench should hide during component selection")
	_assert(choice_list != null and choice_list.columns == 3, "three component candidates should form one balanced desktop row")
	var component_accents := {}
	if choice_list != null:
		for action in choice_list.get_children():
			var component_button := action as Button
			_assert(component_button.custom_minimum_size.y >= 104.0, "component choices should use full engineering-module tiles")
			var component_style := component_button.get_theme_stylebox("normal") as StyleBoxFlat
			if component_style != null:
				component_accents[component_style.border_color.to_html()] = true
	_assert(component_accents.size() >= 2, "component choices should use distinct functional accents")
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
	game.knowledge_stats = {
		"tags": {
			"sensor-basics": {"positive": 2, "errors": 0},
			"data-trust": {"positive": 1, "errors": 1},
			"bus-scheduling": {"positive": 1, "errors": 0}
		},
		"questionCorrect": 1, "questionTotal": 2,
		"weaknessRepair": 8, "totalRepair": 16, "reviewFaultIds": []
	}
	game.state = game.RunState.RESULT
	game._render_state()
	await process_frame
	_assert(result_view.visible and !choice_view.visible, "result state should show result view")
	var result_heading = game.find_child("RunResultHeading", true, false)
	result_metrics = game.find_child("RunResultMetrics", true, false)
	var learning_summary = game.find_child("RunLearningSummary", true, false)
	_assert(result_heading != null and result_metrics != null and learning_summary != null, "result state should expose the refreshed result hierarchy")
	_assert(result_metrics_panel != null and result_learning_panel != null, "result state should organize metrics and learning evidence into two report panels")
	if learning_summary != null:
		_assert(learning_summary.text.contains("已掌握") and learning_summary.text.contains("继续加强") and learning_summary.text.contains("正在建立"), "result state should render all learning classifications")
	if result_metrics != null:
		_assert(result_metrics.text.contains("得分 87 / 100"), "result state should retain the score metric")
		_assert(result_metrics.text.contains("到达节点 12 / 12"), "result state should retain the node-count metric")
		_assert(result_metrics.text.contains("稳定度 55 / 70"), "result state should retain the stability metric")
		_assert(result_metrics.text.contains("检查点 2 / 2"), "result state should retain the checkpoint metric")
		_assert(result_metrics.text.contains("牌组 %d 张" % game.deck.size()), "result state should retain the deck-size metric")
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
		if button != null and button.is_visible_in_tree() and button.name != "EnemyIntent":
			_assert(button.size.y >= 44.0, "%s should be at least 44 px high when visible" % button.name)


func _has_complete_card_face(card: Button) -> bool:
	if card == null:
		return false
	for node_name in ["CardCostOrb", "CardTitle", "CardArt", "CardTypeStrip", "CardEffect", "CardFooter"]:
		if card.get_node_or_null(node_name) == null:
			return false
	return true


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
		_assert(tutorial_coach.get_global_rect().size.x <= 640.0, "%s coach should stay compact instead of masking the battlefield" % step_name)
		if step_name != "complete":
			_assert(tutorial_coach.get_global_rect().size.y <= 84.0, "%s coach should read as a slim operation rail" % step_name)
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
		var chain_preview := game._chain_preview_for_card(card) as Dictionary
		var support_text: String = str(game._chain_decision_label(str(chain_preview.get("decision", "preserves"))))
		var pending_reward := str(chain_preview.get("pendingReward", "none"))
		if pending_reward != "none":
			support_text += " · " + game._chain_reward_label(pending_reward)
		return "[%d] %s · %s\n%s\n%s" % [
			game._card_cost_preview(card),
			card.get("name", ""),
			card.get("type", ""),
			effect_text,
			support_text
		]
	return ""


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 graybox UI tests passed")
		quit(0)
