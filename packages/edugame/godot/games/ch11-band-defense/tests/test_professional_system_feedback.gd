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
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	_test_hud_uses_compact_watch_metrics(game)
	_test_upgrade_copy_names_specific_chapter_knowledge(game)
	game.queue_free()
	_finish()


func _test_hud_uses_compact_watch_metrics(game) -> void:
	_assert(game.has_method("_band_link_metrics"), "game should expose wearable link engineering metrics")
	_assert(game.has_method("_band_metrics_text"), "game should expose full engineering metrics text")
	_assert(game.has_method("_band_metrics_compact_text"), "game should expose compact watch-screen metrics text")
	if !game.has_method("_band_link_metrics") or !game.has_method("_band_metrics_compact_text"):
		return
	game.enemies.clear()
	game.enemies.append({"type": "config", "threatTag": "config", "hp": 80.0, "maxHp": 80.0, "pos": Vector2(160, 180), "progress": 0.2})
	game.enemies.append({"type": "noise", "threatTag": "noise", "hp": 60.0, "maxHp": 60.0, "pos": Vector2(260, 220), "progress": 0.4})
	game.enemies.append({"type": "false_peak", "threatTag": "false_peak", "hp": 60.0, "maxHp": 60.0, "pos": Vector2(360, 260), "progress": 0.6})
	game.enemies.append({"type": "power_spike", "threatTag": "power", "hp": 70.0, "maxHp": 70.0, "pos": Vector2(460, 300), "progress": 0.8})
	game.tower_slots[0]["tower"] = {"id": "i2c", "level": 2, "cooldown": 0.0}
	game.tower_slots[1]["tower"] = {"id": "filter", "level": 2, "cooldown": 0.0}
	game.tower_slots[2]["tower"] = {"id": "peak", "level": 2, "cooldown": 0.0}
	game.tower_slots[3]["tower"] = {"id": "power", "level": 2, "cooldown": 0.0}
	var metrics := game._band_link_metrics() as Dictionary
	for key in ["ackRate", "noiseRms", "stepErrorRate", "averageCurrent", "wakeLatency"]:
		_assert(metrics.has(key), "engineering metrics should include %s" % key)
	_assert(float(metrics.get("ackRate", 100.0)) < 100.0, "config faults should reduce I2C ACK rate")
	_assert(float(metrics.get("noiseRms", 0.0)) > 0.0, "noise faults should produce a visible RMS value")
	_assert(float(metrics.get("stepErrorRate", 0.0)) > 0.0, "false peaks should raise the step error rate")
	_assert(float(metrics.get("averageCurrent", 0.0)) > 0.0, "power faults should produce current draw")
	_assert(float(metrics.get("wakeLatency", 0.0)) > 0.0, "power state should produce wake latency")
	var compact_text := str(game._band_metrics_compact_text())
	for label in ["应答", "噪声", "误步", "电流", "唤醒", "数据"]:
		_assert(compact_text.contains(label), "compact watch metric text should expose Chinese metric label: %s" % label)
	for debug_token in ["LINK", "STEP", "ERR", "CUR", "WAKE", "DATA"]:
		_assert(!compact_text.contains(debug_token), "compact watch metric text should avoid English debug token: %s" % debug_token)
	game._update_ui()
	_assert(str(game.hud_label.text).contains("应答"), "side HUD should show the response rate with a Chinese label")
	_assert(str(game.hud_label.text).contains("电流"), "side HUD should show current draw with a Chinese label")
	for debug_token in ["STB", "PWR", "DEBUG", "LINK", "STEP", "WAKE", "DATA"]:
		_assert(!str(game.hud_label.text).contains(debug_token), "side HUD should avoid English debug token: %s" % debug_token)
	var hud_metric_font_size: int = game.hud_label.get_theme_font_size("font_size")
	_assert(hud_metric_font_size >= 13, "watch-screen HUD metrics should be large enough to read beside the waveform")
	_assert(hud_metric_font_size <= 14, "watch-screen HUD metrics should remain compact enough for the readout tray")
	var side_box := game._side_hud_root() as VBoxContainer
	_assert(side_box.get_theme_constant("separation") <= 5, "watch-screen HUD should keep side dashboard spacing compact")
	_assert(game.get("hud_metrics_strip") != null, "watch-screen HUD should include a compact telemetry strip")
	for tower_id in game.tower_buttons.keys():
		var tower_button := game.tower_buttons[tower_id] as Button
		_assert(tower_button.custom_minimum_size.y >= 40.0 and tower_button.custom_minimum_size.y <= 44.0, "PS Light tower controls should keep a compact but usable touch height")
	_assert(str(game._tutorial_text()).length() <= 26, "expanded engineering HUD should keep the first tutorial hint short enough for the dashboard")


func _test_upgrade_copy_names_specific_chapter_knowledge(game) -> void:
	_assert(game.has_method("_tower_upgrade_description"), "game should expose tower upgrade teaching text")
	if !game.has_method("_tower_upgrade_description"):
		return
	var expectations := {
		"i2c": {
			1: ["Lv2", "WHO_AM_I"],
			2: ["Lv3", "ACK"]
		},
		"filter": {
			1: ["Lv2"],
			2: ["Lv3"]
		},
		"peak": {
			1: ["Lv2"],
			2: ["Lv3"]
		},
		"power": {
			1: ["Lv2", "WOM", "STOP"],
			2: ["Lv3"]
		}
	}
	for tower_id in expectations.keys():
		for current_level in expectations[tower_id].keys():
			var copy := str(game._tower_upgrade_description(str(tower_id), int(current_level)))
			for needle in expectations[tower_id][current_level]:
				_assert(copy.contains(str(needle)), "%s level %d upgrade copy should contain %s" % [tower_id, current_level, needle])


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("professional system feedback tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
