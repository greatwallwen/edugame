extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	var game: Node = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	_test_upgrade_costs_support_mid_run_choices(game)
	_test_kill_rewards_are_secondary_to_quiz_economy(game)
	_test_tutorial_waves_stay_readable()
	_test_late_wave_pressure_stays_readable()
	_finish()


func _test_upgrade_costs_support_mid_run_choices(game) -> void:
	for tower_id in game.tower_defs.keys():
		var def := game.tower_defs[tower_id] as Dictionary
		var base_cost := int(def["cost"])
		var level_two_cost := int(game._tower_upgrade_cost(def, 1))
		var level_three_cost := int(game._tower_upgrade_cost(def, 2))
		_assert(level_two_cost <= base_cost + 20, "%s Lv2 upgrade should stay affordable after one quiz or a short wave" % tower_id)
		_assert(level_three_cost <= base_cost + 40, "%s Lv3 upgrade should be reachable without hoarding the whole level economy" % tower_id)
		_assert(level_three_cost > level_two_cost, "%s Lv3 upgrade should still cost more than Lv2" % tower_id)


func _test_kill_rewards_are_secondary_to_quiz_economy(game) -> void:
	for enemy_type in game.enemy_defs.keys():
		var def := game.enemy_defs[enemy_type] as Dictionary
		var reward := int(def["reward"])
		if str(enemy_type) == "hybrid_fault":
			_assert(reward >= 20 and reward <= 24, "hybrid fault reward should feel special without flooding energy")
		else:
			_assert(reward >= 10 and reward <= 16, "%s reward should be a small data bonus, not the main economy" % enemy_type)


func _test_tutorial_waves_stay_readable() -> void:
	var waves := _read_json_array("res://data/waves.sample.json")
	var expected_caps := {1: 4, 2: 4, 3: 5}
	for wave_number in expected_caps.keys():
		var total := _enemy_count_for_wave(waves, 1, int(wave_number))
		var wave := _wave_data_for(waves, 1, int(wave_number))
		_assert(total <= int(expected_caps[wave_number]), "tutorial wave %d should teach concepts before adding pressure" % int(wave_number))
		_assert(float(wave.get("hpMultiplier", 1.0)) <= 0.85, "tutorial wave %d should soften enemy HP while concepts are introduced" % int(wave_number))
		_assert(float(wave.get("speedMultiplier", 1.0)) <= 0.85, "tutorial wave %d should slow enemies enough for first-time tower reading" % int(wave_number))


func _test_late_wave_pressure_stays_readable() -> void:
	var director = load("res://scripts/wave_level_director.gd")
	_assert(director != null, "wave director should load")
	if director == null:
		return
	var level_two := _read_json_array("res://data/waves.level2.json")
	var level_three := _read_json_array("res://data/waves.level3.json")
	for wave_number in range(1, 4):
		var interval := float(director.wave_spawn_interval(level_two, 2, wave_number))
		_assert(interval >= 0.56, "level 2 wave %d should leave enough visual reading time" % wave_number)
		_assert(interval <= 0.60, "level 2 wave %d should still feel tighter than the tutorial" % wave_number)
	_assert(float(director.wave_spawn_interval(level_three, 3, 3)) >= 0.52, "final wave should be hard through mixed threats, not unreadable spawn speed")
	var final_wave: Dictionary = director.wave_data_for(level_three, 3, 3)
	for raw_entry in final_wave.get("enemies", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry := raw_entry as Dictionary
		if str(entry.get("type", "")) == "hybrid_fault":
			_assert(float(entry.get("hpMultiplier", 1.0)) <= 1.75, "final hybrid faults should be durable but not become boss walls")
			_assert(float(entry.get("rewardMultiplier", 1.0)) <= 2.0, "final hybrid rewards should not flood the economy after tuning")


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


func _enemy_count_for_wave(waves: Array, level_number: int, wave_number: int) -> int:
	var wave := _wave_data_for(waves, level_number, wave_number)
	var total := 0
	for raw_entry in wave.get("enemies", []):
		if typeof(raw_entry) == TYPE_DICTIONARY:
			total += int((raw_entry as Dictionary).get("count", 0))
	return total


func _wave_data_for(waves: Array, level_number: int, wave_number: int) -> Dictionary:
	for raw_wave in waves:
		if typeof(raw_wave) != TYPE_DICTIONARY:
			continue
		var wave := raw_wave as Dictionary
		if int(wave.get("level", 1)) != level_number or int(wave.get("wave", 0)) != wave_number:
			continue
		return wave
	return {}


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("balance tuning tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
