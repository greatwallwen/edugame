extends SceneTree

const MAX_STEPS := 500

var failures := 0
var game
var steps := 0
var boss_turns := 0
var target_map_id := "mvp_a"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			target_map_id = argument.trim_prefix("--map=")
	var scene := load("res://scenes/main.tscn")
	game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.run_map_id = target_map_id
	game._reset_run()
	while game.state != game.RunState.RESULT and steps < MAX_STEPS:
		steps += 1
		match game.state:
			game.RunState.MAP:
				var choice := _route_choice()
				_assert(bool(game.choose_node(choice)), "autoplayer should choose a valid node at layer %d" % (game.current_layer + 1))
			game.RunState.COMBAT:
				_play_combat_step()
			game.RunState.REWARD:
				_assert(game.choose_reward(_reward_choice_id()), "autoplayer should resolve the card reward")
			game.RunState.EVENT:
				_resolve_question_event()
			game.RunState.SHOP:
				_resolve_shop()
			game.RunState.REST:
				var needs_boss_card: bool = game.current_layer >= 8 and !game._missing_boss_stage_tags().is_empty()
				_assert(game.choose_service("shop" if needs_boss_card else "maintenance"), "autoplayer should resolve the service node")
			game.RunState.COMPONENT:
				var component_id := str((game.component_choices[0] as Dictionary).get("id", ""))
				_assert(bool(game.choose_component(component_id)), "autoplayer should select an offered component")
			_:
				_assert(false, "autoplayer reached unsupported state %s" % game.state)
				break
		await process_frame

	_assert(steps < MAX_STEPS, "full run should finish without hitting the step limit")
	_assert(game.state == game.RunState.RESULT, "full run should reach result")
	_assert(game.completed and game.victory, "deterministic run should pass the boss")
	_assert(game.current_layer == 12 and game.visited_nodes.size() == 12, "full run should visit twelve nodes")
	_assert(game.event_history.size() == 2, "full run should resolve both seeded question nodes")
	_assert(game.checkpoint_results.size() == 2, "full run should record two checkpoints")
	_assert(game.checkpoints_passed == 2, "reasonable starter-deck play should pass both checkpoints")
	_assert(game.boss_phase == 2, "full run should clear all three boss phases")
	_assert(game.stability > 0, "successful run should retain stability")
	_assert(game.score >= 60, "successful full run should score at least sixty")
	print(JSON.stringify({
		"map": target_map_id,
		"steps": steps,
		"bossTurns": boss_turns,
		"bossPhase": game.boss_phase,
		"score": game.score,
		"stability": game.stability,
		"deckSize": game.deck.size(),
		"visitedNodes": game.visited_nodes.size(),
		"checkpointsPassed": game.checkpoints_passed,
		"checkpoints": game.checkpoint_results
	}))
	game.queue_free()
	await process_frame
	_finish()


func _route_choice() -> int:
	var layers: Array = game.run_map.get("layers", [])
	var layer := layers[game.current_layer] as Dictionary
	var choices: Array = layer.get("choices", [])
	for preferred_type in ["ordinary", "event", "shop", "elite"]:
		for index in range(choices.size()):
			if str((choices[index] as Dictionary).get("type", "")) == preferred_type:
				return index
	return 0


func _play_combat_step() -> void:
	if !game.pending_card_selection.is_empty():
		_assert(game.choose_pending_card(0), "autoplayer should resolve combat-owned card selections")
		return
	var is_boss := str(game.current_encounter.get("tier", "")) == "boss"
	if is_boss:
		boss_turns += 1
	if game.cards_played_this_turn == 0 and game.reroute_available and _required_gate_unmet() and !_has_playable_gate_card():
		var reroute_index := _reroute_index()
		if reroute_index >= 0 and game.begin_reroute():
			if game.reroute_card(reroute_index):
				return
	var played_any := true
	while played_any and game.state == game.RunState.COMBAT:
		played_any = false
		var index := _best_card_index()
		if index >= 0 and game.play_card(index):
			played_any = true
	if game.state == game.RunState.COMBAT:
		game.end_turn()


func _best_card_index() -> int:
	var best_index := -1
	var best_score := -1
	var raw_total := 0
	for source in game.SOURCE_ORDER:
		raw_total += int(game.raw_data.get(source, 0))
	for index in range(game.hand.size()):
		var card := game.hand[index] as Dictionary
		if bool(card.get("negative", false)):
			continue
		if game.processing_points < game._card_cost_preview(card) or !game._card_requirements_met(card):
			continue
		var tags: Array = card.get("tags", [])
		var stage := str(card.get("stage", ""))
		var score := 10
		var trust_mode: bool = (str(game.current_encounter.get("tier", "")) == "boss" and game.boss_phase == 1) or str(game.current_node.get("type", "")) == "checkpoint_trust"
		var trusted_count: int = game.phase_trusted_sources.size() if str(game.current_encounter.get("tier", "")) == "boss" else game.trusted_sources_seen.size()
		var filter_count: int = game.phase_filters_played if str(game.current_encounter.get("tier", "")) == "boss" else game.filters_played
		var tier := str(game.current_encounter.get("tier", ""))
		if _card_advances_required_gate(card):
			score = 220 if tier == "boss" and game.boss_phase == 2 and tags.has("alarm") else 200
		elif ["ordinary", "elite"].has(tier) and _card_fills_missing_evidence(card):
			score = 170
		elif trust_mode:
			if tags.has("filter") and trusted_count >= 2 and filter_count == 0:
				score = 150
			elif _card_can_convert_available_raw(card):
				score = 130
			elif raw_total == 0 and stage == "collect":
				score = 120
			elif tags.has("filter") and filter_count == 0:
				score = 110
		elif str(game.current_encounter.get("tier", "")) == "boss":
			match game.boss_phase:
				0:
					score = 120 if stage == "collect" else 60
				2:
					var gate_met: bool = game._boss_phase_requirements_met()
					var fills_report: bool = (tags.has("display") or tags.has("uart")) and !gate_met
					var fills_control: bool = (tags.has("alarm") or tags.has("scheduler")) and !gate_met
					if fills_report or fills_control:
						score = 140
					elif gate_met:
						score = 100 + _card_repair_value(card)
		elif raw_total == 0 and stage == "collect":
			score = 100
		elif raw_total > 0 and (stage == "interface" or str(card.get("id", "")) == "unit_convert"):
			score = 90
		elif stage == "output":
			score = 80
		elif tags.has("filter"):
			score = 70
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func _resolve_question_event() -> void:
	if !game.pending_card_selection.is_empty():
		_assert(game.choose_pending_card(0), "autoplayer should resolve the event-owned card or component choice")
		return
	if !game.event_answer_locked:
		var expected = game.current_event.get("correctAnswer")
		var answer = expected.duplicate(true) if expected is Array or expected is Dictionary else expected
		_assert(game.submit_event_answer(answer), "autoplayer should submit the seeded correct answer")
	if bool(game.event_result.get("rewardPending", false)):
		_assert(game.choose_event_reward(0), "autoplayer should choose the first question reward")
	if !game.pending_card_selection.is_empty():
		_assert(game.choose_pending_card(0), "autoplayer should resolve the event-owned card or component choice")
	if bool(game.event_result.get("resolved", false)):
		_assert(game.continue_event(), "autoplayer should continue after the question explanation")


func _resolve_shop() -> void:
	var guaranteed_id: String = game._guaranteed_boss_shop_card_id()
	if !guaranteed_id.is_empty() and _array_has_id(game.shop_cards, guaranteed_id):
		_assert(game.purchase_shop_card(guaranteed_id), "autoplayer should buy the affordable Boss preparation card")
	_assert(game.leave_shop(), "autoplayer should leave the shop")


func _reward_choice_id() -> String:
	var missing: Array[String] = game._missing_boss_stage_tags()
	if !missing.is_empty():
		for raw_card in game.reward_choices:
			var card := raw_card as Dictionary
			var tags: Array = card.get("tags", [])
			if missing[0] == "control" and tags.has("scheduler"):
				return str(card.get("id", ""))
			if missing[0] != "control" and _card_fills_boss_deck_gap(card, missing[0]):
				return str(card.get("id", ""))
		return ""
	for preferred_reason in ["补链", "反制", "协同"]:
		for raw_card in game.reward_choices:
			var card := raw_card as Dictionary
			if str(card.get("rewardReason", "")) == preferred_reason:
				return str(card.get("id", ""))
	return ""


func _card_fills_boss_deck_gap(card: Dictionary, gap: String) -> bool:
	var tags: Array = card.get("tags", [])
	var required_tags := {
		"source": ["smoke", "light", "temp", "humidity"],
		"trusted": ["adc", "i2c", "calculation", "trusted_data"],
		"filter": ["filter"],
		"report": ["display", "uart"],
		"control": ["alarm", "scheduler"]
	}.get(gap, []) as Array
	for raw_tag in required_tags:
		if tags.has(str(raw_tag)):
			return true
	return false


func _required_gate_unmet() -> bool:
	var tier := str(game.current_encounter.get("tier", ""))
	if tier == "boss":
		return !game._boss_phase_requirements_met()
	if tier == "checkpoint":
		return !game._checkpoint_requirements_met()
	if ["ordinary", "elite"].has(tier):
		return !game._encounter_requirements_met()
	return false


func _has_playable_gate_card() -> bool:
	for raw_card in game.hand:
		var card := raw_card as Dictionary
		if _card_is_playable(card) and _card_advances_required_gate(card):
			return true
	return false


func _reroute_index() -> int:
	for index in range(game.hand.size()):
		var card := game.hand[index] as Dictionary
		if !bool(card.get("negative", false)) and !_card_advances_required_gate(card):
			return index
	return -1


func _card_is_playable(card: Dictionary) -> bool:
	return (
		!bool(card.get("negative", false))
		and game.processing_points >= game._card_cost_preview(card)
		and game._card_requirements_met(card)
	)


func _card_advances_required_gate(card: Dictionary) -> bool:
	var tier := str(game.current_encounter.get("tier", ""))
	var node_type := str(game.current_node.get("type", ""))
	var tags: Array = card.get("tags", [])
	if ["ordinary", "elite"].has(tier):
		return _card_fills_missing_evidence(card)
	if tier == "checkpoint":
		if node_type == "checkpoint_trust" and game.filters_played == 0 and tags.has("filter"):
			return true
		if game.trusted_sources_seen.size() < 2:
			return _card_can_convert_new_source(card, game.trusted_sources_seen) or _card_collects_new_source(card, game.trusted_sources_seen)
		return false
	if tier != "boss":
		return false
	match game.boss_phase:
		0:
			return _card_collects_new_source(card, game.phase_source_coverage)
		1:
			if game.phase_filters_played == 0 and tags.has("filter"):
				return true
			if game.phase_trusted_sources.size() < 2:
				return _card_can_convert_new_source(card, game.phase_trusted_sources) or _card_collects_new_source(card, game.phase_trusted_sources)
		2:
			var needs_report := !bool(game.phase_output_types.get("display", false)) and !bool(game.phase_output_types.get("uart", false)) and !bool(game.persistent_output_types.get("display", false)) and !bool(game.persistent_output_types.get("uart", false))
			var needs_control := !bool(game.phase_output_types.get("alarm", false)) and !bool(game.phase_output_types.get("scheduler", false)) and !bool(game.persistent_output_types.get("alarm", false)) and !bool(game.persistent_output_types.get("scheduler", false))
			return (needs_report and (tags.has("display") or tags.has("uart"))) or (needs_control and (tags.has("alarm") or tags.has("scheduler")))
	return false


func _card_collects_new_source(card: Dictionary, coverage: Dictionary) -> bool:
	if str(card.get("stage", "")) != "collect":
		return false
	var tags: Array = card.get("tags", [])
	for source in game.SOURCE_ORDER:
		if tags.has(source) and !coverage.has(source):
			return true
	return false


func _card_can_convert_new_source(card: Dictionary, coverage: Dictionary) -> bool:
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if str(effect.get("op", "")) != "convert":
			continue
		var candidates: Array = game.SOURCE_ORDER.duplicate()
		match str(effect.get("source", "any")):
			"smoke":
				candidates = ["smoke"]
			"i2c_any":
				candidates = ["light", "temp", "humidity"]
		for source in candidates:
			if int(game.raw_data.get(source, 0)) > 0:
				return !coverage.has(source)
	return false


func _card_fills_missing_evidence(card: Dictionary) -> bool:
	var card_tags: Array = card.get("tags", [])
	var groups: Array = game.current_encounter.get("evidenceGroups", [])
	for raw_group in groups:
		var group := raw_group as Array
		var group_met := false
		for raw_tag in group:
			if bool(game.encounter_evidence_tags.get(str(raw_tag), false)):
				group_met = true
				break
		if group_met:
			continue
		for raw_tag in group:
			if card_tags.has(str(raw_tag)):
				return true
	return false


func _card_can_convert_available_raw(card: Dictionary) -> bool:
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if str(effect.get("op", "")) != "convert":
			continue
		match str(effect.get("source", "any")):
			"smoke":
				return int(game.raw_data.get("smoke", 0)) > 0
			"i2c_any":
				return int(game.raw_data.get("light", 0)) + int(game.raw_data.get("temp", 0)) + int(game.raw_data.get("humidity", 0)) > 0
			_:
				return true
	return false


func _card_repair_value(card: Dictionary) -> int:
	var value := 0
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if str(effect.get("op", "")) == "repair":
			value += int(effect.get("amount", 0))
		elif str(effect.get("op", "")) == "batch_repair":
			value += int(effect.get("amount", 0)) * int(effect.get("repairPer", 0))
	return value


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _array_has_id(items: Array, expected_id: String) -> bool:
	for raw_item in items:
		if str((raw_item as Dictionary).get("id", "")) == expected_id:
			return true
	return false


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 full run tests passed")
		quit(0)
