extends RefCounted


static func load_json_object(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		push_error("Missing Ch09 data file: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid Ch09 data file: %s" % path)
		return {}
	return parsed as Dictionary


static func load_json_array(path: String, key: String) -> Array:
	var payload := load_json_object(path)
	var value = payload.get(key, [])
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func index_by_id(items: Array) -> Dictionary:
	var result := {}
	for raw_item in items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item := raw_item as Dictionary
		var item_id := str(item.get("id", ""))
		if !item_id.is_empty():
			result[item_id] = item.duplicate(true)
	return result


static func merge_question_defs(existing: Dictionary, questions: Array) -> Dictionary:
	var result := existing.duplicate(true)
	for raw_question in questions:
		if typeof(raw_question) != TYPE_DICTIONARY:
			continue
		var question := raw_question as Dictionary
		var question_id := str(question.get("id", ""))
		if !question_id.is_empty():
			result[question_id] = question.duplicate(true)
	return result


static func compose_events(mechanics: Dictionary, questions: Dictionary) -> Dictionary:
	var result := {}
	for raw_event_id in mechanics.keys():
		var event_id := str(raw_event_id)
		var mechanic := mechanics[event_id] as Dictionary
		var question_id := str(mechanic.get("questionId", event_id))
		if !questions.has(question_id):
			continue
		var merged := (questions[question_id] as Dictionary).duplicate(true)
		merged.merge(mechanic, true)
		result[event_id] = merged
	return result


static func resolve_run_map(run_map: Dictionary, run_seed: int) -> Dictionary:
	var resolved := run_map.duplicate(true)
	var used_by_type := {}
	var layers: Array = resolved.get("layers", [])
	for layer_index in range(layers.size()):
		var layer := layers[layer_index] as Dictionary
		var choices: Array = layer.get("choices", [])
		for choice_index in range(choices.size()):
			var choice := choices[choice_index] as Dictionary
			var pool: Array = choice.get("contentPool", [])
			if pool.is_empty():
				continue
			var node_type := str(choice.get("type", "content"))
			var used: Array = used_by_type.get(node_type, []) as Array
			var eligible: Array[String] = []
			for raw_id in pool:
				var content_id := str(raw_id)
				if !used.has(content_id):
					eligible.append(content_id)
			if eligible.is_empty():
				for raw_id in pool:
					eligible.append(str(raw_id))
			eligible.sort()
			var node_id := str(choice.get("id", "%d:%d" % [layer_index, choice_index]))
			var selection_hash := hash("%d:%s:%s" % [run_seed, node_type, node_id]) & 0x7FFFFFFF
			var selected_id := eligible[selection_hash % eligible.size()]
			choice["contentId"] = selected_id
			choice["resolvedFromPool"] = true
			used.append(selected_id)
			used_by_type[node_type] = used
	return resolved


static func resolve_boss_gates(phases: Array, run_seed: int) -> Array[String]:
	var result: Array[String] = []
	for phase_index in range(phases.size()):
		var phase := phases[phase_index] as Dictionary
		var options: Array = phase.get("gateOptions", [])
		if options.is_empty():
			result.append(str(phase.get("gate", "")))
			continue
		var selection_hash := hash("%d:boss_gate:%d" % [run_seed, phase_index]) & 0x7FFFFFFF
		var option := options[selection_hash % options.size()] as Dictionary
		result.append(str(option.get("id", "")))
	return result


static func select_question_event(
	event_defs: Dictionary,
	tier: String,
	history: Array,
	run_seed: int,
	node_id: String
) -> Dictionary:
	var tier_ids: Array[String] = []
	for raw_id in event_defs.keys():
		var event_id := str(raw_id)
		var event := event_defs[event_id] as Dictionary
		if str(event.get("tier", "")) == tier:
			tier_ids.append(event_id)
	tier_ids.sort()
	if tier_ids.is_empty():
		return {"event": {}, "relaxed": false}

	var prior_types := {}
	var prior_primary_tags := {}
	for raw_event in history:
		var event := raw_event as Dictionary
		prior_types[str(event.get("questionType", ""))] = true
		var tags := event.get("knowledgeTags", []) as Array
		if !tags.is_empty():
			prior_primary_tags[str(tags[0])] = true
	var eligible_ids: Array[String] = []
	for event_id in tier_ids:
		var event := event_defs[event_id] as Dictionary
		var tags := event.get("knowledgeTags", []) as Array
		var primary_tag := str(tags[0]) if !tags.is_empty() else ""
		if !prior_types.has(str(event.get("questionType", ""))) and !prior_primary_tags.has(primary_tag):
			eligible_ids.append(event_id)
	var relaxed := eligible_ids.is_empty()
	if relaxed:
		eligible_ids = tier_ids.duplicate()
	var selection_hash := hash("%d:%s" % [run_seed, node_id]) & 0x7FFFFFFF
	var selected_id := eligible_ids[selection_hash % eligible_ids.size()]
	return {
		"event": (event_defs[selected_id] as Dictionary).duplicate(true),
		"relaxed": relaxed
	}
