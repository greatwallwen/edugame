extends RefCounted

const Content = preload("res://scripts/env_spire_content.gd")


static func reset_fixture(host, deck_fixture: String, coverage_card_ids: Array) -> void:
	host.node_lab_active = true
	host._reset_run()
	host.formal_run_active = false
	host.lab_deck_fixture = deck_fixture
	host.stability = host.max_stability
	host.relics.clear()
	if deck_fixture == "coverage":
		host.deck.clear()
		for card_id in coverage_card_ids:
			host.deck.append(host._card_copy(card_id))
	host.draw_pile = host.deck.duplicate(true)
	host._shuffle(host.draw_pile)
	host.discard_pile.clear()
	host.exhaust_pile.clear()
	host.hand.clear()
	host._reset_combat_resources()


static func add_card_to_hand(host, card_id: String) -> bool:
	if !bool(host._gameplay_action_allowed()) or !host.node_lab_active:
		return false
	var card: Dictionary = host._card_copy(card_id)
	if card.is_empty():
		return false
	host.hand.append(card)
	host._render_state()
	return true


static func remove_hand_card(host, hand_index: int) -> bool:
	if !bool(host._gameplay_action_allowed()):
		return false
	if !host.node_lab_active or hand_index < 0 or hand_index >= host.hand.size():
		return false
	host.hand.remove_at(hand_index)
	host._render_state()
	return true


static func remove_deck_card(host, card_id: String) -> bool:
	if !bool(host._gameplay_action_allowed()) or !host.node_lab_active:
		return false
	for deck_index in range(host.deck.size()):
		var card := host.deck[deck_index] as Dictionary
		if str(card.get("id", "")) != card_id:
			continue
		host.deck.remove_at(deck_index)
		host._render_state()
		return true
	return false


static func set_stability(host, value: int) -> bool:
	if !bool(host._gameplay_action_allowed()) or !host.node_lab_active:
		return false
	host.stability = clampi(value, 1, host.max_stability)
	host._render_state()
	return true


static func set_fault_remaining(host, value: int, combat_state: int) -> bool:
	if !bool(host._gameplay_action_allowed()):
		return false
	if !host.node_lab_active or host.state != combat_state or host.repair_target <= 0:
		return false
	var remaining := clampi(value, 0, host.repair_target)
	host.repair_progress = host.repair_target - remaining
	host._render_state()
	return true


static func fault_remaining(host) -> int:
	if !host.node_lab_active:
		return -1
	return clampi(host.repair_target - host.repair_progress, 0, maxi(host.repair_target, 0))


static func start_scenario(host, entry: Dictionary, deck_fixture: String, states: Dictionary, coverage_card_ids: Array) -> bool:
	if !bool(host._gameplay_action_allowed()) or entry.is_empty():
		return false
	var selected_entry := entry.duplicate(true)
	reset_fixture(host, deck_fixture, coverage_card_ids)
	host.run_seed = int(selected_entry.get("seedId", host.run_seed))
	host.rng.seed = host.run_seed
	host.lab_current_entry = selected_entry
	var kind := str(selected_entry.get("kind", ""))
	match kind:
		"enemy":
			var tier := str(selected_entry.get("tier", "ordinary"))
			host.current_node = {"type": tier, "contentId": selected_entry.get("contentId", "")}
			host.boss_phase = 0
			host._start_encounter(str(selected_entry.get("contentId", "")), tier)
		"boss_phase":
			host.boss_phase = int(selected_entry.get("phase", 0))
			host.current_node = {"type": "boss", "contentId": selected_entry.get("contentId", "warehouse_acceptance")}
			host._start_encounter(str(selected_entry.get("contentId", "warehouse_acceptance")), "boss")
		"boss_gate":
			host.boss_phase = int(selected_entry.get("phase", 0))
			var boss_definition := host.enemy_defs.get(str(selected_entry.get("contentId", "warehouse_acceptance")), {}) as Dictionary
			host.boss_gate_ids = Content.resolve_boss_gates(boss_definition.get("phases", []) as Array, host.run_seed)
			if host.boss_phase >= 0 and host.boss_phase < host.boss_gate_ids.size():
				host.boss_gate_ids[host.boss_phase] = str(selected_entry.get("gateId", ""))
			host.current_node = {"type": "boss", "contentId": selected_entry.get("contentId", "warehouse_acceptance")}
			host._start_encounter(str(selected_entry.get("contentId", "warehouse_acceptance")), "boss")
		"event", "question_event":
			var selected_event := (host.event_defs.get(str(selected_entry.get("contentId", "")), {}) as Dictionary).duplicate(true)
			if selected_event.is_empty():
				return false
			host._begin_question_event(selected_event)
		"question_correct", "question_wrong":
			var result_event := (host.event_defs.get(str(selected_entry.get("contentId", "")), {}) as Dictionary).duplicate(true)
			if result_event.is_empty():
				return false
			host._begin_question_event(result_event)
			if !bool(host.force_lab_question_result(kind == "question_correct")):
				return false
		"fault_rule":
			var fault_enemy_id := str(selected_entry.get("contentId", ""))
			var fault_tier := str(selected_entry.get("tier", "ordinary"))
			host.current_node = {"type": fault_tier, "contentId": fault_enemy_id}
			host._start_encounter(fault_enemy_id, fault_tier)
			if host.current_encounter.is_empty() or !prepare_fault_rule_hand(host):
				return false
		"checkpoint_sensor":
			host.current_node = {"type": "checkpoint_sensor"}
			host._start_checkpoint(true)
		"checkpoint_trust":
			host.current_node = {"type": "checkpoint_trust"}
			host._start_checkpoint(false)
		"component":
			host._open_component_choice()
		"service":
			host.current_node = {"type": "service", "label": "节点实验室休整"}
			host.state = int(states["rest"])
		"reward":
			host._open_reward()
		_:
			return false
	host._render_state()
	if host.node_lab_overlay != null:
		host.node_lab_overlay.show_scenario_controls()
	return true


static func prepare_fault_rule_hand(host) -> bool:
	var rule_id := str(host._fault_rule_definition().get("id", ""))
	var card_ids := fault_rule_hand_ids(rule_id)
	if card_ids.is_empty():
		return false
	host.hand.clear()
	host.draw_pile.clear()
	host.discard_pile.clear()
	host.exhaust_pile.clear()
	for card_id in card_ids:
		var card: Dictionary = host._card_copy(card_id)
		if card.is_empty():
			return false
		host.hand.append(card)
	host.processing_points = 6
	if ["lcd_unprepared_output", "display_bus_deadlock"].has(rule_id):
		host.trusted_data["smoke"] = 1
	elif rule_id == "alarm_without_trust":
		host.alarm_markers = 1
	elif ["i2c_second_transaction", "hdc1080_conversion_wait", "i2c_address_collision"].has(rule_id):
		host.raw_data["light"] = 2
	return true


static func fault_rule_hand_ids(rule_id: String) -> Array[String]:
	var ids: Array[String] = []
	match rule_id:
		"mq2_uncalibrated": ids.append_array(["mq2_sample", "mq2_sample", "environment_baseline"])
		"bh1750_stale_raw": ids.append_array(["bh1750_read", "data_cache"])
		"adc_second_collect": ids.append_array(["mq2_sample", "bh1750_read", "outlier_reject"])
		"lcd_unprepared_output": ids.append_array(["lcd_display", "data_cache"])
		"alarm_without_trust": ids.append_array(["led_alarm", "sliding_average"])
		"i2c_second_transaction": ids.append_array(["i2c_transaction", "i2c_transaction", "environment_baseline"])
		"mq2_baseline_drift": ids.append_array(["mq2_sample", "environment_baseline"])
		"bh1750_early_read": ids.append_array(["bh1750_read", "task_yield"])
		"hdc1080_conversion_wait": ids.append_array(["i2c_transaction", "i2c_transaction", "task_yield"])
		"i2c_address_collision": ids.append_array(["i2c_transaction", "logic_probe"])
		"uart_frame_overrun": ids.append_array(["interrupt_trace", "interrupt_trace", "task_yield"])
		"multi_sensor_race": ids.append_array(["mq2_sample", "bh1750_read", "task_yield"])
		"display_bus_deadlock": ids.append_array(["lcd_display", "task_yield"])
	return ids


static func restart_scenario(host, states: Dictionary, coverage_card_ids: Array) -> bool:
	if !bool(host._gameplay_action_allowed()) or host.lab_current_entry.is_empty():
		return false
	return start_scenario(host, host.lab_current_entry, host.lab_deck_fixture, states, coverage_card_ids)


static func return_to_catalog(host, waiting_state: int) -> void:
	host._reset_combat_resources()
	host.reward_choices.clear()
	host.component_choices.clear()
	host.current_event.clear()
	host.state = waiting_state
	if host.node_lab_overlay != null:
		host.node_lab_overlay.show_catalog()
	host._render_state()
