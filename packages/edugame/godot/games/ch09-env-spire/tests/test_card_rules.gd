extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	game._reset_run()

	_assert(game.deck.size() == 12, "starter deck should contain twelve cards")
	_assert(game.hand.size() == 5, "reset should draw five cards")
	_assert(game.processing_points == 3, "each turn should start with three processing points")

	game._start_encounter("mq2_warmup", "ordinary")
	game.block = 0
	game.diagnosis = 0
	game.repair_progress = 0
	game.processing_points = 3
	game.chain_count = 0
	game.last_stage = ""
	game.chain_rewards_claimed.clear()

	game.hand = [game._card_copy("mq2_sample")]
	_assert(game.play_card(0), "collect should begin the engineering chain")
	game.hand = [game._card_copy("adc_convert")]
	_assert(game.play_card(0), "interface should reach the two-stage threshold")
	_assert(game.chain_count == 1 and game.block == 3, "two stages should grant 3 block once")

	game.raw_data["smoke"] = 1
	game.hand = [game._card_copy("unit_convert")]
	_assert(game.play_card(0), "process should reach the three-stage threshold")
	_assert(game.chain_count == 2 and game.processing_points == 2, "three stages should refund one processing point")

	game.trusted_data["smoke"] = 1
	game.hand = [game._card_copy("uart_log")]
	var repair_before_chain: int = game.repair_progress
	_assert(game.play_card(0), "output should close the four-stage chain")
	_assert(game.chain_count == 3, "output should mark a complete chain")
	_assert(game.repair_progress >= repair_before_chain + 8, "complete chain should add 8 repair")
	_assert(game.diagnosis == 2, "UART diagnosis plus complete chain should grant two diagnosis")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("mq2_sample")]
	game.processing_points = 3
	_assert(game.play_card(0), "collect should prepare a defense chain")
	game.hand = [game._card_copy("adc_convert")]
	_assert(game.play_card(0), "interface should prepare a defense chain")
	game.hand = [game._card_copy("time_slice")]
	_assert(game.play_card(0), "defense card with the next stage should play")
	_assert(game.chain_count == 2, "defense card with the next valid stage should advance the chain")

	game.chain_count = 2
	game.last_stage = "process"
	game.hand = [game._card_copy("display_buffer")]
	game.processing_points = 3
	_assert(game.play_card(0), "power card with the next stage should play")
	_assert(game.chain_count == 3, "power card with the next valid stage should advance the chain")

	game.chain_count = 1
	game.last_stage = "interface"
	game.hand = [{"id": "neutral_stage", "cost": 0, "stage": "", "type": "utility", "effects": []}]
	_assert(game.play_card(0), "neutral-stage card should play")
	_assert(game.chain_count == 1 and game.last_stage == "interface", "empty stage should preserve chain progress")

	game._reset_turn_state(true)
	game.block = 0
	game.diagnosis = 0
	game.repair_progress = 0
	game.processing_points = 3
	game.chain_rewards_claimed.clear()
	for stage in ["collect", "interface", "process", "output"]:
		game._advance_chain(stage)
	var block_after_first_chain: int = game.block
	var points_after_first_chain: int = game.processing_points
	var repair_after_first_chain: int = game.repair_progress
	var diagnosis_after_first_chain: int = game.diagnosis
	for stage in ["collect", "interface", "process", "output"]:
		game._advance_chain(stage)
	_assert(game.block == block_after_first_chain, "repeat chain should not repeat the two-stage reward")
	_assert(game.processing_points == points_after_first_chain, "repeat chain should not repeat the three-stage reward")
	_assert(game.repair_progress == repair_after_first_chain and game.diagnosis == diagnosis_after_first_chain, "repeat chain should not repeat the complete-chain reward")

	game._reset_turn_state(true)
	game.block = 0
	game.diagnosis = 0
	game.repair_progress = 0
	game.processing_points = 3
	game.powers["chain_energy"] = 1
	game._advance_chain("collect")
	game._advance_chain("interface")
	_assert(game.block == 3, "active state template should retain the two-stage block reward")
	game._advance_chain("process")
	_assert(game.processing_points == 4, "active state template should receive exactly one three-stage processing-point refund")
	game._advance_chain("output")
	_assert(game.processing_points == 4, "complete chain should not add a legacy state-template processing-point refund")
	_assert(game.repair_progress == 8 and game.diagnosis == 1, "complete chain should grant exactly 8 repair and 1 diagnosis once")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("mq2_sample")]
	game.processing_points = 3
	_assert(bool(game.play_card(0)), "an affordable card should play")
	_assert(int(game.raw_data.get("smoke", 0)) == 1, "MQ-2 sample should preserve smoke source")
	_assert(game.processing_points == 2, "playing a one-cost card should spend one point")

	game.hand = [game._card_copy("adc_convert")]
	_assert(bool(game.play_card(0)), "ADC conversion should play")
	_assert(int(game.raw_data.get("smoke", 0)) == 0, "ADC conversion should consume smoke raw data")
	_assert(int(game.trusted_data.get("smoke", 0)) == 1, "ADC conversion should produce smoke trusted data")
	_assert(game.chain_count == 1, "collect followed by interface should start chain progression")

	game.hand = [game._card_copy("unit_convert")]
	_assert(bool(game.play_card(0)), "zero-cost process card should play")
	_assert(game.chain_count == 2, "interface followed by process should advance chain")

	game.hand = [game._card_copy("lcd_display")]
	game.trusted_data["smoke"] = 1
	_assert(bool(game.play_card(0)), "output should consume trusted data")
	_assert(game.chain_count == 3, "process followed by output should complete the chain")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("i2c_transaction")]
	game.processing_points = 0
	game.i2c_cost_penalty = 1
	game.powers["i2c_discount"] = 1
	_assert(!bool(game.play_card(0)), "a card should not play without enough processing points")
	_assert(game.hand.size() == 1, "failed card play should leave the card in hand")
	_assert(int(game.powers.get("i2c_discount", 0)) == 1, "insufficient energy should not consume an I2C discount")

	game.hand = [game._card_copy("threshold_judgement")]
	game.processing_points = 3
	game.powers["process_discount"] = 1
	game.trusted_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	_assert(!bool(game.play_card(0)), "a card should not play without required trusted data")
	_assert(int(game.powers.get("process_discount", 0)) == 1, "failed requirements should not consume a process discount")

	game.hand = [game._card_copy("sliding_average")]
	game.processing_points = 3
	game.block = 0
	game.discard_pile.append({"id": "abnormal_reading", "negative": true, "group": "noise"})
	_assert(bool(game.play_card(0)), "filter card should play")
	_assert(game.block >= 7, "sliding average should grant block")
	_assert(!game._pile_has_card("abnormal_reading"), "sliding average should remove an abnormal reading")

	game._reset_turn_state(true)
	game.hand = [game._card_copy("mq2_sample"), game._card_copy("bh1750_read")]
	game.draw_pile = [game._card_copy("sliding_average")]
	game.discard_pile.clear()
	_assert(game.begin_reroute(), "reroute should open before the first card")
	_assert(game.reroute_card(0), "reroute should replace one selected card")
	_assert(game.hand.size() == 2, "reroute should preserve hand size")
	_assert(str((game.hand[1] as Dictionary).get("id", "")) == "sliding_average", "reroute should draw the replacement")
	_assert(!game.begin_reroute(), "reroute should be limited to once per turn")

	game._reset_turn_state(false)
	game.hand = [game._card_copy("mq2_sample")]
	game.processing_points = 3
	_assert(game.play_card(0), "card should play before late reroute check")
	_assert(!game.begin_reroute(), "reroute should lock after the first card")

	game._reset_turn_state(true)
	game.hand = [game._card_copy("mq2_sample")]
	game.draw_pile.clear()
	game.discard_pile.clear()
	_assert(game.begin_reroute(), "reroute should open before an empty-pile attempt")
	_assert(!game.reroute_card(0), "reroute should fail when no replacement can be drawn")
	_assert(game.hand.size() == 1 and str((game.hand[0] as Dictionary).get("id", "")) == "mq2_sample", "empty-pile reroute should return the selected card to hand")
	_assert(game.reroute_available, "empty-pile reroute should remain available")

	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 2
	game._apply_boss_phase()
	var has_phase_output_property := false
	for property in game.get_property_list():
		if str((property as Dictionary).get("name", "")) == "phase_output_types":
			has_phase_output_property = true
			break
	if !has_phase_output_property:
		_assert(false, "boss encounters should track output tags for the active phase")
		game.queue_free()
		await process_frame
		_finish()
		return
	game.hand = [game._card_copy("time_slice")]
	game.processing_points = 3
	_assert(bool(game.play_card(0)), "scheduler defense card should play during boss acceptance")
	_assert(bool(game.phase_output_types.get("scheduler", false)), "scheduler tags should count toward final output acceptance")

	var has_persistent_output_property := false
	for property in game.get_property_list():
		if str((property as Dictionary).get("name", "")) == "persistent_output_types":
			has_persistent_output_property = true
			break
	if !has_persistent_output_property:
		_assert(false, "power cards should expose persistent output capability tracking")
		game.queue_free()
		await process_frame
		_finish()
		return
	game._start_encounter("warehouse_acceptance", "boss")
	game.hand = [game._card_copy("scheduler_template")]
	game.processing_points = 3
	_assert(bool(game.play_card(0)), "scheduler power should play")
	_assert(bool(game.persistent_output_types.get("scheduler", false)), "scheduler power should persist its capability")
	game.boss_phase = 2
	game._apply_boss_phase()
	game.phase_output_types = {"uart": true}
	_assert(game._boss_phase_requirements_met(), "persistent scheduler plus current UART should satisfy final acceptance")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 card rule tests passed")
		quit(0)
