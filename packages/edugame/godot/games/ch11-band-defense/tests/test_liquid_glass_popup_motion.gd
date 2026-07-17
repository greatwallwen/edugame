extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _run() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_assert_true(packed_scene != null, "Main scene should load")
	if packed_scene == null:
		quit(1)
		return

	var game = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	_assert_true(game.has_method("_popup_motion_controls"), "Popup motion should expose its registered windows")
	_assert_true(game.has_method("_animate_popup_in"), "Popup motion should provide an entrance animation")
	_assert_true(game.has_method("_animate_popup_out"), "Popup motion should provide an exit animation")
	_assert_true(game.has_method("_popup_open_total_duration"), "Popup motion should expose its entrance duration")
	_assert_true(game.has_method("_popup_close_duration"), "Popup motion should expose its exit duration")
	_assert_true(game.has_method("_popup_motion_profile"), "Popup motion should expose the selected motion profile")
	_assert_true(game.has_method("_slot_menu_motion_profile"), "Radial build menu should expose its outward motion profile")
	_assert_true(game.has_method("_animate_slot_menu_in"), "Radial build menu should provide a center-out entrance")
	_assert_true(game.has_method("_animate_slot_menu_out"), "Radial build menu should provide an inward exit")
	if failures > 0:
		game.queue_free()
		await process_frame
		quit(1)
		return

	var expected_popups: Array[Control] = [
		game.main_menu_panel,
		game.level_select_panel,
		game.diagnosis_tutorial_popup,
		game.slot_menu_panel,
		game.diagnostic_menu_panel,
		game.codex_popup,
		game.quiz_panel,
	]
	var registered_popups: Array = game._popup_motion_controls()
	_assert_true(registered_popups.size() == expected_popups.size(), "Every top-level popup should be registered exactly once")
	for popup in expected_popups:
		_assert_true(registered_popups.has(popup), "%s should use the shared popup motion" % popup.name)

	var open_duration: float = game._popup_open_total_duration()
	var close_duration: float = game._popup_close_duration()
	_assert_near(open_duration, 0.28, 0.015, "Liquid expansion should use the selected 280ms entrance")
	_assert_near(close_duration, 0.17, 0.015, "Liquid contraction should use the selected 170ms exit")
	var profile := game._popup_motion_profile() as Dictionary
	_assert_true(str(profile.get("name", "")) == "liquid_expand", "Selected popup motion should be the liquid expansion profile")
	var start_scale := profile.get("startScale", Vector2.ONE) as Vector2
	var overshoot_scale := profile.get("overshootScale", Vector2.ONE) as Vector2
	var close_scale := profile.get("closeScale", Vector2.ONE) as Vector2
	_assert_true(start_scale.y <= 0.90 and start_scale.y < start_scale.x, "Liquid entrance should begin vertically compressed")
	_assert_true(overshoot_scale.x > 1.0 and overshoot_scale.y > 1.0, "Liquid entrance should briefly expand past its resting size")
	_assert_true(close_scale.y <= 0.92 and close_scale.y < close_scale.x, "Liquid exit should contract vertically before disappearing")

	var probe := game.quiz_panel as Control
	probe.visible = false
	game._animate_popup_in(probe)
	await process_frame
	_assert_true(probe.visible, "Entrance motion should reveal the popup immediately")
	_assert_near(probe.pivot_offset.x, probe.size.x * 0.5, 1.0, "Entrance motion should pivot from the horizontal center")
	_assert_near(probe.pivot_offset.y, probe.size.y * 0.5, 1.0, "Entrance motion should pivot from the vertical center")
	_assert_true(probe.scale != Vector2.ONE or probe.modulate.a < 0.99, "Entrance should materialize instead of appearing fully formed")
	_assert_true(probe.scale.y < probe.scale.x, "Liquid entrance should visibly unfold from a vertically compressed shape")
	_assert_true(probe.modulate.b >= probe.modulate.r, "Liquid entrance should materialize through a subtle cool glass tint")

	await create_timer(open_duration + 0.08).timeout
	_assert_near(probe.scale.x, 1.0, 0.01, "Entrance should settle at the original width")
	_assert_near(probe.scale.y, 1.0, 0.01, "Entrance should settle at the original height")
	_assert_near(probe.modulate.a, 1.0, 0.01, "Entrance should settle at full opacity")

	game._animate_popup_out(probe)
	await process_frame
	_assert_true(probe.visible, "Exit motion should remain visible while it contracts")
	await create_timer(close_duration + 0.08).timeout
	_assert_true(not probe.visible, "Exit motion should hide the popup after completing")
	_assert_near(probe.scale.x, 1.0, 0.01, "Exit should restore scale for the next opening")
	_assert_near(probe.scale.y, 1.0, 0.01, "Exit should restore scale for the next opening")
	_assert_near(probe.modulate.a, 1.0, 0.01, "Exit should restore opacity for the next opening")

	if game.has_method("_slot_menu_motion_profile") and game.has_method("_animate_slot_menu_in") and game.has_method("_animate_slot_menu_out"):
		var radial_profile := game._slot_menu_motion_profile() as Dictionary
		_assert_true(str(radial_profile.get("name", "")) == "radial_emit", "Build menu should use the center-out radial emit profile")
		var radial_origin := radial_profile.get("origin", Vector2.ZERO) as Vector2
		var radial_duration := float(radial_profile.get("openDuration", 0.0))
		_assert_true(radial_duration >= 0.24 and radial_duration <= 0.28, "Radial build menu entrance should stay near 260ms")
		_assert_true(float(radial_profile.get("stagger", 0.0)) > 0.0, "Build choices should emit with a short clockwise stagger")
		game._open_slot_menu(0)
		await process_frame
		for tower_id in game.slot_menu_buttons.keys():
			var entry := game.slot_menu_buttons[tower_id] as Dictionary
			_assert_true(entry.has("item") and entry.has("targetPosition"), "Each build choice should retain its animated container and final position")
			if !entry.has("item") or !entry.has("targetPosition"):
				continue
			var item := entry["item"] as Control
			var target := entry["targetPosition"] as Vector2
			_assert_true(item.position.distance_to(radial_origin) < target.distance_to(radial_origin), "Build choices should begin between the center and their final ring position")
			_assert_true(item.scale.x < 1.0 or item.modulate.a < 0.99, "Build choices should materialize while moving outward")
		await create_timer(radial_duration + 0.06).timeout
		for tower_id in game.slot_menu_buttons.keys():
			var entry := game.slot_menu_buttons[tower_id] as Dictionary
			if !entry.has("item") or !entry.has("targetPosition"):
				continue
			var item := entry["item"] as Control
			var target := entry["targetPosition"] as Vector2
			_assert_near(item.position.x, target.x, 0.75, "Build choice should settle at its original horizontal position")
			_assert_near(item.position.y, target.y, 0.75, "Build choice should settle at its original vertical position")
			_assert_near(item.scale.x, 1.0, 0.01, "Build choice should settle at full scale")
			_assert_near(item.modulate.a, 1.0, 0.01, "Build choice should settle at full opacity")
		game._close_slot_menu()
		await process_frame
		var close_probe := (game.slot_menu_buttons.values()[0] as Dictionary).get("item") as Control
		_assert_true(close_probe.position.distance_to(radial_origin) < ((game.slot_menu_buttons.values()[0] as Dictionary).get("targetPosition") as Vector2).distance_to(radial_origin) or close_probe.modulate.a < 0.99, "Closing build choices should begin retracting toward the center")
		await create_timer(close_duration + 0.08).timeout
		_assert_true(not game.slot_menu_panel.visible, "Radial build menu should hide after the inward contraction")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("LIQUID_GLASS_POPUP_MOTION_TEST_PASSED")
	quit(failures)
