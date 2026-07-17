extends RefCounted


static func build_spawn_queue(waves: Array, level_number: int, wave_number: int) -> Array:
	var queue := []
	var wave_data := wave_data_for(waves, level_number, wave_number)
	if wave_data.is_empty():
		return queue
	var wave_modifiers := _wave_spawn_modifiers(wave_data)
	for raw_entry in wave_data.get("enemies", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry := raw_entry as Dictionary
		var count := int(entry.get("count", 0))
		for i in range(count):
			if entry.has("switches") or !wave_modifiers.is_empty() or _entry_has_spawn_modifiers(entry):
				var spawn_entry := entry.duplicate(true)
				for key in wave_modifiers.keys():
					spawn_entry[key] = float(spawn_entry.get(key, 1.0)) * float(wave_modifiers[key])
				queue.append(spawn_entry)
			else:
				queue.append(str(entry.get("type", "noise")))
	return queue


static func wave_brief(waves: Array, level_number: int, wave_number: int) -> String:
	var wave_data := wave_data_for(waves, level_number, wave_number)
	return str(wave_data.get("brief", ""))


static func wave_focus_type(waves: Array, level_number: int, wave_number: int) -> String:
	var wave_data := wave_data_for(waves, level_number, wave_number)
	return str(wave_data.get("focusType", ""))


static func wave_spawn_interval(waves: Array, level_number: int, wave_number: int) -> float:
	var wave_data := wave_data_for(waves, level_number, wave_number)
	return float(wave_data.get("spawnInterval", 0.68))


static func wave_pressure_label(waves: Array, level_number: int, wave_number: int) -> String:
	var wave_data := wave_data_for(waves, level_number, wave_number)
	return str(wave_data.get("pressureLabel", ""))


static func wave_count_for_level(waves: Array, level_number: int) -> int:
	var count := 0
	for raw_wave in waves:
		if typeof(raw_wave) != TYPE_DICTIONARY:
			continue
		var wave_data := raw_wave as Dictionary
		if _wave_level(wave_data) == level_number:
			count = maxi(count, int(wave_data.get("wave", 0)))
	return count


static func wave_data_for(waves: Array, level_number: int, wave_number: int) -> Dictionary:
	for raw_wave in waves:
		if typeof(raw_wave) != TYPE_DICTIONARY:
			continue
		var wave_data := raw_wave as Dictionary
		if _wave_level(wave_data) == level_number and int(wave_data.get("wave", 0)) == wave_number:
			return wave_data
	return {}


static func type_for_progress(enemy: Dictionary, path_length: float) -> String:
	var switches = enemy.get("switches", [])
	if typeof(switches) != TYPE_ARRAY or (switches as Array).is_empty():
		return str(enemy.get("type", "noise"))
	var ratio := 0.0
	if path_length > 0.0:
		ratio = clampf(float(enemy.get("progress", 0.0)) / path_length, 0.0, 1.0)
	var selected_type := str(enemy.get("type", "noise"))
	for raw_switch in switches as Array:
		if typeof(raw_switch) != TYPE_DICTIONARY:
			continue
		var switch_data := raw_switch as Dictionary
		if ratio >= float(switch_data.get("progress", 0.0)):
			selected_type = str(switch_data.get("type", selected_type))
	return selected_type


static func _wave_level(wave_data: Dictionary) -> int:
	return int(wave_data.get("level", 1))


static func _wave_spawn_modifiers(wave_data: Dictionary) -> Dictionary:
	var modifiers := {}
	for key in ["hpMultiplier", "rewardMultiplier", "speedMultiplier"]:
		if wave_data.has(key):
			modifiers[key] = float(wave_data[key])
	return modifiers


static func _entry_has_spawn_modifiers(entry: Dictionary) -> bool:
	for key in ["hpMultiplier", "rewardMultiplier", "speedMultiplier"]:
		if entry.has(key):
			return true
	return false
