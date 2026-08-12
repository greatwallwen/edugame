extends RefCounted


static func begin_encounter(
	component_defs: Dictionary,
	owned_components: Array,
	context: Dictionary
) -> Dictionary:
	var tracking := {}
	var actions: Array = []
	for component_id in owned_components:
		var effect := _effect(component_defs, str(component_id))
		var effect_id := str(effect.get("id", ""))
		if effect_id.is_empty():
			continue
		tracking[effect_id] = false
		if effect_id == "i2c_start_diagnosis" and (context.get("weaknessTags", []) as Array).has("i2c"):
			actions.append({"op": "diagnosis", "amount": int(effect.get("amount", 1))})
	return {"tracking": tracking, "actions": actions}


static func adjusted_cost(
	base_cost: int,
	card: Dictionary,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary
) -> int:
	var tags: Array = card.get("tags", [])
	if tags.has("uart") and _ready("first_uart_free", component_defs, owned_components, tracking):
		return 0
	if tags.has("calibration") and _ready("first_calibration_free", component_defs, owned_components, tracking):
		return 0
	return base_cost


static func after_play(
	card: Dictionary,
	context: Dictionary,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary
) -> Dictionary:
	var next_tracking := tracking.duplicate(true)
	var actions: Array = []
	var tags: Array = card.get("tags", [])
	if tags.has("uart"):
		_consume("first_uart_free", component_defs, owned_components, next_tracking)
	if tags.has("calibration"):
		_consume("first_calibration_free", component_defs, owned_components, next_tracking)
	_append_once_action("first_filter_block", "filter", "block", card, component_defs, owned_components, next_tracking, actions)
	_append_once_action("first_buffer_draw", "buffer", "draw", card, component_defs, owned_components, next_tracking, actions)
	_append_once_action("first_analog_repair", "analog", "repair", card, component_defs, owned_components, next_tracking, actions)
	_append_once_action("first_diagnosis_block", "diagnosis", "block", card, component_defs, owned_components, next_tracking, actions)
	if bool(context.get("chainCompleted", false)) and _owned_effect("chain_draw", component_defs, owned_components):
		var turn := int(context.get("turn", 0))
		if int(next_tracking.get("chain_draw_turn", -1)) != turn:
			next_tracking["chain_draw_turn"] = turn
			actions.append({"op": "draw", "amount": _effect_amount("chain_draw", component_defs, owned_components, 1)})
	if bool(card.get("negative", false)) and str(card.get("group", "")) == "blocking":
		if _consume("block_first_delay", component_defs, owned_components, next_tracking):
			actions.append({"op": "ignore_negative", "amount": 1})
	return {"tracking": next_tracking, "actions": actions}


static func modify_damage(
	amount: int,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary
) -> Dictionary:
	var next_tracking := tracking.duplicate(true)
	var adjusted := amount
	if amount > 0 and _consume("first_damage_reduction", component_defs, owned_components, next_tracking):
		adjusted = maxi(0, amount - _effect_amount("first_damage_reduction", component_defs, owned_components, 4))
	return {"amount": adjusted, "tracking": next_tracking}


static func _append_once_action(
	effect_id: String,
	tag: String,
	op: String,
	card: Dictionary,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary,
	actions: Array
) -> void:
	if !(card.get("tags", []) as Array).has(tag):
		return
	if _consume(effect_id, component_defs, owned_components, tracking):
		actions.append({"op": op, "amount": _effect_amount(effect_id, component_defs, owned_components, 1)})


static func _ready(
	effect_id: String,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary
) -> bool:
	return _owned_effect(effect_id, component_defs, owned_components) and !bool(tracking.get(effect_id, false))


static func _consume(
	effect_id: String,
	component_defs: Dictionary,
	owned_components: Array,
	tracking: Dictionary
) -> bool:
	if !_ready(effect_id, component_defs, owned_components, tracking):
		return false
	tracking[effect_id] = true
	return true


static func _owned_effect(effect_id: String, component_defs: Dictionary, owned_components: Array) -> bool:
	for component_id in owned_components:
		if str(_effect(component_defs, str(component_id)).get("id", "")) == effect_id:
			return true
	return false


static func _effect_amount(
	effect_id: String,
	component_defs: Dictionary,
	owned_components: Array,
	fallback: int
) -> int:
	for component_id in owned_components:
		var effect := _effect(component_defs, str(component_id))
		if str(effect.get("id", "")) == effect_id:
			return int(effect.get("amount", fallback))
	return fallback


static func _effect(component_defs: Dictionary, component_id: String) -> Dictionary:
	return (component_defs.get(component_id, {}) as Dictionary).get("effect", {}) as Dictionary
