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
	_assert(game.has_method("_apply_platform_button_style"), "root should expose platform button styling helper")
	_assert(game.has_method("_ui_style_id"), "root should expose the reversible UI style identifier")
	_assert(game.has_method("_uses_ps_light_ui"), "root should expose the PS Light theme switch")
	if game.has_method("_ui_style_id") and game.has_method("_uses_ps_light_ui"):
		_assert(str(game._ui_style_id()) == "ps_light", "PS Light should be the default text UI style")
		_assert(bool(game._uses_ps_light_ui()), "PS Light theme should be active by default")
	_assert(game.has_method("_make_platform_panel_style"), "root should expose platform panel styling helper")
	_assert(game.has_method("_apply_game_button_style"), "root should expose polished game button styling helper")
	_assert(game.has_method("_make_game_panel_style"), "root should expose polished game panel styling helper")
	_assert(game.has_method("_make_hud_texture_style"), "root should expose texture-backed HUD style helper")
	_assert(game.has_method("_apply_hud_label_style"), "root should expose readable HUD label styling helper")
	_assert(game.has_method("_apply_watch_readout_label_style"), "root should expose refined watch readout text styling helper")
	_assert(game.has_method("_apply_level_info_label_style"), "root should expose a dedicated art-font style for compact level information")
	_assert(game.has_method("_apply_status_banner_label_style"), "root should expose centered map status banner styling helper")
	_assert(game.has_method("_tower_upgrade_description"), "root should expose tower upgrade teaching text")
	_assert(game.has_method("_attack_feedback_text"), "root should expose teaching hit feedback text")
	_assert(game.has_method("_hit_feedback_font"), "root should expose the hit feedback display font")
	_assert(game.has_method("_hit_feedback_font_size"), "root should expose the hit feedback display font size")
	_assert(game.has_method("_build_codex_text"), "root should expose enemy codex text")
	_assert(game.has_method("_tutorial_text"), "root should expose state-aware tutorial text")
	_assert(game.has_method("_enemy_visual_marker"), "root should expose enemy visual marker text")
	_assert(game.has_method("_tower_level_badge"), "root should expose tower level badge text")
	_assert(game.has_method("_game_canvas_rect"), "root should expose fixed 16:9 canvas rect")
	_assert(game.has_method("_background_draw_rect"), "background should use the fixed design canvas")
	_assert(game.has_method("_hud_background_draw_rect"), "right HUD background should be drawn as its own fixed layer")
	_assert(game.has_method("_hud_shell_rect"), "right HUD should expose a full-height metal shell geometry")
	_assert(game.has_method("_hud_screen_rect"), "right HUD should expose a full-bleed black screen geometry")
	_assert(game.has_method("_hud_screen_corner_radius"), "right HUD should preserve all four rounded screen corners")
	_assert(game.has_method("_hud_shell_palette"), "right HUD should expose its map-frame-matched shell palette")
	_assert(game.has_method("_draw_path_layer"), "route should be drawn as a separate configurable layer")
	_assert(game.has_method("_path_layer_style"), "route layer should expose style settings separately from the background")
	_assert(game.has_method("_hud_panel_rect"), "side HUD should use the shared design canvas coordinates")
	_assert(game.has_method("_slot_marker_center"), "tower slot markers should expose a shared pixel-aligned center helper")
	_assert(game.has_method("_slot_cross_rects"), "tower slot markers should expose centered cross geometry")
	_assert(game.has_method("_enemy_should_draw_fault_tag"), "enemy fault tags should expose a single disable policy")
	_assert(game.has_method("_enemy_should_draw_symptom_label"), "enemy labels should expose a density-aware visibility helper")
	_assert(game.has_method("_hud_section_order"), "side HUD should expose its three-section information hierarchy")
	if game.has_method("_hud_section_order"):
		var hud_sections := game._hud_section_order() as Array
		_assert(hud_sections == ["core", "action", "feedback"], "side HUD should read as core status, current action, then feedback")
		_assert(game.get("hud_core_section") != null, "side HUD should have a top core status section")
		_assert(game.get("hud_action_section") != null, "side HUD should have a middle current-action section")
		_assert(game.get("hud_feedback_section") != null, "side HUD should have a bottom diagnosis and feedback section")
		_assert(_node_has_descendant(game.get("hud_core_section") as Node, game.hud_metrics_strip), "core HUD section should contain the telemetry strip")
		_assert(_node_has_descendant(game.get("hud_core_section") as Node, game.hud_label), "core HUD section should contain the compact readout")
		_assert(_node_has_descendant(game.get("hud_action_section") as Node, game.start_button), "action HUD section should contain the primary wave button")
		for tower_id in game.tower_buttons.keys():
			_assert(_node_has_descendant(game.get("hud_action_section") as Node, game.tower_buttons[tower_id] as Node), "action HUD section should contain tower control: %s" % tower_id)
		_assert(_node_has_descendant(game.get("hud_feedback_section") as Node, game.codex_button), "feedback HUD section should contain the codex button")
		_assert(_node_has_descendant(game.get("hud_feedback_section") as Node, game.diagnostic_label), "feedback HUD section should contain diagnosis text")
		_assert(_node_has_descendant(game.get("hud_feedback_section") as Node, game.result_label), "feedback HUD section should contain result text")
	if game.has_method("_game_canvas_rect") and game.has_method("_background_draw_rect") and game.has_method("_hud_panel_rect"):
		var canvas_rect := game._game_canvas_rect() as Rect2
		var background_rect := game._background_draw_rect() as Rect2
		var hud_background_rect := game._hud_background_draw_rect() as Rect2 if game.has_method("_hud_background_draw_rect") else Rect2()
		var hud_rect := game._hud_panel_rect() as Rect2
		_assert(canvas_rect.size == Vector2(1280, 720), "game canvas should stay 1280x720 even in narrow embeds")
		_assert(background_rect == canvas_rect, "background should not stretch to a non-16:9 viewport")
		_assert(hud_background_rect == canvas_rect, "right HUD background layer should share the same fixed canvas coordinates as the map layer")
		_assert(game.get("hud_background_map") != null, "right HUD background texture should load independently from the left map background")
		if game.has_method("_hud_shell_rect") and game.has_method("_hud_screen_rect") and game.has_method("_hud_screen_corner_radius"):
			var shell_rect := game._hud_shell_rect() as Rect2
			var screen_rect := game._hud_screen_rect() as Rect2
			var screen_radius := int(game._hud_screen_corner_radius())
			_assert(shell_rect.position.x <= 960.0 and shell_rect.position.y <= 0.0, "right HUD metal shell should begin where the left map frame ends")
			_assert(shell_rect.end.x >= canvas_rect.end.x and shell_rect.end.y >= canvas_rect.end.y, "right HUD metal shell should cover the complete right column")
			var panel_rect := game._hud_panel_rect() as Rect2
			_assert(absf(panel_rect.get_center().x - screen_rect.get_center().x) <= 1.0, "PS Light white HUD surface should be geometrically centered in the black watch screen")
			_assert(screen_rect.position.x <= 968.0 and screen_rect.position.y <= 4.0, "black watch screen should start close to the right-column edges")
			_assert(screen_rect.end.x >= canvas_rect.end.x - 4.0 and screen_rect.end.y >= canvas_rect.end.y - 4.0, "black watch screen should not leave a white base around the HUD")
			_assert(screen_radius >= 28, "black watch screen should retain four clearly rounded corners")
			_assert(screen_rect.encloses(hud_rect), "full-bleed black watch screen should contain the complete side HUD")
		if game.has_method("_hud_shell_palette"):
			var shell_palette := game._hud_shell_palette() as Dictionary
			var frame_color := shell_palette.get("frame", Color.WHITE) as Color
			var screen_color := shell_palette.get("screen", Color.WHITE) as Color
			_assert(frame_color.get_luminance() >= 0.18 and frame_color.get_luminance() <= 0.38, "right HUD shell should continue the left map frame's restrained metal gray")
			_assert(screen_color.get_luminance() <= 0.08, "right HUD screen should remain genuinely black instead of white-backed")
		if game.has_method("_path_layer_style"):
			var path_style := game._path_layer_style() as Dictionary
			_assert(bool(path_style.get("visible", false)), "path layer should be visible by default")
			_assert(float(path_style.get("width", 0.0)) >= 8.0, "path layer should expose a readable stroke width")
			_assert(float(path_style.get("glowWidth", 999.0)) <= 18.0, "path layer glow should stay narrow enough to keep tower pads readable")
			_assert(float(path_style.get("glowAlpha", 1.0)) <= 0.24, "path layer glow should stay subtle over empty tower pads")
		var watch_screen_rect := game._hud_screen_rect() as Rect2
		_assert(absf(hud_rect.get_center().x - watch_screen_rect.get_center().x) <= 1.0, "side HUD should center on the right inset smartwatch display")
		_assert(hud_rect.position.x >= 968 and hud_rect.end.x <= 1272, "enlarged side HUD should stay inside the right inset smartwatch display safe area")
		_assert(hud_rect.size.x >= watch_screen_rect.size.x * 0.92, "white HUD surface should use most of the black watch-screen width")
		_assert(hud_rect.size.y >= watch_screen_rect.size.y * 0.92, "white HUD surface should use most of the black watch-screen height")
		_assert(game.quiz_panel.get_rect().end.x <= hud_rect.position.x - 12.0, "quiz dialog should leave a clear gutter before the right HUD border")
		_assert(hud_rect.position.y >= 20.0 and hud_rect.position.y <= 32.0, "enlarged side HUD should stay below the rounded smartwatch top corner")
		_assert(hud_rect.end.y <= canvas_rect.end.y - 20.0, "enlarged side HUD should preserve a black bottom margin inside the watch screen")
		_assert(hud_rect.size.y >= 640.0, "side HUD should still use enough screen height for compact iOS-style cards")
		_assert(!bool(game.status_label.visible), "top status should stay hidden so it cannot overlap hardware art")
	_assert(game.get("side_hud_content_frame") != null, "side HUD should expose a content safe frame")
	var side_frame := game.get("side_hud_content_frame") as MarginContainer
	_assert(side_frame != null, "side HUD content safe frame should be a margin container")
	if side_frame != null:
		_assert(side_frame.get_theme_constant("margin_left") == side_frame.get_theme_constant("margin_right"), "side HUD content should use symmetric horizontal padding inside the watch screen")
		_assert(side_frame.get_theme_constant("margin_left") >= 4, "side HUD content should keep breathing room inside the watch screen")
	var side_box := side_frame.get_child(0) as VBoxContainer if side_frame != null and side_frame.get_child_count() > 0 else null
	_assert(side_box != null, "side HUD content safe frame should contain the dashboard VBox")
	if side_box == null:
		_finish()
		return
	_assert(side_box.get_theme_constant("separation") <= 2, "side HUD sections should share one continuous instrument surface without black gaps")
	var section_cards = game.get("hud_section_cards") as Dictionary
	_assert(section_cards.size() == 3, "side HUD should preserve its semantic status, action, and feedback groups")
	for section_id in ["core", "action", "feedback"]:
		var card := section_cards.get(section_id, null) as PanelContainer
		_assert(card != null, "side HUD should expose a semantic group for section: %s" % section_id)
		if card != null:
			_assert(bool(card.clip_contents), "side HUD section card should clip its contents: %s" % section_id)
			var card_style = card.get_theme_stylebox("panel")
			_assert(card_style is StyleBoxEmpty, "side HUD semantic groups should not break the continuous inner panel: %s" % section_id)
			var section_node = game.get("hud_%s_section" % section_id) as Node
			_assert(_node_has_descendant(card, section_node), "side HUD section should stay inside its matching card: %s" % section_id)
			if section_node != null and section_node.get_child_count() > 0:
				var title_plate := section_node.get_child(0) as PanelContainer
				_assert(title_plate != null and title_plate.get_theme_stylebox("panel") is StyleBoxEmpty, "section titles should sit directly on the card without another capsule: %s" % section_id)
				if title_plate != null:
					var title_style := title_plate.get_theme_stylebox("panel")
					_assert(title_plate.custom_minimum_size.y >= 26.0, "section title frame should reserve a more breathable row: %s" % section_id)
					_assert(title_style.get_content_margin(SIDE_LEFT) >= 10.0 and title_style.get_content_margin(SIDE_RIGHT) >= 10.0, "section title should keep symmetric horizontal padding: %s" % section_id)
					_assert(title_style.get_content_margin(SIDE_TOP) >= 2.0 and title_style.get_content_margin(SIDE_BOTTOM) >= 2.0, "section title should not touch its vertical frame: %s" % section_id)
	_assert(bool(game.side_panel.clip_contents), "side HUD panel should clip all content to the smartwatch screen frame")
	_assert(game.start_button.custom_minimum_size.y >= 46.0 and game.start_button.custom_minimum_size.y <= 50.0, "side HUD primary action should have a larger touch target without overflowing")
	_assert(game.codex_button.custom_minimum_size.y >= 42.0, "side HUD codex action should use the enlarged control size")
	_assert(game.get("codex_button") != null, "side panel should include an enemy codex button")
	_assert(game.get("codex_label") != null, "side panel should include an enemy codex label")
	_assert(game.get("tutorial_label") == null, "side HUD should not include tutorial guide text after the first-level popup owns onboarding")
	_assert(game.title_label == null or !game.title_label.is_inside_tree(), "top-left title should be removed from the play surface")
	_assert(game.diagnosis_tutorial_popup.size.y <= 440.0, "tutorial popup should fit its concise copy without a large empty lower half")
	_assert(game.diagnosis_tutorial_label.custom_minimum_size.y <= 280.0, "tutorial body should reserve only the height needed by its short steps")
	_assert(!bool(game.status_label.visible), "map status banner should remain hidden after the left-top title removal")
	game.select_level(3)
	game.start_game()
	_assert(!bool(game.status_label.visible), "wave status should stay inside the right HUD instead of reappearing on the map")
	_assert(!str(game.diagnostic_label.text).contains("观察"), "side HUD running status should not contain tutorial guide verbs")
	_assert(!str(game.diagnostic_label.text).contains("点击塔位"), "side HUD running status should keep build teaching inside the first-level popup")
	_assert(game.diagnostic_label.max_lines_visible <= 2, "side diagnostic feedback should avoid dense stacked small text")
	_assert(game.result_label.get_theme_font("font") is FontVariation, "result text should use a calm product emphasis font")
	_assert(game.hud_label.get_theme_font("font") is FontVariation, "HUD readout should use an embedded font on textured panels")
	var hud_font := game.hud_label.get_theme_font("font") as FontVariation
	_assert(hud_font.variation_embolden >= 0.14, "Chinese HUD readout should stay bold enough to read on the watch panel")
	_assert(_font_base_path(hud_font).ends_with("DingTalkJinBuTi.ttf"), "PS Light level information should retain the previously approved art font")
	_assert(game.hud_label.get_theme_constant("outline_size") == 0, "HUD readout should not rely on dark outlines over the HUD texture")
	var hud_text_color: Color = game.hud_label.get_theme_color("font_color")
	_assert(hud_text_color.r < 0.25 and hud_text_color.g < 0.35 and hud_text_color.b < 0.42, "HUD readout should use dark text on light hidden-debug glass")
	_assert(game.get("hud_metrics_strip") != null, "side HUD should include a compact watch telemetry strip")
	_assert(game.hud_metrics_strip.has_method("_decorative_status_labels"), "watch telemetry strip should expose decorative label policy")
	if game.hud_metrics_strip.has_method("_decorative_status_labels"):
		_assert(game.hud_metrics_strip._decorative_status_labels().is_empty(), "watch telemetry strip should remove STB/PWR/DEBUG decorative text labels")
	_assert(game.hud_metrics_strip.has_method("_status_icon_count"), "watch telemetry strip should express core state with icons and status lamps")
	if game.hud_metrics_strip.has_method("_status_icon_count"):
		_assert(int(game.hud_metrics_strip._status_icon_count()) == 2, "watch telemetry strip should keep only the two functional ring icons")
	_assert(game.hud_metrics_strip.has_method("_tile_shadow_size"), "watch telemetry strip should expose its tile elevation policy")
	if game.hud_metrics_strip.has_method("_tile_shadow_size"):
		_assert(int(game.hud_metrics_strip._tile_shadow_size()) == 0, "metric tiles should not stack another shadow inside the core card")
	_assert(game.get("hud_status_tray") != null, "core white HUD readout should expose its framed tray")
	if game.get("hud_status_tray") != null:
		var status_tray := game.get("hud_status_tray") as Control
		_assert(bool(status_tray.clip_contents), "core white HUD readout tray should clip text to the frame")
		_assert(status_tray.custom_minimum_size.y >= 88.0, "core status frame should reserve enough vertical padding around two text lines")
		_assert(game.get("hud_status_text_plate") != null, "core HUD status text should sit on its own readable text plate")
		_assert(game.get("hud_status_wave_preview") == null, "core HUD should not repeat the waveform in a second nested card")
		await process_frame
		var tray_safe_rect: Rect2 = status_tray.get_global_rect().grow_side(SIDE_LEFT, -8.0).grow_side(SIDE_RIGHT, -8.0).grow_side(SIDE_TOP, -6.0).grow_side(SIDE_BOTTOM, -6.0)
		var hud_label_rect: Rect2 = game.hud_label.get_global_rect()
		_assert(tray_safe_rect.encloses(hud_label_rect), "core HUD text should stay inside the white readout frame safe area")
		_assert(str(game.hud_label.text).split("\n").size() <= game.hud_label.max_lines_visible, "core HUD status text should not contain more lines than the readout can display")
		_assert(str(game.hud_label.text).split("\n").size() <= 2, "core HUD status text should stay to two breathable lines beside the waveform preview")
		var text_plate := game.get("hud_status_text_plate") as Control
		if text_plate != null:
			_assert(text_plate.get_global_rect().encloses(hud_label_rect), "core HUD readout text should stay inside its isolated text plate")
			_assert(text_plate.custom_minimum_size.y >= 68.0, "core HUD text plate should be taller than the text block")
			var plate_rect := text_plate.get_global_rect()
			var horizontal_gap := minf(hud_label_rect.position.x - plate_rect.position.x, plate_rect.end.x - hud_label_rect.end.x)
			var vertical_gap := minf(hud_label_rect.position.y - plate_rect.position.y, plate_rect.end.y - hud_label_rect.end.y)
			_assert(horizontal_gap >= 12.0, "core HUD text should keep at least 12 px horizontal inset inside its frame")
			_assert(vertical_gap >= 12.0, "core HUD text should keep at least 12 px vertical inset inside its frame")
			_assert(text_plate.get_parent().get_child_count() == 1, "core readout row should contain one clean status surface")
			_assert(text_plate.get_theme_stylebox("panel") is StyleBoxEmpty, "core HUD text should not add a nested bordered card inside the status card")
		_assert(game.hud_label.get_theme_font_size("font_size") >= 13, "core HUD readout text beside the waveform should be larger and easier to read")
	_assert(game.diagnostic_label.custom_minimum_size.y >= 40.0, "diagnostic feedback should reserve breathing room for two lines")
	_assert(!str(game.result_label.text).is_empty() or !bool(game.result_label.visible), "empty result text should not consume the padding budget of the feedback card")
	for debug_token in ["STB", "PWR", "DEBUG", "LINK", "STEP", "WAKE", "DATA"]:
		_assert(!str(game.hud_label.text).contains(debug_token), "core HUD readout should avoid English debug token: %s" % debug_token)
	_assert(game.get("tower_match_hint_label") != null, "tower match hint should remain available for non-visual help")
	var tower_hint := game.get("tower_match_hint_label") as Label
	if tower_hint != null:
		_assert(!tower_hint.visible, "damage multiplier helper copy should not occupy permanent HUD space")
	_assert(game.get("hud_feedback_title_label") != null, "feedback section title should be a named readable label")
	var feedback_title := game.get("hud_feedback_title_label") as Label
	if feedback_title != null:
		var feedback_title_color: Color = feedback_title.get_theme_color("font_color")
		_assert(feedback_title.get_theme_font_size("font_size") >= 12, "feedback section title should be large enough to read")
		_assert(feedback_title_color.a >= 0.96, "feedback section title should not be faded")
	_assert(game.start_button.get_theme_font("font") is FontVariation, "button text should use a medium product button font")
	var start_button_font := game.start_button.get_theme_font("font") as FontVariation
	_assert(start_button_font.variation_embolden <= 0.34, "button text should avoid the old heavy HUD embolden")
	_assert(_font_base_path(start_button_font).ends_with("DingTalkJinBuTi.ttf"), "PS Light buttons should retain the previously approved art font")
	_assert(game.start_button.get_theme_constant("outline_size") == 0, "button text should not use a strong dark outline on instrument plates")
	var button_text_color: Color = game.start_button.get_theme_color("font_color")
	_assert(button_text_color.r < 0.25 and button_text_color.g < 0.35 and button_text_color.b < 0.42, "watch-style capsule buttons should use dark text on light controls")
	for tower_id in game.tower_buttons.keys():
		var tower_button := game.tower_buttons[tower_id] as Button
		_assert(tower_button.custom_minimum_size.y >= 40.0 and tower_button.custom_minimum_size.y <= 44.0, "tower buttons should provide larger readable touch targets")
		_assert(bool(tower_button.clip_text), "tower buttons should clip text inside their capsule frames")
		_assert(tower_button.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "tower buttons should trim any long label inside the capsule frame")
	for control in _side_text_controls(game.side_panel):
		if control is Label:
			var label := control as Label
			_assert(bool(label.clip_text), "side HUD labels should clip text within their card or panel frame")
		elif control is Button:
			var button := control as Button
			_assert(bool(button.clip_text), "side HUD buttons should clip text within their capsule frame")
			_assert(button.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "side HUD buttons should ellipsize text instead of overflowing their capsule frame")
	_assert(bool(game.main_menu_panel.get_meta("game_ui_polish", false)), "main menu should opt into the polished game UI treatment")
	_assert(bool(game.level_select_panel.get_meta("game_ui_polish", false)), "level select should opt into the polished game UI treatment")
	for panel_name in ["main_menu_panel", "level_select_panel", "diagnosis_tutorial_popup", "quiz_panel", "diagnostic_hud_overlay", "diagnostic_menu_panel"]:
		var hud_panel := game.get(panel_name) as Control
		_assert(hud_panel != null and bool(hud_panel.clip_contents), "white HUD panel should clip text to its frame: %s" % panel_name)
	var side_style = game.side_panel.get_theme_stylebox("panel")
	_assert(side_style is StyleBoxFlat, "PS Light side HUD should use one clean scalable white surface")
	if side_style is StyleBoxFlat:
		var continuous_panel := side_style as StyleBoxFlat
		_assert(continuous_panel.bg_color.get_luminance() >= 0.94, "PS Light side HUD should use a genuinely white system surface")
		_assert(continuous_panel.border_color.b > continuous_panel.border_color.r, "PS Light side HUD border should carry a restrained cool-blue focus bias")
		_assert(continuous_panel.get_corner_radius(CORNER_TOP_LEFT) >= 18, "PS Light side HUD should retain the approved compact rounded card silhouette")
		_assert(continuous_panel.get_content_margin(SIDE_LEFT) >= 14.0, "PS Light side HUD should keep content clear of the rounded edge")
	var start_style = game.start_button.get_theme_stylebox("normal")
	_assert(start_style is StyleBoxFlat, "PS Light primary action should use a crisp scalable focus surface")
	if start_style is StyleBoxFlat:
		var start_flat := start_style as StyleBoxFlat
		_assert(start_flat.bg_color.get_luminance() >= 0.90, "PS Light primary action should stay light instead of becoming a solid colored pill")
		_assert(start_flat.border_color.b >= 0.80 and start_flat.border_color.r <= 0.35, "PS Light primary action should use a restrained blue focus border")
		_assert(start_flat.get_corner_radius(CORNER_TOP_LEFT) <= 14, "PS Light controls should avoid the old oversized capsule radius")
	var main_style = game.main_menu_panel.get_theme_stylebox("panel")
	_assert(main_style is StyleBoxFlat, "PS Light main menu should use the same scalable white knowledge-card surface")
	if main_style is StyleBoxFlat:
		var main_flat := main_style as StyleBoxFlat
		_assert(main_flat.bg_color.get_luminance() >= 0.94, "PS Light main menu should have a white card background")
		_assert(main_flat.get_content_margin(SIDE_TOP) >= 34.0, "main menu text should keep generous top padding")
		_assert(main_flat.get_content_margin(SIDE_LEFT) >= 28.0, "main menu text should keep generous side padding")
	for menu_control in _side_text_controls(game.main_menu_panel):
		var menu_font := menu_control.get_theme_font("font")
		_assert(_font_base_path(menu_font).ends_with("DingTalkJinBuTi.ttf"), "PS Light main menu text should use the previously approved art font family")
	var level_style = game.level_select_panel.get_theme_stylebox("panel")
	_assert(level_style is StyleBoxFlat, "PS Light level select should use a scalable white system card")
	if level_style is StyleBoxFlat:
		var level_flat := level_style as StyleBoxFlat
		_assert(level_flat.bg_color.get_luminance() >= 0.94, "PS Light level select should have a white card background")
		_assert(level_flat.get_content_margin(SIDE_TOP) >= 34.0, "level select text should keep generous top padding")
		_assert(level_flat.get_content_margin(SIDE_LEFT) >= 28.0, "level select text should keep generous side padding")
	var quiz_style = game.quiz_panel.get_theme_stylebox("panel")
	_assert(quiz_style is StyleBoxFlat, "PS Light quiz panel should use a scalable white knowledge card")
	if quiz_style is StyleBoxFlat:
		var quiz_flat := quiz_style as StyleBoxFlat
		_assert(quiz_flat.bg_color.get_luminance() >= 0.94, "PS Light quiz panel should have a white card background")
		_assert(quiz_flat.get_content_margin(SIDE_TOP) >= 36.0, "quiz dialog text should keep generous top padding")
		_assert(quiz_flat.get_content_margin(SIDE_LEFT) >= 30.0, "quiz dialog text should keep generous side padding")
	var slot_title_color: Color = game.slot_menu_title.get_theme_color("font_color")
	_assert(slot_title_color.b >= 0.80 and slot_title_color.r <= 0.35, "PS Light slot menu title should use the restrained blue focus color")
	_assert(game.get("slot_menu_backdrop") != null, "slot menu should include a dedicated frosted backdrop layer")
	var slot_backdrop := game.get("slot_menu_backdrop") as Control
	_assert(slot_backdrop != null and slot_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "slot menu backdrop should not block radial menu clicks")
	if slot_backdrop != null:
		_assert(slot_backdrop.get_index() < game.slot_menu_title.get_index(), "slot menu backdrop should render below the title and buttons")
		_assert(slot_backdrop.has_method("_surface_count") and int(slot_backdrop._surface_count()) == 1, "slot menu should use one clean frosted surface")
		_assert(slot_backdrop.has_method("_outline_count") and int(slot_backdrop._outline_count()) == 0, "slot menu should not stack decorative ring outlines")
		_assert(slot_backdrop.has_method("_uses_clean_window_glass") and bool(slot_backdrop._uses_clean_window_glass()), "slot menu should share the clean liquid-glass treatment used by popup windows")
		_assert(slot_backdrop.has_method("_specular_highlight_count") and int(slot_backdrop._specular_highlight_count()) == 1, "slot menu glass should use one controlled highlight instead of decorative rings")
		_assert(slot_backdrop.has_method("_glass_shadow_size") and float(slot_backdrop._glass_shadow_size()) >= 8.0, "slot menu glass should have enough depth to read as a floating window")
	_assert(game.slot_menu_title.size.y >= 50.0, "slot menu center copy should have comfortable space for its two-line status")
	for tower_id in game.slot_menu_buttons.keys():
		var entry := game.slot_menu_buttons[tower_id] as Dictionary
		_assert(!entry.has("costPlate"), "slot menu cost should be integrated into the button instead of another floating capsule")
		var radial_button := entry.get("button", null) as Button
		_assert(radial_button != null and str(radial_button.text).split("\n").size() <= 2, "radial tower buttons should keep name and cost to at most two lines")
		if radial_button != null:
			_assert(radial_button.has_meta("slot_glass_style") and bool(radial_button.get_meta("slot_glass_style")), "radial tower buttons should identify the shared glass-window style")
			var radial_style := radial_button.get_theme_stylebox("normal")
			_assert(radial_style is StyleBoxFlat, "radial tower buttons should use a crisp scalable glass surface")
			if radial_style is StyleBoxFlat:
				var radial_flat := radial_style as StyleBoxFlat
				_assert(radial_flat.bg_color.r > 0.88 and radial_flat.bg_color.g > 0.92 and radial_flat.bg_color.b > 0.94, "radial tower buttons should use a clean cool-white glass fill")
				_assert(radial_flat.get_border_width(SIDE_TOP) >= 2, "radial tower buttons should carry a restrained tower-type accent ring")
				_assert(radial_flat.shadow_size >= 8, "radial tower buttons should match the dimensional depth of popup controls")
			_assert(_font_base_path(radial_button.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "PS Light radial tower buttons should retain the previously approved art font")
	_assert(game.quiz_prompt.get_theme_font("font") is FontVariation, "quiz prompt should use a readable product body font over the dialog texture")
	var quiz_prompt_font := game.quiz_prompt.get_theme_font("font") as FontVariation
	_assert(quiz_prompt_font.variation_embolden >= 0.14, "quiz body copy should be moderately bold for readability")
	_assert(quiz_prompt_font.variation_embolden <= 0.24, "quiz body copy should not look like heavy HUD text")
	_assert(_font_base_path(quiz_prompt_font).ends_with("DingTalkJinBuTi.ttf"), "quiz body copy should retain the previously approved art font")
	if game.quiz_buttons.size() > 0:
		var quiz_button := game.quiz_buttons[0] as Button
		var quiz_button_font := quiz_button.get_theme_font("font") as FontVariation
		_assert(_font_base_path(quiz_button_font).ends_with("DingTalkJinBuTi.ttf"), "quiz answers should retain the previously approved art font")
		_assert(quiz_button_font.variation_embolden >= 0.14, "long quiz answers should use a readable art-font weight over the white dialog")
		_assert(quiz_button.get_theme_font_size("font_size") >= 15, "long quiz answers should not look washed out on the pale dialog texture")
	_assert(game.quiz_prompt.get_theme_constant("outline_size") == 0, "quiz prompt should remain legible without the dark outline")
	var quiz_prompt_color: Color = game.quiz_prompt.get_theme_color("font_color")
	_assert(quiz_prompt_color.r < 0.25 and quiz_prompt_color.g < 0.35 and quiz_prompt_color.b < 0.42, "quiz prompt should use dark hidden-debug text")
	game._show_quiz()
	await process_frame
	_assert(!str(game.quiz_prompt.text).strip_edges().is_empty(), "quiz dialog should render a visible question prompt")
	_assert(game.quiz_prompt.get_global_rect().size.y >= 40.0, "quiz prompt should reserve a readable row instead of collapsing above the choices")
	if game.quiz_buttons.size() > 0:
		var first_quiz_button := game.quiz_buttons[0] as Button
		_assert(first_quiz_button.get_global_rect().position.y >= game.quiz_prompt.get_global_rect().end.y, "quiz choices should begin below the complete question prompt")
	game._animate_popup_out(game.quiz_panel)
	_assert(game.diagnostic_menu_title.custom_minimum_size.y >= 36.0, "diagnostic popup title should keep a dedicated readable row")
	if game.has_method("_slot_marker_center") and game.has_method("_slot_cross_rects"):
		var marker_center: Vector2 = game._slot_marker_center(Vector2(205.4, 279.6))
		_assert(marker_center == Vector2(205, 280), "slot marker center should snap to whole-pixel tower base center")
		var cross_rects: Array = game._slot_cross_rects(Vector2(205.4, 279.6))
		_assert(cross_rects.size() == 2, "slot cross should be built from horizontal and vertical rects")
		if cross_rects.size() == 2:
			var horizontal := cross_rects[0] as Rect2
			var vertical := cross_rects[1] as Rect2
			_assert(horizontal.get_center() == marker_center, "horizontal cross arm should be centered on tower base center")
			_assert(vertical.get_center() == marker_center, "vertical cross arm should be centered on tower base center")
			_assert(horizontal.size.x == vertical.size.y and horizontal.size.y == vertical.size.x, "cross arms should be symmetric")
			_assert(horizontal.size.x <= 14.0 and horizontal.size.y <= 2.0, "slot cross should stay subtle over the hardware base art")
	_assert(game.has_method("_empty_slot_marker_style"), "empty slot rendering should expose its compositing policy")
	if game.has_method("_empty_slot_marker_style"):
		var empty_style := game._empty_slot_marker_style() as Dictionary
		_assert(int(empty_style.get("runtimeRingCount", -1)) == 0, "background tower bases should not receive a second runtime ring")
		_assert(float(empty_style.get("crossAlpha", 1.0)) <= 0.22, "interactive slot cross should stay faint over the background base")
	if game.has_method("_enemy_should_draw_symptom_label"):
		var clustered_first := {"pos": Vector2(120, 220), "diagnosed": false, "reached": false}
		var clustered_second := {"pos": Vector2(142, 228), "diagnosed": false, "reached": false}
		var clustered_diagnosed := {"pos": Vector2(136, 238), "diagnosed": true, "reached": false}
		var distant_enemy := {"pos": Vector2(340, 220), "diagnosed": false, "reached": false}
		var label_context := [clustered_first, clustered_second, clustered_diagnosed, distant_enemy]
		if game.has_method("_enemy_should_draw_fault_tag"):
			_assert(!bool(game._enemy_should_draw_fault_tag(clustered_first)), "wave enemies should no longer draw fault marker tags before diagnosis")
			_assert(!bool(game._enemy_should_draw_fault_tag(clustered_diagnosed)), "wave enemies should no longer draw fault marker tags after diagnosis")
		_assert(!bool(game._enemy_should_draw_symptom_label(clustered_first, label_context)), "wave enemies should no longer draw symptom labels")
		_assert(!bool(game._enemy_should_draw_symptom_label(clustered_second, label_context)), "later undiagnosed enemies in a dense cluster should hide duplicate symptom labels")
		_assert(!bool(game._enemy_should_draw_symptom_label(clustered_diagnosed, label_context)), "diagnosed enemies should not draw type labels on the map")
		_assert(!bool(game._enemy_should_draw_symptom_label(distant_enemy, label_context)), "distant enemies should not draw symptom labels")
		game._open_slot_menu(0)
		_assert(game.slot_menu_panel.get_rect().end.x <= game._hud_panel_rect().position.x - 12.0, "open radial build menu should stay clear of the right HUD display")
		if slot_backdrop != null:
			_assert(slot_backdrop.size == game.slot_menu_panel.size, "slot menu backdrop should cover the full radial build menu")
		_assert(!bool(game._enemy_should_draw_symptom_label(clustered_first, label_context)), "open radial build menu should suppress undiagnosed symptom labels near the tower choices")
		_assert(!bool(game._enemy_should_draw_symptom_label(clustered_diagnosed, label_context)), "open radial build menu should keep diagnosed type labels hidden too")
		game._close_slot_menu()
	if game.has_method("_tower_upgrade_description"):
		var level_two_text := str(game._tower_upgrade_description("filter", 1))
		var level_three_text := str(game._tower_upgrade_description("filter", 2))
		_assert(level_two_text.contains("Lv2") and level_two_text.contains("解锁"), "level 2 upgrade text should use Chinese unlock copy")
		_assert(level_three_text.contains("Lv3") and level_three_text.contains("增强"), "level 3 upgrade text should use Chinese boost copy")
	if game.has_method("_attack_feedback_text"):
		var matched_text := str(game._attack_feedback_text("filter", {"matched": true, "concept": "滤波抑噪"}, {"type": "noise"}))
		var mismatched_text := str(game._attack_feedback_text("i2c", {"matched": false, "concept": "错配"}, {"type": "noise"}))
		_assert(matched_text == "应对！", "matched hit feedback should use a short Chinese floating label")
		_assert(mismatched_text == "错配！", "mismatched hit feedback should use a short Chinese floating label")
	if game.has_method("_hit_feedback_font") and game.has_method("_hit_feedback_font_size"):
		_assert(_font_base_path(game._hit_feedback_font()).ends_with("DingTalkJinBuTi.ttf"), "battle-only hit feedback should retain the bold display art font outside the PS Light text UI")
		_assert(int(game._hit_feedback_font_size()) >= 20, "hit feedback should be large enough to read as a bold effect label")
	if game.has_method("_build_codex_text"):
		var codex_text := str(game._build_codex_text())
		for enemy_name in ["配置错误", "噪声包", "漂移噪声", "假峰值", "功耗尖峰", "混合故障"]:
			_assert(codex_text.contains(enemy_name), "codex should describe %s" % enemy_name)
		for forbidden in ["I2C", "Filter", "Peak", "Power", "counter", "克制", "x1.8", "x0.25", "匹配"]:
			_assert(!codex_text.contains(forbidden), "codex should not reveal counters or damage rules: %s" % forbidden)
	if game.has_method("_tutorial_text"):
		if game.has_method("select_level"):
			game.select_level(1)
		var intro_guide := str(game._tutorial_text())
		_assert(intro_guide.contains("引导") and intro_guide.contains("点击塔位"), "tutorial should guide the first build action")
		game._open_slot_menu(0)
		var menu_guide := str(game._tutorial_text())
		_assert(menu_guide.contains("圆形菜单") and menu_guide.contains("费用"), "tutorial should explain the radial build menu")
		game._close_slot_menu()
		game.tower_slots[0]["tower"] = {"id": "filter", "level": 1, "cooldown": 0.0}
		var ready_guide := str(game._tutorial_text())
		_assert(ready_guide.contains("开始") and ready_guide.contains("观察"), "tutorial should move on after a tower exists")
	if game.has_method("_enemy_visual_marker"):
		_assert(str(game._enemy_visual_marker("config")) == "配", "config enemy should get a compact Chinese marker")
		_assert(str(game._enemy_visual_marker("power_spike")) == "电", "power enemy should get a compact Chinese marker")
	if game.has_method("_tower_level_badge"):
		_assert(str(game._tower_level_badge(1)).contains("基础"), "level 1 tower badge should be readable")
		_assert(str(game._tower_level_badge(2)).contains("特效"), "level 2 tower badge should describe special mode")
		_assert(str(game._tower_level_badge(3)).contains("强化"), "level 3 tower badge should describe boosted mode")
	game.queue_free()
	await process_frame
	var original_style = ProjectSettings.get_setting("band_defense/ui_style", "ps_light")
	ProjectSettings.set_setting("band_defense/ui_style", "watch_debug")
	var legacy_game = scene.instantiate()
	get_root().add_child(legacy_game)
	await process_frame
	_assert(str(legacy_game._ui_style_id()) == "watch_debug", "watch_debug should remain available as the one-setting rollback theme")
	_assert(legacy_game.side_panel.get_theme_stylebox("panel") is StyleBoxTexture, "rollback theme should restore the previous texture-backed right HUD")
	_assert(_font_base_path(legacy_game.start_button.get_theme_font("font")).ends_with("DingTalkJinBuTi.ttf"), "rollback theme should restore the previous display font")
	legacy_game.queue_free()
	ProjectSettings.set_setting("band_defense/ui_style", original_style)
	_finish()


func _colors_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _font_base_path(font: Font) -> String:
	if font is FontVariation:
		var base_font := (font as FontVariation).base_font
		if base_font != null:
			return base_font.resource_path
	return font.resource_path if font != null else ""


func _side_text_controls(root: Node) -> Array[Control]:
	var controls: Array[Control] = []
	for child in root.get_children():
		if child is Label or child is Button:
			controls.append(child as Control)
		controls.append_array(_side_text_controls(child))
	return controls


func _node_has_descendant(root: Node, target: Node) -> bool:
	if root == null or target == null:
		return false
	if root == target:
		return true
	for child in root.get_children():
		if _node_has_descendant(child, target):
			return true
	return false


func _finish() -> void:
	if failures > 0:
		quit(1)
	else:
		print("platform ui theme tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
