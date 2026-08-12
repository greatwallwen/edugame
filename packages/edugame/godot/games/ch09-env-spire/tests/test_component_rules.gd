extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame

	_start_with(game, "pullup_4k7", "i2c_congestion", "elite")
	_assert(game.diagnosis == 1, "pull-up resistor should grant diagnosis in an I2C encounter")

	_start_with(game, "serial_helper")
	var uart := _fixture_card("uart", ["uart"], 2)
	_assert(game._card_cost_preview(uart) == 0, "serial helper should make the first UART card free")
	game.hand = [uart.duplicate(true)]
	_assert(game.play_card(0), "serial helper fixture should play")
	_assert(game._card_cost_preview(uart) == 2, "serial helper should be consumed after one UART card")

	_start_with(game, "precision_reference")
	var calibration := _fixture_card("calibration", ["calibration"], 2)
	_assert(game._card_cost_preview(calibration) == 0, "precision reference should make the first calibration free")
	game.hand = [calibration.duplicate(true)]
	_assert(game.play_card(0), "precision reference fixture should play")
	_assert(game._card_cost_preview(calibration) == 2, "precision reference should trigger once per encounter")

	_start_with(game, "window_n8")
	game.hand = [_fixture_card("filter", ["filter"], 0), _fixture_card("filter_2", ["filter"], 0)]
	_assert(game.play_card(0) and game.block == 4, "window should add four block on the first filter")
	_assert(game.play_card(0) and game.block == 4, "window should not repeat in the same encounter")

	_start_with(game, "dma_channel")
	game.draw_pile = [_fixture_card("drawn", [], 0)]
	game.hand = [_fixture_card("buffer", ["buffer"], 0)]
	_assert(game.play_card(0) and game._hand_has_card("drawn"), "DMA channel should draw after the first buffer card")

	_start_with(game, "watchdog_timer")
	game.stability = 30
	game._take_damage(9)
	_assert(game.stability == 25, "watchdog should reduce the first damage by four")
	game._take_damage(9)
	_assert(game.stability == 16, "watchdog should not reduce a second hit")

	_start_with(game, "shielded_cable")
	game.repair_target = 99
	game.hand = [_fixture_card("analog", ["analog"], 0), _fixture_card("analog_2", ["analog"], 0)]
	_assert(game.play_card(0) and game.repair_progress == 3, "shielded cable should add three repair once")
	_assert(game.play_card(0) and game.repair_progress == 3, "shielded cable should not repeat in the same encounter")

	_start_with(game, "trace_probe")
	game.hand = [_fixture_card("diagnosis", ["diagnosis"], 0)]
	_assert(game.play_card(0) and game.block == 5, "trace probe should add five block after diagnosis")

	_start_with(game, "lcd_buffer")
	game.processing_points = 3
	game._apply_negative_draw(game._negative_card("blocking_delay"))
	_assert(game.processing_points == 3, "LCD buffer should ignore the first blocking delay")
	game._apply_negative_draw(game._negative_card("blocking_delay"))
	_assert(game.processing_points == 2, "LCD buffer should allow later blocking delays")

	_start_with(game, "state_template")
	game.draw_pile = [_fixture_card("chain_drawn", [], 0)]
	game.hand = []
	for stage in ["collect", "interface", "process", "output"]:
		game.hand.append(_fixture_card(stage, [], 0, stage))
	for _index in range(4):
		_assert(game.play_card(0), "state template should accept each chain stage")
	_assert(game._hand_has_card("chain_drawn"), "state template should draw on the first completed chain")

	_start_with(game, "watchdog_timer", "warehouse_acceptance", "boss")
	game._take_damage(5)
	_assert(bool(game.component_tracking.get("first_damage_reduction", false)), "Boss encounter should consume its watchdog")
	game.boss_phase = 1
	game._apply_boss_phase()
	_assert(bool(game.component_tracking.get("first_damage_reduction", false)), "Boss phase changes should not reset component tracking")
	game._start_encounter("mq2_warmup", "ordinary")
	_assert(!bool(game.component_tracking.get("first_damage_reduction", false)), "a new encounter should reset component tracking")

	game.queue_free()
	await process_frame
	if failures > 0:
		quit(1)
	else:
		print("Ch09 component rule tests passed")
		quit(0)


func _start_with(game, component_id: String, enemy_id: String = "mq2_warmup", tier: String = "ordinary") -> void:
	game._reset_run()
	game.relics = [component_id]
	game._activate_relic(component_id)
	game.current_node = {"type": tier, "contentId": enemy_id}
	game._start_encounter(enemy_id, tier)


func _fixture_card(card_id: String, tags: Array, cost: int, stage: String = "process") -> Dictionary:
	return {
		"id": card_id,
		"name": card_id,
		"stage": stage,
		"type": stage,
		"tags": tags,
		"cost": cost,
		"effects": [],
		"upgraded": false
	}


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
