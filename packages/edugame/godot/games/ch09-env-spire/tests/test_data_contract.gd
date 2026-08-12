extends SceneTree

const SINGLE_ROUTE_TYPES := [
	"ordinary", "event", "ordinary", "service",
	"checkpoint_sensor", "event", "ordinary", "checkpoint_trust",
	"service", "elite", "service", "boss"
]
const REQUIRED_ROUTE_MILESTONES := {
	2: {"type": "event", "contentId": "random_basic", "eventTier": "basic"},
	6: {"type": "event", "contentId": "random_advanced", "eventTier": "advanced"},
	11: {"type": "service", "contentId": "service"},
	12: {"type": "boss", "contentId": "warehouse_acceptance"}
}
const EVENT_IDS := [
	"advanced_address_shift",
	"advanced_alarm_hysteresis",
	"advanced_display_buffer",
	"advanced_moving_average",
	"advanced_nonblocking_loop",
	"advanced_outlier_reject",
	"advanced_polling_order",
	"advanced_uart_report",
	"basic_adc_spike",
	"basic_i2c_pullup",
	"basic_i2c_result",
	"basic_mq2_warmup",
	"basic_raw_trusted",
	"basic_sample_period",
	"basic_sensor_interface",
	"basic_signal_order"
]
const EVENT_EXPECTATIONS := {
	"basic_mq2_warmup": {
		"answer": "insufficient_warmup",
		"rewards": [{"op": "reveal_nodes", "nodes": [3, 4]}, {"op": "heal", "amount": 6}],
		"penalty": {"op": "heal", "amount": -6, "minimum": 1}
	},
	"basic_signal_order": {
		"answer": ["sensor", "interface", "convert", "output"],
		"rewards": [{"op": "choose_card", "rarity": "common"}, {"op": "heal", "amount": 8}],
		"penalty": {"op": "add_negative", "cardId": "stale_data"}
	},
	"basic_adc_spike": {
		"answer": "spike_noise",
		"rewards": [{"op": "choose_card", "rarity": "common", "tag": "filter"}, {"op": "reveal_nodes", "nodes": [3, 4]}],
		"penalty": {"op": "heal", "amount": -6, "minimum": 1},
		"waveform": {"samples": [20, 21, 20, 79, 21, 20]}
	},
	"basic_i2c_pullup": {
		"answer": "inspect_pullups",
		"rewards": [{"op": "heal", "amount": 6}, {"op": "reveal_nodes", "nodes": [3, 4]}],
		"penalty": {"op": "add_negative", "cardId": "i2c_nack"}
	},
	"basic_raw_trusted": {
		"answer": "convert_then_validate",
		"rewards": [{"op": "choose_card", "rarity": "common", "type": "process"}, {"op": "heal", "amount": 8}],
		"penalty": {"op": "add_negative", "cardId": "uncalibrated_reading"}
	},
	"basic_sample_period": {
		"answer": "nonblocking_500ms",
		"rewards": [{"op": "reveal_nodes", "nodes": [3, 4]}, {"op": "heal", "amount": 6}],
		"penalty": {"op": "heal", "amount": -6, "minimum": 1}
	},
	"basic_i2c_result": {
		"answer": "retry_and_log",
		"rewards": [{"op": "choose_card", "rarity": "common", "tag": "diagnosis"}, {"op": "heal", "amount": 6}],
		"penalty": {"op": "add_negative", "cardId": "i2c_nack"}
	},
	"basic_sensor_interface": {
		"answer": "mq2_adc_others_i2c",
		"rewards": [{"op": "reveal_nodes", "nodes": [3, 4]}, {"op": "choose_card", "rarity": "common", "type": "interface"}],
		"penalty": {"op": "heal", "amount": -6, "minimum": 1}
	},
	"advanced_moving_average": {
		"answer": "reduce_spike_add_delay",
		"rewards": [{"op": "upgrade_card", "type": "process"}, {"op": "choose_component", "componentIds": ["window_n8"]}],
		"penalty": {"op": "heal", "amount": -8, "minimum": 1},
		"waveform": {"raw": [20, 21, 70, 22, 21], "filtered": [20, 20, 37, 38, 37]}
	},
	"advanced_address_shift": {
		"answer": "write_byte_0x46",
		"rewards": [{"op": "add_upgraded_card", "cardId": "address_shift"}, {"op": "remove_card", "rarity": "starter"}],
		"penalty": {"op": "add_negative", "cardId": "stale_data"}
	},
	"advanced_nonblocking_loop": {
		"answer": "millis_state_machine",
		"rewards": [{"op": "choose_component", "componentIds": ["state_template"]}, {"op": "choose_card", "rarity": "uncommon", "tag": "scheduler"}],
		"penalty": {"op": "heal", "amount": -10, "minimum": 1}
	},
	"advanced_display_buffer": {
		"answer": "separate_sample_refresh",
		"rewards": [{"op": "choose_component", "componentIds": ["lcd_buffer"]}, {"op": "upgrade_card", "type": "output"}],
		"penalty": {"op": "add_negative", "cardId": "blocking_delay"}
	},
	"advanced_alarm_hysteresis": {
		"answer": "on70_off60",
		"rewards": [{"op": "choose_card", "rarity": "uncommon", "tag": "alarm"}, {"op": "remove_card", "rarity": "starter"}],
		"penalty": {"op": "add_negative", "cardId": "false_alarm"}
	},
	"advanced_outlier_reject": {
		"answer": "reject_isolated_before_average",
		"rewards": [{"op": "upgrade_card", "type": "process"}, {"op": "choose_component", "componentIds": ["window_n8"]}],
		"penalty": {"op": "add_negative", "cardId": "abnormal_reading"},
		"waveform": {"samples": [48, 49, 50, 121, 49, 50]}
	},
	"advanced_polling_order": {
		"answer": ["schedule", "sample", "convert", "validate", "publish"],
		"rewards": [{"op": "choose_component", "componentIds": ["serial_helper"]}, {"op": "choose_card", "rarity": "uncommon", "tag": "chain"}],
		"penalty": {"op": "heal", "amount": -8, "minimum": 1}
	},
	"advanced_uart_report": {
		"answer": "timestamp_status_raw_trusted",
		"rewards": [{"op": "upgrade_card", "type": "output"}, {"op": "remove_card", "rarity": "starter"}],
		"penalty": {"op": "heal", "amount": -10, "minimum": 1}
	}
}

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_payload = JSON.parse_string(FileAccess.get_file_as_string("res://levels/ch09_env_spire_level.json"))
	_assert(typeof(level_payload) == TYPE_DICTIONARY, "level manifest should be a JSON object")
	if typeof(level_payload) == TYPE_DICTIONARY:
		var level_data := (level_payload as Dictionary).get("data", {}) as Dictionary
		_assert(int(level_data.get("nodeCount", 0)) == 12, "level manifest should advertise all twelve route nodes")
	var cards := _load_array("res://data/cards.local.json", "cards")
	var enemies := _load_array("res://data/enemies.local.json", "enemies")
	var event_mechanics := _load_array("res://data/events.local.json", "events")
	var questions := _load_top_level_array("res://data/questions.local.json")
	var events := _compose_events(event_mechanics, questions)
	var relics := _load_array("res://data/relics.local.json", "relics")
	var maps := _load_array("res://data/run_maps.local.json", "maps")
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate() if scene != null else null
	if game != null:
		get_root().add_child(game)
		await process_frame
	var stretch_mode := str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	var allow_hidpi := bool(ProjectSettings.get_setting("display/window/dpi/allow_hidpi", true))

	_assert(stretch_mode == "disabled", "Responsive UI should use the browser's actual CSS-pixel dimensions")
	_assert(not allow_hidpi, "Web UI should not multiply its logical dimensions by device pixel ratio")
	var card_ids := {}
	for raw_card in cards:
		var card := raw_card as Dictionary
		if !bool(card.get("negative", false)):
			card_ids[str(card.get("id", ""))] = true
	_assert(card_ids.size() == 37, "graybox card pool should contain 37 playable cards")
	for card_id in [
		"polling_scan", "logic_probe", "task_yield", "median_filter",
		"dma_queue", "trusted_snapshot", "interrupt_trace", "multi_source_dashboard"
	]:
		_assert(card_ids.has(card_id), "card pool should contain %s" % card_id)
	if game == null:
		_assert(false, "main scene should expose the starter deck contract")
	else:
		var starter_ids: Array = game.get_script().get_script_constant_map().get("STARTER_CARD_IDS", [])
		_assert(starter_ids.count("unit_convert") == 1, "starter deck should keep one unit conversion")
		_assert(starter_ids.count("sliding_average") == 2, "starter deck should contain two filters")
	for raw_card in cards:
		var card := raw_card as Dictionary
		var can_be_zero_cost := int(card.get("cost", 0)) == 0 or int(card.get("upgradeCost", card.get("cost", 0))) == 0
		if !can_be_zero_cost:
			continue
		for effects in [card.get("effects", []), card.get("upgradeEffects", [])]:
			for raw_effect in effects:
				var effect := raw_effect as Dictionary
				if ["draw", "draw_discard", "select_draw", "draw_if_removed", "next_energy"].has(str(effect.get("op", ""))):
					_assert(int(effect.get("perTurnLimit", 0)) > 0, "%s zero-cost draw or refund should be turn-limited" % card.get("id", "card"))
	_assert(_unique_ids(cards), "card ids should be unique and non-empty")
	_assert(_count_where(enemies, "tier", "ordinary") == 10, "release build should define ten ordinary faults")
	_assert(_count_where(enemies, "tier", "elite") == 3, "release build should define three elite faults")
	_assert(_count_where(enemies, "tier", "boss") == 1, "MVP should define one boss")
	for raw_enemy in enemies:
		var enemy := raw_enemy as Dictionary
		if ["ordinary", "elite"].has(str(enemy.get("tier", ""))):
			var evidence_groups: Array = enemy.get("evidenceGroups", [])
			_assert(evidence_groups.size() >= 2, "%s should require at least two engineering evidence groups" % enemy.get("id", "enemy"))
			for raw_group in evidence_groups:
				_assert(raw_group is Array and !(raw_group as Array).is_empty(), "enemy evidence groups should contain one or more tags")
			var rule := enemy.get("faultRule", {}) as Dictionary
			_assert(!rule.is_empty(), "%s should declare faultRule" % enemy.get("id", "enemy"))
			_assert(!str(rule.get("id", "")).is_empty(), "fault rule should have an id")
			_assert(!str(rule.get("description", "")).is_empty(), "fault rule should explain its trigger")
			_assert(!str(rule.get("counterText", "")).is_empty(), "fault rule should explain its counter")
			_assert((rule.get("counterTags", []) as Array).size() >= 2 or bool(rule.get("behaviorCounter", false)), "fault rule should have broad counterplay")
			var penalties: Array = rule.get("penalties", [])
			_assert(!penalties.is_empty(), "%s should declare data-driven penalties" % enemy.get("id", "enemy"))
			for raw_penalty in penalties:
				var penalty := raw_penalty as Dictionary
				_assert(["add_negative", "damage", "next_energy"].has(str(penalty.get("op", ""))), "fault penalties should use supported operations")
		elif str(enemy.get("tier", "")) == "boss":
			var phases: Array = enemy.get("phases", [])
			_assert(phases.size() == 3, "Boss should retain three phases")
			for raw_phase in phases:
				var gate_options: Array = (raw_phase as Dictionary).get("gateOptions", [])
				_assert(gate_options.size() == 2, "each Boss phase should expose two visible gate options")
				for raw_gate in gate_options:
					var gate := raw_gate as Dictionary
					_assert(!str(gate.get("id", "")).is_empty() and !str(gate.get("label", "")).is_empty(), "Boss gate options should expose id and label")
	_assert(events.size() == 16, "question event pool should define sixteen events")
	_assert(_count_where(events, "tier", "basic") == 8, "question event pool should define eight basic events")
	_assert(_count_where(events, "tier", "advanced") == 8, "question event pool should define eight advanced events")
	var actual_event_ids: Array = []
	for raw_event in events:
		var event := raw_event as Dictionary
		var event_id := str(event.get("id", ""))
		actual_event_ids.append(event_id)
		_assert(["basic", "advanced"].has(str(event.get("tier", ""))), "event tier should be basic or advanced")
		_assert([
			"diagnosis", "ordering", "code_trace", "parameter", "waveform", "tradeoff"
		].has(str(event.get("questionType", ""))), "event should use a supported question type")
		_assert(!(event.get("knowledgeTags", []) as Array).is_empty(), "event should declare knowledge tags")
		_assert(event.has("correctAnswer"), "event should declare the answer")
		_assert(!str(event.get("explanation", "")).is_empty(), "event should explain the answer")
		_assert((event.get("rewardChoices", []) as Array).size() == 2, "event should offer two correct-answer rewards")
		_assert(!(event.get("penalty", {}) as Dictionary).is_empty(), "event should declare one wrong-answer penalty")
		var expected := EVENT_EXPECTATIONS.get(event_id, {}) as Dictionary
		_assert(!expected.is_empty(), "event %s should be part of the specified pool" % event_id)
		if expected.is_empty():
			continue
		_assert(_same_value(event.get("correctAnswer"), expected.get("answer")), "%s should keep answer identity on IDs or arrays" % event_id)
		var reward_effects: Array = []
		for raw_reward in event.get("rewardChoices", []) as Array:
			reward_effects.append((raw_reward as Dictionary).get("effect", {}))
		_assert(_same_value(reward_effects, expected.get("rewards")), "%s should declare the specified rewards" % event_id)
		_assert(_same_value(event.get("penalty"), expected.get("penalty")), "%s should declare the specified penalty" % event_id)
		if expected.has("waveform"):
			_assert(_same_value(event.get("waveform"), expected.get("waveform")), "%s should declare the specified waveform samples" % event_id)
	actual_event_ids.sort()
	_assert(actual_event_ids == EVENT_IDS, "question event pool should use the sixteen specified IDs")
	_assert(relics.size() == 10, "release build should define ten engineering components")
	var state_template := {}
	for raw_relic in relics:
		var relic := raw_relic as Dictionary
		if str(relic.get("id", "")) == "state_template":
			state_template = relic
	_assert(str((state_template.get("effect", {}) as Dictionary).get("id", "")) == "chain_draw", "state template should draw for the first complete chain instead of restoring energy")
	_assert(maps.size() == 3, "MVP should define three fixed map seeds")

	var enemy_ids := _ids_by_type(enemies)
	for raw_map in maps:
		var run_map := raw_map as Dictionary
		var layers: Array = run_map.get("layers", [])
		_assert(layers.size() == 12, "%s should contain twelve layers" % run_map.get("id", "map"))
		for index in range(layers.size()):
			var layer := layers[index] as Dictionary
			var choices: Array = layer.get("choices", [])
			_assert(int(layer.get("layer", 0)) == index + 1, "map layers should be numbered 1 through 12")
			_assert(choices.size() == 1, "single-route layers should contain exactly one choice")
			if choices.is_empty() or index >= SINGLE_ROUTE_TYPES.size():
				continue
			var choice := choices[0] as Dictionary
			var node_type := str(choice.get("type", ""))
			var content_id := str(choice.get("contentId", ""))
			_assert(node_type == SINGLE_ROUTE_TYPES[index], "layer %d should be %s" % [index + 1, SINGLE_ROUTE_TYPES[index]])
			var layer_number := index + 1
			if REQUIRED_ROUTE_MILESTONES.has(layer_number):
				var milestone := REQUIRED_ROUTE_MILESTONES[layer_number] as Dictionary
				_assert(node_type == str(milestone.get("type", "")), "layer %d should use the required route node type" % layer_number)
				_assert(content_id == str(milestone.get("contentId", "")), "layer %d should use the required route content" % layer_number)
				if milestone.has("eventTier"):
					_assert(str(choice.get("eventTier", "")) == str(milestone.get("eventTier", "")), "layer %d should use the required event tier" % layer_number)
			if ["ordinary", "elite"].has(node_type):
				var content_pool: Array = choice.get("contentPool", [])
				_assert(!content_pool.is_empty(), "%s %s node should declare a content pool" % [run_map.get("id", "map"), node_type])
				for pooled_id in content_pool:
					_assert(enemy_ids.has(str(pooled_id)), "%s should resolve pooled enemy %s" % [run_map.get("id", "map"), pooled_id])
			elif node_type == "boss":
				_assert(enemy_ids.has(content_id), "%s should resolve enemy %s" % [run_map.get("id", "map"), content_id])
			elif node_type == "event":
				_assert(!str(choice.get("id", "")).is_empty(), "%s event node should expose a seeded-selection node id" % run_map.get("id", "map"))

	if game != null:
		game.queue_free()
		await process_frame
	_finish()


func _compose_events(mechanics: Array, questions: Array) -> Array:
	var questions_by_id := {}
	for raw_question in questions:
		var question := raw_question as Dictionary
		questions_by_id[str(question.get("id", ""))] = question
	var result: Array = []
	for raw_mechanic in mechanics:
		var mechanic := raw_mechanic as Dictionary
		var question_id := str(mechanic.get("questionId", ""))
		_assert(questions_by_id.has(question_id), "event mechanic should resolve question %s" % question_id)
		if !questions_by_id.has(question_id):
			continue
		var merged := (questions_by_id[question_id] as Dictionary).duplicate(true)
		merged.merge(mechanic, true)
		result.append(merged)
	return result


func _load_top_level_array(path: String) -> Array:
	if !FileAccess.file_exists(path):
		_assert(false, "%s should exist" % path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		_assert(false, "%s should contain a top-level array" % path)
		return []
	return parsed as Array


func _load_array(path: String, key: String) -> Array:
	if !FileAccess.file_exists(path):
		_assert(false, "%s should exist" % path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_assert(false, "%s should contain a JSON object" % path)
		return []
	var value = (parsed as Dictionary).get(key, [])
	if typeof(value) != TYPE_ARRAY:
		_assert(false, "%s should contain an array named %s" % [path, key])
		return []
	return value as Array


func _unique_ids(items: Array) -> bool:
	var seen := {}
	for raw_item in items:
		var item := raw_item as Dictionary
		var id := str(item.get("id", ""))
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true


func _count_where(items: Array, key: String, value: String) -> int:
	var count := 0
	for raw_item in items:
		if str((raw_item as Dictionary).get(key, "")) == value:
			count += 1
	return count


func _ids_by_type(items: Array) -> Dictionary:
	var result := {}
	for raw_item in items:
		var item := raw_item as Dictionary
		result[str(item.get("id", ""))] = true
	return result


func _same_value(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return float(actual) == float(expected)
	if actual is Array and expected is Array:
		var actual_array := actual as Array
		var expected_array := expected as Array
		if actual_array.size() != expected_array.size():
			return false
		for index in range(actual_array.size()):
			if !_same_value(actual_array[index], expected_array[index]):
				return false
		return true
	if actual is Dictionary and expected is Dictionary:
		var actual_dictionary := actual as Dictionary
		var expected_dictionary := expected as Dictionary
		if actual_dictionary.size() != expected_dictionary.size():
			return false
		for key in expected_dictionary:
			if !actual_dictionary.has(key) or !_same_value(actual_dictionary[key], expected_dictionary[key]):
				return false
		return true
	return actual == expected


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 data contract tests passed")
		quit(0)
