extends RefCounted


static func penalties(rule: Dictionary) -> Array:
	var result: Array = []
	for raw_penalty in rule.get("penalties", []) as Array:
		if raw_penalty is Dictionary:
			result.append((raw_penalty as Dictionary).duplicate(true))
	return result


static func card_matches_trigger(rule: Dictionary, card: Dictionary) -> bool:
	var trigger_tag := str(rule.get("triggerTag", ""))
	var trigger_stage := str(rule.get("triggerStage", ""))
	if trigger_tag.is_empty() and trigger_stage.is_empty():
		return false
	if !trigger_tag.is_empty() and !(card.get("tags", []) as Array).has(trigger_tag):
		return false
	if !trigger_stage.is_empty() and str(card.get("stage", "")) != trigger_stage:
		return false
	return true


static func behavior_counter(rule: Dictionary, snapshot: Dictionary) -> String:
	match str(rule.get("id", "")):
		"bh1750_stale_raw":
			return "cache_retention" if bool(snapshot.get("retainData", false)) else ""
		"alarm_without_trust":
			return "trusted_data" if int(snapshot.get("trustedTotal", 0)) > 0 else ""
		"i2c_second_transaction":
			return "chain3" if int(snapshot.get("chainCount", 0)) >= 2 else ""
	return ""


static func will_trigger(rule: Dictionary, card: Dictionary, state: Dictionary) -> bool:
	if str(rule.get("timing", "")) != "after_card":
		return false
	if !card_matches_trigger(rule, card):
		return false
	var threshold := int(rule.get("triggerCount", 1))
	return int(state.get("triggerMatches", 0)) + 1 >= threshold


static func counter_for_card(
	rule: Dictionary,
	card: Dictionary,
	state: Dictionary,
	snapshot: Dictionary
) -> String:
	if will_trigger(rule, card, state):
		return ""
	var counter_tags := rule.get("counterTags", []) as Array
	for raw_tag in card.get("tags", []) as Array:
		var tag := str(raw_tag)
		if counter_tags.has(tag):
			return tag
	return behavior_counter(rule, snapshot)


static func evaluate_after_card(
	rule: Dictionary,
	card: Dictionary,
	state: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	if str(rule.get("timing", "")) != "after_card":
		return {"triggered": false, "suppressed": false, "reason": "wrong_timing"}
	if bool(state.get("suppressed", false)):
		return {"triggered": false, "suppressed": true, "reason": "already_suppressed"}
	if bool(state.get("triggered", false)):
		return {"triggered": true, "suppressed": false, "reason": "already_triggered"}
	var counter := counter_for_card(rule, card, state, snapshot)
	if !counter.is_empty():
		return {"triggered": false, "suppressed": true, "reason": counter}
	var matches := int(state.get("triggerMatches", 0))
	if card_matches_trigger(rule, card):
		matches += 1
	var triggered := matches >= int(rule.get("triggerCount", 1))
	return {
		"triggered": triggered,
		"suppressed": false,
		"reason": "threshold" if triggered else "below_threshold",
		"triggerMatches": matches
	}


static func evaluate_end_turn(rule: Dictionary, state: Dictionary, snapshot: Dictionary) -> Dictionary:
	if str(rule.get("timing", "")) != "end_turn":
		return {"triggered": false, "suppressed": false, "reason": "wrong_timing"}
	if bool(state.get("suppressed", false)):
		return {"triggered": false, "suppressed": true, "reason": "already_suppressed"}
	if bool(state.get("triggered", false)):
		return {"triggered": true, "suppressed": false, "reason": "already_triggered"}
	var counter := behavior_counter(rule, snapshot)
	if !counter.is_empty():
		return {"triggered": false, "suppressed": true, "reason": counter}
	var source := str(rule.get("source", ""))
	var raw_data := snapshot.get("rawData", {}) as Dictionary
	var triggered := !source.is_empty() and int(raw_data.get(source, 0)) > 0
	return {
		"triggered": triggered,
		"suppressed": false,
		"reason": "source_present" if triggered else "source_absent"
	}
