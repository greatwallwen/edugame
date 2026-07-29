extends SceneTree

const SINGLE_ROUTE_TYPES := [
	"ordinary", "event", "ordinary", "service",
	"checkpoint_sensor", "component", "ordinary", "checkpoint_trust",
	"shop", "elite", "service", "boss"
]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cards := _load_array("res://data/cards.local.json", "cards")
	var enemies := _load_array("res://data/enemies.local.json", "enemies")
	var events := _load_array("res://data/events.local.json", "events")
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
	_assert(_count_where(enemies, "tier", "ordinary") == 5, "MVP should define five ordinary faults")
	_assert(_count_where(enemies, "tier", "elite") == 1, "MVP should define one elite fault")
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
	_assert(events.size() == 4, "MVP should define four events")
	_assert(relics.size() == 5, "MVP should define five engineering components")
	var state_template := {}
	for raw_relic in relics:
		var relic := raw_relic as Dictionary
		if str(relic.get("id", "")) == "state_template":
			state_template = relic
	_assert(str((state_template.get("effect", {}) as Dictionary).get("id", "")) == "chain_draw", "state template should draw for the first complete chain instead of restoring energy")
	_assert(maps.size() == 3, "MVP should define three fixed map seeds")

	var enemy_ids := _ids_by_type(enemies)
	var event_ids := _ids_by_type(events)
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
			if ["ordinary", "elite", "boss"].has(node_type):
				_assert(enemy_ids.has(content_id), "%s should resolve enemy %s" % [run_map.get("id", "map"), content_id])
			elif node_type == "event":
				_assert(event_ids.has(content_id), "%s should resolve event %s" % [run_map.get("id", "map"), content_id])

	if game != null:
		game.queue_free()
		await process_frame
	_finish()


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
