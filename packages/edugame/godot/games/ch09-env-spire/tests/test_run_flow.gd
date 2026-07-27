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
	_assert(bool(game.choose_event_option(1)), "event option should resolve")
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

	var run_states: Dictionary = game.get_script().get_script_constant_map().get("RunState", {})
	if !run_states.has("COMPONENT"):
		_assert(false, "component node should expose a dedicated run state")
	else:
		game._reset_run()
		game.current_layer = 5
		_assert(bool(game.choose_node(0)), "node six should open the component choice")
		_assert(game.state == int(run_states.get("COMPONENT")), "component node should enter its choice state")
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
