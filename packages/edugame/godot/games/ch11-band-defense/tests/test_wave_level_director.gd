extends SceneTree

var failures := 0


func _init() -> void:
	_test_old_wave_entries_expand_to_string_queue()
	_test_level_two_hybrid_entries_keep_switch_data()
	_test_wave_brief_and_focus_are_level_aware()
	_test_wave_pacing_metadata_has_safe_defaults()
	_test_wave_level_modifiers_are_attached_to_spawn_entries()
	_test_switch_type_uses_path_progress_ratio()
	_test_level_two_introduces_drift_noise()
	_test_level_three_waves_cover_all_fault_families()
	_test_level_two_and_three_define_distinct_pacing()
	if failures > 0:
		quit(1)
	else:
		print("wave level director tests passed")
		quit(0)


func _director():
	var script = load("res://scripts/wave_level_director.gd")
	_assert(script != null, "wave_level_director.gd should load")
	return script


func _test_old_wave_entries_expand_to_string_queue() -> void:
	var director = _director()
	if director == null:
		return
	var waves := [
		{"wave": 1, "enemies": [{"type": "noise", "count": 2}, {"type": "config", "count": 1}]}
	]
	var queue: Array = director.build_spawn_queue(waves, 1, 1)
	_assert(queue == ["noise", "noise", "config"], "old wave entries should expand to string spawn queue")


func _test_level_two_hybrid_entries_keep_switch_data() -> void:
	var director = _director()
	if director == null:
		return
	var waves := [
		{
			"level": 2,
			"wave": 3,
			"enemies": [
				{
					"type": "hybrid_fault",
					"count": 1,
					"switches": [
						{"progress": 0.0, "type": "power_spike"},
						{"progress": 0.45, "type": "false_peak"}
					]
				}
			]
		}
	]
	var queue: Array = director.build_spawn_queue(waves, 2, 3)
	_assert(queue.size() == 1, "hybrid wave should spawn one entry")
	_assert(typeof(queue[0]) == TYPE_DICTIONARY, "hybrid spawn entry should preserve dictionary data")
	if queue.size() > 0 and typeof(queue[0]) == TYPE_DICTIONARY:
		var entry := queue[0] as Dictionary
		_assert(str(entry.get("type", "")) == "hybrid_fault", "hybrid entry should keep its declared type")
		_assert((entry.get("switches", []) as Array).size() == 2, "hybrid entry should keep switch table")


func _test_wave_brief_and_focus_are_level_aware() -> void:
	var director = _director()
	if director == null:
		return
	var waves := [
		{"level": 1, "wave": 1, "brief": "链路入门", "focusType": "config", "enemies": []},
		{"level": 2, "wave": 1, "brief": "夜跑跳变", "focusType": "noise", "enemies": []}
	]
	_assert(director.wave_brief(waves, 2, 1) == "夜跑跳变", "brief lookup should prefer matching level")
	_assert(director.wave_focus_type(waves, 2, 1) == "noise", "focus lookup should prefer matching level")


func _test_wave_pacing_metadata_has_safe_defaults() -> void:
	var director = _director()
	if director == null:
		return
	if !_director_has_method(director, "wave_spawn_interval") or !_director_has_method(director, "wave_pressure_label"):
		_assert(false, "director should expose wave pacing metadata helpers")
		return
	var waves := [
		{"level": 1, "wave": 1, "enemies": []}
	]
	_assert(is_equal_approx(director.wave_spawn_interval(waves, 1, 1), 0.68), "legacy waves should keep default spawn interval")
	_assert(director.wave_pressure_label(waves, 1, 1) == "", "legacy waves should have empty pressure label")


func _test_wave_level_modifiers_are_attached_to_spawn_entries() -> void:
	var director = _director()
	if director == null:
		return
	if !_director_has_method(director, "wave_spawn_interval") or !_director_has_method(director, "wave_pressure_label"):
		_assert(false, "director should expose wave pacing metadata helpers")
		return
	var waves := [
		{
			"level": 2,
			"wave": 1,
			"spawnInterval": 0.52,
			"speedMultiplier": 1.18,
			"hpMultiplier": 1.10,
			"pressureLabel": "夜跑噪声",
			"enemies": [{"type": "noise", "count": 2}]
		}
	]
	var queue: Array = director.build_spawn_queue(waves, 2, 1)
	_assert(is_equal_approx(director.wave_spawn_interval(waves, 2, 1), 0.52), "wave should expose custom spawn interval")
	_assert(director.wave_pressure_label(waves, 2, 1) == "夜跑噪声", "wave should expose pressure label")
	_assert(queue.size() == 2, "wave should expand all modified enemies")
	for entry in queue:
		_assert(typeof(entry) == TYPE_DICTIONARY, "modified spawn entries should preserve pacing data")
		if typeof(entry) == TYPE_DICTIONARY:
			var data := entry as Dictionary
			_assert(str(data.get("type", "")) == "noise", "modified entry should keep type")
			_assert(is_equal_approx(float(data.get("speedMultiplier", 0.0)), 1.18), "modified entry should include speed multiplier")
			_assert(is_equal_approx(float(data.get("hpMultiplier", 0.0)), 1.10), "modified entry should include hp multiplier")


func _test_switch_type_uses_path_progress_ratio() -> void:
	var director = _director()
	if director == null:
		return
	var enemy := {
		"type": "power_spike",
		"progress": 48.0,
		"switches": [
			{"progress": 0.0, "type": "power_spike"},
			{"progress": 0.45, "type": "false_peak"}
		]
	}
	_assert(director.type_for_progress(enemy, 100.0) == "false_peak", "enemy should switch type after threshold ratio")


func _test_level_two_introduces_drift_noise() -> void:
	var director = _director()
	if director == null:
		return
	var waves := _read_json_array("res://data/waves.level2.json")
	var seen := {}
	var has_drift_to_peak_switch := false
	for wave_number in range(1, 4):
		var queue: Array = director.build_spawn_queue(waves, 2, wave_number)
		for entry in queue:
			if typeof(entry) == TYPE_DICTIONARY:
				var data := entry as Dictionary
				seen[str(data.get("type", ""))] = true
				var switches := data.get("switches", []) as Array
				var switch_types := []
				for raw_switch in switches:
					if typeof(raw_switch) == TYPE_DICTIONARY:
						switch_types.append(str((raw_switch as Dictionary).get("type", "")))
				has_drift_to_peak_switch = has_drift_to_peak_switch or (switch_types.has("drift_noise") and switch_types.has("false_peak"))
			else:
				seen[str(entry)] = true
	_assert(bool(seen.get("drift_noise", false)), "level 2 should introduce drift noise")
	_assert(has_drift_to_peak_switch, "level 2 should include a drift noise entry that can become a false peak")


func _test_level_three_waves_cover_all_fault_families() -> void:
	var director = _director()
	if director == null:
		return
	var waves := _read_json_array("res://data/waves.level3.json")
	_assert(director.wave_count_for_level(waves, 3) == 3, "level 3 should provide three comprehensive waves")
	var seen := {}
	var has_switching_enemy := false
	for wave_number in range(1, 4):
		var queue: Array = director.build_spawn_queue(waves, 3, wave_number)
		_assert(!queue.is_empty(), "level 3 wave %d should spawn enemies" % wave_number)
		for entry in queue:
			if typeof(entry) == TYPE_DICTIONARY:
				var data := entry as Dictionary
				has_switching_enemy = has_switching_enemy or (data.get("switches", []) as Array).size() >= 2
				for raw_switch in data.get("switches", []):
					if typeof(raw_switch) == TYPE_DICTIONARY:
						seen[str((raw_switch as Dictionary).get("type", ""))] = true
				seen[str(data.get("type", ""))] = true
			else:
				seen[str(entry)] = true
	for enemy_type in ["config", "noise", "false_peak", "power_spike"]:
		_assert(bool(seen.get(enemy_type, false)), "level 3 should cover %s faults" % enemy_type)
	_assert(bool(seen.get("hybrid_fault", false)), "level 3 should include a visible hybrid fault envelope")
	_assert(has_switching_enemy, "level 3 should include at least one multi-stage switching enemy")


func _test_level_two_and_three_define_distinct_pacing() -> void:
	var director = _director()
	if director == null:
		return
	if !_director_has_method(director, "wave_spawn_interval") or !_director_has_method(director, "wave_pressure_label"):
		_assert(false, "director should expose wave pacing metadata helpers")
		return
	var level_two := _read_json_array("res://data/waves.level2.json")
	var level_three := _read_json_array("res://data/waves.level3.json")
	_assert(director.wave_pressure_label(level_two, 2, 1).contains("夜跑"), "level 2 should advertise night-run pressure")
	_assert(director.wave_spawn_interval(level_two, 2, 1) < 0.68, "level 2 should spawn faster than the tutorial")
	_assert(director.wave_pressure_label(level_three, 3, 3).contains("综合"), "level 3 final wave should advertise comprehensive pressure")
	_assert(director.wave_spawn_interval(level_three, 3, 3) <= director.wave_spawn_interval(level_two, 2, 1), "level 3 final wave should be at least as fast as level 2 opening")
	var final_queue: Array = director.build_spawn_queue(level_three, 3, 3)
	var has_final_speed_modifier := false
	for entry in final_queue:
		if typeof(entry) == TYPE_DICTIONARY and float((entry as Dictionary).get("speedMultiplier", 1.0)) > 1.0:
			has_final_speed_modifier = true
	_assert(has_final_speed_modifier, "level 3 final wave should apply a speed modifier to reinforce pacing")


func _read_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_assert(file != null, "%s should exist" % path)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	_assert(typeof(parsed) == TYPE_ARRAY, "%s should parse to an array" % path)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed as Array


func _director_has_method(director, method_name: String) -> bool:
	for method in director.get_script_method_list():
		if str((method as Dictionary).get("name", "")) == method_name:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
