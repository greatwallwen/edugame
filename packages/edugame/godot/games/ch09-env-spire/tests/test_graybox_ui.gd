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
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()
	await process_frame

	DisplayServer.window_set_size(mobile_size)
	get_root().size = mobile_size
	game.size = Vector2(mobile_size)
	await process_frame
	await process_frame
	var hand_row = game.find_child("HandRow", true, false)
	var end_turn = game.find_child("EndTurnButton", true, false)
	var footer = game.get_node_or_null("Shell/RunFooter")
	_assert(hand_row != null and hand_row.get_child_count() > 0, "live resize should retain the rendered hand")
	if hand_row != null and hand_row.get_child_count() > 0:
		_assert((hand_row.get_child(0) as Control).custom_minimum_size.y <= 200.0, "live resize should compact existing cards")
	if end_turn != null and footer != null:
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "live resize should keep combat actions above the footer")
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
	var choice_description = game.find_child("ChoiceDescription", true, false)
	var gate_label = game.find_child("GateLabel", true, false)
	var restart_button = game.find_child("RestartButton", true, false)
	var arena = game.find_child("EncounterArena", true, false)
	var device_unit = game.find_child("DeviceUnit", true, false)
	var evidence_bridge = game.find_child("EvidenceBridge", true, false)
	var fault_unit = game.find_child("FaultUnit", true, false)
	var enemy_intent = game.find_child("EnemyIntent", true, false)
	var hand_dock = game.find_child("HandDock", true, false)
	var point_counter = game.find_child("ProcessingPointCounter", true, false)

	_assert(header != null, "header should exist at %s" % size)
	_assert(map_view != null and combat_view != null and choice_view != null and result_view != null, "all state views should exist")
	_assert(run_hud != null, "normal flow should expose a stable RunHud")
	_assert(scene_stage != null, "normal flow should expose a stable SceneStage")
	_assert(run_footer != null, "normal flow should expose a stable RunFooter")
	_assert(run_hud.theme == game.ui_theme, "RunHud should use the bundled UI theme")
	_assert(hand_row != null and end_turn != null and log_label != null and repair_bar != null, "combat controls, repair progress, and log should exist")
	_assert(choice_list != null, "choice states should expose a stable choice grid")
	_assert(gate_label != null and restart_button != null, "boss gate and result action should expose stable controls")
	_assert(arena != null, "combat should expose an encounter arena")
	_assert(device_unit != null and evidence_bridge != null and fault_unit != null, "combat should render device, evidence, and fault zones")
	_assert(enemy_intent != null, "fault intent should have a stable visual anchor")
	_assert(hand_dock != null and point_counter != null, "combat should expose a fixed action dock")
	_assert(map_route != null and map_route.get_child_count() == 12, "map climb should render twelve route nodes")
	_assert(map_enter != null and map_enter.custom_minimum_size.y >= 44.0, "map enter should be a full touch target")
	_assert(mission_summary != null and next_detail != null, "map should expose mission and next-node context")
	_assert(map_composition != null and map_route_scroll != null, "map should expose its responsive route composition")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
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
	if point_counter != null:
		_assert(point_counter.text.contains(str(game.processing_points)), "processing point counter should render the live point total")
	if arena != null and hand_dock != null:
		_assert(hand_dock.get_global_rect().position.y >= arena.get_global_rect().end.y, "hand dock should remain below the encounter arena at %s" % size)
	if footer != null and hand_dock != null:
		_assert(hand_dock.get_global_rect().end.y <= footer.get_global_rect().position.y, "hand dock should remain above the footer at %s" % size)
	if size.x < 720 and fault_unit != null and evidence_bridge != null and device_unit != null:
		_assert(fault_unit.get_global_rect().position.y <= evidence_bridge.get_global_rect().position.y and evidence_bridge.get_global_rect().position.y <= device_unit.get_global_rect().position.y, "compact arena should stack fault, evidence, then device")
	elif size.x >= 720 and device_unit != null and evidence_bridge != null and fault_unit != null:
		_assert(device_unit.get_global_rect().position.x <= evidence_bridge.get_global_rect().position.x and evidence_bridge.get_global_rect().position.x <= fault_unit.get_global_rect().position.x, "desktop arena should order device, evidence, then fault")
		if enemy_intent != null:
			_assert(enemy_intent.get_global_rect().end.y <= game.encounter_name_label.get_global_rect().position.y, "desktop enemy intent should sit above the fault details")
	if hand_row.get_child_count() > 0:
		var minimum_card_height := 180.0 if size.x < 720 else 220.0
		_assert((hand_row.get_child(0) as Control).custom_minimum_size.y >= minimum_card_height, "cards should use the available work area")
	if !viewport_rect.encloses(end_turn.get_global_rect()):
		print("END_TURN_RECT %s VIEWPORT %s" % [end_turn.get_global_rect(), viewport_rect])
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "end turn button should stay inside viewport at %s" % size)
	_assert(end_turn.custom_minimum_size.y >= 44.0, "primary touch target should be at least 44 px high")
	_assert(end_turn.get_global_rect().end.y <= run_footer.get_global_rect().position.y, "End turn should stay above the footer")
	_assert_visible_primary_command_heights(game)
	game.encounter_evidence_tags = {"smoke": true, "adc": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._render_state()
	await process_frame
	_assert(choice_description != null and choice_description.text.contains("调试报告"), "reward state should expose the latest debugging report")

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	await process_frame
	if gate_label != null:
		_assert(gate_label.text.contains("显示/上报") and gate_label.text.contains("报警/调度"), "boss phase three should expose both output gates")
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "boss phase three actions should stay inside viewport at %s" % size)
	if footer != null:
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "boss phase three action should not be covered by the footer at %s" % size)

	game.state = game.RunState.REWARD
	game.reward_choices = [game._card_copy("threshold_judgement")]
	game._render_state()
	await process_frame
	_assert(choice_view.visible and !combat_view.visible, "reward state should show choice view")
	var choice_backdrop = game.find_child("SceneChoiceBackdrop", true, false)
	var choice_context = game.find_child("SceneChoiceContext", true, false)
	var reward_cards = game.find_child("RewardCards", true, false)
	var reward_skip = game.find_child("RewardSkipButton", true, false)
	_assert(choice_backdrop != null and choice_context != null, "choice states should retain scene context")
	_assert(reward_cards != null, "reward should expose a dedicated card row")
	if reward_cards != null and reward_skip != null and reward_cards.get_child_count() > 0:
		_assert((reward_skip as Control).custom_minimum_size.y < (reward_cards.get_child(0) as Control).custom_minimum_size.y, "reward skip should be visually secondary to reward cards")
	if choice_list != null:
		_assert(choice_list is GridContainer, "choice states should use a responsive grid")
		_assert((choice_list as GridContainer).columns == (1 if size.x < 720 else 2), "choice grid should adapt its column count")
	if reward_cards != null:
		_assert(reward_cards.get_child_count() == 1, "one reward should render in the dedicated reward row")
		if reward_cards.get_child_count() > 0:
			_assert((reward_cards.get_child(0) as Control).custom_minimum_size.y >= 88.0, "reward cards should be visually scannable")

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

	var run_states: Dictionary = game.get_script().get_script_constant_map().get("RunState", {})
	if !run_states.has("COMPONENT"):
		_assert(false, "component node should expose a dedicated run state")
	else:
		game.state = game.RunState.MAP
		game.current_layer = 5
		game.choose_node(0)
		game._render_state()
		await process_frame
		_assert(choice_view.visible, "component state should reuse the choice view")
		_assert(choice_list.get_child_count() == 3, "component node should render three choices")
		if choice_list.get_child_count() > 0:
			_assert(!(choice_list.get_child(0) as Button).text.is_empty(), "component choice should have a readable label")

	game._finish_run(true)
	game._render_state()
	await process_frame
	_assert(result_view.visible and !choice_view.visible, "result state should show result view")
	var result_heading = game.find_child("RunResultHeading", true, false)
	var result_metrics = game.find_child("RunResultMetrics", true, false)
	var learning_summary = game.find_child("RunLearningSummary", true, false)
	_assert(result_heading != null and result_metrics != null and learning_summary != null, "result state should expose the refreshed result hierarchy")
	if learning_summary != null:
		_assert(learning_summary.text.contains("调试报告"), "result state should retain the run's debugging report summary")
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
		var lab_scenario = game.find_child("NodeLabScenario_mq2_warmup", true, false)
		var lab_root = game.find_child("NodeLabRoot", true, false)
		_assert(lab_catalog != null and lab_catalog.visible, "node lab catalog should be visible at %s" % size)
		_assert(lab_root != null and lab_root.theme == game.ui_theme, "node lab should inherit the bundled UI font theme")
		_assert(!game.shell.visible, "node lab catalog should hide the normal shell")
		_assert(lab_return != null and lab_restart != null, "node lab should expose stable scenario controls")
		_assert(lab_scenario != null, "node lab should render generated scenario buttons")
		if lab_scenario != null:
			_assert((lab_scenario as Control).custom_minimum_size.y >= 44.0, "lab scenario touch target should be at least 44 px")
			_assert(viewport_rect.intersects((lab_scenario as Control).get_global_rect()), "first lab scenario should be visible at %s" % size)
		game.start_lab_scenario({
			"id": "sensor_replacement",
			"kind": "event",
			"contentId": "sensor_replacement"
		})
		await process_frame
		_assert(!lab_catalog.visible, "starting a lab scenario should hide the catalog")
		_assert(!run_hud.visible and game.shell.visible and game.shell.offset_top == 58.0, "scenario toolbar should replace RunHud")
		_assert(lab_return.visible and lab_restart.visible, "scenario controls should remain visible during lab play")
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


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 graybox UI tests passed")
		quit(0)
