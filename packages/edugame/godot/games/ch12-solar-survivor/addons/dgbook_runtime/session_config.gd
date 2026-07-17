extends RefCounted
class_name DGBSessionConfig


static func build(level: Dictionary, data: Dictionary, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	result["level_id"] = str(level.get("levelId", result.get("level_id", "")))
	result["initial_state"] = _dictionary_value(data.get("initialState", result.get("initial_state", {})))
	_copy_float(data, "durationSec", result, "duration_sec")
	_copy_int(data, "maxFaults", result, "max_faults")
	_copy_int(data, "maxLeaks", result, "max_leaks")
	_copy_float(data, "questionTimeSec", result, "question_time_sec")
	for key in data:
		if !["durationSec", "maxFaults", "maxLeaks", "questionTimeSec", "initialState"].has(key):
			result[str(key)] = data[key]
	return result


static func _copy_float(source: Dictionary, source_key: String, target: Dictionary, target_key: String) -> void:
	if source.has(source_key) and typeof(source[source_key]) in [TYPE_INT, TYPE_FLOAT]:
		target[target_key] = float(source[source_key])


static func _copy_int(source: Dictionary, source_key: String, target: Dictionary, target_key: String) -> void:
	if source.has(source_key) and typeof(source[source_key]) in [TYPE_INT, TYPE_FLOAT]:
		target[target_key] = int(source[source_key])


static func _dictionary_value(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
