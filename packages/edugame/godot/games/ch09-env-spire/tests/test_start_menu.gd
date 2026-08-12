extends SceneTree

const TEST_RECORD_PATH := "user://ch09_start_menu_tutorial_test.cfg"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var menu_script = load("res://scripts/env_spire_start_menu.gd")
	_assert(menu_script != null, "start menu control should load independently")
	var game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_record_path = TEST_RECORD_PATH
	get_root().add_child(game)
	await process_frame

	_assert(game._select_initial_experience(false, false, 0) == "menu", "incomplete profiles should open the menu")
	_assert(game._select_initial_experience(false, false, game.TUTORIAL_VERSION) == "menu", "completed profiles should still open the menu")
	_assert(game._select_initial_experience(true, true, 0) == "node_lab", "Node Lab QA route should keep highest priority")
	_assert(game._select_initial_experience(false, true, game.TUTORIAL_VERSION) == "tutorial", "forced tutorial should remain a direct route")

	_assert(game.has_method("show_start_menu"), "root should expose the menu transition")
	_assert(game.has_method("select_start_menu_command"), "root should expose menu command routing")
	if !game.has_method("show_start_menu") or !game.has_method("select_start_menu_command"):
		_finish(game)
		return

	game.show_start_menu()
	var menu_state := int(game.RunState.get("MENU", -1))
	var codex_state := int(game.RunState.get("CODEX", -1))
	_assert(menu_state >= 0 and game.state == menu_state, "show_start_menu should enter MENU")
	var menu = game.find_child("StartMenuView", true, false)
	_assert(menu != null and menu.visible, "MENU should render the start menu control")
	_assert(!game.deck_label.visible, "MENU should hide the run deck metric")
	for node_name in ["StartMenuTutorial", "StartMenuRun", "StartMenuNodeLab", "StartMenuCodex", "StartMenuSettings"]:
		_assert(game.find_child(node_name, true, false) is Button, "menu should expose %s" % node_name)
	var menu_title := game.find_child("StartMenuTitle", true, false) as Label
	_assert(menu_title != null, "console menu should expose a stable title anchor")
	if menu_title != null:
		var title_font := menu_title.get_theme_font("font")
		_assert(title_font is FontVariation and int((title_font as FontVariation).variation_opentype.get("wght", 0)) >= 700, "console menu title should use a bold variable weight")
		_assert(_font_path(title_font).ends_with("DingTalkJinBuTi.ttf"), "start menu should use the Ch11 DingTalk art font")
	_assert(_font_path(game.ui_theme.default_font).ends_with("DingTalkJinBuTi.ttf"), "the global Ch09 theme should default to the Ch11 DingTalk art font")
	var run_button := game.find_child("StartMenuRun", true, false) as Button
	var menu_frame := game.find_child("StartMenuTacticalFrame", true, false) as Control
	_assert(menu_frame != null and str(menu_frame.call("visual_signature")).contains("tactical_hud"), "start menu should use the out-of-run tactical HUD frame")
	if run_button != null:
		var normal_style := run_button.get_theme_stylebox("normal") as StyleBoxFlat
		var focus_style := run_button.get_theme_stylebox("focus") as StyleBoxFlat
		_assert(normal_style.bg_color.get_luminance() < 0.12, "menu commands should use dark console surfaces")
		_assert(normal_style.border_width_top == 0 and normal_style.border_width_right == 0, "menu commands should keep their tactical frame edges open")
		_assert(focus_style.border_width_left >= 5, "menu command focus should use a strong navigation edge")
	var recommendation := game.find_child("StartMenuTutorialBadge", true, false) as Label
	_assert(recommendation != null and recommendation.visible and recommendation.text.contains("推荐"), "unfinished tutorial should be recommended")

	_assert(game.select_start_menu_command("settings"), "settings command should route")
	var settings_title := game.find_child("SettingsTitle", true, false) as Label
	var settings_panel := game.find_child("SettingsPanel", true, false) as PanelContainer
	_assert(settings_title != null and settings_panel != null, "settings should expose console visual anchors")
	if settings_title != null:
		var settings_font := settings_title.get_theme_font("font")
		_assert(settings_font is FontVariation and int((settings_font as FontVariation).variation_opentype.get("wght", 0)) >= 700, "settings title should use a bold variable weight")
		_assert(_font_path(settings_font).ends_with("DingTalkJinBuTi.ttf"), "settings should use the Ch11 DingTalk art font")
	if settings_panel != null:
		_assert((settings_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.get_luminance() > 0.82, "settings should use a light layout surface")
	var settings_frame := game.find_child("SettingsTacticalFrame", true, false) as Control
	_assert(settings_frame != null and str(settings_frame.call("visual_signature")).contains("tactical_hud"), "settings should use the out-of-run tactical HUD frame")
	game._close_settings()

	_assert(game.select_start_menu_command("tutorial"), "tutorial command should route")
	_assert(game.tutorial_active and game.tutorial_step == game.TutorialStep.BRIEFING, "tutorial command should open briefing")

	game.show_start_menu()
	_assert(game.select_start_menu_command("run"), "formal command should route")
	_assert(game.formal_run_active and game.state == game.RunState.MAP, "formal command should start a clean route")
	game._open_run_menu()
	_assert(game.run_menu_layer.visible, "formal run should expose the Escape run menu")
	_assert(game.run_menu_panel.theme != null and game.run_menu_panel.theme.default_font == game.ui_font, "run menu should carry the bundled Chinese font into Web CanvasLayer rendering")
	_assert(game.new_run_dialog.theme == game.run_menu_panel.theme and game.run_action_dialog.theme == game.run_menu_panel.theme, "confirmation dialogs should share the Web-safe UI theme")
	_assert(game.run_action_dialog.get_ok_button().text == "确认" and game.run_action_dialog.get_cancel_button().text == "取消", "run confirmation should use localized actions")
	game._request_run_action("restart")
	_assert(game.pending_run_action == "restart" and game.run_action_dialog.visible, "restart should require confirmation")
	game.run_action_dialog.hide()
	game._request_run_action("abandon")
	_assert(game.pending_run_action == "abandon" and game.run_action_dialog.dialog_text.contains("无法恢复"), "abandon should require irreversible-action confirmation")
	game.run_action_dialog.hide()
	game.pending_run_action = ""
	game._close_run_menu()
	game._finish_run(false)
	var result_menu := game.find_child("ResultMenuButton", true, false) as Button
	_assert(result_menu != null and result_menu.is_visible_in_tree(), "result should expose a menu command")
	if result_menu != null:
		result_menu.pressed.emit()
		_assert(game.state == menu_state, "result menu command should restore MENU")

	_assert(game.select_start_menu_command("codex"), "codex command should route")
	_assert(codex_state >= 0 and game.state == codex_state, "codex command should enter CODEX")
	var codex = game.find_child("CodexView", true, false)
	_assert(codex != null and codex.visible, "CODEX should render the archive control")
	_assert(!game.deck_label.visible, "CODEX should hide the run deck metric")
	var codex_back := game.find_child("CodexBack", true, false) as Button
	_assert(codex_back != null, "codex should expose a menu return")
	if codex_back != null:
		codex_back.pressed.emit()
		_assert(game.state == menu_state, "codex return should restore MENU")

	_assert(game.select_start_menu_command("node_lab"), "developer command should route")
	_assert(game.node_lab_active, "developer command should enter Node Lab")
	_assert(!game.select_start_menu_command("unknown"), "unknown menu commands should be rejected")

	game.show_start_menu()
	_assert(game._save_tutorial_completion(TEST_RECORD_PATH), "tutorial completion fixture should save")
	game.show_start_menu()
	recommendation = game.find_child("StartMenuTutorialBadge", true, false) as Label
	_assert(recommendation != null and !recommendation.visible, "completed tutorial should remove recommendation")

	_finish(game)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _font_path(font: Font) -> String:
	var resolved := (font as FontVariation).base_font if font is FontVariation else font
	return resolved.resource_path if resolved != null else ""


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_RECORD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RECORD_PATH))


func _finish(game) -> void:
	_cleanup()
	if is_instance_valid(game):
		game.queue_free()
	if failures == 0:
		print("Ch09 start menu tests passed")
	quit(1 if failures > 0 else 0)
