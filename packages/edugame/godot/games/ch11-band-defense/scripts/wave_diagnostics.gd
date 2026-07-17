extends RefCounted


static func build_wave_summary(stats: Dictionary, enemy_defs: Dictionary) -> String:
	var wave := int(stats.get("wave", 0))
	var matched_hits := _sum_counts(stats.get("matched_hits", {}))
	var mismatched_hits := _sum_counts(stats.get("mismatched_hits", {}))
	var kills := _sum_counts(stats.get("kills", {}))
	var leaks := _sum_counts(stats.get("leaks", {}))
	if matched_hits + mismatched_hits + kills + leaks <= 0:
		return "第 %d 波诊断\n还没有形成有效诊断：先建塔并观察敌人症状。" % wave

	var focus_type := str(stats.get("focusType", ""))
	var strong_type := _top_type(stats.get("kills", {}), stats.get("matched_hits", {}))
	var weak_type := _top_type(stats.get("leaks", {}), stats.get("mismatched_hits", {}))
	var lines := [
		"第 %d 波诊断" % wave,
		"本波重点：%s" % _type_label(focus_type, enemy_defs) if focus_type != "" else "本波重点：综合判断",
		"拦截稳定：%s（匹配命中 %d 次，净化 %d 个）" % [
			_type_label(strong_type, enemy_defs),
			int(_count_for(stats.get("matched_hits", {}), strong_type)),
			int(_count_for(stats.get("kills", {}), strong_type))
		],
		"优先复习：%s（错配命中 %d 次，漏防 %d 个）" % [
			_type_label(weak_type, enemy_defs),
			int(_count_for(stats.get("mismatched_hits", {}), weak_type)),
			int(_count_for(stats.get("leaks", {}), weak_type))
		]
	]
	if mismatched_hits > matched_hits:
		lines.append("提示：错配次数偏高，先回忆“塔类型对应哪类异常”。")
		lines.append("下一步：优先补强 %s 对应的塔位。" % _type_label(weak_type, enemy_defs))
	elif leaks > 0:
		lines.append("提示：漏防集中时，优先补对应塔或升级同类塔。")
		lines.append("下一步：把资源留给 %s 的克制塔。" % _type_label(weak_type, enemy_defs))
	else:
		lines.append("提示：本波识别较稳，可以把资源留给下一类异常。")
		lines.append("下一步：观察下一波症状，再决定是否升级。")
	return "\n".join(lines)


static func build_level_summary(stats: Dictionary, enemy_defs: Dictionary) -> String:
	var level := int(stats.get("level", 1))
	var matched_hits := _sum_counts(stats.get("matched_hits", {}))
	var mismatched_hits := _sum_counts(stats.get("mismatched_hits", {}))
	var total_hits := matched_hits + mismatched_hits
	var match_rate := 0
	if total_hits > 0:
		match_rate = roundi(float(matched_hits) / float(total_hits) * 100.0)
	var weak_type := _top_type(stats.get("leaks", {}), stats.get("mismatched_hits", {}))
	var lines := [
		"第 %d 关诊断" % level,
		"匹配率：%d%%" % match_rate,
		"主要薄弱点：%s" % _type_label(weak_type, enemy_defs)
	]
	if match_rate < 65:
		lines.append("建议：先读波前症状，再决定建塔类型。")
	elif weak_type != "":
		lines.append("建议复习：%s 对应的第 11 章知识点。" % _type_label(weak_type, enemy_defs))
	else:
		lines.append("建议：本关判断较稳，可以进入综合验收。")
	return "\n".join(lines)


static func _sum_counts(counts) -> int:
	if typeof(counts) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for key in (counts as Dictionary).keys():
		total += int((counts as Dictionary)[key])
	return total


static func _top_type(primary, secondary) -> String:
	var best_type := ""
	var best_value := -1
	for counts in [primary, secondary]:
		if typeof(counts) != TYPE_DICTIONARY:
			continue
		for key in (counts as Dictionary).keys():
			var value := int((counts as Dictionary)[key])
			if value > best_value:
				best_value = value
				best_type = str(key)
	return best_type


static func _count_for(counts, key: String) -> int:
	if typeof(counts) != TYPE_DICTIONARY or key == "":
		return 0
	return int((counts as Dictionary).get(key, 0))


static func _type_label(enemy_type: String, enemy_defs: Dictionary) -> String:
	if enemy_type == "":
		return "暂无明显短板"
	if enemy_defs.has(enemy_type):
		return str((enemy_defs[enemy_type] as Dictionary).get("label", enemy_type))
	return enemy_type
