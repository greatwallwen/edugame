extends RefCounted


static func build(debug_reports: Array, knowledge_stats: Dictionary) -> Dictionary:
	var tag_stats := (knowledge_stats.get("tags", {}) as Dictionary).duplicate(true)
	if tag_stats.is_empty():
		for raw_report in debug_reports:
			var report := raw_report as Dictionary
			for raw_tag in report.get("knowledgeTags", []) as Array:
				var tag := str(raw_tag)
				var entry := (tag_stats.get(tag, {}) as Dictionary).duplicate(true)
				var key := "positive" if bool(report.get("passed", false)) else "errors"
				entry[key] = int(entry.get(key, 0)) + 1
				tag_stats[tag] = entry
	var mastered: Array[String] = []
	var review: Array[String] = []
	var building: Array[String] = []
	var entries: Array[Dictionary] = []
	var tags: Array = tag_stats.keys()
	tags.sort()
	for raw_tag in tags:
		var tag := str(raw_tag)
		var stat := tag_stats[tag] as Dictionary
		var positive := int(stat.get("positive", 0))
		var errors := int(stat.get("errors", 0))
		var status := ""
		if errors > 0:
			status = "继续加强"
			review.append(tag)
		elif positive >= 2:
			status = "已掌握"
			mastered.append(tag)
		elif positive == 1:
			status = "正在建立"
			building.append(tag)
		if !status.is_empty():
			entries.append({"tag": tag, "positive": positive, "errors": errors, "status": status})
	var question_total := int(knowledge_stats.get("questionTotal", 0))
	var question_accuracy := float(knowledge_stats.get("questionCorrect", 0)) / float(question_total) if question_total > 0 else 0.0
	var total_repair := int(knowledge_stats.get("totalRepair", 0))
	var engineering_rate := float(knowledge_stats.get("weaknessRepair", 0)) / float(total_repair) if total_repair > 0 else 0.0
	var recommended: Array[String] = []
	for raw_id in knowledge_stats.get("reviewFaultIds", []) as Array:
		var fault_id := str(raw_id)
		if !fault_id.is_empty() and !recommended.has(fault_id):
			recommended.append(fault_id)
	return {
		"entries": entries,
		"mastered": mastered,
		"review": review,
		"building": building,
		"questionAccuracy": question_accuracy,
		"engineeringResolutionRate": engineering_rate,
		"conclusion": "工程证据解决" if engineering_rate >= 0.5 else "基础修复为主",
		"recommendedFaultIds": recommended,
		"hostStats": {
			"masteredKnowledgeTags": mastered,
			"reviewKnowledgeTags": review,
			"questionAccuracy": question_accuracy,
			"engineeringResolutionRate": engineering_rate
		}
	}
