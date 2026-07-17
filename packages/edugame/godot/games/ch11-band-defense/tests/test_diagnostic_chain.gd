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
	_test_enemies_start_as_symptoms(game)
	_test_diagnosis_reveals_fault_with_method(game)
	_test_clicking_enemy_runs_diagnosis(game)
	_test_gui_clicking_enemy_opens_diagnosis(game)
	_test_diagnostic_menu_pauses_wave_time(game)
	await _test_level_one_shows_diagnosis_tutorial_popup(game)
	_test_diagnostic_text_uses_product_weight(game)
	_test_clicking_enemy_opens_method_menu(game)
	_test_diagnostic_data_can_return_to_methods(game)
	_test_diagnostic_data_uses_right_hud_overlay(game)
	await _test_enemy_codex_popup_pauses_and_shows_textures(game)
	_test_each_diagnostic_method_outputs_real_data(game)
	_test_diagnosis_requires_data_then_fault_choice(game)
	_test_undiagnosed_enemy_uses_unknown_visual(game)
	_test_same_fault_type_stays_diagnosed(game)
	_test_undiagnosed_enemies_only_take_probe_damage(game)
	_test_upgraded_effects_require_diagnosis(game)
	_finish()


func _test_enemies_start_as_symptoms(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game._spawn_enemy("config")
	_assert(game.enemies.size() == 1, "spawn should create an enemy")
	var enemy := game.enemies[0] as Dictionary
	_assert(!bool(enemy.get("diagnosed", true)), "new enemies should start undiagnosed")
	var display_text := str(game._enemy_display_text(enemy))
	_assert(display_text.contains("WHO_AM_I"), "undiagnosed config enemy should show a real symptom")
	_assert(!display_text.contains("配置错误"), "undiagnosed enemy should not reveal fault type")
	_assert(str(game._enemy_display_marker(enemy)) == "症", "undiagnosed enemy marker should read as symptom")


func _test_diagnosis_reveals_fault_with_method(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("power_spike")
	var enemy := game.enemies[0] as Dictionary
	var before_energy := int(game.energy)
	var ok := bool(game._diagnose_enemy(enemy))
	_assert(ok, "diagnosis should succeed when enough energy is available")
	_assert(int(game.energy) == before_energy - int(game.DIAGNOSIS_COST), "diagnosis should spend energy")
	_assert(bool(enemy.get("diagnosed", false)), "diagnosis should mark enemy as diagnosed")
	var display_text := str(game._enemy_display_text(enemy))
	_assert(display_text.contains("功耗尖峰"), "diagnosed enemy should reveal fault type")
	var diagnostic_text := str(game.diagnostic_label.text)
	_assert(diagnostic_text.contains("查看电流曲线"), "diagnosis should name the practical inspection method")
	_assert(diagnostic_text.contains("静止电流"), "diagnosis should explain the observed evidence")


func _test_clicking_enemy_runs_diagnosis(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("false_peak")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	var ok := bool(game._diagnose_enemy_at(Vector2(324, 243)))
	_assert(ok, "clicking near an enemy should open diagnosis")
	_assert(!bool(enemy.get("diagnosed", false)), "clicking should wait for a selected diagnostic method")
	_assert(game.get("pending_diagnostic_enemy") != null, "clicked enemy should become the pending diagnosis target")


func _test_gui_clicking_enemy_opens_diagnosis(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game.state = "wave_running"
	game._spawn_enemy("config")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(320, 240)
	game._gui_input(click)
	_assert(game.get("pending_diagnostic_enemy") != null, "GUI click should select the enemy for diagnosis")
	var menu = game.get("diagnostic_menu_panel")
	_assert(menu != null and bool((menu as Control).visible), "GUI click should open the diagnostic menu")


func _test_diagnostic_menu_pauses_wave_time(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game.state = "wave_running"
	game.spawn_queue = ["noise"]
	game.spawn_interval = 0.25
	game.spawn_elapsed = 0.0
	game._spawn_enemy("config")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	var before_progress := float(enemy.get("progress", 0.0))
	var before_spawn_count: int = game.enemies.size()
	_assert(bool(game._diagnose_enemy_at(Vector2(320, 240))), "diagnostic pause starts after selecting an enemy")
	game._process(1.0)
	_assert(is_equal_approx(float(enemy.get("progress", 0.0)), before_progress), "diagnostic menu should pause enemy movement")
	_assert(game.enemies.size() == before_spawn_count, "diagnostic menu should pause enemy spawning")
	_assert(is_equal_approx(float(game.spawn_elapsed), 0.0), "diagnostic menu should pause spawn timers")


func _test_level_one_shows_diagnosis_tutorial_popup(game: Node) -> void:
	_assert(game.has_method("_dismiss_diagnosis_tutorial_popup"), "diagnosis tutorial popup should be dismissible")
	game.show_main_menu()
	game.start_game()
	var popup = game.get("diagnosis_tutorial_popup")
	_assert(popup != null and bool((popup as Control).visible), "level one first wave should show the diagnosis tutorial popup")
	_assert(popup != null and (popup as Control).size.y <= 440.0, "combined first-level tutorial popup should avoid a large empty lower half")
	var popup_style := (popup as PanelContainer).get_theme_stylebox("panel") if popup is PanelContainer else null
	_assert(popup_style is StyleBoxFlat, "PS Light tutorial should use a scalable white knowledge-card surface")
	if popup_style is StyleBoxFlat:
		var popup_flat := popup_style as StyleBoxFlat
		_assert(popup_flat.bg_color.get_luminance() >= 0.94, "PS Light tutorial card should have a white background")
		_assert(popup_flat.get_content_margin(SIDE_LEFT) >= 28.0, "tutorial text should stay clear of the rounded edge")
	var label = game.get("diagnosis_tutorial_label") as Label
	_assert(label != null and str(label.text).contains("第一关"), "combined tutorial should keep the opening summary sentence")
	_assert(label != null and str(label.text).contains("四组数据"), "diagnosis tutorial should teach reading four data groups")
	_assert(label != null and !str(label.text).contains("第一关会先教"), "diagnosis tutorial should not announce the first-level teaching sequence")
	_assert(label != null and !str(label.text).contains("游戏时间会暂停"), "diagnosis tutorial should not expose pause mechanics in the body copy")
	_assert(label != null and str(label.text).contains("塔位"), "first-level tutorial should also teach tower slots")
	_assert(label != null and str(label.text).contains("圆形菜单"), "first-level tutorial should teach the radial build menu")
	_assert(label != null and label.custom_minimum_size.y <= 280.0, "combined first-level tutorial body should reserve only the height needed by its concise steps")
	var before_spawn_count: int = game.enemies.size()
	var before_spawn_elapsed := float(game.spawn_elapsed)
	game._process(1.0)
	_assert(game.enemies.size() == before_spawn_count, "diagnosis tutorial popup should pause spawning")
	_assert(is_equal_approx(float(game.spawn_elapsed), before_spawn_elapsed), "diagnosis tutorial popup should pause spawn timers")
	_assert(bool(game._dismiss_diagnosis_tutorial_popup()), "dismiss should close the diagnosis tutorial")
	await create_timer(float(game._popup_close_duration()) + 0.05).timeout
	await process_frame
	_assert(!bool((popup as Control).visible), "diagnosis tutorial popup should hide after dismissal")
	game._prepare_level_intro(2)
	game.start_game()
	_assert(!bool((popup as Control).visible), "diagnosis tutorial popup should not show on later levels")


func _test_diagnostic_text_uses_product_weight(game: Node) -> void:
	var tutorial_title := game.get("diagnosis_tutorial_title") as Label
	_assert(tutorial_title != null, "diagnosis tutorial should expose its title for display-font verification")
	if tutorial_title != null:
		var title_font: Font = tutorial_title.get_theme_font("font")
		_assert(_font_base_path(title_font).ends_with("DingTalkJinBuTi.ttf"), "PS Light tutorial title should retain the previously approved art font")
	var labels := [
		game.get("diagnostic_label") as Label,
		game.get("diagnosis_tutorial_label") as Label
	]
	for label in labels:
		_assert(label != null, "diagnostic text label should exist")
		if label == null:
			continue
		var color: Color = label.get_theme_color("font_color")
		_assert(color.r <= 0.25 and color.g <= 0.35 and color.b <= 0.42, "diagnostic text should use dark readable color on light watch UI")
		var font: Font = label.get_theme_font("font")
		_assert(font is FontVariation, "diagnostic text should use the product UI font variation")
		if font is FontVariation:
			_assert((font as FontVariation).variation_embolden >= 0.14, "diagnostic body text should be moderately bold for readability")
			_assert((font as FontVariation).variation_embolden <= 0.30, "diagnostic text should avoid the old heavy HUD font weight")
		_assert(_font_base_path(font).ends_with("DingTalkJinBuTi.ttf"), "diagnostic text should retain the previously approved art font")
	var tutorial_body := game.get("diagnosis_tutorial_label") as Label
	if tutorial_body != null and tutorial_body.get_theme_font("font") is FontVariation:
		var tutorial_body_font := tutorial_body.get_theme_font("font") as FontVariation
		_assert(tutorial_body_font.variation_embolden >= 0.14, "tutorial card body copy should use a readable art-font weight")
	var data_label := game.get("diagnostic_data_label") as Label
	_assert(data_label != null and data_label.get_theme_font_size("font_size") >= 16, "simulated diagnostic data should be large enough to scan in the right HUD")
	_assert(data_label != null and data_label.get_theme_constant("line_spacing") >= 4, "simulated diagnostic data should use generous product-style line spacing")
	if data_label != null and data_label.get_theme_font("font") is FontVariation:
		var data_font := data_label.get_theme_font("font") as FontVariation
		_assert(_font_base_path(data_font).ends_with("DingTalkJinBuTi.ttf"), "PS Light diagnostic data should retain the previously approved art font")
		_assert(data_font.variation_embolden >= 0.14, "simulated diagnostic art text should retain a readable bold display weight")
	var method_buttons := game.get("diagnostic_menu_buttons") as Dictionary
	if data_label != null and !method_buttons.is_empty():
		var option_font := (method_buttons.values()[0] as Button).get_theme_font("font")
		_assert(_font_base_path(data_label.get_theme_font("font")) == _font_base_path(option_font), "simulated diagnostic data and diagnostic options should share one art font family")


func _test_clicking_enemy_opens_method_menu(game: Node) -> void:
	_assert(game.has_method("_choose_diagnostic_method"), "diagnosis should expose method choices")
	_assert(game.has_method("_choose_fault_type"), "diagnosis should require a fault choice after reading data")
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("false_peak")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	_assert(bool(game._diagnose_enemy_at(Vector2(324, 243))), "clicking an enemy should open the method menu")
	var menu = game.get("diagnostic_menu_panel")
	_assert(menu != null and bool((menu as Control).visible), "diagnostic method menu should be visible after selecting an enemy")
	_assert(bool(game._choose_diagnostic_method("check_threshold")), "correct method should show diagnostic data")
	_assert(!bool(enemy.get("diagnosed", false)), "method data alone should not reveal the clicked enemy")
	_assert(str(game.diagnostic_label.text).contains("最小步间隔"), "peak data should mention the practical evidence")
	_assert(bool(game._choose_fault_type("false_peak")), "correct fault choice should complete peak diagnosis")
	_assert(bool(enemy.get("diagnosed", false)), "correct method should reveal the clicked enemy")
	_assert(str(game.diagnostic_label.text).contains("最小步间隔"), "peak diagnosis should mention the step interval check")


func _test_diagnostic_data_can_return_to_methods(game: Node) -> void:
	_assert(game.has_method("_return_to_diagnostic_methods"), "diagnostic data view should expose a back action")
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("power_spike")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	_assert(bool(game._diagnose_enemy_at(Vector2(320, 240))), "clicking an enemy should start diagnosis")
	_assert(bool(game._choose_diagnostic_method("read_registers")), "student can inspect one data group first")
	var first_report := str(game.diagnostic_label.text)
	_assert(str(game.get("pending_diagnostic_method")) == "read_registers", "selected method should be tracked while reading data")
	_assert(bool(game._return_to_diagnostic_methods()), "back action should return to diagnostic method choices")
	_assert(game.get("pending_diagnostic_enemy") != null, "back action should keep the same pending enemy")
	_assert(str(game.get("pending_diagnostic_method")) == "", "back action should clear the previous method")
	var data_label = game.get("diagnostic_data_label") as Label
	_assert(data_label != null and !data_label.visible, "data text should hide after returning to method choices")
	var method_buttons := game.get("diagnostic_menu_buttons") as Dictionary
	_assert(bool((method_buttons["inspect_current"] as Button).visible), "method buttons should be visible after returning")
	_assert(bool(game._choose_diagnostic_method("inspect_current")), "student can inspect another data group in the same diagnosis")
	var second_report := str(game.diagnostic_label.text)
	_assert(second_report != first_report and second_report.contains("8.5mA"), "second data group should replace the displayed evidence")
	_assert(!bool(enemy.get("diagnosed", false)), "viewing multiple data groups should not reveal the enemy until a fault is selected")


func _test_diagnostic_data_uses_right_hud_overlay(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("power_spike")
	var enemy := game.enemies[0] as Dictionary
	enemy["pos"] = Vector2(320, 240)
	_assert(bool(game._diagnose_enemy_at(Vector2(320, 240))), "clicking an enemy should start diagnosis")
	_assert(bool(game._choose_diagnostic_method("inspect_current")), "choosing a method should show data")
	var overlay = game.get("diagnostic_hud_overlay") as Control
	_assert(overlay != null and overlay.visible, "diagnostic data should appear as a right HUD overlay")
	_assert(overlay != null and overlay.position.x >= 900.0, "diagnostic data overlay should cover the right dashboard area")
	var overlay_panel := overlay as PanelContainer
	var overlay_style := overlay_panel.get_theme_stylebox("panel") if overlay_panel != null else null
	_assert(overlay_style is StyleBoxFlat, "PS Light diagnostic data overlay should use a scalable white system surface")
	if overlay_style is StyleBoxFlat:
		var overlay_flat := overlay_style as StyleBoxFlat
		_assert(overlay_flat.bg_color.get_luminance() >= 0.94, "diagnostic data overlay should stay white and opaque enough to hide the HUD underneath")
		_assert(overlay_flat.border_color.b >= 0.80, "diagnostic data overlay should retain the restrained blue focus edge")
	var data_label = game.get("diagnostic_data_label") as Label
	_assert(data_label != null and data_label.visible, "diagnostic data label should be visible inside the HUD overlay")
	_assert(data_label != null and str(data_label.text).contains("静止电流"), "HUD overlay should display the selected data report")
	_assert(bool(game._return_to_diagnostic_methods()), "returning to method choices should hide the HUD overlay")
	_assert(!overlay.visible, "diagnostic HUD overlay should hide after returning to method choices")


func _test_enemy_codex_popup_pauses_and_shows_textures(game: Node) -> void:
	_assert(game.has_method("_show_codex_popup"), "enemy codex should open as a popup")
	_assert(game.has_method("_hide_codex_popup"), "enemy codex popup should be closable")
	_assert(game.has_method("_codex_entry_count"), "enemy codex popup should expose its entry count")
	_assert(game.has_method("_codex_texture_count"), "enemy codex popup should expose how many texture previews it renders")
	if !game.has_method("_show_codex_popup") or !game.has_method("_hide_codex_popup") or !game.has_method("_codex_entry_count") or !game.has_method("_codex_texture_count"):
		return
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.state = "wave_running"
	game.spawn_queue = ["noise"]
	game.spawn_interval = 0.25
	game.spawn_elapsed = 0.0
	game._spawn_enemy("config")
	var enemy := game.enemies[0] as Dictionary
	var before_progress := float(enemy.get("progress", 0.0))
	var before_spawn_count: int = game.enemies.size()
	_assert(bool(game._show_codex_popup()), "codex button should show a centered popup")
	var popup = game.get("codex_popup") as Control
	_assert(popup != null and popup.visible, "enemy codex popup should be visible")
	_assert(popup != null and popup.position.x < 500.0, "enemy codex popup should be centered rather than embedded in the right HUD")
	_assert(int(game._codex_entry_count()) >= 6, "enemy codex popup should list the known enemy families")
	_assert(int(game._codex_texture_count()) >= 6, "enemy codex popup should render a texture preview for each enemy family")
	game._process(1.0)
	_assert(is_equal_approx(float(enemy.get("progress", 0.0)), before_progress), "enemy codex popup should pause enemy movement")
	_assert(game.enemies.size() == before_spawn_count, "enemy codex popup should pause enemy spawning")
	_assert(is_equal_approx(float(game.spawn_elapsed), 0.0), "enemy codex popup should pause spawn timers")
	_assert(bool(game._hide_codex_popup()), "closing the codex popup should succeed")
	await create_timer(float(game._popup_close_duration()) + 0.05).timeout
	await process_frame
	_assert(!popup.visible, "enemy codex popup should hide after closing")
	game._process(1.0)
	_assert(float(enemy.get("progress", 0.0)) > before_progress, "closing the codex popup should resume wave time")


func _test_each_diagnostic_method_outputs_real_data(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("power_spike")
	var enemy := game.enemies[0] as Dictionary
	enemy["hp"] = 40.0
	enemy["maxHp"] = 100.0
	var reports := {
		"read_registers": str(game._diagnostic_report_for_method(enemy, "read_registers")),
		"inspect_waveform": str(game._diagnostic_report_for_method(enemy, "inspect_waveform")),
		"inspect_current": str(game._diagnostic_report_for_method(enemy, "inspect_current")),
		"check_threshold": str(game._diagnostic_report_for_method(enemy, "check_threshold"))
	}
	_assert(str(reports["read_registers"]).contains("WHO_AM_I") and str(reports["read_registers"]).contains("0x"), "register diagnosis should show register values even when not abnormal")
	_assert(str(reports["inspect_waveform"]).contains("RMS") and str(reports["inspect_waveform"]).contains("g"), "waveform diagnosis should show waveform metrics even when not abnormal")
	_assert(str(reports["inspect_current"]).contains("mA") and str(reports["inspect_current"]).contains("静止电流"), "current diagnosis should show current metrics")
	_assert(str(reports["check_threshold"]).contains("ms") and str(reports["check_threshold"]).contains("阈值"), "threshold diagnosis should show threshold metrics even when not abnormal")
	for report in reports.values():
		var text := str(report)
		_assert(text.contains("40 / 100") and text.contains("40%"), "every diagnostic data view should include exact enemy health")
		_assert(!text.contains("未发现足以解释"), "diagnostic report should use concrete data instead of a generic normal message")
		_assert(!text.contains("看起来正常"), "diagnostic report should not be only a normal summary")


func _test_diagnosis_requires_data_then_fault_choice(game: Node) -> void:
	_assert(game.has_method("_choose_diagnostic_method"), "diagnosis should require choosing a method")
	_assert(game.has_method("_choose_fault_type"), "diagnosis should require choosing a fault type from the data")
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("power_spike")
	var enemy := game.enemies[0] as Dictionary
	var before_energy := int(game.energy)
	enemy["pos"] = Vector2(320, 240)
	_assert(bool(game._diagnose_enemy_at(Vector2(320, 240))), "clicking an enemy should start diagnosis")
	_assert(bool(game._choose_diagnostic_method("inspect_current")), "current inspection should show power data")
	_assert(!bool(enemy.get("diagnosed", false)), "data should not reveal the enemy until a fault type is selected")
	_assert(str(game.diagnostic_label.text).contains("静止电流"), "power data should expose the abnormal evidence")
	var wrong := bool(game._choose_fault_type("config"))
	_assert(!wrong, "wrong fault choice should fail the diagnosis")
	_assert(!bool(enemy.get("diagnosed", false)), "wrong fault choice should not reveal the enemy type")
	_assert(int(game.energy) == before_energy - int(game.DIAGNOSIS_MISS_COST), "wrong fault choice should spend only the miss cost")
	_assert(str(game.get("pending_diagnostic_method")) == "", "wrong fault choice should require choosing a method again")
	_assert(bool(game._choose_diagnostic_method("inspect_current")), "student should be able to re-run the diagnostic method")
	var right := bool(game._choose_fault_type("power_spike"))
	_assert(right, "correct fault choice should diagnose the enemy")
	_assert(bool(enemy.get("diagnosed", false)), "correct fault choice should reveal the enemy type")


func _test_undiagnosed_enemy_uses_unknown_visual(game: Node) -> void:
	_assert(game.has_method("_enemy_visual_texture_key"), "enemy visuals should expose a diagnosis-aware texture key")
	var unknown_texture = game.enemy_anim_sheets.get("unknown_fault", null)
	_assert(unknown_texture != null, "undiagnosed enemies should load the shared unknown fault sprite sheet")
	if unknown_texture != null:
		_assert((unknown_texture as Texture2D).get_width() == 1024, "unknown fault sheet should use the generated 4x3 runtime texture")
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("config")
	var enemy := game.enemies[0] as Dictionary
	_assert(str(game._enemy_visual_texture_key(enemy)) == "unknown_fault", "undiagnosed enemy should use the shared unknown fault visual")
	_assert(bool(game._diagnose_enemy_with_method(enemy, "read_registers")), "correct method should diagnose config enemy")
	_assert(str(game._enemy_visual_texture_key(enemy)) == "config", "diagnosed enemy should return to its specific visual")


func _test_same_fault_type_stays_diagnosed(game: Node) -> void:
	game.diagnosed_enemy_types.clear()
	game.enemies.clear()
	game.energy = 90
	game._spawn_enemy("noise")
	game._spawn_enemy("noise")
	var first := game.enemies[0] as Dictionary
	_assert(bool(game._diagnose_enemy(first)), "first noise enemy should be diagnosable")
	var energy_after_first := int(game.energy)
	var already_visible := game.enemies[1] as Dictionary
	_assert(bool(already_visible.get("diagnosed", false)), "visible enemies of the same type should be marked by the first diagnosis")
	game._spawn_enemy("noise")
	var second := game.enemies[2] as Dictionary
	_assert(bool(second.get("diagnosed", false)), "same enemy type should spawn already diagnosed after the first diagnosis")
	_assert(bool(game._diagnose_enemy(second)), "rechecking a known type should be allowed")
	_assert(int(game.energy) == energy_after_first, "rechecking a known type should not spend energy again")


func _test_undiagnosed_enemies_only_take_probe_damage(game: Node) -> void:
	var undiagnosed := {"type": "config", "threatTag": "config", "hp": 100.0, "pos": Vector2.ZERO, "diagnosed": false}
	var probed: Dictionary = game._resolve_tower_attack("i2c", 1, undiagnosed)
	var diagnosed := {"type": "config", "threatTag": "config", "hp": 100.0, "pos": Vector2.ZERO, "diagnosed": true}
	var resolved: Dictionary = game._resolve_tower_attack("i2c", 1, diagnosed)
	_assert(float(probed.get("damage", 0.0)) < float(resolved.get("damage", 0.0)), "undiagnosed enemies should take reduced probe damage")
	_assert(is_equal_approx(float(probed.get("damage", 0.0)), float(resolved.get("damage", 0.0)) * 0.45), "probe damage should use the intended diagnosis penalty")
	_assert(str(probed.get("concept", "")).contains("试探"), "probe attack should explain that diagnosis is still needed")


func _test_upgraded_effects_require_diagnosis(game: Node) -> void:
	var undiagnosed_noise := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO, "diagnosed": false}
	game._resolve_tower_attack("filter", 2, undiagnosed_noise)
	_assert(float(undiagnosed_noise.get("slowTimer", 0.0)) == 0.0, "undiagnosed enemies should not receive upgraded filter effects")
	var diagnosed_noise := {"type": "noise", "threatTag": "noise", "hp": 100.0, "pos": Vector2.ZERO, "diagnosed": true}
	game._resolve_tower_attack("filter", 2, diagnosed_noise)
	_assert(float(diagnosed_noise.get("slowTimer", 0.0)) > 0.0, "diagnosed enemies should receive upgraded filter effects")


func _font_base_path(font: Font) -> String:
	if font is FontVariation:
		var base_font := (font as FontVariation).base_font
		if base_font != null:
			return base_font.resource_path
	return font.resource_path if font != null else ""


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("diagnostic chain tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
