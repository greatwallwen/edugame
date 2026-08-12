extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card_rules = load("res://scripts/env_spire_card_rules.gd")
	var fault_rules = load("res://scripts/env_spire_fault_rules.gd")
	var run_rules = load("res://scripts/env_spire_run_rules.gd")
	var content = load("res://scripts/env_spire_content.gd")
	var component_rules = load("res://scripts/env_spire_component_rules.gd")
	var learning_report = load("res://scripts/env_spire_learning_report.gd")
	var run_snapshot = load("res://scripts/env_spire_run_snapshot.gd")
	var service_controller = load("res://scripts/env_spire_service_controller.gd")
	var node_lab_controller = load("res://scripts/env_spire_node_lab_controller.gd")
	_assert(card_rules != null, "card rules module should load")
	_assert(fault_rules != null, "fault rules module should load")
	_assert(run_rules != null, "run rules module should load")
	_assert(content != null, "content module should load")
	_assert(component_rules != null, "component rules module should load")
	_assert(learning_report != null, "learning report module should load")
	_assert(run_snapshot != null, "run snapshot module should load")
	_assert(service_controller != null, "service controller should load")
	_assert(node_lab_controller != null, "node lab controller should load")
	if card_rules == null or fault_rules == null or run_rules == null or content == null or component_rules == null or learning_report == null or run_snapshot == null or service_controller == null or node_lab_controller == null:
		_finish()
		return

	var discounted_cost: int = card_rules.card_cost({
		"cost": 2,
		"type": "interface",
		"tags": ["i2c"]
	}, {
		"i2cPenalty": 1,
		"i2cDiscount": 1,
		"interfaceDiscount": 1
	})
	_assert(discounted_cost == 1, "card cost should combine penalties and one-shot discounts")
	var chain: Dictionary = card_rules.chain_transition({
		"stage": "convert",
		"type": "defense"
	}, {
		"stageOrder": ["collect", "convert", "process", "output"],
		"lastStage": "collect",
		"chainCount": 0,
		"rewardsClaimed": {}
	})
	_assert(chain.get("decision") == "advances", "ordered defense cards should advance the chain")
	var preserved: Dictionary = card_rules.chain_transition({
		"stage": "output",
		"type": "defense"
	}, {
		"stageOrder": ["collect", "convert", "process", "output"],
		"lastStage": "collect",
		"chainCount": 0,
		"rewardsClaimed": {}
	})
	_assert(preserved.get("decision") == "preserves", "out-of-order defense cards should preserve the chain")

	var triggered: Dictionary = fault_rules.evaluate_after_card({
		"timing": "after_card",
		"triggerTag": "i2c",
		"triggerCount": 2,
		"counterTags": ["retry"]
	}, {
		"tags": ["i2c"]
	}, {
		"triggerMatches": 1,
		"suppressed": false,
		"triggered": false
	}, {
		"retainData": false,
		"trustedTotal": 0,
		"chainCount": 0
	})
	_assert(triggered.get("triggered") == true, "fault evaluation should trigger at its threshold")
	var suppressed: Dictionary = fault_rules.evaluate_after_card({
		"timing": "after_card",
		"triggerTag": "i2c",
		"triggerCount": 1,
		"counterTags": ["retry"]
	}, {
		"tags": ["retry"]
	}, {}, {})
	_assert(suppressed.get("suppressed") == true, "fault evaluation should report a matching counter")
	var penalties: Array = fault_rules.penalties({
		"penalties": [
			{"op": "add_negative", "cardId": "stale_data"},
			{"op": "damage", "amount": 5},
			{"op": "next_energy", "amount": -1}
		]
	})
	_assert(penalties.size() == 3, "fault rules should expose every declared data-driven penalty")

	var evidence: Dictionary = run_rules.evidence_result(
		[["sample", "diagnosis"], ["convert"], ["output", "alarm"]],
		{"sample": true, "convert": true, "alarm": true}
	)
	_assert(evidence.get("met") == true and evidence.get("completed") == 3, "evidence groups should accept any tag in each group")
	_assert(run_rules.boss_requirements_met("trusted_and_filter", {
		"trustedSourceCount": 2,
		"filtersPlayed": 1,
		"calibrationsPlayed": 0
	}), "filter gate should require two trusted sources plus filtering")
	_assert(run_rules.boss_requirements_met("two_sources", {"sourceCoverageCount": 2}), "two-source gate should accept two sources")
	_assert(!run_rules.boss_requirements_met("three_sources", {"sourceCoverageCount": 2}), "three-source gate should reject two sources")
	_assert(run_rules.boss_requirements_met("three_sources", {"sourceCoverageCount": 3}), "three-source gate should accept three sources")
	_assert(run_rules.boss_requirements_met("trusted_and_calibration", {"trustedSourceCount": 2, "calibrationsPlayed": 1}), "calibration gate should require calibration")
	_assert(run_rules.boss_requirements_met("two_output_types", {"distinctOutputCount": 2}), "output gate should accept two output types")
	_assert(run_rules.boss_requirements_met("acceptance_output", {"acceptancePlayed": true, "otherOutputCount": 1}), "acceptance gate should require acceptance plus another output")
	_assert(run_rules.calculate_score({
		"checkpointsPassed": 2,
		"relicCount": 1,
		"bossReviewUsed": false,
		"stability": 40,
		"maxStability": 70,
		"sourceCoverageCount": 3,
		"trustedSourceCount": 2,
		"filtersPlayed": 1
	}) == 100, "complete run evidence should reach the score cap")

	var mechanics: Dictionary = content.index_by_id([{
		"id": "event_a",
		"questionId": "question_a",
		"tier": "basic",
		"rewardChoices": [{}, {}],
		"penalty": {"op": "heal", "amount": -4}
	}])
	var questions: Dictionary = content.index_by_id([{
		"id": "question_a",
		"prompt": "Injected prompt",
		"questionType": "diagnosis"
	}])
	var events: Dictionary = content.compose_events(mechanics, questions)
	_assert(events.size() == 1, "content module should compose mechanics with questions")
	_assert(str((events.get("event_a", {}) as Dictionary).get("prompt", "")) == "Injected prompt", "composed events should contain teaching content")
	_assert(str((events.get("event_a", {}) as Dictionary).get("tier", "")) == "basic", "composed events should retain gameplay mechanics")

	var pooled_map := {
		"id": "pool_test",
		"seedId": 77,
		"layers": [
			{"layer": 1, "choices": [{"id": "n1", "type": "ordinary", "contentPool": ["a", "b", "c"]}]},
			{"layer": 2, "choices": [{"id": "n2", "type": "ordinary", "contentPool": ["a", "b", "c"]}]},
			{"layer": 3, "choices": [{"id": "n3", "type": "elite", "contentPool": ["x", "y"]}]}
		]
	}
	var resolved_a: Dictionary = content.resolve_run_map(pooled_map, 77)
	var resolved_b: Dictionary = content.resolve_run_map(pooled_map, 77)
	_assert(resolved_a == resolved_b, "map content pools should resolve deterministically")
	var layers: Array = resolved_a.get("layers", [])
	var first_id := str((((layers[0] as Dictionary).get("choices", []) as Array)[0] as Dictionary).get("contentId", ""))
	var second_id := str((((layers[1] as Dictionary).get("choices", []) as Array)[0] as Dictionary).get("contentId", ""))
	_assert(!first_id.is_empty() and first_id != second_id, "same-tier pools should avoid repeats while alternatives remain")

	var component_defs := {
		"precision_reference": {"effect": {"id": "first_calibration_free", "amount": 1}},
		"dma_channel": {"effect": {"id": "first_buffer_draw", "amount": 1}},
		"watchdog_timer": {"effect": {"id": "first_damage_reduction", "amount": 4}},
		"shielded_cable": {"effect": {"id": "first_analog_repair", "amount": 3}},
		"trace_probe": {"effect": {"id": "first_diagnosis_block", "amount": 5}}
	}
	var owned := component_defs.keys()
	var started: Dictionary = component_rules.begin_encounter(component_defs, owned, {"weaknessTags": []})
	var tracking := started.get("tracking", {}) as Dictionary
	_assert(component_rules.adjusted_cost(2, {"tags": ["calibration"]}, component_defs, owned, tracking) == 0, "precision reference should make the first calibration free")
	var played: Dictionary = component_rules.after_play({"tags": ["buffer", "analog", "diagnosis"]}, {"turn": 1}, component_defs, owned, tracking)
	var actions: Array = played.get("actions", [])
	_assert(actions.has({"op": "draw", "amount": 1}), "DMA channel should draw after the first buffer card")
	_assert(actions.has({"op": "repair", "amount": 3}), "shielded cable should repair after the first analog card")
	_assert(actions.has({"op": "block", "amount": 5}), "trace probe should block after the first diagnosis card")
	var damage_result: Dictionary = component_rules.modify_damage(9, component_defs, owned, played.get("tracking", {}) as Dictionary)
	_assert(int(damage_result.get("amount", 0)) == 5, "watchdog should reduce the first stability damage by four")
	var report: Dictionary = learning_report.build([], {
		"tags": {
			"mastered": {"positive": 2, "errors": 0},
			"review": {"positive": 4, "errors": 1},
			"building": {"positive": 1, "errors": 0}
		},
		"questionCorrect": 3,
		"questionTotal": 4,
		"weaknessRepair": 30,
		"totalRepair": 50,
		"reviewFaultIds": ["fault_a"]
	})
	_assert((report.get("mastered", []) as Array).has("mastered"), "learning report should classify two clean positives as mastered")
	_assert((report.get("review", []) as Array).has("review"), "learning report should prioritize any error as review")
	_assert((report.get("building", []) as Array).has("building"), "learning report should classify one positive as building")
	_assert(is_equal_approx(float(report.get("questionAccuracy", 0.0)), 0.75), "learning report should calculate question accuracy")
	_assert(is_equal_approx(float(report.get("engineeringResolutionRate", 0.0)), 0.6), "learning report should calculate engineering repair rate")

	var service_deck := [
		{"tags": ["smoke", "display"]},
		{"tags": ["adc", "filter", "uart"]}
	]
	_assert(service_controller.deck_output_types(service_deck, ["display", "uart"]).size() == 2, "service controller should count distinct output types")
	_assert(service_controller.missing_boss_stage_tags(service_deck, [
		{"id": "source", "tags": ["smoke", "light"]},
		{"id": "trusted", "tags": ["adc", "i2c"]},
		{"id": "filter", "tags": ["filter", "calibration"]}
	], ["display", "uart"]).is_empty(), "service controller should recognize a boss-ready deck")
	_assert(node_lab_controller.fault_rule_hand_ids("display_bus_deadlock") == ["lcd_display", "task_yield"], "node lab controller should own fault-rule fixtures")

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
		print("Ch09 domain module tests passed")
		quit(0)
