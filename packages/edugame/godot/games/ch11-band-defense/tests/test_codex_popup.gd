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
	await _test_codex_button_opens_popup_with_sprites(game)
	await _test_codex_popup_pauses_and_resumes_wave_time(game)
	game.queue_free()
	_finish()


func _test_codex_button_opens_popup_with_sprites(game: Node) -> void:
	_assert(game.get("codex_popup") != null, "enemy codex should use a popup panel")
	_assert(game.get("codex_card_grid") != null, "enemy codex popup should expose a card grid")
	_assert(game.has_method("_close_codex_popup"), "enemy codex popup should expose a close action")
	var popup := game.get("codex_popup") as Control
	_assert(popup != null and !popup.visible, "enemy codex popup should start hidden")
	game.codex_button.emit_signal("pressed")
	_assert(popup != null and popup.visible, "enemy codex button should open the popup")
	_assert(game.codex_label != null and !game.codex_label.visible, "old inline codex label should stay hidden")
	_assert(game.codex_button.text == "关闭图鉴", "enemy codex button should become a close action while popup is open")
	_assert(!_all_label_text(popup).contains("记录已知故障族群"), "enemy codex popup should omit the descriptive subtitle below the title")
	var sprite_views_raw = game.get("codex_sprite_views")
	_assert(typeof(sprite_views_raw) == TYPE_DICTIONARY, "enemy codex should expose sprite view lookup")
	var sprite_views := sprite_views_raw as Dictionary if typeof(sprite_views_raw) == TYPE_DICTIONARY else {}
	for enemy_type in ["config", "noise", "drift_noise", "false_peak", "power_spike", "hybrid_fault"]:
		_assert(sprite_views.has(enemy_type), "enemy codex should include a sprite card for %s" % enemy_type)
		var sprite_view := sprite_views.get(enemy_type) as TextureRect
		_assert(sprite_view != null and sprite_view.texture != null, "sprite card should display an enemy texture for %s" % enemy_type)
		if sprite_view != null:
			_assert(sprite_view.custom_minimum_size.x >= 54.0 and sprite_view.custom_minimum_size.y >= 54.0, "sprite card should reserve readable art size for %s" % enemy_type)
	_assert(!str(_all_label_text(popup)).contains("克制"), "enemy codex popup should not reveal tower counters")
	_assert(game.has_method("_close_codex_popup") and bool(game._close_codex_popup()), "close action should hide the popup")
	await create_timer(float(game._popup_close_duration()) + 0.05).timeout
	await process_frame
	_assert(popup != null and !popup.visible, "enemy codex popup should hide after closing")
	_assert(game.codex_button.text == "敌人图鉴", "enemy codex button should reset after closing")


func _test_codex_popup_pauses_and_resumes_wave_time(game: Node) -> void:
	game.state = "wave_running"
	game.enemies.clear()
	game.spawn_queue = ["noise"]
	game.spawn_interval = 0.25
	game.spawn_elapsed = 0.0
	game._spawn_enemy("config")
	var enemy := game.enemies[0] as Dictionary
	var before_progress := float(enemy.get("progress", 0.0))
	var before_spawn_count: int = game.enemies.size()
	game.codex_button.emit_signal("pressed")
	_assert(bool(game._is_diagnostic_time_paused()), "open enemy codex popup should pause wave time")
	game._process(1.0)
	_assert(is_equal_approx(float(enemy.get("progress", 0.0)), before_progress), "enemy codex popup should pause enemy movement")
	_assert(game.enemies.size() == before_spawn_count, "enemy codex popup should pause enemy spawning")
	_assert(is_equal_approx(float(game.spawn_elapsed), 0.0), "enemy codex popup should pause spawn timers")
	_assert(game.has_method("_close_codex_popup") and bool(game._close_codex_popup()), "closing enemy codex should resume the wave")
	await create_timer(float(game._popup_close_duration()) + 0.05).timeout
	await process_frame
	_assert(!bool(game._is_diagnostic_time_paused()), "closed enemy codex popup should no longer pause wave time")
	game._process(1.0)
	_assert(float(enemy.get("progress", 0.0)) > before_progress or game.enemies.size() > before_spawn_count or float(game.spawn_elapsed) > 0.0, "wave should resume after codex popup closes")


func _all_label_text(root: Node) -> String:
	if root == null:
		return ""
	var parts := []
	if root is Label:
		parts.append(str((root as Label).text))
	for child in root.get_children():
		parts.append(_all_label_text(child))
	return "\n".join(parts)


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("codex popup tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
