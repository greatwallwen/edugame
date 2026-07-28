extends SceneTree

const OUT_DIR := "C:/Users/sy/Desktop/dgbook-ref-main/dgbook-ref/.superpowers/visual-qa/ch09-env-spire"

var capture_failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var mobile := OS.get_cmdline_user_args().has("--mobile")
	var scene := load("res://scenes/main.tscn")
	if scene == null:
		push_error("main scene should load")
		quit(1)
		return

	get_root().size = Vector2i(390, 844) if mobile else Vector2i(1280, 720)
	var game = scene.instantiate()
	get_root().add_child(game)
	await _settle()
	print("capture viewport=", get_root().size, " control=", game.size, " window=", DisplayServer.window_get_size())
	game._start_tutorial_briefing()
	game._render_state()
	await _capture("39-mobile-tutorial-briefing.png" if mobile else "19-desktop-tutorial-briefing.png")

	game._start_tutorial_encounter()
	await _capture("40-mobile-tutorial-intent.png" if mobile else "20-desktop-tutorial-intent.png")

	if !_advance_tutorial(game, func() -> bool: return game.confirm_tutorial_intent(), game.TutorialStep.PLAY_DEFENSE, "confirm intent"):
		return
	await _capture("41-mobile-tutorial-defense.png" if mobile else "21-desktop-tutorial-defense.png")

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.END_TURN, "play defense"):
		return
	await _capture("42-mobile-tutorial-end-turn.png" if mobile else "22-desktop-tutorial-end-turn.png")

	if !_advance_tutorial(game, func() -> bool: return game.end_turn(), game.TutorialStep.PLAY_SAMPLE, "end turn"):
		return
	await _capture("43-mobile-tutorial-sample.png" if mobile else "23-desktop-tutorial-sample.png")

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_CONVERT, "play sample"):
		return
	await _capture("44-mobile-tutorial-convert.png" if mobile else "24-desktop-tutorial-convert.png")

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.PLAY_OUTPUT, "play conversion"):
		return
	await _capture("45-mobile-tutorial-output.png" if mobile else "25-desktop-tutorial-output.png")

	if !_advance_tutorial(game, func() -> bool: return game.play_card(0), game.TutorialStep.COMPLETE, "play output"):
		return
	await _capture("46-mobile-tutorial-complete.png" if mobile else "26-desktop-tutorial-complete.png")

	game._reset_run()
	game._render_state()
	await _capture("21-mobile-map.png" if mobile else "01-desktop-map.png")

	game.choose_node(0)
	game._render_state()
	await _capture("22-mobile-combat.png" if mobile else "02-desktop-combat.png")

	game.encounter_evidence_tags = {"smoke": true, "adc": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._render_state()
	await _capture("23-mobile-reward.png" if mobile else "03-desktop-reward.png")

	game._open_shop()
	game._render_state()
	await _capture("24-mobile-shop.png" if mobile else "04-desktop-shop.png")

	game.state = game.RunState.REST
	game._render_state()
	await _capture("25-mobile-rest.png" if mobile else "05-desktop-rest.png")

	game.current_node = {"type": "checkpoint_sensor", "contentId": "sensor_checkpoint"}
	game._start_checkpoint(true)
	game._render_state()
	await _capture("26-mobile-checkpoint-sensor.png" if mobile else "06-desktop-checkpoint-sensor.png")

	game.current_node = {"type": "checkpoint_trust", "contentId": "trust_checkpoint"}
	game._start_checkpoint(false)
	game._render_state()
	await _capture("27-mobile-checkpoint-trust.png" if mobile else "07-desktop-checkpoint-trust.png")

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game._start_encounter("warehouse_acceptance", "boss")
	game._render_state()
	await _capture("28-mobile-boss-phase-1.png" if mobile else "08-desktop-boss-phase-1.png")
	game.boss_phase = 1
	game._apply_boss_phase()
	game._render_state()
	await _capture("29-mobile-boss-phase-2.png" if mobile else "09-desktop-boss-phase-2.png")
	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	await _capture("30-mobile-boss-phase-3.png" if mobile else "10-desktop-boss-phase-3.png")

	game.current_layer = 12
	game.checkpoints_passed = 2
	game._finish_run(true)
	game._render_state()
	await _capture("31-mobile-result.png" if mobile else "11-desktop-result.png")

	game._reset_run()
	game.current_node = {"type": "event", "contentId": "sensor_replacement"}
	game.current_event = (game.event_defs.get("sensor_replacement", {}) as Dictionary).duplicate(true)
	game.state = game.RunState.EVENT
	game._render_state()
	await _capture("35-mobile-event.png" if mobile else "15-desktop-event.png")

	game._reset_run()
	game.current_node = {"type": "component", "label": "工程组件"}
	game._open_component_choice()
	game._render_state()
	await _capture("36-mobile-component.png" if mobile else "16-desktop-component.png")

	game._reset_run()
	game.current_layer = 11
	game.current_node = {"type": "service", "label": "节点 11 · Boss 前整备"}
	game.state = game.RunState.REST
	game._render_state()
	await _capture("37-mobile-service-node-11.png" if mobile else "17-desktop-service-node-11.png")

	game._reset_run()
	game.current_node = {"type": "ordinary", "contentId": "mq2_warmup"}
	game.reward_choices.clear()
	game.state = game.RunState.REWARD
	game._render_state()
	await _capture("38-mobile-reward-fallback.png" if mobile else "18-desktop-reward-fallback.png")

	game._enter_node_lab()
	await _capture("32-mobile-node-lab.png" if mobile else "12-desktop-node-lab.png")

	game.start_lab_scenario({
		"id": "sensor_replacement",
		"label": "传感器替换",
		"kind": "event",
		"contentId": "sensor_replacement"
	}, "starter")
	await _capture("33-mobile-node-lab-event.png" if mobile else "13-desktop-node-lab-event.png")

	game.start_lab_scenario({
		"id": "mq2_warmup",
		"label": "MQ-2 预热不足",
		"kind": "enemy",
		"contentId": "mq2_warmup",
		"tier": "ordinary"
	}, "coverage")
	await _capture("34-mobile-node-lab-combat.png" if mobile else "14-desktop-node-lab-combat.png")

	game.queue_free()
	await process_frame
	print("Ch09 graybox captures written to: " + OUT_DIR)
	quit(1 if capture_failed else 0)


func _settle() -> void:
	await create_timer(0.25).timeout
	for _index in range(3):
		await process_frame


func _capture(filename: String) -> void:
	if capture_failed:
		return
	await _settle()
	var image := get_root().get_texture().get_image()
	if image == null:
		capture_failed = true
		push_error("could not capture %s: a rendered viewport is required" % filename)
		return
	var result := image.save_png(OUT_DIR.path_join(filename))
	if result != OK:
		capture_failed = true
		push_error("could not save capture: %s" % filename)


func _advance_tutorial(game, action: Callable, expected_step: int, action_name: String) -> bool:
	if !bool(action.call()):
		push_error("tutorial capture action failed: %s" % action_name)
		quit(1)
		return false
	if game.tutorial_step != expected_step:
		push_error("tutorial capture action reached the wrong step: %s" % action_name)
		quit(1)
		return false
	return true
