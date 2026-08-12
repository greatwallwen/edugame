extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual_theme = load("res://scripts/env_spire_visual_theme.gd")
	_assert(visual_theme != null, "visual theme module should load independently")
	if visual_theme == null:
		_finish()
		return

	var base_font := load("res://assets/fonts/DingTalkJinBuTi.ttf") as Font
	var readable_font := load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	_assert(base_font != null, "visual theme should bundle the Ch11 DingTalk display font")
	_assert(readable_font != null, "visual theme should retain Noto Sans SC for dense card details")
	if base_font == null or readable_font == null:
		_finish()
		return
	var body_font := visual_theme.font_for_role(base_font, "body") as FontVariation
	var strong_font := visual_theme.font_for_role(base_font, "strong") as FontVariation
	var display_font := visual_theme.font_for_role(base_font, "display") as FontVariation
	_assert(body_font != null and strong_font != null and display_font != null, "visual theme should create the complete unified type family")
	if body_font != null and strong_font != null and display_font != null:
		_assert(body_font.base_font == base_font and strong_font.base_font == base_font and display_font.base_font == base_font, "all global UI roles should share the DingTalk art family")
		_assert(int(body_font.variation_opentype.get("wght", 0)) >= 600, "body copy should use a visibly heavier engineering weight")
		_assert(int(strong_font.variation_opentype.get("wght", 0)) >= 720, "controls should use a bold engineering weight")
		_assert(int(display_font.variation_opentype.get("wght", 0)) >= 800, "display headings should use the heaviest artistic weight")
		_assert(body_font.variation_embolden >= 0.05 and body_font.variation_embolden <= 0.08, "DingTalk body copy should match the restrained Ch11 embolden range")
		_assert(strong_font.variation_embolden >= 0.10 and strong_font.variation_embolden <= 0.14, "DingTalk controls should match the Ch11 strong-display treatment")
		_assert(display_font.variation_embolden >= 0.15 and display_font.variation_embolden <= 0.18, "DingTalk headings should keep the Ch11 artistic silhouette without clogged strokes")
		_assert(display_font.variation_embolden > strong_font.variation_embolden, "display headings should remain distinct without switching typefaces")

	var canvas := visual_theme.color("canvas") as Color
	var surface := visual_theme.color("surface") as Color
	var text_primary := visual_theme.color("text_primary") as Color
	_assert(canvas.get_luminance() > 0.72, "layout canvas should use a light engineering-workbench surface")
	_assert(surface.get_luminance() > 0.82, "layout panels should remain visibly light")
	_assert(text_primary.get_luminance() < 0.22, "primary text should remain dark on light layout surfaces")
	_assert(visual_theme.color("button_surface").get_luminance() < 0.16, "buttons should use a dark command surface")
	_assert(visual_theme.color("button_text").get_luminance() > 0.82, "dark buttons should use high-contrast light text")

	var panel := visual_theme.panel_style(surface, visual_theme.color("line"), 1, 6) as StyleBoxFlat
	_assert(panel != null and panel.bg_color == surface, "panel style should retain the requested surface")
	_assert(panel.corner_radius_top_left <= 8, "console panels should keep compact corner radii")

	var button_styles := visual_theme.button_styles(visual_theme.color("focus")) as Dictionary
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		_assert(button_styles.get(state_name) is StyleBoxFlat, "button style should define %s state" % state_name)
	var normal := button_styles.get("normal") as StyleBoxFlat
	var hover := button_styles.get("hover") as StyleBoxFlat
	_assert(normal.bg_color.get_luminance() < 0.16 and hover.bg_color.get_luminance() < 0.22, "button interaction states should remain dark against the light layout")
	_assert(hover.bg_color.get_luminance() > normal.bg_color.get_luminance(), "hover state should visibly lift from the dark command surface")
	_assert((button_styles.get("focus") as StyleBoxFlat).border_width_left >= 3, "focus state should expose a strong navigation edge")

	var command_styles := visual_theme.command_button_styles(visual_theme.color("focus")) as Dictionary
	var command_normal := command_styles.get("normal") as StyleBoxFlat
	var command_hover := command_styles.get("hover") as StyleBoxFlat
	_assert(command_normal != null and command_hover != null, "visual theme should expose dedicated command button states")
	if command_normal != null and command_hover != null:
		_assert(command_normal.border_width_left >= 3, "command buttons should expose a sci-fi accent rail")
		_assert(command_normal.border_width_right <= 1 and command_normal.corner_radius_top_left <= 3, "command buttons should avoid heavy stacked box borders")
		_assert(command_hover.shadow_size >= 5 and command_hover.shadow_color.a > 0.15, "command hover should expose a restrained accent glow")

	_assert(visual_theme.has_method("hardware_panel_style"), "visual theme should expose an in-run hardware frame style")
	if visual_theme.has_method("hardware_panel_style"):
		var hardware := visual_theme.hardware_panel_style(surface, visual_theme.color("focus")) as StyleBoxFlat
		_assert(hardware.border_width_top >= 2 and hardware.border_width_left >= 2, "hardware frames should carry a reinforced top-left bezel")
		_assert(hardware.border_width_right <= 1 and hardware.border_width_bottom <= 1, "hardware frames should keep the shadow edges restrained")
		_assert(hardware.corner_radius_top_left <= 2 and hardware.shadow_size >= 4, "hardware frames should feel machined instead of rounded and flat")

	_assert(visual_theme.has_method("tactical_panel_style"), "visual theme should expose an out-of-run tactical HUD style")
	if visual_theme.has_method("tactical_panel_style"):
		var tactical := visual_theme.tactical_panel_style(surface, visual_theme.color("focus")) as StyleBoxFlat
		var tactical_edges := int(tactical.border_width_left > 0) + int(tactical.border_width_right > 0) + int(tactical.border_width_top > 0) + int(tactical.border_width_bottom > 0)
		_assert(tactical_edges <= 2 and tactical.corner_radius_top_left == 0, "tactical panels should avoid another complete rounded rectangle")

	_assert(visual_theme.has_method("tactical_button_styles"), "visual theme should expose broken-edge tactical controls")
	if visual_theme.has_method("tactical_button_styles"):
		var tactical_buttons := visual_theme.tactical_button_styles(visual_theme.color("focus")) as Dictionary
		var tactical_normal := tactical_buttons.get("normal") as StyleBoxFlat
		var tactical_focus := tactical_buttons.get("focus") as StyleBoxFlat
		_assert(tactical_normal.border_width_left >= 3 and tactical_normal.border_width_top == 0 and tactical_normal.border_width_right == 0, "idle tactical controls should use an open rail instead of a full outline")
		_assert(tactical_focus.border_width_left > tactical_normal.border_width_left and tactical_focus.shadow_size >= 5, "focused tactical controls should energize without changing layout")

	_assert(visual_theme.category_color("negative") == Color("#d94b5f"), "fault cards should keep the dedicated red accent")
	_assert(visual_theme.category_color("interface") != visual_theme.category_color("output"), "card categories should remain visually distinct")
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 visual theme tests passed")
	quit(1 if failures > 0 else 0)
