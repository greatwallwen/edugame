extends RefCounted


static func evidence_result(groups: Array, evidence_tags: Dictionary) -> Dictionary:
	var completed := 0
	var missing: Array[String] = []
	for raw_group in groups:
		var group := raw_group as Array
		var group_met := false
		var labels: Array[String] = []
		for raw_tag in group:
			var tag := str(raw_tag)
			labels.append(tag)
			if bool(evidence_tags.get(tag, false)):
				group_met = true
		if group_met:
			completed += 1
		else:
			missing.append("/".join(labels))
	return {
		"met": completed == groups.size(),
		"completed": completed,
		"missing": missing
	}


static func boss_requirements_met(gate_id: String, snapshot: Dictionary) -> bool:
	match gate_id:
		"two_sources":
			return int(snapshot.get("sourceCoverageCount", 0)) >= 2
		"three_sources":
			return int(snapshot.get("sourceCoverageCount", 0)) >= 3
		"trusted_and_filter":
			return int(snapshot.get("trustedSourceCount", 0)) >= 2 and int(snapshot.get("filtersPlayed", 0)) > 0
		"trusted_and_calibration":
			return int(snapshot.get("trustedSourceCount", 0)) >= 2 and int(snapshot.get("calibrationsPlayed", 0)) > 0
		"two_output_types":
			return int(snapshot.get("distinctOutputCount", 0)) >= 2
		"acceptance_output":
			return bool(snapshot.get("acceptancePlayed", false)) and int(snapshot.get("otherOutputCount", 0)) >= 1
	return false


static func checkpoint_requirements_met(sensor_checkpoint: bool, snapshot: Dictionary) -> bool:
	if sensor_checkpoint:
		return int(snapshot.get("trustedSourceCount", 0)) >= 2
	return (
		int(snapshot.get("trustedSourceCount", 0)) >= 2
		and int(snapshot.get("filtersPlayed", 0)) > 0
		and !bool(snapshot.get("hasAbnormalReading", false))
	)


static func distinct_output_count(
	output_tags: Array,
	phase_output_types: Dictionary,
	persistent_output_types: Dictionary
) -> int:
	var distinct_outputs := 0
	for raw_tag in output_tags:
		var tag := str(raw_tag)
		if bool(phase_output_types.get(tag, false)) or bool(persistent_output_types.get(tag, false)):
			distinct_outputs += 1
	return distinct_outputs


static func calculate_score(snapshot: Dictionary) -> int:
	var result := 60
	if int(snapshot.get("checkpointsPassed", 0)) >= 2:
		result += 10
	if int(snapshot.get("relicCount", 0)) > 0:
		result += 8
	var boss_review_used := bool(snapshot.get("bossReviewUsed", false))
	if !boss_review_used:
		result += 8
	var max_stability := maxi(int(snapshot.get("maxStability", 0)), 1)
	if int(snapshot.get("stability", 0)) >= int(ceil(max_stability * 0.4)):
		result += 6
	if int(snapshot.get("sourceCoverageCount", 0)) >= 3:
		result += 4
	if (
		int(snapshot.get("trustedSourceCount", 0)) >= 2
		and int(snapshot.get("filtersPlayed", 0)) > 0
	):
		result += 4
	return mini(result, 89 if boss_review_used else 100)
