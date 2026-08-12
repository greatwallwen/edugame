extends RefCounted

const COLORS := {
	"canvas": Color("#e7eef2"),
	"canvas_blue": Color("#d9e5eb"),
	"surface": Color("#f6f9fa"),
	"surface_raised": Color("#ffffff"),
	"surface_hover": Color("#e4edf1"),
	"surface_muted": Color("#d9e3e8"),
	"line": Color("#7d929d"),
	"line_soft": Color("#b7c7ce"),
	"focus": Color("#137f9a"),
	"focus_soft": Color("#5c97a6"),
	"text_primary": Color("#17232d"),
	"text_secondary": Color("#465b69"),
	"text_muted": Color("#74848e"),
	"button_surface": Color("#111c28"),
	"button_hover": Color("#203244"),
	"button_pressed": Color("#09131d"),
	"button_disabled": Color("#65717b"),
	"button_text": Color("#f4f8fb"),
	"button_text_muted": Color("#c3ccd3"),
	"success": Color("#167451"),
	"warning": Color("#9a5a00"),
	"danger": Color("#bd3444")
}

const CATEGORY_COLORS := {
	"collect": Color("#c85c52"),
	"interface": Color("#25b7c8"),
	"process": Color("#8b69da"),
	"defense": Color("#58b278"),
	"output": Color("#e59a2c"),
	"power": Color("#d3b548"),
	"negative": Color("#d94b5f")
}

const FONT_ROLE_WEIGHTS := {
	"body": 620,
	"strong": 750,
	"display": 840
}


static func color(token: String) -> Color:
	return COLORS.get(token, Color.MAGENTA) as Color


static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, COLORS.focus) as Color


static func font_for_role(base_font: Font, role: String) -> Font:
	return font_with_weight(base_font, int(FONT_ROLE_WEIGHTS.get(role, FONT_ROLE_WEIGHTS.body)))


static func font_with_weight(base_font: Font, weight: int) -> Font:
	if base_font == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_opentype = {"wght": clampi(weight, 100, 900)}
	var is_dingtalk := base_font.resource_path.ends_with("DingTalkJinBuTi.ttf")
	if is_dingtalk:
		variation.variation_embolden = 0.16 if weight >= 800 else (0.12 if weight >= 720 else 0.06)
	elif weight >= 800:
		variation.variation_embolden = 1.10
	elif weight >= 720:
		variation.variation_embolden = 0.80
	elif weight >= 600:
		variation.variation_embolden = 0.45
	elif weight >= 500:
		variation.variation_embolden = 0.24
	return variation


static func panel_style(
	background: Color,
	border: Color = Color.TRANSPARENT,
	border_width: int = 1,
	corner_radius: int = 6,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 4)
	return style


static func inset_panel(accent: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var border := color("line_soft") if accent == Color.TRANSPARENT else Color(accent.r, accent.g, accent.b, 0.52)
	var style := panel_style(Color("#eef4f6f2"), border, 1, 5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func hardware_panel_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := panel_style(background, accent, 1, 2, 6)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 11
	style.shadow_color = Color(0.08, 0.14, 0.18, 0.20)
	style.shadow_offset = Vector2(3, 4)
	return style


static func tactical_panel_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := panel_style(background, Color(accent.r, accent.g, accent.b, 0.44), 0, 0, 3)
	style.border_width_left = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.08)
	style.shadow_offset = Vector2(0, 3)
	return style


static func button_styles(accent: Color) -> Dictionary:
	var normal := panel_style(color("button_surface"), Color(accent.r, accent.g, accent.b, 0.48), 1, 2, 2)
	var hover := panel_style(color("button_hover"), accent, 1, 2, 5)
	var pressed := panel_style(color("button_pressed"), accent.darkened(0.08), 1, 2, 0)
	var focus := panel_style(color("button_hover"), accent, 1, 2, 6)
	focus.border_width_left = 4
	var disabled := panel_style(color("button_disabled"), Color("#8a969f"), 1, 2, 0)
	for style in [normal, hover, pressed, focus, disabled]:
		style.border_width_left = maxi(style.border_width_left, 2)
		style.border_width_top = 2
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"focus": focus,
		"disabled": disabled
	}


static func command_button_styles(accent: Color) -> Dictionary:
	var normal := panel_style(color("button_surface").lerp(accent, 0.04), Color(accent.r, accent.g, accent.b, 0.44), 1, 2, 2)
	var hover := panel_style(color("button_hover").lerp(accent, 0.07), accent, 1, 2, 7)
	var pressed := panel_style(color("button_pressed").lerp(accent, 0.05), accent.darkened(0.05), 1, 2, 1)
	var focus := panel_style(color("button_hover").lerp(accent, 0.08), accent, 1, 2, 7)
	var disabled := panel_style(color("button_disabled"), Color("#8a969f"), 1, 2, 0)
	for style in [normal, hover, pressed, focus, disabled]:
		style.border_width_left = 4
		style.border_width_right = 1
		style.border_width_top = 2
		style.border_width_bottom = 1
		style.content_margin_left = 18
		style.content_margin_right = 15
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.24)
	focus.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	pressed.border_width_left = 6
	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"focus": focus,
		"disabled": disabled
	}


static func tactical_button_styles(accent: Color) -> Dictionary:
	var normal := tactical_panel_style(color("button_surface").lerp(accent, 0.035), accent)
	var hover := tactical_panel_style(color("button_hover").lerp(accent, 0.07), accent)
	var pressed := tactical_panel_style(color("button_pressed").lerp(accent, 0.06), accent.darkened(0.06))
	var focus := tactical_panel_style(color("button_hover").lerp(accent, 0.08), accent)
	var disabled := tactical_panel_style(color("button_disabled"), Color("#8a969f"))
	for style in [normal, hover, pressed, focus, disabled]:
		style.border_width_left = 3
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 1
		style.content_margin_left = 18
		style.content_margin_right = 15
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	hover.border_width_left = 4
	hover.shadow_size = 6
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
	pressed.border_width_left = 5
	focus.border_width_left = 6
	focus.shadow_size = 7
	focus.shadow_color = Color(accent.r, accent.g, accent.b, 0.26)
	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"focus": focus,
		"disabled": disabled
	}


static func apply_button(button: Button, accent: Color, strong_font: Font = null) -> void:
	var styles := button_styles(accent)
	for state_name in styles:
		button.add_theme_stylebox_override(str(state_name), styles[state_name] as StyleBox)
	button.add_theme_color_override("font_color", color("button_text"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", color("button_text"))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", color("button_text_muted"))
	button.add_theme_color_override("icon_normal_color", color("button_text_muted"))
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	if strong_font != null:
		button.add_theme_font_override("font", strong_font)


static func apply_tactical_button(button: Button, accent: Color, strong_font: Font = null) -> void:
	var styles := tactical_button_styles(accent)
	for state_name in styles:
		button.add_theme_stylebox_override(str(state_name), styles[state_name] as StyleBox)
	button.add_theme_color_override("font_color", color("button_text"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", color("button_text_muted"))
	if strong_font != null:
		button.add_theme_font_override("font", strong_font)


static func apply_command_button(button: Button, accent: Color, strong_font: Font = null) -> void:
	var styles := command_button_styles(accent)
	for state_name in styles:
		button.add_theme_stylebox_override(str(state_name), styles[state_name] as StyleBox)
	button.add_theme_color_override("font_color", color("button_text"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", color("button_text_muted"))
	if strong_font != null:
		button.add_theme_font_override("font", strong_font)


static func apply_heading(label: Label, strong_font: Font, size: int, accent: Color = Color.TRANSPARENT) -> void:
	if strong_font != null:
		label.add_theme_font_override("font", strong_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color("text_primary") if accent == Color.TRANSPARENT else accent)


static func apply_secondary(label: Label, body_font: Font, size: int = 14) -> void:
	if body_font != null:
		label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color("text_secondary"))
