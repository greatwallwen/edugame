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
				var reward_id := ""
				if !game._deck_has_any_tag(["scheduler"]):
					for raw_card in game.reward_choices:
						var card := raw_card as Dictionary
						if str(card.get("id", "")) == "time_slice":
							reward_id = str(card.get("id", ""))
							break
				game.choose_reward(reward_id)
			game.RunState.EVENT:
				var options: Array = game.current_event.get("options", [])
				game.choose_event_option(1 if options.size() > 1 else 0)
			game.RunState.SHOP:
				if !game._deck_has_any_tag(["scheduler"]):
					for raw_card in game.shop_cards:
						var card := raw_card as Dictionary
						var tags: Array = card.get("tags", [])
						if tags.has("scheduler"):
							game.purchase_shop_card(str(card.get("id", "")))
							break
				game.leave_shop()
			game.RunState.REST:
				game.choose_service("maintenance" if game._deck_has_any_tag(["scheduler"]) else "shop")
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
	_assert(game.checkpoint_results.size() == 2, "full run should record two checkpoints")
	_assert(game.checkpoints_passed == 2, "reasonable starter-deck play should pass both checkpoints")
	_assert(game.boss_phase == 2, "full run should clear all three boss phases")
	_assert(game.stability > 0, "successful run should retain stability")
	_assert(game.source_coverage.size() >= 3, "full run should accumulate three source coverage")
	_assert(game.score >= 86, "three source coverage should contribute to the host score")
	_assert(boss_turns >= 6 and boss_turns <= 8, "boss should take six to eight turns, got %d" % boss_turns)
	print(JSON.stringify({
		"map": target_map_id,
		"steps": steps,
		"bossTurns": boss_turns,
		"score": game.score,
		"stability": game.stability,
		"deckSize": game.deck.size(),
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
	var is_boss := str(game.current_encounter.get("tier", "")) == "boss"
	if is_boss:
		boss_turns += 1
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
		if ["ordinary", "elite"].has(tier) and _card_fills_missing_evidence(card):
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


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("Ch09 full run tests passed")
		quit(0)
