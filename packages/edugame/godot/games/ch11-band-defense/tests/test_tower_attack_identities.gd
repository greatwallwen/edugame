extends SceneTree

var failures := 0


func _init() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	_test_level_one_uses_base_counter_damage(game)
	_test_level_two_unlocks_special_attack_modes(game)
	_test_level_three_strengthens_upgraded_modes(game)
	_test_build_tower_can_upgrade_to_level_three(game)
	_test_firing_tower_creates_attack_effect(game)
	game.queue_free()
	if failures > 0:
		quit(1)
	else:
		print("tower attack identity tests passed")
		quit(0)


func _test_level_one_uses_base_counter_damage(game) -> void:
	_assert(game.has_method("_resolve_tower_attack"), "root should expose attack resolver")
	if !game.has_method("_resolve_tower_attack"):
		return
	var enemy := {"type": "config", "threatTag": "config", "hp": 100.0, "pos": Vector2.ZERO}
	var report: Dictionary = game._resolve_tower_attack("i2c", 1, enemy)
	_assert(is_equal_approx(float(report.get("damage", 0.0)), 32.0 * 1.8), "level 1 should keep only base counter damage")
	_assert(!bool(enemy.get("calibrated", false)), "level 1 I2C should not apply calibration mode")
	_assert(str(report.get("concept", "")) == "匹配", "level 1 feedback should stay generic")


func _test_level_two_unlocks_special_attack_modes(game) -> void:
	var config_enemy := {"type": "config", "threatTag": "config", "hp": 100.0, "pos": Vector2.ZERO}
	var i2c_report: Dictionary = game._resolve_tower_attack("i2c", 2, config_enemy)
	_assert(bool(config_enemy.get("calibrated", false)), "level 2 I2C should mark config enemies as calibrated")
	_assert(str(i2c_report.get("concept", "")).contains("校准"), "level 2 I2C feedback should mention calibration")

	var noise_enemy := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO}
	var filter_report: Dictionary = game._resolve_tower_attack("filter", 2, noise_enemy)
	_assert(float(noise_enemy.get("slowTimer", 0.0)) > 0.0, "level 2 Filter should add slow timer")
	_assert(float(noise_enemy.get("slowMultiplier", 1.0)) < 1.0, "level 2 Filter should reduce speed multiplier")
	_assert(str(filter_report.get("concept", "")).contains("滤波"), "level 2 Filter feedback should mention filtering")

	var peak_enemy := {"type": "false_peak", "threatTag": "false_peak", "hp": 100.0, "pos": Vector2.ZERO}
	var peak_report: Dictionary = game._resolve_tower_attack("peak", 2, peak_enemy)
	_assert(str(peak_enemy.get("captureTag", "")) == "threshold", "level 2 Peak should mark threshold capture")
	_assert(str(peak_report.get("concept", "")).contains("峰值"), "level 2 Peak feedback should mention peak capture")

	game.energy = 100
	var power_enemy := {"type": "power_spike", "threatTag": "power", "hp": 100.0, "pos": Vector2.ZERO}
	var power_report: Dictionary = game._resolve_tower_attack("power", 2, power_enemy)
	_assert(float(power_enemy.get("stunTimer", 0.0)) > 0.0, "level 2 Power should stun power spikes")
	_assert(int(game.energy) > 100, "level 2 Power should refund energy on matched power faults")
	_assert(str(power_report.get("concept", "")).contains("低功耗"), "level 2 Power feedback should mention low power")


func _test_level_three_strengthens_upgraded_modes(game) -> void:
	var level_two_enemy := {"type": "false_peak", "threatTag": "false_peak", "hp": 100.0, "pos": Vector2.ZERO}
	var level_three_enemy := {"type": "false_peak", "threatTag": "false_peak", "hp": 100.0, "pos": Vector2.ZERO}
	var level_two_peak: Dictionary = game._resolve_tower_attack("peak", 2, level_two_enemy)
	var level_three_peak: Dictionary = game._resolve_tower_attack("peak", 3, level_three_enemy)
	_assert(float(level_three_peak.get("damage", 0.0)) > float(level_two_peak.get("damage", 0.0)), "level 3 should increase special attack damage")

	var level_two_noise := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO}
	var level_three_noise := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO}
	game._resolve_tower_attack("filter", 2, level_two_noise)
	game._resolve_tower_attack("filter", 3, level_three_noise)
	_assert(float(level_three_noise.get("slowMultiplier", 1.0)) < float(level_two_noise.get("slowMultiplier", 1.0)), "level 3 Filter should slow harder than level 2")

	game.energy = 100
	var level_two_power := {"type": "power_spike", "threatTag": "power", "hp": 100.0, "pos": Vector2.ZERO}
	game._resolve_tower_attack("power", 2, level_two_power)
	var energy_after_level_two := int(game.energy)
	game.energy = 100
	var level_three_power := {"type": "power_spike", "threatTag": "power", "hp": 100.0, "pos": Vector2.ZERO}
	game._resolve_tower_attack("power", 3, level_three_power)
	_assert(float(level_three_power.get("stunTimer", 0.0)) > float(level_two_power.get("stunTimer", 0.0)), "level 3 Power should stun longer than level 2")
	_assert(int(game.energy) > energy_after_level_two, "level 3 Power should refund more energy than level 2")


func _test_build_tower_can_upgrade_to_level_three(game) -> void:
	game.state = "intro"
	game.energy = 500
	game.build_tower(0, "i2c")
	game.build_tower(0, "i2c")
	game.build_tower(0, "i2c")
	var slot := game.tower_slots[0] as Dictionary
	var tower := slot["tower"] as Dictionary
	_assert(int(tower.get("level", 0)) == 3, "build_tower should support level 3 upgrades")


func _test_firing_tower_creates_attack_effect(game) -> void:
	game.attack_effects.clear()
	var slot := {
		"pos": Vector2(120, 180),
		"tower": {"id": "filter", "level": 2, "cooldown": 0.0, "attackAnim": 0.0}
	}
	var tower := slot["tower"] as Dictionary
	var target := {"type": "noise", "threatTag": "noise", "hp": 100.0, "maxHp": 100.0, "pos": Vector2(260, 220)}
	var def := game.tower_defs["filter"] as Dictionary
	game._fire_tower(slot, tower, def, target)
	_assert(game.attack_effects.size() == 1, "firing should create one visible attack effect")
	if game.attack_effects.size() == 0:
		return
	var effect := game.attack_effects[0] as Dictionary
	_assert(str(effect.get("towerId", "")) == "filter", "attack effect should remember tower identity")
	_assert(bool(effect.get("showRange", false)), "matched filter attack should show a range particle hint")
	_assert(float(tower.get("attackAnim", 0.0)) > 0.0, "firing should trigger the tower body attack animation")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
