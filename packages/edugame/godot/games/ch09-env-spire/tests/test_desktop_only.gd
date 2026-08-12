extends SceneTree

const DESKTOP_SIZE := Vector2i(1280, 720)

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(DESKTOP_SIZE)
	get_root().size = DESKTOP_SIZE
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return

	var natural_game = scene.instantiate()
	get_root().add_child(natural_game)
	await process_frame
	_assert(
		natural_game._gameplay_action_allowed(),
		"natural headless root should use desktop fallback, got %s" % natural_game.size
	)
	natural_game.queue_free()
	await process_frame

	var game = scene.instantiate()
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(DESKTOP_SIZE)
	await process_frame
	await process_frame

	_assert(
		game.has_method("is_desktop_viewport_supported"),
		"game should expose its desktop viewport contract"
	)
	_assert(
		game.has_method("_update_desktop_only_overlay"),
		"game should update a desktop-only blocker when its viewport changes"
	)
	if !game.has_method("is_desktop_viewport_supported") or !game.has_method("_update_desktop_only_overlay"):
		game.queue_free()
		await process_frame
		_finish()
		return

	_assert(game.is_desktop_viewport_supported(Vector2(1280, 720)), "1280x720 should be supported")
	_assert(game.is_desktop_viewport_supported(Vector2(1024, 576)), "1024x576 should be supported")
	_assert(!game.is_desktop_viewport_supported(Vector2(932, 430)), "mobile landscape should be blocked")
	_assert(!game.is_desktop_viewport_supported(Vector2(430, 932)), "mobile portrait should be blocked")

	var overlay := game.get_node_or_null("DesktopOnlyOverlay") as CanvasLayer
	_assert(overlay != null, "desktop-only overlay should exist")
	if overlay != null:
		var heading := overlay.find_child("DesktopOnlyHeading", true, false) as Label
		var detail := overlay.find_child("DesktopOnlyDetail", true, false) as Label
		_assert(heading != null and heading.text == "请使用桌面端体验", "desktop blocker should expose readable Chinese heading text")
		_assert(detail != null and detail.text == "环境监测工程需要 1024 × 576 或更大的桌面视口。", "desktop blocker should expose readable Chinese detail text")
		if heading != null and detail != null:
			_assert(heading.has_theme_font_override("font"), "desktop blocker heading should bind the project Chinese display font explicitly")
			_assert(detail.has_theme_font_override("font"), "desktop blocker detail should bind the project Chinese body font explicitly")
		_assert(!overlay.visible, "desktop viewport should keep the blocker hidden")
		game.size = Vector2(430, 932)
		game._update_desktop_only_overlay()
		_assert(overlay.visible, "mobile viewport should show the blocker")
		_assert(!game._gameplay_action_allowed(), "mobile viewport should reject gameplay actions")
		game.size = Vector2(DESKTOP_SIZE)
		game._update_desktop_only_overlay()
		_assert(!overlay.visible, "restoring desktop size should hide the blocker")
		_assert(game._gameplay_action_allowed(), "restoring desktop size should restore gameplay actions")
		game.size = Vector2.ZERO
		game._update_desktop_only_overlay()
		_assert(!overlay.visible, "an uninitialized root size should use the configured desktop viewport")
		_assert(game._gameplay_action_allowed(), "headless startup should not reject desktop gameplay")
		game.size = Vector2(64, 64)
		game._update_desktop_only_overlay()
		_assert(!overlay.visible, "Godot's headless placeholder should use the configured desktop viewport")
		_assert(game._gameplay_action_allowed(), "headless placeholder size should not reject desktop tests")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 desktop-only viewport tests passed")
	quit(1 if failures > 0 else 0)
