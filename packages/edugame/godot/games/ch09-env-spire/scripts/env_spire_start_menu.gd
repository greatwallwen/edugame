extends PanelContainer

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const TechFrame = preload("res://scripts/env_spire_tech_frame.gd")
const UI_FONT_PATH := "res://assets/fonts/DingTalkJinBuTi.ttf"

signal command_selected(command: String)

var tutorial_badge: Label
var progress_label: Label
var resume_button: Button
var body_font: Font
var strong_font: Font
var display_font: Font


func _ready() -> void:
	name = "StartMenuView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_font := load(UI_FONT_PATH) as Font
	body_font = VisualTheme.font_for_role(base_font, "body")
	strong_font = VisualTheme.font_for_role(base_font, "strong")
	display_font = VisualTheme.font_for_role(base_font, "display")
	add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f4f8f9f7"), Color("#91a5af")))
	_build_ui()
	add_child(_tactical_frame("StartMenuTacticalFrame", "start_menu", VisualTheme.color("focus")))


func configure(tutorial_recommended: bool, card_progress: Vector2i, fault_progress: Vector2i, has_resume: bool = false) -> void:
	if tutorial_badge != null:
		tutorial_badge.visible = tutorial_recommended
	if progress_label != null:
		progress_label.text = "图鉴记录  卡牌 %d/%d  ·  故障 %d/%d" % [
			card_progress.x,
			card_progress.y,
			fault_progress.x,
			fault_progress.y
		]
	if resume_button != null:
		resume_button.visible = has_resume


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 34)
	margin.add_child(layout)

	var commands := VBoxContainer.new()
	commands.custom_minimum_size = Vector2(650, 0)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_theme_constant_override("separation", 6)
	layout.add_child(commands)

	var eyebrow := Label.new()
	eyebrow.text = "CHAPTER 09   /   ENVIRONMENT MONITORING"
	VisualTheme.apply_secondary(eyebrow, strong_font, 12)
	eyebrow.add_theme_color_override("font_color", VisualTheme.color("focus"))
	commands.add_child(eyebrow)

	var title := Label.new()
	title.name = "StartMenuTitle"
	title.text = "ENV / SPIRE"
	VisualTheme.apply_heading(title, display_font, 36)
	commands.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "环境监测工程  ·  信号链构筑与故障诊断"
	VisualTheme.apply_secondary(subtitle, body_font, 16)
	commands.add_child(subtitle)

	var command_list := VBoxContainer.new()
	command_list.name = "StartMenuCommands"
	command_list.add_theme_constant_override("separation", 6)
	command_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commands.add_child(command_list)

	var tutorial_row := HBoxContainer.new()
	tutorial_row.add_theme_constant_override("separation", 10)
	tutorial_badge = Label.new()
	tutorial_badge.name = "StartMenuTutorialBadge"
	tutorial_badge.text = "推荐"
	tutorial_badge.custom_minimum_size.x = 54
	tutorial_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_badge.add_theme_font_override("font", strong_font)
	tutorial_badge.add_theme_font_size_override("font_size", 12)
	tutorial_badge.add_theme_color_override("font_color", Color("#ff8a67"))
	tutorial_row.add_child(tutorial_badge)
	var tutorial_button := _command_button("StartMenuTutorial", "教程", "按目标完成一次信号链训练", "tutorial", VisualTheme.category_color("collect"))
	tutorial_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_row.add_child(tutorial_button)
	command_list.add_child(tutorial_row)

	command_list.add_child(_command_button("StartMenuRun", "新游戏", "挑战十二节点环境监测塔", "run", VisualTheme.color("focus")))
	command_list.add_child(_command_button("StartMenuNodeLab", "开发者测试", "指定节点、牌组与战斗状态", "node_lab", VisualTheme.category_color("process")))
	command_list.add_child(_command_button("StartMenuCodex", "图鉴", "查阅已记录的卡牌与故障", "codex", VisualTheme.category_color("defense")))
	resume_button = _command_button("StartMenuResume", "继续游戏", "恢复上次正式运行", "resume", VisualTheme.category_color("interface"))
	command_list.add_child(resume_button)
	command_list.add_child(_command_button("StartMenuSettings", "设置", "音效、动画与闪光", "settings", Color("#78879a")))

	progress_label = Label.new()
	progress_label.name = "StartMenuCodexProgress"
	progress_label.text = "图鉴记录  卡牌 0/0  ·  故障 0/0"
	VisualTheme.apply_secondary(progress_label, body_font, 13)
	commands.add_child(progress_label)

	var visual_panel := PanelContainer.new()
	visual_panel.custom_minimum_size = Vector2(430, 0)
	visual_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#e7eff3f2"), Color("#7895a4")))
	layout.add_child(visual_panel)
	var visual_margin := MarginContainer.new()
	visual_margin.add_theme_constant_override("margin_left", 22)
	visual_margin.add_theme_constant_override("margin_right", 22)
	visual_margin.add_theme_constant_override("margin_top", 20)
	visual_margin.add_theme_constant_override("margin_bottom", 20)
	visual_panel.add_child(visual_margin)
	var visual := VBoxContainer.new()
	visual.alignment = BoxContainer.ALIGNMENT_CENTER
	visual.add_theme_constant_override("separation", 14)
	visual_margin.add_child(visual)

	var visual_title := Label.new()
	visual_title.text = "ENGINEERING LOADOUT"
	visual_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VisualTheme.apply_secondary(visual_title, strong_font, 13)
	visual.add_child(visual_title)

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 8)
	art_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual.add_child(art_row)
	for card_id in ["mq2_sample", "adc_convert", "led_alarm"]:
		art_row.add_child(_art_panel(card_id))

	var flow := Label.new()
	flow.text = "采集  →  转换  →  输出\n用严谨的工程证据完成故障修复"
	flow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VisualTheme.apply_secondary(flow, body_font, 14)
	flow.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	visual.add_child(flow)
	visual_panel.add_child(_tactical_frame("LoadoutTacticalFrame", "loadout", VisualTheme.category_color("interface")))


func _command_button(node_name: String, title: String, detail: String, command: String, accent: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = "%s    %s" % [title, detail]
	button.tooltip_text = detail
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 15)
	VisualTheme.apply_tactical_button(button, accent, strong_font)
	button.pressed.connect(func() -> void: command_selected.emit(command))
	return button


func _art_panel(card_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118, 286)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#dce7eb"), Color("#78909b")))
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.texture = load("res://assets/card-art/prototypes/%s-v4.png" % card_id) as Texture2D
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(texture_rect)
	return panel


func _tactical_frame(node_name: String, frame_id: String, accent: Color) -> Control:
	var frame := TechFrame.new() as Control
	frame.name = node_name
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.configure(frame_id, accent, "tactical")
	return frame
