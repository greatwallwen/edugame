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
	for method in ["_make_watch_shell_style", "_make_surface_card_style", "_make_metric_tile_style", "_apply_text_role"]:
		_assert(game.has_method(method), "missing shared UI method: %s" % method)
	for path in ["res://assets/fonts/NotoSansSC-VF.ttf", "res://assets/fonts/DingTalkJinBuTi.ttf", "res://assets/fonts/Orbitron-wght.ttf", "res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"]:
		_assert(ResourceLoader.exists(path), "missing embedded UI font: %s" % path)
	if game.has_method("_make_watch_shell_style"):
		var shell := game._make_watch_shell_style() as StyleBoxFlat
		_assert(shell.bg_color.get_luminance() < 0.08, "watch shell should be near-black")
		_assert(shell.corner_radius_top_left >= 20, "watch shell should have hardware-scale rounding")
	if game.has_method("_make_surface_card_style"):
		var card := game._make_surface_card_style() as StyleBoxFlat
		_assert(card.bg_color.get_luminance() > 0.88, "cards should be pale blue-white")
		_assert(card.shadow_size >= 4, "cards should have restrained elevation")
	_assert(game.get("hud_shell") is PanelContainer, "HUD should expose the dark hardware shell")
	_assert(game.get("hud_screen") is PanelContainer, "HUD should expose the pale screen surface")
	var metrics = game.get("hud_metric_labels")
	_assert(metrics is Dictionary, "HUD should expose a metric dictionary")
	if metrics is Dictionary:
		for key in ["time", "energy", "faults", "efficiency", "stability", "correction", "shadow", "protection", "score"]:
			_assert(metrics.has(key), "HUD should expose metric: %s" % key)
		if metrics.has("energy") and metrics.has("faults"):
			game._update_hud()
			_assert(str((metrics["energy"] as Label).text).contains("%"), "energy metric should keep its percentage value")
			_assert(str((metrics["faults"] as Label).text).contains("/"), "fault metric should keep current/max formatting")
		if metrics.has("stability") and metrics.has("shadow"):
			_assert(!_font_base_path((metrics["stability"] as Label).get_theme_font("font")).ends_with("Orbitron-wght.ttf"), "Chinese stability values must not use the Latin-only technical font")
			_assert(!_font_base_path((metrics["shadow"] as Label).get_theme_font("font")).ends_with("Orbitron-wght.ttf"), "Chinese shadow values must not use the Latin-only technical font")
	_assert(!_font_base_path(game.hud_control_label.get_theme_font("font")).ends_with("Orbitron-wght.ttf"), "Chinese movement hint must not use the Latin-only technical font")
	_assert(str(game.hint_label.text) == "普通光能会自动吸收；金色偏移带需要主动靠近。", "HUD hint copy must remain unchanged")
	_assert(game.has_method("_apply_modal_shell"), "modal states should share one shell helper")
	_assert(game.has_method("_add_modal_kicker"), "modal states should share one compact hierarchy helper")
	var pause_style: StyleBox = game.pause_panel.get_theme_stylebox("panel")
	_assert(pause_style is StyleBoxFlat, "pause modal should use a scalable hardware style")
	if pause_style is StyleBoxFlat:
		_assert((pause_style as StyleBoxFlat).corner_radius_top_left >= 20, "pause modal should use hardware-scale rounding")
		_assert((pause_style as StyleBoxFlat).border_width_left >= 8, "pause modal should expose a dark hardware bezel")
	_assert(_tree_contains_text(game.pause_box, "已暂停"), "pause title copy must remain unchanged")
	var pause_hint := _find_text_control(game.pause_box, "当前追光状态已冻结，继续后计时和光能流动恢复。")
	_assert(pause_hint != null, "pause explanation should remain visible")
	if pause_hint != null:
		_assert(pause_hint.get_theme_color("font_color").get_luminance() < 0.36, "muted copy should stay dark enough on the pale screen")
	var resume_button := _find_text_control(game.pause_box, "继续")
	_assert(resume_button != null, "pause resume action should remain visible")
	if resume_button != null:
		_assert(_font_base_path(resume_button.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "buttons should use the same strong Chinese display font as Ch11")
	game.active_question = {
		"prompt": "PID 控制中 D 项主要用于什么？",
		"choices": ["抑制变化趋势，减少超调和抖动", "消除长期稳态误差", "提高 PWM 频率", "扩大 ADC 采样范围"],
		"answerIndex": 0,
		"explanation": "D 项根据误差变化率进行抑制。"
	}
	game.question_time_left = 12.0
	game._show_question()
	_assert(str(game.question_title_label.text).begins_with("升级校验"), "question title copy must remain unchanged")
	_assert(!_font_base_path(game.question_title_label.get_theme_font("font")).ends_with("Orbitron-wght.ttf"), "Chinese countdown title must not use the Latin-only technical font")
	_assert(_tree_contains_text(game.question_box, "PID 控制中 D 项主要用于什么？"), "question prompt copy must remain unchanged")
	game.shutdown = false
	game._show_result()
	_assert(_tree_contains_text(game.question_box, "追光挑战完成"), "result title copy must remain unchanged")
	_assert(_tree_contains_text(game.question_box, "重新开始"), "result action copy must remain unchanged")
	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _tree_contains_text(root: Node, expected: String) -> bool:
	return _find_text_control(root, expected) != null


func _find_text_control(root: Node, expected: String) -> Control:
	if root == null:
		return null
	if (root is Label or root is Button) and str(root.get("text")) == expected:
		return root as Control
	for child in root.get_children():
		var found := _find_text_control(child, expected)
		if found != null:
			return found
	return null


func _font_base_path(font: Font) -> String:
	if font is FontVariation:
		var base_font := (font as FontVariation).base_font
		return base_font.resource_path if base_font != null else ""
	return font.resource_path if font != null else ""


func _finish() -> void:
	if failures > 0:
		print("watch debug UI tests failed: %d" % failures)
		quit(1)
	else:
		print("watch debug UI tests passed")
		quit(0)
