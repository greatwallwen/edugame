extends PanelContainer

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const TechFrame = preload("res://scripts/env_spire_tech_frame.gd")
const UI_FONT_PATH := "res://assets/fonts/DingTalkJinBuTi.ttf"

signal settings_changed(settings: Dictionary)
signal close_requested

var sfx_toggle: CheckButton
var volume_slider: HSlider
var speed_selector: OptionButton
var flash_toggle: CheckButton
var body_font: Font
var strong_font: Font


func _ready() -> void:
	name = "SettingsView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_font := load(UI_FONT_PATH) as Font
	body_font = VisualTheme.font_for_role(base_font, "body")
	strong_font = VisualTheme.font_for_role(base_font, "strong")
	add_theme_stylebox_override("panel", VisualTheme.panel_style(Color("#e7eef2f2"), Color.TRANSPARENT, 0, 0))
	_build_ui()


func configure(settings: Dictionary) -> void:
	if sfx_toggle == null:
		return
	sfx_toggle.set_pressed_no_signal(bool(settings.get("sfxEnabled", true)))
	volume_slider.set_value_no_signal(float(settings.get("sfxVolume", 0.4)) * 100.0)
	speed_selector.select(1 if is_equal_approx(float(settings.get("animationSpeed", 1.0)), 1.5) else 0)
	flash_toggle.set_pressed_no_signal(bool(settings.get("reducedFlash", false)))


func _build_ui() -> void:
	var center := CenterContainer.new()
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.custom_minimum_size = Vector2(600, 450)
	panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f8fafbf9"), Color("#7895a4")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "SYSTEM / PRESENTATION"
	VisualTheme.apply_secondary(eyebrow, strong_font, 12)
	eyebrow.add_theme_color_override("font_color", VisualTheme.color("focus"))
	column.add_child(eyebrow)
	var title := Label.new()
	title.name = "SettingsTitle"
	title.text = "设置"
	VisualTheme.apply_heading(title, strong_font, 30)
	column.add_child(title)
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 12)
	column.add_child(divider)

	sfx_toggle = _toggle("SettingsSfxToggle", "音效", "播放卡牌、故障与结算反馈")
	column.add_child(sfx_toggle)
	var volume_row := _setting_row("音效音量", "控制所有游戏内反馈音量")
	volume_slider = HSlider.new()
	volume_slider.name = "SettingsSfxVolume"
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.custom_minimum_size = Vector2(260, 34)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin_slider(volume_slider)
	volume_row.add_child(volume_slider)
	column.add_child(volume_row)

	var speed_row := _setting_row("动画速度", "结算始终等待动作动画播放完成")
	speed_selector = OptionButton.new()
	speed_selector.name = "SettingsAnimationSpeed"
	speed_selector.custom_minimum_size = Vector2(150, 42)
	speed_selector.add_item("1.0x")
	speed_selector.add_item("1.5x")
	VisualTheme.apply_tactical_button(speed_selector, VisualTheme.category_color("interface"), strong_font)
	speed_row.add_child(speed_selector)
	column.add_child(speed_row)

	flash_toggle = _toggle("SettingsReducedFlash", "减弱闪光", "降低受击和故障触发时的全屏亮度变化")
	column.add_child(flash_toggle)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var close_button := Button.new()
	close_button.name = "SettingsClose"
	close_button.text = "完成"
	close_button.custom_minimum_size = Vector2(160, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	VisualTheme.apply_tactical_button(close_button, VisualTheme.color("focus"), strong_font)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	column.add_child(close_button)

	for control in [sfx_toggle, volume_slider, speed_selector, flash_toggle]:
		if control is OptionButton:
			(control as OptionButton).item_selected.connect(func(_index: int) -> void: _emit_settings())
		elif control is BaseButton:
			(control as BaseButton).toggled.connect(func(_value: bool) -> void: _emit_settings())
		elif control is Range:
			(control as Range).value_changed.connect(func(_value: float) -> void: _emit_settings())

	var frame := TechFrame.new() as Control
	frame.name = "SettingsTacticalFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.configure("settings", VisualTheme.color("focus"), "tactical")
	panel.add_child(frame)


func _toggle(node_name: String, title: String, detail: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = "%s    %s" % [title, detail]
	toggle.custom_minimum_size = Vector2(0, 44)
	toggle.add_theme_font_override("font", strong_font)
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.add_theme_color_override("font_pressed_color", VisualTheme.color("text_primary"))
	return toggle


func _setting_row(title: String, detail: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 50
	row.add_theme_constant_override("separation", 18)
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 270
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_label := Label.new()
	title_label.text = title
	VisualTheme.apply_heading(title_label, strong_font, 15)
	copy.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	VisualTheme.apply_secondary(detail_label, body_font, 12)
	copy.add_child(detail_label)
	row.add_child(copy)
	return row


func _skin_slider(slider: HSlider) -> void:
	var track := VisualTheme.panel_style(Color("#253142"), Color.TRANSPARENT, 0, 3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := VisualTheme.panel_style(VisualTheme.color("focus_soft"), Color.TRANSPARENT, 0, 3)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", VisualTheme.panel_style(VisualTheme.color("focus"), Color.TRANSPARENT, 0, 3))


func _emit_settings() -> void:
	settings_changed.emit({
		"sfxEnabled": sfx_toggle.button_pressed,
		"sfxVolume": volume_slider.value / 100.0,
		"animationSpeed": 1.5 if speed_selector.selected == 1 else 1.0,
		"reducedFlash": flash_toggle.button_pressed
	})
