extends RefCounted


static func card_cost(card: Dictionary, modifiers: Dictionary) -> int:
	var cost := int(card.get("upgradeCost", card.get("cost", 0))) if bool(card.get("upgraded", false)) else int(card.get("cost", 0))
	var tags := card.get("tags", []) as Array
	if tags.has("i2c"):
		cost += int(modifiers.get("i2cPenalty", 0))
		if int(modifiers.get("i2cDiscount", 0)) > 0:
			cost -= 1
	var card_type := str(card.get("type", ""))
	if card_type == "process" and int(modifiers.get("processDiscount", 0)) > 0:
		cost -= 1
	if card_type == "interface" and int(modifiers.get("interfaceDiscount", 0)) > 0:
		cost -= 1
	return maxi(cost, 0)


static func requirements_met(
	card: Dictionary,
	trusted_total: int,
	trusted_by_source: Dictionary,
	alarm_markers: int
) -> bool:
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if effect.has("consumeTrusted") and trusted_total < int(effect.get("consumeTrusted", 0)):
			return false
		if effect.has("consumeTrustedSource"):
			var source := str(effect.get("consumeTrustedSource", ""))
			if int(trusted_by_source.get(source, 0)) <= 0 and alarm_markers < int(effect.get("consumeAlarmFallback", 0)):
				return false
	return true


static func chain_transition(card: Dictionary, snapshot: Dictionary) -> Dictionary:
	var stage_order := snapshot.get("stageOrder", []) as Array
	var last_stage := str(snapshot.get("lastStage", ""))
	var chain_count := int(snapshot.get("chainCount", 0))
	var rewards_claimed := snapshot.get("rewardsClaimed", {}) as Dictionary
	var stage := str(card.get("stage", ""))
	var card_type := str(card.get("type", ""))
	var stage_index := stage_order.find(stage)
	var current_index := stage_order.find(last_stage)
	var decision := "preserves"
	if stage_index >= 0:
		if current_index < 0:
			if stage_index == 0:
				decision = "advances"
			elif !["defense", "power"].has(card_type):
				decision = "breaks"
		elif stage == last_stage:
			decision = "preserves"
		elif stage_index == current_index + 1:
			decision = "advances"
		elif !["defense", "power"].has(card_type):
			decision = "breaks"
	var predicted_chain := chain_count
	var predicted_last_stage := last_stage
	if decision == "advances":
		predicted_chain = 0 if stage_index == 0 else mini(chain_count + 1, 3)
		predicted_last_stage = stage
	elif decision == "breaks":
		predicted_chain = 0
		predicted_last_stage = stage
	return {
		"stage": stage,
		"current": stage == last_stage,
		"completed": stage_index >= 0 and current_index >= stage_index and chain_count == current_index,
		"next": stage_index >= 0 and stage_index == current_index + 1,
		"decision": decision,
		"pendingReward": pending_chain_reward(predicted_chain, decision, rewards_claimed),
		"chainCount": predicted_chain,
		"lastStage": predicted_last_stage
	}


static func next_chain_stage(stage_order: Array, last_stage: String) -> String:
	if stage_order.is_empty():
		return ""
	var current_index := stage_order.find(last_stage)
	if current_index < 0 or current_index >= stage_order.size() - 1:
		return str(stage_order[0])
	return str(stage_order[current_index + 1])


static func pending_chain_reward(predicted_chain: int, decision: String, rewards_claimed: Dictionary) -> String:
	if decision != "advances":
		return "none"
	if predicted_chain >= 1 and !bool(rewards_claimed.get("two", false)):
		return "+3 block"
	if predicted_chain >= 2 and !bool(rewards_claimed.get("three", false)):
		return "+1 processing point"
	if predicted_chain >= 3 and !bool(rewards_claimed.get("four", false)):
		return "+8 repair +1 diagnosis"
	return "none"
