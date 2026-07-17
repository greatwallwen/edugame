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

	_assert(game.has_method("_band_model_nodes"), "game should expose wearable band model nodes for the map overlay")
	_assert(game.has_method("_band_model_overlay_draws_text"), "game should expose whether the map overlay draws node text")
	_assert(game.has_method("_empty_tower_slot_draws_text"), "game should expose whether empty tower slots draw background text")
	_assert(game.has_method("_band_model_wave_title"), "game should expose chapter model wave titles")
	_assert(game.has_method("_band_model_hud_title"), "game should expose a wearable band HUD title")
	_assert(game.has_method("_attack_feedback_text"), "game should expose attack feedback text")

	if game.has_method("_band_model_nodes"):
		var nodes := game._band_model_nodes() as Array
		_assert(nodes.size() >= 6, "wearable model should include at least six chain nodes")
		var labels := []
		for raw_node in nodes:
			var node := raw_node as Dictionary
			labels.append(str(node.get("label", "")))
		for expected in ["IMU 采集", "PPG 采样", "I2C 总线", "MCU 算法", "OLED 显示", "低功耗管理"]:
			_assert(labels.has(expected), "wearable model should show node: %s" % expected)

	if game.has_method("_band_model_overlay_draws_text"):
		_assert(!bool(game._band_model_overlay_draws_text()), "map background overlay should not draw faint node labels over the art")

	if game.has_method("_empty_tower_slot_draws_text"):
		_assert(!bool(game._empty_tower_slot_draws_text()), "empty tower slots should not draw faint build text over the map")

	if game.has_method("_band_model_wave_title"):
		var l1w1 := str(game._band_model_wave_title(1, 1, "配置错误和噪声进入链路"))
		var l1w2 := str(game._band_model_wave_title(1, 2, "峰值判断受干扰"))
		var l1w3 := str(game._band_model_wave_title(1, 3, "低功耗异常"))
		_assert(l1w1.contains("采集建链阶段") and l1w1.contains("配置错误和噪声进入链路"), "level 1 wave 1 should read as the sensor acquisition stage")
		_assert(l1w2.contains("MCU 算法阶段") and l1w2.contains("峰值判断"), "level 1 wave 2 should read as the algorithm stage")
		_assert(l1w3.contains("显示与功耗阶段") and l1w3.contains("低功耗"), "level 1 wave 3 should read as the display/power stage")

	if game.has_method("_band_model_hud_title"):
		_assert(str(game._band_model_hud_title()) == "手环链路仪表盘", "side HUD should be named as a wearable band link dashboard")

	if game.has_method("_attack_feedback_text"):
		var matched_text := str(game._attack_feedback_text("filter", {"matched": true, "concept": "滤波抑噪"}, {"type": "noise"}))
		var mismatched_text := str(game._attack_feedback_text("i2c", {"matched": false, "concept": "错配"}, {"type": "noise"}))
		_assert(matched_text == "应对！", "matched hit floating feedback should stay short")
		_assert(mismatched_text == "错配！", "mismatched hit floating feedback should stay short")

	game.queue_free()
	_finish()


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("band model semantics tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
