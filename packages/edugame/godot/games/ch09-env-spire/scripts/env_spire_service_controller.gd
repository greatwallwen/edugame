extends RefCounted


static func boss_gap_card_id(deck: Array, card_defs: Dictionary, output_tags: Array) -> String:
	var existing_outputs := deck_output_types(deck, output_tags)
	if existing_outputs.size() >= 2:
		return ""
	for output_tag in output_tags:
		if existing_outputs.has(output_tag):
			continue
		for raw_id in card_defs.keys():
			var card := card_defs[str(raw_id)] as Dictionary
			if ["common", "uncommon"].has(str(card.get("rarity", ""))) and (card.get("tags", []) as Array).has(output_tag):
				return str(raw_id)
	return ""


static func missing_boss_stage_tags(deck: Array, requirements: Array, output_tags: Array) -> Array[String]:
	var missing: Array[String] = []
	for raw_requirement in requirements:
		var requirement := raw_requirement as Dictionary
		if !deck_has_any_tag(deck, requirement.get("tags", []) as Array):
			missing.append(str(requirement.get("id", "")))
	if deck_output_types(deck, output_tags).size() < 2:
		missing.append("output")
	return missing


static func recommended_card_id(deck: Array, card_defs: Dictionary, requirements: Array, output_tags: Array) -> String:
	var missing := missing_boss_stage_tags(deck, requirements, output_tags)
	if missing.is_empty():
		return ""
	var required_tags: Array = []
	for raw_requirement in requirements:
		var requirement := raw_requirement as Dictionary
		if str(requirement.get("id", "")) == missing[0]:
			required_tags = requirement.get("tags", []) as Array
			break
	if missing[0] == "output":
		var existing_outputs := deck_output_types(deck, output_tags)
		for output_tag in output_tags:
			if !existing_outputs.has(output_tag):
				required_tags.append(output_tag)
	var best_id := ""
	var best_rarity_rank := 99
	for raw_id in card_defs.keys():
		var card_id := str(raw_id)
		var card := card_defs[card_id] as Dictionary
		var rarity := str(card.get("rarity", ""))
		if !["common", "uncommon"].has(rarity):
			continue
		var card_tags: Array = card.get("tags", [])
		var fills_gap := false
		for raw_tag in required_tags:
			if card_tags.has(str(raw_tag)):
				fills_gap = true
				break
		if !fills_gap:
			continue
		var rarity_rank := 0 if rarity == "common" else 1
		if rarity_rank < best_rarity_rank:
			best_id = card_id
			best_rarity_rank = rarity_rank
	return best_id


static func deck_output_types(deck: Array, output_tags: Array) -> Dictionary:
	var result := {}
	for raw_card in deck:
		var tags: Array = (raw_card as Dictionary).get("tags", [])
		for output_tag in output_tags:
			if tags.has(output_tag):
				result[output_tag] = true
	return result


static func deck_has_any_tag(deck: Array, required_tags: Array) -> bool:
	for raw_card in deck:
		var tags: Array = (raw_card as Dictionary).get("tags", [])
		for tag in required_tags:
			if tags.has(tag):
				return true
	return false


static func choose(host, action_id: String, config: Dictionary) -> bool:
	if !bool(host._gameplay_action_allowed()) or host.state != int(config["restState"]):
		return false
	if !(config["actions"] as Array).has(action_id) or !unavailable_reason(host, action_id, config).is_empty():
		return false
	match action_id:
		"maintenance":
			host.stability = mini(host.max_stability, host.stability + int(config["repairAmount"]))
			apply_payment(host, action_id, config)
			host.state = int(config["mapState"])
		"upgrade":
			host._open_card_selection("event_card", host._question_deck_options({}, "upgrade_card"), [], "service", {"action": "upgrade_card", "serviceAction": action_id})
		"add":
			host._open_card_selection("event_card", add_options(host, config), [], "service", {"action": "add_card", "serviceAction": action_id})
		"remove":
			host._open_card_selection("event_card", host._question_deck_options({}, "remove_card"), [], "service", {"action": "remove_card", "serviceAction": action_id})
		"skip":
			host.state = int(config["mapState"])
		_:
			return false
	return host.state == int(config["mapState"]) or !host.pending_card_selection.is_empty()


static func unavailable_reason(host, action_id: String, config: Dictionary) -> String:
	if !(config["actions"] as Array).has(action_id):
		return "无效操作"
	match action_id:
		"maintenance":
			if host.max_stability <= 30:
				return "最大稳定度无法继续降低"
			return "稳定度已满" if host.stability >= host.max_stability else ""
		"upgrade":
			if host.stability <= int(config["upgradeDamage"]):
				return "稳定度不足以承担固件风险"
			return "没有可升级卡牌" if host._question_deck_options({}, "upgrade_card").is_empty() else ""
		"add":
			return "没有可补充卡牌" if add_options(host, config).is_empty() else ""
		"remove":
			return "牌组无法继续精简" if host.deck.size() <= 1 else ""
	return ""


static func apply_payment(host, action_id: String, config: Dictionary) -> void:
	match action_id:
		"maintenance":
			host.max_stability = maxi(30, host.max_stability - int(config["maintenanceMaxCost"]))
			host.stability = mini(host.stability, host.max_stability)
		"upgrade":
			host.stability = maxi(1, host.stability - int(config["upgradeDamage"]))
		"add":
			host.pending_service_reroute_lock = true
		"remove":
			host.pending_service_energy_penalty -= 1


static func add_options(host, config: Dictionary) -> Array:
	var ids: Array[String] = []
	for raw_id in host.card_defs.keys():
		var card_id := str(raw_id)
		var card := host.card_defs[card_id] as Dictionary
		if str(card.get("rarity", "")) != "starter" and !bool(card.get("negative", false)):
			ids.append(card_id)
	ids.sort()
	host._shuffle(ids)
	var preferred_id := recommended_card_id(host.deck, host.card_defs, config["stageRequirements"], config["outputTags"]) if host.current_layer >= 9 else boss_gap_card_id(host.deck, host.card_defs, config["outputTags"])
	var options: Array = []
	if !preferred_id.is_empty() and ids.has(preferred_id):
		options.append(host._card_copy(preferred_id))
		ids.erase(preferred_id)
	for card_id in ids:
		options.append(host._card_copy(card_id))
		if options.size() >= 3:
			break
	return options
