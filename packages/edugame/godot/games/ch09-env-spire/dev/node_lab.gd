extends CanvasLayer

var game: Control
var entries: Array = []
var current_entry := {}
var deck_fixture := "starter"


func configure(game_root: Control) -> void:
	game = game_root
	entries = _build_catalog()


func catalog_entries() -> Array:
	return entries.duplicate(true)


func _build_catalog() -> Array:
	var result: Array = []
	var enemy_ids: Array = game.enemy_defs.keys()
	enemy_ids.sort()
	for raw_id in enemy_ids:
		var enemy_id := str(raw_id)
		var enemy := game.enemy_defs[enemy_id] as Dictionary
		var tier := str(enemy.get("tier", "ordinary"))
		result.append({
			"id": enemy_id,
			"group": _enemy_group(tier),
			"label": str(enemy.get("name", enemy_id)),
			"kind": "enemy",
			"contentId": enemy_id,
			"tier": tier,
			"phase": -1
		})
		if tier == "boss":
			var phases: Array = enemy.get("phases", [])
			for phase_index in range(phases.size()):
				var phase := phases[phase_index] as Dictionary
				result.append({
					"id": "boss_phase_%d" % (phase_index + 1),
					"group": "Boss 阶段",
					"label": "%s · %s" % [enemy.get("name", "综合验收"), phase.get("name", "阶段")],
					"kind": "boss_phase",
					"contentId": enemy_id,
					"tier": "boss",
					"phase": phase_index
				})

	var event_ids: Array = game.event_defs.keys()
	event_ids.sort()
	for raw_id in event_ids:
		var event_id := str(raw_id)
		var event := game.event_defs[event_id] as Dictionary
		result.append({
			"id": event_id,
			"group": "调试事件",
			"label": str(event.get("name", event_id)),
			"kind": "event",
			"contentId": event_id,
			"tier": "",
			"phase": -1
		})

	result.append_array([
		_catalog_entry("sensor_checkpoint", "教学检查点", "传感器接入检查", "checkpoint_sensor"),
		_catalog_entry("trust_checkpoint", "教学检查点", "数据可信检查", "checkpoint_trust"),
		_catalog_entry("component", "功能节点", "工程组件三选一", "component"),
		_catalog_entry("shop", "功能节点", "器材商店", "shop"),
		_catalog_entry("service", "功能节点", "阶段维护", "service"),
		_catalog_entry("ordinary_reward", "奖励节点", "普通故障奖励", "reward", "ordinary"),
		_catalog_entry("elite_reward", "奖励节点", "精英故障奖励", "reward", "elite")
	])
	return result


func _catalog_entry(id: String, group: String, label: String, kind: String, tier: String = "") -> Dictionary:
	return {
		"id": id,
		"group": group,
		"label": label,
		"kind": kind,
		"contentId": id,
		"tier": tier,
		"phase": -1
	}


func _enemy_group(tier: String) -> String:
	return {
		"ordinary": "普通故障",
		"elite": "精英故障",
		"boss": "综合验收"
	}.get(tier, "故障")
