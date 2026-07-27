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
	var map_timeline = game.find_child("MapTimeline", true, false)
	var choice_list = game.find_child("ChoiceList", true, false)
	var choice_description = game.find_child("ChoiceDescription", true, false)
	var gate_label = game.find_child("GateLabel", true, false)
	var restart_button = game.find_child("RestartButton", true, false)

	_assert(header != null, "header should exist at %s" % size)
	_assert(map_view != null and combat_view != null and choice_view != null and result_view != null, "all state views should exist")
	_assert(run_hud != null, "normal flow should expose a stable RunHud")
	_assert(scene_stage != null, "normal flow should expose a stable SceneStage")
	_assert(run_footer != null, "normal flow should expose a stable RunFooter")
	_assert(run_hud.theme == game.ui_theme, "RunHud should use the bundled UI theme")
	_assert(hand_row != null and end_turn != null and log_label != null and repair_bar != null, "combat controls, repair progress, and log should exist")
	_assert(choice_list != null, "choice states should expose a stable choice grid")
	_assert(gate_label != null and restart_button != null, "boss gate and result action should expose stable controls")
	_assert(map_timeline != null and map_timeline.get_child_count() == 12, "map should render a twelve-stage timeline")
	if map_timeline != null and map_timeline.get_child_count() > 0:
		_assert((map_timeline.get_child(0) as Control).custom_minimum_size.y >= 52.0, "timeline stages should be visually scannable")
	if header != null:
		_assert(header.theme != null and header.theme.default_font != null, "bundled Chinese font should be installed")
		_assert(game.ui_font.resource_path == game.UI_FONT_PATH, "UI font should use the imported resource for Web export")
		_assert(game.ui_font.has_char("选".unicode_at(0)), "UI font should contain Chinese glyphs")
	_assert(map_view != null and map_view.visible, "map view should be visible after reset")
	_assert(combat_view != null and !combat_view.visible, "combat view should be hidden on map")

	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game._start_encounter("mq2_warmup", "ordinary")
	game._render_state()
	await process_frame
	_assert(combat_view.visible and !map_view.visible, "combat state should show only combat view")
	_assert(hand_row.get_child_count() == game.hand.size(), "hand row should render one button per card")
	if hand_row.get_child_count() > 0:
		var minimum_card_height := 180.0 if size.x < 720 else 220.0
		_assert((hand_row.get_child(0) as Control).custom_minimum_size.y >= minimum_card_height, "cards should use the available work area")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
	if !viewport_rect.encloses(end_turn.get_global_rect()):
		print("END_TURN_RECT %s VIEWPORT %s" % [end_turn.get_global_rect(), viewport_rect])
	_assert(viewport_rect.encloses(end_turn.get_global_rect()), "end turn button should stay inside viewport at %s" % size)
	_assert(end_turn.custom_minimum_size.y >= 44.0, "primary touch target should be at least 44 px high")
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
	if choice_list != null:
		_assert(choice_list is GridContainer, "choice states should use a responsive grid")
		_assert(choice_list.get_child_count() == 2, "one reward and the skip action should render")
		_assert((choice_list.get_child(0) as Control).custom_minimum_size.y >= 88.0, "choice cards should be visually scannable")
		_assert((choice_list as GridContainer).columns == (1 if size.x < 720 else 2), "choice grid should adapt its column count")

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
	var result_summary = game.find_child("ResultSummary", true, false)
	_assert(result_summary != null and result_summary.text.contains("调试报告"), "result state should retain the run's debugging report summary")
	if restart_button != null:
		_assert(restart_button.size.x <= 360.0, "desktop result action should not stretch across the work area")
		_assert(viewport_rect.encloses(restart_button.get_global_rect()), "result action should stay inside viewport at %s" % size)

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
		_assert(lab_return.visible and lab_restart.visible, "scenario controls should remain visible during lab play")
		_assert(viewport_rect.encloses(lab_return.get_global_rect()), "lab return control should stay inside viewport at %s" % size)
		_assert(viewport_rect.encloses(lab_restart.get_global_rect()), "lab restart control should stay inside viewport at %s" % size)
		game.start_lab_scenario({
			"id": "mq2_warmup",
			"kind": "enemy",
			"contentId": "mq2_warmup",
			"tier": "ordinary"
		}, "coverage")
		await process_frame
		_assert(!header.visible, "lab toolbar should replace the normal game header during scenarios")
		_assert(end_turn.get_global_rect().end.y <= footer.get_global_rect().position.y, "lab combat action should stay above the footer at %s" % size)

	game.queue_free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 graybox UI tests passed")
		quit(0)
