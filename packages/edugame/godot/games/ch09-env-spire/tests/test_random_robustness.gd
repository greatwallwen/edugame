extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	game._reset_run()
	_assert_seeded_event_selection(game)

	for seed in range(32):
		game.rng.seed = seed
		game._open_shop()
		_assert(game.shop_cards.size() == 5, "shop seed %d should offer five cards" % seed)
		_assert(_shop_has_control_closer(game.shop_cards), "shop seed %d should offer an alarm or scheduler gap card" % seed)

	var original_defs: Dictionary = game.card_defs.duplicate(true)
	game.card_defs = original_defs
	game.rng.seed = 4242
	game._open_reward()
	var first_ids := _card_ids(game.reward_choices)
	var reversed_defs := {}
	var reversed_keys: Array = original_defs.keys()
	reversed_keys.sort()
	reversed_keys.reverse()
	for card_id in reversed_keys:
		reversed_defs[card_id] = original_defs[card_id]
	game.card_defs = reversed_defs
	game.rng.seed = 4242
	game._open_reward()
	_assert(first_ids == _card_ids(game.reward_choices), "seeded rewards should not depend on dictionary key order")

	game.card_defs = original_defs
	game.deck.clear()
	for card_id in game.STARTER_CARD_IDS:
		game.deck.append(game._card_copy(card_id))
	game.deck.append(game._card_copy("time_slice"))
	game.current_node = {"type": "boss"}
	game.rng.seed = 11
	game._start_encounter("warehouse_acceptance", "boss")
	var first_boss_hand := _card_ids(game.hand)
	game.current_node = {"type": "boss"}
	game.rng.seed = 99991
	game._start_encounter("warehouse_acceptance", "boss")
	_assert(first_boss_hand == _card_ids(game.hand), "boss opening hand should not depend on prior route RNG state")

	_assert_bounded_refund_loop(game)

	game.queue_free()
	await process_frame
	_finish()


func _shop_has_control_closer(cards: Array) -> bool:
	for raw_card in cards:
		var tags: Array = (raw_card as Dictionary).get("tags", [])
		if tags.has("alarm") or tags.has("scheduler"):
			return true
	return false


func _card_ids(cards: Array) -> Array:
	var ids: Array = []
	for raw_card in cards:
		ids.append(str((raw_card as Dictionary).get("id", "")))
	return ids


func _assert_bounded_refund_loop(game) -> void:
	game._start_encounter("mq2_warmup", "ordinary")
	game.powers = {"chain_draw": 1, "i2c_discount": 1, "process_discount": 1, "interface_discount": 1}
	var loop_card := {
		"id": "bounded_refund_probe",
		"name": "Bounded refund probe",
		"type": "process",
		"cost": 0,
		"stage": "process",
		"effects": [{"op": "draw", "amount": 2, "perTurnLimit": 1, "effectId": "bounded_refund_probe_draw"}]
	}
	game.draw_pile.clear()
	for _index in range(64):
		game.draw_pile.append(loop_card.duplicate(true))
	game.hand = [loop_card.duplicate(true)]
	game.processing_points = 3
	for _play_index in range(20):
		if game.hand.is_empty():
			game.hand.append(loop_card.duplicate(true))
		_assert(game.play_card(0), "bounded refund probe should play")
		_assert(game.processing_points <= 3, "all refund powers should keep processing points bounded across 20 plays")
		_assert(game.hand.size() <= 2, "turn-limited refund draws should keep hand size bounded across 20 plays")


func _assert_seeded_event_selection(game) -> void:
	if !game.has_method("_select_question_event"):
		_assert(false, "question events should expose a seeded selector")
		return
	var has_run_seed := false
	var has_event_history := false
	for property in game.get_property_list():
		var property_name := str((property as Dictionary).get("name", ""))
		has_run_seed = has_run_seed or property_name == "run_seed"
		has_event_history = has_event_history or property_name == "event_history"
	_assert(has_run_seed, "question events should expose the active run seed")
	_assert(has_event_history, "question events should expose event history")
	if !has_run_seed or !has_event_history:
		return
	_assert(int(game.run_seed) == 901, "the active map seed should initialize question selection")
	game.run_seed = 901
	game.event_history.clear()
	var basic: Dictionary = game._select_question_event("basic", "a2")
	game.event_history.append(basic)
	var advanced: Dictionary = game._select_question_event("advanced", "a6")
	_assert(str(basic.get("tier", "")) == "basic", "node two should draw basic")
	_assert(str(advanced.get("tier", "")) == "advanced", "node six should draw advanced")
	_assert(basic.get("questionType") != advanced.get("questionType"), "event types should not repeat")
	_assert((basic.get("knowledgeTags", []) as Array)[0] != (advanced.get("knowledgeTags", []) as Array)[0], "primary knowledge tags should not repeat")

	game.event_history.clear()
	game.run_seed = 901
	_assert(game._select_question_event("basic", "a2").get("id") == basic.get("id"), "same seed and node should reproduce event")

	game.event_history.clear()
	for event_id in game.event_defs:
		var event := game.event_defs[event_id] as Dictionary
		if str(event.get("tier", "")) == "advanced":
			game.event_history.append(event)
	game.message_log.clear()
	var fallback: Dictionary = game._select_question_event("advanced", "fallback")
	_assert(!fallback.is_empty() and str(fallback.get("tier", "")) == "advanced", "dedup exhaustion should fall back to the full sorted tier")
	_assert(_log_contains(game.message_log, "事件去重约束已放宽"), "dedup exhaustion should explain its relaxed fallback")


func _log_contains(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 random robustness tests passed")
		quit(0)
