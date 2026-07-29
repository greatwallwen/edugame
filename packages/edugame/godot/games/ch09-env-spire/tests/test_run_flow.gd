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
	_assert_route_order(game)
	game._reset_run()
	_assert_question_event_resolution(game)
	game._reset_run()

	_assert(game.current_layer == 0 and game.state == game.RunState.MAP, "new run should begin before layer one")
	var script_constants: Dictionary = game.get_script().get_script_constant_map()
	_assert(int(script_constants.get("RUN_NODE_COUNT", 0)) == 12, "the single route should contain twelve nodes")
	_assert((game.run_map.get("layers", []) as Array).size() == 12, "the active map should expose twelve layers")
	_assert(!bool(game.choose_node(1)), "a single-route layer should reject a second choice")
	_assert(bool(game.choose_node(0)), "layer one node should be selectable")
	_assert(game.current_layer == 1, "choosing a node should advance the visited layer count")
	_assert(game.state == game.RunState.COMBAT, "ordinary node should enter combat")
	_assert(!bool(game.choose_node(0)), "route selection should be locked during combat")
	game.hand = [game._card_copy("mq2_sample")]
	game.processing_points = 3
	game.diagnosis = 1
	game.message_log.clear()
	_assert(bool(game.play_card(0)), "matching sensor card should be playable")
	_assert(_log_contains(game.message_log, "命中弱点") and _log_contains(game.message_log, "smoke"), "matching card play should explain the fault weakness hit")
	_assert(_log_contains(game.message_log, "+2"), "diagnosed weakness feedback should explain the repair bonus")

	if !game.has_method("_encounter_requirements_met"):
		_assert(false, "ordinary faults should expose an engineering evidence gate")
		game.queue_free()
		await process_frame
		_finish()
		return
	else:
		game.encounter_evidence_tags = {"smoke": true}
		game.repair_progress = game.repair_target
		game.message_log.clear()
		game._finish_encounter()
		_assert(game.state == game.RunState.COMBAT, "repair progress alone should not clear MQ-2 without interface evidence")
		_assert(_log_contains(game.message_log, "缺少工程证据") and _log_contains(game.message_log, "calibration/adc"), "blocked completion should list the missing evidence group")
		game.encounter_evidence_tags["adc"] = true
		_assert(game._encounter_requirements_met(), "smoke plus ADC evidence should satisfy the MQ-2 engineering gate")
		game._finish_encounter()
	_assert(game.state == game.RunState.REWARD, "ordinary victory should open card rewards")
	if _object_has_property(game, "debug_reports"):
		var first_report := (game.get("debug_reports") as Array)[0] as Dictionary
		_assert((game.get("debug_reports") as Array).size() == 1, "ordinary victory should record one debugging report")
		_assert(str(first_report.get("encounterId", "")) == "mq2_warmup", "debugging report should identify the resolved fault")
		_assert((first_report.get("evidence", []) as Array).has("smoke") and (first_report.get("evidence", []) as Array).has("adc"), "debugging report should retain demonstrated evidence")
	else:
		_assert(false, "game should expose persistent debugging reports")
	if game.has_method("_latest_debug_summary"):
		_assert(str(game._latest_debug_summary()).contains("调试报告") and str(game._latest_debug_summary()).contains("smoke"), "latest debugging summary should explain the validated evidence")
	else:
		_assert(false, "game should expose a latest debugging summary")
	_assert(int(game._run_stats().get("debugReportCount", 0)) == 1, "runtime stats should report debugging summary count")
	_assert(game.reward_choices.size() == 3, "combat reward should offer three cards")
	var deck_before: int = game.deck.size()
	_assert(bool(game.choose_reward(str((game.reward_choices[0] as Dictionary).get("id", "")))), "reward card should be selectable")
	_assert(game.deck.size() == deck_before + 1, "chosen reward should join the permanent deck")
	_assert(game.state == game.RunState.MAP, "reward selection should return to map")

	_assert(bool(game.choose_node(0)), "layer two event should be selectable")
	_assert(game.state == game.RunState.EVENT, "event node should enter event state")
	if game.has_method("submit_event_answer"):
		_assert(!game.current_event.is_empty(), "normal event nodes should select a seeded question")
		_assert(game.event_history.size() == 1, "normal event selection should enter event history")
		var route_answer = game.current_event.get("correctAnswer")
		_assert(game.submit_event_answer(route_answer), "the seeded route event should accept its ID-based answer")
		_assert(game.choose_event_reward(0), "the seeded route event should accept one reward")
		if !game.pending_card_selection.is_empty():
			_assert(game.choose_pending_card(0), "the route reward should resolve through the shared event owner")
		_assert(game.continue_event(), "the explained route event should continue")
	else:
		game.state = game.RunState.MAP
	_assert(game.state == game.RunState.MAP, "event should return to map")

	_assert(bool(game.choose_node(0)), "layer three ordinary fault should be selectable")
	_assert(str(game.current_node.get("type", "")) == "ordinary", "layer three should be an ordinary fault")
	game.encounter_evidence_tags = {"light": true, "i2c": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.state == game.RunState.REWARD, "layer three fault should grant a reward")
	game.choose_reward("")

	_assert(bool(game.choose_node(0)), "layer four rest should be selectable")
	_assert(game.state == game.RunState.REST, "layer four should open rest state")
	_assert(bool(game.choose_service("upgrade")), "layer four upgrade should resolve")

	_assert(bool(game.choose_node(0)), "layer five checkpoint should be selectable")
	_assert(str(game.current_node.get("type", "")) == "checkpoint_sensor", "layer five should be sensor checkpoint")
	game.trusted_sources_seen = {"smoke": true, "light": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.checkpoint_results.size() == 1, "sensor checkpoint should record a result")
	_assert(bool((game.checkpoint_results[0] as Dictionary).get("passed", false)), "two completed source chains should pass sensor checkpoint")
	_assert(game.state == game.RunState.REWARD, "passed checkpoint should grant a reward")
	game.choose_reward("")
	game.current_node = {"type": "checkpoint_trust"}
	game.trusted_sources_seen = {"smoke": true, "light": true}
	game.filters_played = 1
	game.hand.clear()
	game.discard_pile = [{"id": "abnormal_reading", "negative": true, "group": "noise"}]
	_assert(game._checkpoint_requirements_met(), "a discarded abnormal reading should not fail the hand-only trust check")
	game.hand = [{"id": "abnormal_reading", "negative": true, "group": "noise"}]
	_assert(!game._checkpoint_requirements_met(), "an abnormal reading still in hand should fail the trust check")
	_assert_fault_rule_counterplay(game)

	var run_states: Dictionary = game.get_script().get_script_constant_map().get("RunState", {})
	if !run_states.has("COMPONENT"):
		_assert(false, "component node should expose a dedicated run state")
	else:
		game._reset_run()
		game._open_component_choice()
		_assert(game.state == int(run_states.get("COMPONENT")), "component fixture should enter its choice state")
		_assert(game.component_choices.size() == 3, "component node should offer three choices")
		var chosen_id := str((game.component_choices[0] as Dictionary).get("id", ""))
		_assert(bool(game.choose_component(chosen_id)), "an offered component should be selectable")
		_assert(game.relics.has(chosen_id), "selected component should join the run")
		_assert(game.state == game.RunState.MAP, "component selection should return to the route")
		_assert(!bool(game.choose_component("missing_component")), "an unoffered component should be rejected")

		var component_ids: Array = game.relic_defs.keys()
		component_ids.sort()
		game.relics = component_ids.slice(0, 4)
		game._open_component_choice()
		_assert(game.component_choices.size() == 2, "one remaining component should be paired with one fallback")
		_assert(_array_has_id(game.component_choices, "upgrade_fallback"), "component shortage should offer a card upgrade fallback")

	_assert_boss_shop_guarantee(game)
	game.current_layer = 10
	game.state = game.RunState.MAP
	_assert(bool(game.choose_node(0)), "layer eleven service should be selectable")
	_assert(game.state == game.RunState.REST, "service node should open rest state")
	game.stability = 20
	_assert(bool(game.choose_service("maintenance")), "maintenance should resolve")
	_assert(game.stability > 20, "maintenance should restore stability")
	_assert(game.state == game.RunState.MAP, "service should return to map")
	game.state = game.RunState.REST
	game.budget = 200
	_assert(bool(game.choose_service("shop")), "service should open the parts shop")
	_assert(game.state == game.RunState.SHOP and game.shop_cards.size() == 5, "shop should offer five non-starter cards")
	var shop_deck_before: int = game.deck.size()
	var shop_card_id := str((game.shop_cards[0] as Dictionary).get("id", ""))
	_assert(bool(game.purchase_shop_card(shop_card_id)), "affordable shop card should be purchasable")
	_assert(game.deck.size() == shop_deck_before + 1 and game.budget < 200, "purchase should spend budget and add a card")
	_assert(bool(game.leave_shop()) and game.state == game.RunState.MAP, "leaving the shop should return to map")

	_assert(bool(game.choose_node(0)), "layer twelve boss should be selectable")
	_assert(game.state == game.RunState.COMBAT and game.boss_phase == 0, "boss should begin at phase one")
	if !game.has_method("_boss_phase_requirements_met"):
		_assert(false, "boss encounters should expose a phase gate evaluator")
		game.queue_free()
		await process_frame
		_finish()
		return
	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.boss_phase == 0, "phase one should not advance without two source chains")
	game.phase_source_coverage = {"smoke": true, "light": true}
	game._finish_encounter()
	_assert(game.boss_phase == 1, "two source chains should unlock boss phase two")

	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.boss_phase == 1, "phase two should not advance without trusted data and filtering")
	game.phase_trusted_sources = {"smoke": true, "light": true}
	game.phase_filters_played = 1
	game._finish_encounter()
	_assert(game.boss_phase == 2, "trusted data and filtering should unlock boss phase three")

	game.repair_progress = game.repair_target
	game.phase_output_types = {"uart": true}
	game._finish_encounter()
	_assert(game.state == game.RunState.COMBAT, "one output family should not complete final acceptance")
	game.phase_output_types["scheduler"] = true
	game._finish_encounter()
	_assert(game.state == game.RunState.RESULT, "final boss phase should reach result")
	_assert(game.completed and game.victory, "boss victory should complete the run")
	_assert(game.current_layer == 12, "successful run should visit twelve layers")
	game.boss_review_used = true
	game.checkpoints_passed = 2
	game.relics = ["test_relic"]
	game.stability = game.max_stability
	game.source_coverage = {"smoke": true, "light": true, "temp": true}
	game.trusted_sources_seen = {"smoke": true, "light": true}
	game.filters_played = 1
	_assert(game._calculate_score() == 89, "boss review should cap the run below the three-star threshold")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _log_contains(entries: Array, expected: String) -> bool:
	for entry in entries:
		if str(entry).contains(expected):
			return true
	return false


func _assert_route_order(game) -> void:
	var expected_types := [
		"ordinary", "event", "ordinary", "service",
		"checkpoint_sensor", "event", "ordinary", "checkpoint_trust",
		"shop", "elite", "service", "boss"
	]
	for raw_map in game.map_defs.values():
		var map := raw_map as Dictionary
		var layers: Array = map.get("layers", [])
		_assert(layers.size() == expected_types.size(), "%s should expose twelve route layers" % map.get("id", "map"))
		for index in range(mini(layers.size(), expected_types.size())):
			var layer := layers[index] as Dictionary
			var choices: Array = layer.get("choices", [])
			_assert(!choices.is_empty(), "%s layer %d should expose a route choice" % [map.get("id"), index + 1])
			if choices.is_empty():
				continue
			var choice := choices[0] as Dictionary
			_assert(str(choice.get("type", "")) == expected_types[index], "%s layer %d should use %s" % [map.get("id"), index + 1, expected_types[index]])
			if index == 1:
				_assert(str(choice.get("eventTier", "")) == "basic", "node two should request a basic event")
				_assert(str(choice.get("contentId", "")) == "random_basic", "node two should use the seeded basic selector")
			if index == 5:
				_assert(str(choice.get("eventTier", "")) == "advanced", "node six should request an advanced event")
				_assert(str(choice.get("contentId", "")) == "random_advanced", "node six should use the seeded advanced selector")


func _assert_boss_shop_guarantee(game) -> void:
	if !game.has_method("_missing_boss_stage_tags") or !game.has_method("_guaranteed_boss_shop_card_id"):
		_assert(false, "late shops should expose Boss missing-link helpers")
		return

	game._reset_run()
	_assert(game._missing_boss_stage_tags() == ["control"], "starter deck should expose only the Boss control-output gap")
	_assert(game._guaranteed_boss_shop_card_id() == "time_slice", "equal-price control cards should preserve the first exact catalog candidate")

	game._reset_run()
	game.deck = [game._card_copy("mq2_sample")]
	_assert(!game._missing_boss_stage_tags().is_empty(), "one-source deck should expose Boss gaps")
	game.budget = 35
	game.current_layer = 8
	game._open_shop()
	var guaranteed_id: String = game._guaranteed_boss_shop_card_id()
	_assert(!guaranteed_id.is_empty(), "one-source deck should identify an exact Boss preparation card")
	_assert(_array_has_id(game.shop_cards, guaranteed_id), "node nine shop should inject a missing-link card")
	var guaranteed_price := 999
	for raw_card in game.shop_cards:
		var shop_card := raw_card as Dictionary
		if str(shop_card.get("id", "")) == guaranteed_id:
			guaranteed_price = int(shop_card.get("price", 999))
	_assert(guaranteed_price <= game.budget, "guaranteed card should be affordable")

	game._reset_run()
	game.deck = [game._card_copy("mq2_sample")]
	game.budget = 35
	game.current_layer = 11
	game.state = game.RunState.REST
	_assert(game.choose_service("shop"), "node eleven service should open its shop")
	guaranteed_id = game._guaranteed_boss_shop_card_id()
	_assert(_array_has_id(game.shop_cards, guaranteed_id), "node eleven service shop should inject a missing-link card")
	for raw_card in game.shop_cards:
		var shop_card := raw_card as Dictionary
		if str(shop_card.get("id", "")) == guaranteed_id:
			_assert(int(shop_card.get("price", 999)) <= game.budget, "service-shop guarantee should also be affordable")

	game._reset_run()
	game.deck = [game._card_copy("mq2_sample")]
	game.budget = 35
	game.current_layer = 4
	game._open_shop()
	for raw_card in game.shop_cards:
		var shop_card := raw_card as Dictionary
		_assert(int(shop_card.get("price", -1)) == game._card_price(shop_card), "early service shop should preserve ordinary pricing")
	game._reset_run()


func _assert_question_event_resolution(game) -> void:
	for method_name in ["submit_event_answer", "choose_event_reward", "continue_event", "_apply_event_consequence"]:
		if !game.has_method(method_name):
			_assert(false, "question events should expose %s" % method_name)
			return
	for property_name in ["event_answer_locked", "event_result"]:
		if !_object_has_property(game, property_name):
			_assert(false, "question events should expose %s" % property_name)
			return

	_force_event(game, "basic_mq2_warmup")
	game.stability = 4
	var budget_before_wrong: int = game.budget
	var deck_before_wrong: int = game.deck.size()
	_assert(!game.continue_event(), "event should not continue before an answer")
	_assert(game.submit_event_answer("adc_resolution"), "wrong answer should lock")
	_assert(game.event_answer_locked, "answer should lock immediately")
	_assert(!bool(game.event_result.get("correct", true)), "wrong answer should be recorded")
	_assert(str(game.event_result.get("explanation", "")).length() > 0, "wrong answer should show explanation")
	_assert(game.stability == 1, "wrong stability penalty should clamp at one")
	_assert(game.budget == budget_before_wrong and game.deck.size() == deck_before_wrong, "wrong answer should apply only its declared penalty")
	_assert(game.continue_event() and game.state == game.RunState.MAP, "wrong explained result should continue to the map")

	_force_event(game, "basic_mq2_warmup")
	game.stability = game.max_stability
	var budget_before_reward: int = game.budget
	_assert(game.submit_event_answer("insufficient_warmup"), "correct option ID should lock")
	_assert(bool(game.event_result.get("correct", false)), "correct answer should be recorded")
	_assert(bool(game.event_result.get("rewardPending", false)), "correct answer should expose a pending reward")
	_assert((game.event_result.get("rewardChoices", []) as Array).size() == 2, "correct answer should expose two rewards")
	_assert(game.budget == budget_before_reward, "correct answer should not apply a reward before selection")
	_assert(!game.continue_event(), "correct event should not continue before reward selection")
	_assert(game.choose_event_reward(0), "one correct-answer reward should be selectable")
	_assert(game.budget == budget_before_reward + 20, "selected budget reward should apply once")
	_assert(!game.choose_event_reward(1), "a second reward should be rejected")
	_assert(game.continue_event() and game.state == game.RunState.MAP, "rewarded event should continue after explanation")

	_force_event(game, "basic_signal_order")
	var ordering_answer := ["sensor", "interface", "convert", "output"]
	var deck_before_card_choice: int = game.deck.size()
	_assert(game.submit_event_answer(ordering_answer), "ordering should accept an array of option IDs")
	_assert(bool(game.event_result.get("correct", false)), "correct ordering IDs should resolve as correct")
	_assert(game.choose_event_reward(0), "card reward should begin a shared selection")
	_assert(game.state == game.RunState.EVENT, "event should remain the owner while card selection is pending")
	_assert(str(game.pending_card_selection.get("owner", "")) == "event", "card selection should declare the event owner")
	_assert(!bool(game.event_result.get("resolved", true)), "event should wait for its card selection")
	_assert(game.choose_pending_card(0), "event-owned card selection should resolve")
	_assert(game.deck.size() == deck_before_card_choice + 1, "selected event card should join the deck")
	_assert(bool(game.event_result.get("resolved", false)), "card selection should resume the event result")
	_assert(game.continue_event(), "card reward event should continue explicitly")

	_force_event(game, "advanced_moving_average")
	_assert(game.submit_event_answer("reduce_spike_add_delay"), "advanced waveform answer should resolve")
	_assert(game.choose_event_reward(1), "component reward should begin a shared selection")
	_assert(game.state == game.RunState.EVENT and str(game.pending_card_selection.get("owner", "")) == "event", "component selection should preserve the event owner")
	_assert(game.choose_pending_card(0), "event-owned component selection should resolve")
	_assert(game.relics.has("window_n8"), "selected event component should join the run")
	_assert(game.continue_event(), "component reward event should continue explicitly")

	_force_event(game, "advanced_alarm_hysteresis")
	_assert(game.submit_event_answer("on70_off60"), "hysteresis answer ID should resolve")
	_assert(game.choose_event_reward(0), "alarm-card reward should offer the exact uncommon alarm pool")
	var alarm_options: Array = game.pending_card_selection.get("options", []) as Array
	_assert(!alarm_options.is_empty(), "alarm reward should expose at least one exact catalog match")
	for raw_option in alarm_options:
		var alarm_card := raw_option as Dictionary
		_assert(
			str(alarm_card.get("rarity", "")) == "uncommon"
			and (alarm_card.get("tags", []) as Array).has("alarm"),
			"every alarm reward option should be both uncommon and alarm-tagged"
		)
	_assert(game.choose_pending_card(0), "alarm reward should resolve through the event owner")
	_assert(game.continue_event(), "alarm reward event should continue explicitly")

	_force_event(game, "advanced_polling_order")
	_assert(game.submit_event_answer(["schedule", "sample", "convert", "validate", "publish"]), "advanced ordering should accept an array of IDs")
	_assert(game.choose_event_reward(1), "chain-card reward should offer the exact uncommon chain pool")
	var chain_options: Array = game.pending_card_selection.get("options", []) as Array
	_assert(!chain_options.is_empty(), "chain reward should expose at least one exact catalog match")
	for raw_option in chain_options:
		var chain_card := raw_option as Dictionary
		_assert(
			str(chain_card.get("rarity", "")) == "uncommon"
			and (chain_card.get("tags", []) as Array).has("chain"),
			"every chain reward option should be both uncommon and chain-tagged"
		)
	_assert(game.choose_pending_card(0), "chain reward should resolve through the event owner")
	_assert(game.continue_event(), "chain reward event should continue explicitly")

	_force_event(game, "basic_i2c_pullup")
	game.budget = 5
	_assert(game.submit_event_answer("change_sample_period"), "wrong budget answer should resolve")
	_assert(game.budget == 0, "budget penalty should clamp at zero")
	_assert(game.continue_event(), "budget penalty should not block continuation")

	_force_event(game, "basic_i2c_result")
	var negative_count_before: int = game.deck.size()
	_assert(game.submit_event_answer("use_stale_value"), "wrong code-trace answer should resolve")
	_assert(game.deck.size() == negative_count_before + 1 and _array_has_id(game.deck, "i2c_nack"), "negative penalty should add exactly one declared card")
	_assert(game.continue_event(), "negative penalty should still allow continuation")

	_force_event(game, "basic_adc_spike")
	_assert(game.submit_event_answer("spike_noise"), "waveform answer ID should resolve")
	_assert(game.choose_event_reward(1), "node-reveal reward should resolve")
	_assert(game.revealed_nodes == [3, 4], "node-reveal reward should retain structured node IDs")
	_assert(game.continue_event(), "node-reveal reward should allow continuation")

	_force_event(game, "advanced_address_shift")
	var upgraded_count_before: int = game.deck.size()
	_assert(game.submit_event_answer("write_byte_0x46"), "address answer ID should resolve")
	_assert(game.choose_event_reward(0), "upgraded-card reward should resolve")
	_assert(game.deck.size() == upgraded_count_before + 1, "upgraded-card reward should add one card")
	var gained_address_shift := game.deck[game.deck.size() - 1] as Dictionary
	_assert(str(gained_address_shift.get("id", "")) == "address_shift" and bool(gained_address_shift.get("upgraded", false)), "address reward should add the specified upgraded card")
	_assert(game.continue_event(), "upgraded-card reward should allow continuation")

	_assert_failed_question_rewards_preserve_choices(game)

	var malformed_stability: int = game.stability
	var malformed_budget: int = game.budget
	var malformed_deck_size: int = game.deck.size()
	game.current_event = {
		"id": "malformed_event",
		"tier": "basic",
		"questionType": "diagnosis",
		"options": [],
		"correctAnswer": "missing",
		"rewardChoices": [],
		"penalty": {"op": "heal", "amount": -50, "minimum": 1}
	}
	game.state = game.RunState.EVENT
	game.event_answer_locked = false
	game.event_result.clear()
	game.pending_card_selection.clear()
	_assert(game.submit_event_answer("missing"), "malformed event should resolve safely")
	_assert(str(game.event_result.get("explanation", "")).contains("事件数据无效"), "malformed event should expose a visible data error")
	_assert(game.stability == malformed_stability and game.budget == malformed_budget and game.deck.size() == malformed_deck_size, "malformed event should apply no consequence")
	_assert(game.continue_event() and game.state == game.RunState.MAP, "malformed event should safely continue to map")


func _assert_failed_question_rewards_preserve_choices(game) -> void:
	game._reset_run()
	_force_event(game, "advanced_moving_average")
	game.relics.append("window_n8")
	_assert(game.submit_event_answer("reduce_spike_add_delay"), "owned-component setup should accept the correct answer")
	var owned_rewards: Array = (game.event_result.get("rewardChoices", []) as Array).duplicate(true)
	_assert(!game.choose_event_reward(1), "an already-owned component reward should fail without consumption")
	_assert(
		bool(game.event_result.get("rewardPending", false))
		and !game.event_result.has("chosenRewardId")
		and game.event_result.get("rewardChoices", []) == owned_rewards,
		"an already-owned component should leave both reward choices available and unconsumed"
	)
	_assert(game.choose_event_reward(0), "the other reward should remain selectable after an owned-component failure")
	_assert(game.choose_pending_card(0), "the retry reward should resolve its shared upgrade selection")
	_assert(game.continue_event(), "owned-component retry should still complete the event")

	game._reset_run()
	game.deck.clear()
	_force_event(game, "advanced_moving_average")
	_assert(game.submit_event_answer("reduce_spike_add_delay"), "empty-upgrade setup should accept the correct answer")
	var upgrade_rewards: Array = (game.event_result.get("rewardChoices", []) as Array).duplicate(true)
	_assert(!game.choose_event_reward(0), "an empty upgrade pool should fail without consumption")
	_assert(
		bool(game.event_result.get("rewardPending", false))
		and !game.event_result.has("chosenRewardId")
		and game.event_result.get("rewardChoices", []) == upgrade_rewards,
		"an empty upgrade pool should leave both reward choices available and unconsumed"
	)
	_assert(game.choose_event_reward(1), "the component reward should remain selectable after an empty-upgrade failure")
	_assert(game.choose_pending_card(0), "the component retry should resolve through shared selection")
	_assert(game.continue_event(), "empty-upgrade retry should still complete the event")

	game._reset_run()
	game.deck.clear()
	_force_event(game, "advanced_address_shift")
	_assert(game.submit_event_answer("write_byte_0x46"), "empty-remove setup should accept the correct answer")
	var remove_rewards: Array = (game.event_result.get("rewardChoices", []) as Array).duplicate(true)
	_assert(!game.choose_event_reward(1), "an empty remove pool should fail without consumption")
	_assert(
		bool(game.event_result.get("rewardPending", false))
		and !game.event_result.has("chosenRewardId")
		and game.event_result.get("rewardChoices", []) == remove_rewards,
		"an empty remove pool should leave both reward choices available and unconsumed"
	)
	_assert(game.choose_event_reward(0), "the direct card reward should remain selectable after an empty-remove failure")
	_assert(game.continue_event(), "empty-remove retry should still complete the event")


func _force_event(game, event_id: String) -> void:
	game.current_event = (game.event_defs[event_id] as Dictionary).duplicate(true)
	game.state = game.RunState.EVENT
	game.event_answer_locked = false
	game.event_result.clear()
	game.pending_card_selection.clear()


func _assert_fault_rule_counterplay(game) -> void:
	if !game.has_method("_fault_rule_definition") or !game.has_method("_fault_rule_preview"):
		_assert(false, "combat should expose data-driven fault-rule helpers")
		return
	if !_object_has_property(game, "fault_rule_state"):
		_assert(false, "combat should expose fault-rule state")
		return

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("mq2_sample"), game._card_copy("adc_continuous_sample")]
	game.processing_points = 3
	_assert(game.play_card(0) and game.play_card(0), "two smoke samples should resolve the MQ-2 fault rule")
	_assert(bool(game.fault_rule_state.get("triggered", false)), "second smoke sample should trigger the MQ-2 rule")
	_assert(game._pile_has_card("uncalibrated_reading"), "uncalibrated MQ-2 sampling should add its negative card")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("environment_baseline"), game._card_copy("mq2_sample"), game._card_copy("adc_continuous_sample")]
	game.processing_points = 3
	_assert(game.play_card(0) and game.play_card(0) and game.play_card(0), "diagnosis should prepare the MQ-2 counter before sampling")
	_assert(bool(game.fault_rule_state.get("suppressed", false)) and !bool(game.fault_rule_state.get("triggered", false)), "diagnosis should suppress the MQ-2 rule")

	game._start_encounter("adc_spike", "ordinary")
	game.hand = [game._card_copy("mq2_sample"), game._card_copy("bh1750_read")]
	game.processing_points = 3
	_assert(game.play_card(0) and game.play_card(0), "two collection cards should resolve the ADC fault rule")
	_assert(bool(game.fault_rule_state.get("triggered", false)), "second collection stage should trigger ADC spike")
	_assert(game._pile_has_card("abnormal_reading"), "uncountered ADC spike should add abnormal reading")

	game._start_encounter("adc_spike", "ordinary")
	game.hand = [game._card_copy("sliding_average"), game._card_copy("mq2_sample"), game._card_copy("bh1750_read")]
	game.processing_points = 3
	_assert(game.play_card(0) and game.play_card(0) and game.play_card(0), "filter should prepare the ADC counter before collection")
	_assert(bool(game.fault_rule_state.get("suppressed", false)) and !bool(game.fault_rule_state.get("triggered", false)), "filter should suppress ADC spike")

	game._start_encounter("lcd_blocking", "ordinary")
	game.trusted_data.smoke = 1
	game.hand = [game._card_copy("lcd_display")]
	game.processing_points = 2
	_assert(game.play_card(0), "unbuffered LCD output should be playable")
	_assert(int(game.fault_rule_state.get("nextEnergyPenalty", 0)) == -1, "unprepared LCD output should queue one less next-turn energy")
	game.encounter_evidence_tags = {"display": true, "buffer": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	_assert(game.state == game.RunState.REWARD, "queued LCD penalty should survive until encounter transition")
	game.current_node = {"type": "checkpoint_sensor"}
	game._start_checkpoint(true)
	_assert(game.processing_points == 3, "checkpoint should not inherit queued LCD energy loss")
	_assert((game.fault_rule_state.get("cardTagCounts", {}) as Dictionary).is_empty(), "checkpoint should not inherit fault tag counts")
	_assert((game.fault_rule_state.get("stageCounts", {}) as Dictionary).is_empty(), "checkpoint should not inherit fault stage counts")
	_assert(!bool(game.fault_rule_state.get("suppressed", false)), "checkpoint should not inherit fault suppression")
	_assert(!bool(game.fault_rule_state.get("triggered", false)), "checkpoint should not inherit fault trigger state")
	_assert(int(game.fault_rule_state.get("nextEnergyPenalty", 0)) == 0, "checkpoint should not inherit a queued fault penalty")

	game._start_encounter("lcd_blocking", "ordinary")
	game.trusted_data.smoke = 1
	game.hand = [game._card_copy("lcd_display")]
	game.processing_points = 2
	_assert(game.play_card(0), "second unbuffered LCD output should be playable")
	game.encounter_evidence_tags = {"display": true, "buffer": true}
	game.repair_progress = game.repair_target
	game._finish_encounter()
	game._start_tutorial_encounter()
	_assert(game.tutorial_active and game.state == game.RunState.COMBAT, "tutorial entry should begin the real practice encounter")
	_assert(game.processing_points == 3, "tutorial should not inherit queued LCD energy loss")
	_assert((game.fault_rule_state.get("cardTagCounts", {}) as Dictionary).is_empty(), "tutorial should not inherit fault tag counts")
	_assert((game.fault_rule_state.get("stageCounts", {}) as Dictionary).is_empty(), "tutorial should not inherit fault stage counts")
	_assert(!bool(game.fault_rule_state.get("suppressed", false)), "tutorial should not inherit fault suppression")
	_assert(!bool(game.fault_rule_state.get("triggered", false)), "tutorial should not inherit fault trigger state")
	_assert(int(game.fault_rule_state.get("nextEnergyPenalty", 0)) == 0, "tutorial should not inherit a queued fault penalty")
	game._reset_run()

	game._start_encounter("lcd_blocking", "ordinary")
	game.trusted_data.smoke = 1
	game.hand = [game._card_copy("data_cache"), game._card_copy("lcd_display")]
	game.processing_points = 2
	_assert(game.play_card(0) and game.play_card(0), "buffer should prepare the LCD counter before output")
	_assert(bool(game.fault_rule_state.get("suppressed", false)) and int(game.fault_rule_state.get("nextEnergyPenalty", 0)) == 0, "buffer should suppress LCD energy loss")

	game._start_encounter("alarm_jitter", "ordinary")
	game.alarm_markers = 1
	game.hand = [game._card_copy("led_alarm")]
	game.processing_points = 2
	_assert(game.play_card(0), "unfiltered alarm output should be playable")
	_assert(bool(game.fault_rule_state.get("triggered", false)) and game._pile_has_card("false_alarm"), "unfiltered alarm should add false alarm")

	game._start_encounter("alarm_jitter", "ordinary")
	game.alarm_markers = 1
	game.hand = [game._card_copy("sliding_average"), game._card_copy("led_alarm")]
	game.processing_points = 2
	_assert(game.play_card(0) and game.play_card(0), "filter should prepare the alarm counter before output")
	_assert(bool(game.fault_rule_state.get("suppressed", false)) and !bool(game.fault_rule_state.get("triggered", false)), "filter should suppress false alarm")

	game._start_encounter("i2c_congestion", "elite")
	game.hand = [game._card_copy("i2c_transaction"), game._card_copy("i2c_register_read")]
	game.processing_points = 3
	var stability_before_rule: int = game.stability
	_assert(game.play_card(0), "first I2C card should be safe")
	_assert(game.play_card(0), "second I2C card should resolve")
	_assert(game.stability == stability_before_rule - 6, "uncountered congestion should deal 6")
	_assert(game._pile_has_card("blocking_delay"), "uncountered congestion should add blocking delay")

	game._start_encounter("i2c_congestion", "elite")
	game.hand = [game._card_copy("uart_log"), game._card_copy("i2c_transaction"), game._card_copy("i2c_register_read")]
	game.processing_points = 4
	var protected_stability: int = game.stability
	_assert(game.play_card(0), "diagnosis card should prepare the counter")
	_assert(game.play_card(0) and game.play_card(0), "two I2C cards should play")
	_assert(game.stability == protected_stability, "diagnosis should suppress congestion once")

	game._start_encounter("bh1750_stale", "ordinary")
	game.raw_data.light = 1
	_assert(game.end_turn(), "light raw data should resolve BH1750 end-turn rule")
	_assert(_log_contains(game.message_log, "Fault rule bh1750_stale_raw triggered"), "unretained light raw data should trigger BH1750 stale rule")

	game._start_encounter("bh1750_stale", "ordinary")
	game.raw_data.light = 1
	game.hand = [game._card_copy("data_cache")]
	game.processing_points = 1
	_assert(game.play_card(0), "cache retention should prepare BH1750 end turn")
	_assert(bool(game.fault_rule_state.get("suppressed", false)), "cache retention should suppress stale BH1750 data")
	_assert(game.end_turn(), "cache retention should resolve BH1750 end turn")


func _object_has_property(object: Object, property_name: String) -> bool:
	for raw_property in object.get_property_list():
		if str((raw_property as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _array_has_id(items: Array, expected_id: String) -> bool:
	for raw_item in items:
		if str((raw_item as Dictionary).get("id", "")) == expected_id:
			return true
	return false


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 run flow tests passed")
		quit(0)
