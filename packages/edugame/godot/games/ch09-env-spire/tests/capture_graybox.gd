extends SceneTree

const OUT_DIR := "C:/Users/sy/Desktop/dgbook-ref-main/dgbook-ref/.superpowers/visual-qa/ch09-env-spire"


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
	quit(0)


func _settle() -> void:
	await create_timer(0.25).timeout
	for _index in range(3):
		await process_frame


func _capture(filename: String) -> void:
	await _settle()
	var image := get_root().get_texture().get_image()
	var result := image.save_png(OUT_DIR.path_join(filename))
	if result != OK:
		push_error("could not save capture: %s" % filename)
		quit(1)
