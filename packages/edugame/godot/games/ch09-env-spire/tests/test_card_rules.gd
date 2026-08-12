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
	var starter_ids: Array = game.get_script().get_script_constant_map().get("STARTER_CARD_IDS", [])
	_assert(starter_ids == [
		"mq2_sample", "mq2_sample", "bh1750_read", "hdc1080_read",
		"adc_convert", "adc_convert", "i2c_transaction", "i2c_transaction",
		"unit_convert", "sliding_average", "sliding_average", "uart_log"
	], "starter counterplay should preserve the approved twelve-card composition and counts")
	_assert(starter_ids.count("unit_convert") == 1, "starter deck should keep one unit conversion")
	_assert(starter_ids.count("sliding_average") == 2, "starter deck should contain two filters")
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

	game.chain_count = 2
	game.last_stage = "process"
	game.hand = [game._card_copy("i2c_address_table")]
	game.processing_points = 3
	_assert(game.play_card(0), "out-of-order power card should play")
	_assert(game.chain_count == 2 and game.last_stage == "process", "out-of-order power card should preserve chain progress")

	game.chain_count = 2
	game.last_stage = "process"
	game.hand = [game._card_copy("bus_reset")]
	game.processing_points = 3
	_assert(game.play_card(0), "out-of-order defense card should play")
	_assert(game.chain_count == 2 and game.last_stage == "process", "out-of-order defense card should preserve chain progress")

	game.chain_count = 2
	game.last_stage = "process"
	game.hand = [{"id": "ordinary_out_of_order", "cost": 0, "stage": "interface", "type": "interface", "effects": []}]
	_assert(game.play_card(0), "out-of-order engineering card should remain legal")
	_assert(game.chain_count == 0 and game.last_stage == "interface", "out-of-order engineering card should still break and restart the chain")

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
	_assert_reroute_public_api_contract(game)

	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_gate_ids.assign(["two_sources", "trusted_and_filter", "two_output_types"])
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

	_assert_card_selection_effects(game)
	_assert_deferred_card_finalization(game)
	_assert_event_owned_selection(game)
	_assert_card_resolution_effects(game)
	_assert_chain_draw_state_template(game)
	_assert_reward_composition(game)
	_assert_lethal_deferred_effect_arbitration(game)
	_assert_boss_phase_hand_normalization(game)

	game.queue_free()
	await process_frame
	_finish()


func _assert_boss_phase_hand_normalization(game) -> void:
	_assert(game.has_method("_ensure_boss_phase_gate_card_in_hand"), "Boss should expose deterministic phase-opening hand normalization")
	if !game.has_method("_ensure_boss_phase_gate_card_in_hand"):
		return

	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_gate_ids.assign(["two_sources", "trusted_and_filter", "two_output_types"])
	game.boss_phase = 0
	game._apply_boss_phase()
	game.hand = [
		game._card_copy("sliding_average"),
		game._card_copy("time_slice"),
		game._card_copy("unit_convert"),
		game._card_copy("uart_log"),
		game._card_copy("state_machine")
	]
	game.draw_pile = [game._card_copy("time_slice")]
	_assert(game._ensure_boss_phase_gate_card_in_hand(), "missing phase answer should create one formal-card assistance copy")
	var generated_source_found := false
	for raw_card in game.hand:
		if str((raw_card as Dictionary).get("stage", "")) == "collect":
			generated_source_found = true
	_assert(generated_source_found and game.hand.size() == 5, "phase assistance should replace one hand card with a source")

	game.hand = [
		game._card_copy("sliding_average"), game._card_copy("time_slice"), game._card_copy("unit_convert"),
		game._card_copy("uart_log"), game._card_copy("state_machine")
	]
	game.draw_pile = [game._card_copy("mq2_sample")]
	var original_draw_size: int = game.draw_pile.size()
	_assert(game._ensure_boss_phase_gate_card_in_hand(), "owned source card should move into phase-one opening hand")
	_assert(game.hand.size() == 5, "phase search should swap instead of increasing hand size")
	_assert(game.draw_pile.size() == original_draw_size, "phase search should preserve draw-pile size")
	_assert(_pile_has_card_id(game.hand, "mq2_sample"), "phase-one hand should contain the owned source card")
	_assert(game._ensure_boss_phase_gate_card_in_hand(), "a multi-source gate may normalize a second complementary source")
	_assert(game.hand.size() == 5, "repeat phase assistance should preserve hand size")

	game.boss_phase = 1
	game._apply_boss_phase()
	game.phase_filters_played = 0
	game.phase_calibrations_played = 0
	game.hand = [
		game._card_copy("mq2_sample"),
		game._card_copy("bh1750_read"),
		game._card_copy("uart_log"),
		game._card_copy("lcd_display"),
		game._card_copy("time_slice")
	]
	game.draw_pile = [game._card_copy("sliding_average"), game._card_copy("adc_convert")]
	_assert(game._ensure_boss_phase_gate_card_in_hand(), "phase two should retrieve owned filter or calibration preparation")
	_assert(_pile_has_card_id(game.hand, "sliding_average"), "phase-two opening hand should prioritize preparation")

	game.boss_phase = 2
	game._apply_boss_phase()
	game.persistent_output_types = {"uart": true}
	game.phase_output_types.clear()
	game.hand = [
		game._card_copy("mq2_sample"),
		game._card_copy("bh1750_read"),
		game._card_copy("adc_convert"),
		game._card_copy("sliding_average"),
		game._card_copy("uart_log")
	]
	game.draw_pile = [game._card_copy("lcd_display")]
	_assert(game._ensure_boss_phase_gate_card_in_hand(), "phase three should retrieve an owned missing output type")
	_assert(_pile_has_card_id(game.hand, "lcd_display"), "phase-three opening hand should contain the missing display output")

	game.boss_phase = 1
	game._apply_boss_phase()
	game._reset_turn_state(true)
	game.hand = [game._card_copy("uart_log")]
	game.draw_pile = [game._card_copy("sliding_average"), game._card_copy("mq2_sample")]
	game.discard_pile.clear()
	game.processing_points = 3
	_assert(game.begin_reroute(), "Boss targeted reroute fixture should enter selection mode")
	_assert(game.reroute_card(0), "Boss targeted reroute should replace the selected card")
	_assert(_pile_has_card_id(game.hand, "sliding_average"), "Boss reroute should retrieve the highest-priority owned gate card")
	_assert(!_pile_has_card_id(game.hand, "mq2_sample"), "Boss reroute should not use the ordinary top draw when a better gate card exists")
	_assert(game.processing_points == 2, "Boss targeted reroute should cost one processing point")


func _assert_reroute_public_api_contract(game) -> void:
	game._start_encounter("mq2_warmup", "ordinary")
	game._reset_turn_state(true)
	game.hand = [game._card_copy("mq2_sample")]
	game.draw_pile = [game._card_copy("bh1750_read")]
	game.discard_pile.clear()
	game.processing_points = 3
	_assert(game.begin_reroute(), "reroute mode should open for the play-card guard")
	_assert(!game.play_card(0), "play_card should reject direct calls while reroute mode is active")
	_assert(game.hand.size() == 1 and game.processing_points == 3, "rejected reroute-mode play should not mutate the hand or points")

	var invalid_cases := [
		{"name": "non-combat state", "state": game.RunState.MAP},
		{"name": "tutorial combat", "tutorial": true},
		{"name": "pending selection", "pending": {"kind": "retain_one"}},
		{"name": "spent availability", "available": false},
		{"name": "after a card play", "cards_played": 1},
		{"name": "closed reroute mode", "mode": false},
	]
	for raw_case in invalid_cases:
		var invalid_case := raw_case as Dictionary
		game.state = game.RunState.COMBAT
		game.tutorial_active = false
		game.pending_card_selection.clear()
		game.reroute_available = true
		game.cards_played_this_turn = 0
		game.reroute_mode = true
		game.hand = [game._card_copy("mq2_sample")]
		game.draw_pile = [game._card_copy("bh1750_read")]
		game.discard_pile.clear()
		if invalid_case.has("state"):
			game.state = int(invalid_case.get("state"))
		if invalid_case.has("tutorial"):
			game.tutorial_active = bool(invalid_case.get("tutorial"))
		if invalid_case.has("pending"):
			game.pending_card_selection = (invalid_case.get("pending") as Dictionary).duplicate(true)
		if invalid_case.has("available"):
			game.reroute_available = bool(invalid_case.get("available"))
		if invalid_case.has("cards_played"):
			game.cards_played_this_turn = int(invalid_case.get("cards_played"))
		if invalid_case.has("mode"):
			game.reroute_mode = bool(invalid_case.get("mode"))
		_assert(!game.reroute_card(0), "reroute_card should reject %s" % str(invalid_case.get("name", "invalid state")))
		_assert(game.hand.size() == 1 and str((game.hand[0] as Dictionary).get("id", "")) == "mq2_sample", "rejected %s reroute should preserve the selected card" % str(invalid_case.get("name", "invalid state")))
		_assert(game.draw_pile.size() == 1 and str((game.draw_pile[0] as Dictionary).get("id", "")) == "bh1750_read", "rejected %s reroute should preserve draw state" % str(invalid_case.get("name", "invalid state")))

	game.state = game.RunState.COMBAT
	game.tutorial_active = false
	game.pending_card_selection.clear()
	game.reroute_available = true
	game.cards_played_this_turn = 0
	game.reroute_mode = true
	game.hand = [game._card_copy("mq2_sample")]
	game.draw_pile.clear()
	game.discard_pile = [game._card_copy("bh1750_read")]
	_assert(game.reroute_card(0), "reroute should refill an empty draw pile from discard")
	_assert(game.hand.size() == 1 and str((game.hand[0] as Dictionary).get("id", "")) == "bh1750_read", "discard refill should draw a distinct replacement")
	_assert(game.discard_pile.size() == 1 and str((game.discard_pile[0] as Dictionary).get("id", "")) == "mq2_sample", "selected reroute card should enter discard only after replacement selection")
	_assert(!game.reroute_available and !game.reroute_mode, "successful discard refill should consume reroute")


func _assert_card_selection_effects(game) -> void:
	game._start_encounter("mq2_warmup", "ordinary")
	game.draw_pile = [
		game._card_copy("mq2_sample"),
		game._card_copy("sliding_average"),
		game._card_copy("uart_log")
	]
	game.discard_pile.clear()
	game.hand = [game._card_copy("logic_probe")]
	game.processing_points = 3
	_assert(game.play_card(0), "logic probe should open top-three selection")
	var selection := _pending_selection(game)
	_assert(selection.get("kind", "") == "draw_one", "logic probe should expose draw-one selection")
	game.hand = [game._card_copy("time_slice")]
	_assert(!game.play_card(0), "normal card play should be disabled while selection is open")
	_assert(!game.end_turn(), "end turn should be disabled while selection is open")
	if _choose_pending_card(game, 1, "logic probe should expose public card selection"):
		_assert(game._hand_has_card("sliding_average"), "selected inspected card should enter hand")
		_assert(_card_id_at(game.draw_pile, game.draw_pile.size() - 1) == "uart_log", "unchosen inspected cards should return to draw-pile top in original order")
		_assert(_card_id_at(game.draw_pile, game.draw_pile.size() - 2) == "mq2_sample", "unchosen inspected cards should preserve their relative order")

	game._start_encounter("mq2_warmup", "ordinary")
	game.draw_pile = [
		game._card_copy("mq2_sample"),
		game._card_copy("sliding_average"),
		game._card_copy("uart_log")
	]
	var upgraded_baseline: Dictionary = game._card_copy("environment_baseline")
	upgraded_baseline["upgraded"] = true
	game.hand = [upgraded_baseline]
	game.processing_points = 3
	_assert(game.play_card(0), "upgraded environment baseline should inspect cards")
	_assert(_pending_selection(game).get("kind", "") == "draw_one", "upgraded environment baseline should expose draw-one selection")
	if _choose_pending_card(game, 1, "upgraded environment baseline should select an inspected card"):
		_assert(game._hand_has_card("sliding_average"), "upgraded environment baseline should add its chosen card to hand")

	game._start_encounter("mq2_warmup", "ordinary")
	game.draw_pile = [game._card_copy("mq2_sample"), game._card_copy("sliding_average"), game._card_copy("uart_log")]
	game.hand = [game._card_copy("polling_scan")]
	game.processing_points = 3
	_assert(game.play_card(0), "polling scan should open source selection")
	_assert(_pending_selection(game).get("kind", "") == "raw_source", "polling scan should let the player choose a raw source")
	if _choose_pending_card(game, 1, "polling scan should select a raw source"):
		_assert(int(game.raw_data.get("light", 0)) == 1, "polling scan should gain the selected raw source")
		_assert(_pending_selection(game).get("kind", "") == "discard_one", "polling scan should draw before prompting for one discard")
		if _choose_pending_card(game, 0, "polling scan should discard one drawn card"):
			_assert(game.hand.size() == 1, "draw-discard should leave one drawn card in hand")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("dma_queue"), game._card_copy("mq2_sample")]
	game.processing_points = 3
	_assert(game.play_card(0), "DMA queue should open retained-card selection")
	_assert(_pending_selection(game).get("kind", "") == "retain_one", "DMA queue should expose retain-one selection")
	if _choose_pending_card(game, 0, "DMA queue should retain its selected card"):
		_assert(_retained_cards(game).size() == 1, "DMA queue should store the selected card for next turn")
		_assert(game.block == 5, "DMA queue should grant five block")

	game._start_encounter("mq2_warmup", "ordinary")
	var upgraded_cache: Dictionary = game._card_copy("data_cache")
	upgraded_cache["upgraded"] = true
	game.draw_pile.clear()
	game.hand = [upgraded_cache, game._card_copy("mq2_sample")]
	game.processing_points = 3
	_assert(game.play_card(0), "upgraded data cache should open retained-card selection")
	_assert(_pending_selection(game).get("kind", "") == "retain_one", "upgraded data cache should retain one selected card instead of drawing two")
	if _choose_pending_card(game, 0, "upgraded data cache should select a retained card"):
		_assert(game.end_turn(), "retained-card selection should resolve before end turn")
		_assert(game._hand_has_card("mq2_sample"), "retained cards should return before normal next-turn draw")


func _assert_deferred_card_finalization(game) -> void:
	game._start_encounter("mq2_warmup", "ordinary")
	game.current_encounter["faultRule"] = {
		"id": "mq2_uncalibrated",
		"timing": "after_card",
		"triggerStage": "collect",
		"triggerCount": 1,
		"penalties": [{"op": "add_negative", "cardId": "abnormal_reading"}],
		"counterTags": []
	}
	game.current_encounter["evidenceGroups"] = []
	game.repair_target = 0
	game.repair_progress = 0
	game.draw_pile = [game._card_copy("mq2_sample"), game._card_copy("sliding_average")]
	game.discard_pile.clear()
	game.hand = [game._card_copy("polling_scan")]
	game.processing_points = 3
	_assert(game.play_card(0), "polling scan should begin its deferred effect chain")
	var selection := _pending_selection(game)
	_assert(selection.get("owner", "") == "combat", "combat card selection should declare its owner")
	_assert(selection.get("kind", "") == "raw_source", "polling scan should pause on raw-source selection")
	_assert(game.state == game.RunState.COMBAT, "selection should keep the encounter in COMBAT before card finalization")
	_assert(!_pile_has_card_id(game.discard_pile, "polling_scan") and !_pile_has_card_id(game.draw_pile, "polling_scan"), "played polling scan should stay out of discard and draw while selection is open")
	_assert(!_pile_has_card_id(game.discard_pile, "abnormal_reading"), "fault-added negatives should not finalize before selection")
	_assert(!bool(game.fault_rule_state.get("triggered", false)), "fault resolution should wait for deferred card effects")
	_assert(game.cards_played_this_turn == 0, "card-play bookkeeping should wait for deferred card effects")
	if _choose_pending_card(game, 0, "polling scan should resolve its first selection"):
		selection = _pending_selection(game)
		_assert(selection.get("kind", "") == "discard_one", "polling scan should continue to its discard selection")
		_assert(game.state == game.RunState.COMBAT, "continued selection should not transition before finalization")
		_assert(!_pile_has_card_id(game.discard_pile, "polling_scan") and !_pile_has_card_id(game.draw_pile, "polling_scan"), "played polling scan should remain pending through the full effect chain")
		_assert(!bool(game.fault_rule_state.get("triggered", false)) and game.cards_played_this_turn == 0, "fault and bookkeeping should remain deferred through chained selections")
		if _choose_pending_card(game, 0, "polling scan should resolve its final selection"):
			_assert(game.state == game.RunState.REWARD, "card finalization should transition only after the full effect chain resolves")
			_assert(bool(game.fault_rule_state.get("triggered", false)), "fault resolution should run after the final selection")
			_assert(_count_card_id(game.discard_pile, "polling_scan") == 1, "shared card finalizer should discard polling scan exactly once")
			_assert(_count_card_id(game.discard_pile, "abnormal_reading") == 1, "shared card finalizer should add its fault negative exactly once")
			_assert(game.cards_played_this_turn == 1, "shared card finalizer should increment card bookkeeping exactly once")
			_assert(!game.choose_pending_card(0), "a completed card finalizer should not be callable twice")
			_assert(_count_card_id(game.discard_pile, "polling_scan") == 1 and game.cards_played_this_turn == 1, "rejected repeat selections should not repeat finalization")

	game._start_encounter("mq2_warmup", "ordinary")
	game.current_encounter["faultRule"] = {
		"id": "mq2_uncalibrated",
		"timing": "after_card",
		"triggerStage": "collect",
		"triggerCount": 1,
		"penalties": [{"op": "add_negative", "cardId": "abnormal_reading"}],
		"counterTags": []
	}
	game.draw_pile.clear()
	game.discard_pile.clear()
	game.hand = [game._card_copy("polling_scan")]
	game.processing_points = 3
	_assert(game.play_card(0), "polling scan should defer before an empty-pile draw")
	if _choose_pending_card(game, 0, "polling scan should resolve an empty-pile source selection"):
		_assert(_pending_selection(game).is_empty(), "deferred draw should not create a discard choice from the played card")
		_assert(!_pile_has_card_id(game.hand, "polling_scan") and !_pile_has_card_id(game.hand, "abnormal_reading"), "polling scan and its fault negative should not redraw from the deferred pile")
		_assert(_count_card_id(game.discard_pile, "polling_scan") == 1 and _count_card_id(game.discard_pile, "abnormal_reading") == 1, "empty-pile polling scan should finalize only after its draw effect completes")


func _assert_event_owned_selection(game) -> void:
	game._reset_run()
	game.stability = 40
	var stability_before: int = game.stability
	game.current_event = {
		"id": "event_card_selection",
		"options": [{
			"effects": [
				{"op": "select_card", "cardIds": ["logic_probe"]},
				{"op": "heal", "amount": 7}
			]
		}]
	}
	game.state = game.RunState.EVENT
	_assert(game.choose_event_option(0), "event should open its owned card selection")
	var selection := _pending_selection(game)
	_assert(game.state == game.RunState.EVENT, "event selection should keep the state in EVENT")
	_assert(selection.get("owner", "") == "event" and selection.get("kind", "") == "event_card" and (selection.get("context", {}) as Dictionary).get("action", "") == "add_card", "event card selection should declare event ownership and context")
	_assert(!game.play_card(0), "event-owned selection should not expose combat card play")
	if _choose_pending_card(game, 0, "event should accept its declared selection owner"):
		_assert(game.state == game.RunState.MAP, "event selection should resume and complete its event continuation")
		_assert(_pile_has_card_id(game.deck, "logic_probe"), "event card selection should add the chosen card")
		_assert(game.stability == stability_before + 7, "event selection should resume remaining event effects")

	game._reset_run()
	game.stability = 40
	stability_before = game.stability
	game.current_event = {
		"id": "event_component_selection",
		"options": [{
			"effects": [
				{"op": "select_component", "componentIds": ["state_template"]},
				{"op": "heal", "amount": 5}
			]
		}]
	}
	game.state = game.RunState.EVENT
	_assert(game.choose_event_option(0), "event should open its owned component selection")
	selection = _pending_selection(game)
	_assert(game.state == game.RunState.EVENT and selection.get("owner", "") == "event" and selection.get("kind", "") == "event_component" and (selection.get("context", {}) as Dictionary).get("action", "") == "add_component", "event component selection should remain in EVENT with event ownership")
	if _choose_pending_card(game, 0, "event component selection should accept its declared selection owner"):
		_assert(game.state == game.RunState.MAP, "event component selection should resume event completion")
		_assert(game.relics.has("state_template") and int(game.powers.get("chain_draw", 0)) == 1, "event component selection should activate the chosen component")
		_assert(game.stability == stability_before + 5, "event component selection should continue remaining effects")


func _assert_card_resolution_effects(game) -> void:
	game._start_encounter("mq2_warmup", "ordinary")
	game.draw_pile = [game._card_copy("uart_log")]
	game.discard_pile = [{"id": "abnormal_reading", "negative": true, "group": "noise"}]
	game.hand = [game._card_copy("median_filter")]
	game.processing_points = 3
	game.repair_progress = 0
	_assert(game.play_card(0), "median filter should play")
	_assert(game._hand_has_card("uart_log"), "median filter should draw after it removes noise")
	_assert(game.repair_progress == 5, "median filter should repair five")

	game._start_encounter("mq2_warmup", "ordinary")
	var upgraded_outlier: Dictionary = game._card_copy("outlier_reject")
	upgraded_outlier["upgraded"] = true
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [upgraded_outlier]
	game.processing_points = 3
	_assert(game.play_card(0), "upgraded outlier reject should play without a target")
	_assert(!game._hand_has_card("uart_log"), "outlier reject should not draw when it removes no negative card")

	game._start_encounter("mq2_warmup", "ordinary")
	var upgraded_delay: Dictionary = game._card_copy("nonblocking_delay")
	upgraded_delay["upgraded"] = true
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [upgraded_delay]
	game.processing_points = 3
	_assert(game.play_card(0), "upgraded nonblocking delay should play without a delay target")
	_assert(!game._hand_has_card("uart_log"), "nonblocking delay should draw only when blocking delay is removed")

	game._start_encounter("mq2_warmup", "ordinary")
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [game._card_copy("task_yield")]
	game.processing_points = 3
	_assert(game.play_card(0), "task yield should play")
	_assert(game.block == 6 and game._hand_has_card("uart_log"), "task yield should gain six block and draw one")
	_assert(int(game.powers.get("interface_discount", 0)) == 1, "task yield should reduce the next interface cost")

	game._start_encounter("mq2_warmup", "ordinary")
	game.trusted_data["light"] = 1
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [game._card_copy("trusted_snapshot")]
	game.processing_points = 3
	_assert(game.play_card(0), "trusted snapshot should play")
	_assert(game.retain_data and game._hand_has_card("uart_log"), "trusted snapshot should retain data and draw one")

	game._start_encounter("mq2_warmup", "ordinary")
	game.raw_data["light"] = 1
	var upgraded_register: Dictionary = game._card_copy("i2c_register_read")
	upgraded_register["upgraded"] = true
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [upgraded_register]
	game.processing_points = 3
	_assert(game.play_card(0), "upgraded I2C register read should play")
	_assert(int(game.raw_data.get("light", 0)) == 0 and int(game.trusted_data.get("light", 0)) == 1, "successful I2C register read should convert one raw source")
	_assert(game._hand_has_card("uart_log"), "successful I2C register read should draw one")
	game.raw_data["temp"] = 1
	game.draw_pile = [game._card_copy("sliding_average")]
	game.hand = [upgraded_register.duplicate(true)]
	_assert(game.play_card(0), "a second upgraded I2C register read should play")
	_assert(!game._hand_has_card("sliding_average"), "I2C register draw should be limited to once per turn")

	game._start_encounter("mq2_warmup", "ordinary")
	game.fault_rule_state["suppressed"] = true
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [game._card_copy("interrupt_trace")]
	game.processing_points = 3
	game.repair_progress = 0
	_assert(game.play_card(0), "interrupt trace should play against a suppressed fault")
	_assert(game.repair_progress == 8 and game._hand_has_card("uart_log"), "interrupt trace should draw and repair eight when the fault is suppressed")

	game._start_encounter("mq2_warmup", "ordinary")
	game.fault_rule_state["suppressed"] = false
	game.draw_pile = [game._card_copy("uart_log")]
	game.hand = [game._card_copy("interrupt_trace")]
	game.processing_points = 3
	game.repair_progress = 0
	_assert(game.play_card(0), "interrupt trace should play against an active fault")
	_assert(game.repair_progress == 4 and !game._hand_has_card("uart_log"), "interrupt trace should repair four without a suppressed-fault draw")

	game._start_encounter("mq2_warmup", "ordinary")
	game.trusted_data = {"smoke": 2, "light": 1, "temp": 0, "humidity": 0}
	game.hand = [game._card_copy("multi_source_dashboard")]
	game.processing_points = 3
	game.repair_progress = 0
	_assert(game.play_card(0), "multi-source dashboard should play")
	_assert(int(game.trusted_data.get("smoke", 0)) == 1 and int(game.trusted_data.get("light", 0)) == 0, "multi-source dashboard should consume at most one trusted item per source")
	_assert(game.repair_progress == 16, "multi-source dashboard should repair eight per distinct source")


func _assert_chain_draw_state_template(game) -> void:
	game._reset_run()
	game.state = game.RunState.COMPONENT
	game.component_choices = [(game.relic_defs.get("state_template", {}) as Dictionary).duplicate(true)]
	_assert(game.choose_component("state_template"), "state template component should be selectable")
	_assert(int(game.powers.get("chain_draw", 0)) == 1, "state template should activate chain draw")
	game._start_encounter("mq2_warmup", "ordinary")
	game.powers["chain_energy"] = 8
	game.draw_pile = [game._card_copy("mq2_sample")]
	game.hand = []
	for stage in ["collect", "interface", "process", "output"]:
		game.hand.append({
			"id": "component_chain_%s" % stage,
			"name": stage,
			"stage": stage,
			"type": stage,
			"tags": [],
			"cost": 0,
			"effects": [],
			"upgraded": false
		})
	game.processing_points = 3
	for _index in range(4):
		_assert(game.play_card(0), "state template fixture should play each ordered stage")
	_assert(game._hand_has_card("mq2_sample"), "chain-draw state template should draw after the first complete chain")
	_assert(game.processing_points <= 4, "legacy chain energy should not restore extra processing points")


func _assert_reward_composition(game) -> void:
	var future_draw_card := {
		"id": "future_draw_fixture",
		"upgraded": false,
		"effects": [{"op": "repair", "amount": 1}],
		"upgradeEffects": [{"op": "draw", "amount": 1}]
	}
	_assert(!game._card_has_draw_effect(future_draw_card), "reward classification should ignore inactive upgrade effects on an unupgraded copy")
	future_draw_card["upgraded"] = true
	_assert(game._card_has_draw_effect(future_draw_card), "reward classification should inspect upgrade effects on an upgraded copy")

	game._reset_run()
	game._start_encounter("mq2_warmup", "ordinary")
	game.rng.seed = 12345
	game._open_reward()
	_assert(game.reward_choices.size() == 3, "reward should contain three cards")
	if !game.has_method("_reward_reason"):
		_assert(false, "rewards should expose a public reason helper")
		return
	var reasons := {}
	for raw_card in game.reward_choices:
		reasons[game._reward_reason(raw_card as Dictionary)] = true
	_assert(reasons.has("协同"), "reward should include current-deck synergy")
	_assert(reasons.has("补链"), "reward should include a missing-chain card")
	_assert(reasons.has("反制"), "reward should include defense, draw, or fault counterplay")


func _assert_lethal_deferred_effect_arbitration(game) -> void:
	game._reset_run()
	game.reward_choices.clear()
	game._start_encounter("i2c_congestion", "elite")
	game.stability = 6
	game.block = 0
	game.repair_target = 0
	game.hand = [game._card_copy("i2c_transaction"), game._card_copy("i2c_register_read")]
	game.raw_data["light"] = 1
	game.processing_points = 3
	_assert(game.play_card(0), "lethal elite setup should play the first I2C card")
	_assert(game.play_card(0), "lethal elite setup should play the triggering I2C card")
	_assert(game.state == game.RunState.RESULT and game.completed and !game.victory, "lethal elite fault should enter defeat before opening its reward")
	_assert(game.reward_choices.is_empty(), "lethal elite fault should not create reward choices")

	game._reset_run()
	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game.pre_boss_stability = 48
	game._start_encounter("warehouse_acceptance", "boss")
	game.boss_phase = 0
	game._apply_boss_phase()
	game.phase_source_coverage = {"smoke": true, "light": true}
	game.repair_target = 8
	game.repair_progress = 0
	game.stability = 3
	game.block = 0
	game.chain_count = 2
	game.last_stage = "process"
	game.chain_rewards_claimed = {"two": true, "three": true}
	game.powers["chain_draw"] = 1
	game.draw_pile = [game._negative_card("abnormal_reading")]
	game.discard_pile.clear()
	game.hand = [game._card_copy("uart_log")]
	game.processing_points = 1
	_assert(game.play_card(0), "lethal chain-draw setup should play a real output card")
	_assert(game.state == game.RunState.REST and game.boss_review_used, "lethal chain draw should enter Boss defeat review before phase transition")
	_assert(game.boss_phase == 0, "lethal chain draw should not advance the Boss phase")


func _pending_selection(game) -> Dictionary:
	for raw_property in game.get_property_list():
		if str((raw_property as Dictionary).get("name", "")) == "pending_card_selection":
			var value = game.get("pending_card_selection")
			return value as Dictionary if value is Dictionary else {}
	return {}


func _retained_cards(game) -> Array:
	for raw_property in game.get_property_list():
		if str((raw_property as Dictionary).get("name", "")) == "retained_cards":
			var value = game.get("retained_cards")
			return value as Array if value is Array else []
	return []


func _choose_pending_card(game, index: int, message: String) -> bool:
	if !game.has_method("choose_pending_card"):
		_assert(false, message)
		return false
	return bool(game.choose_pending_card(index))


func _card_id_at(cards: Array, index: int) -> String:
	if index < 0 or index >= cards.size():
		return ""
	return str((cards[index] as Dictionary).get("id", ""))


func _pile_has_card_id(cards: Array, card_id: String) -> bool:
	return _count_card_id(cards, card_id) > 0


func _count_card_id(cards: Array, card_id: String) -> int:
	var count := 0
	for raw_card in cards:
		if str((raw_card as Dictionary).get("id", "")) == card_id:
			count += 1
	return count


func _card_ids(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_card in cards:
		result.append(str((raw_card as Dictionary).get("id", "")))
	return result


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
