extends PanelContainer

signal close_requested

const CardView = preload("res://scripts/env_spire_card_view.gd")
const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const TechFrame = preload("res://scripts/env_spire_tech_frame.gd")
const UI_FONT_PATH := "res://assets/fonts/DingTalkJinBuTi.ttf"
const CARD_DETAIL_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"

const CARD_TYPE_NAMES := {
	"collect": "采集",
	"interface": "接口",
	"process": "处理",
	"defense": "防护",
	"output": "输出",
	"power": "能力"
}
const FAULT_TIER_NAMES := {
	"ordinary": "普通故障",
	"elite": "精英故障",
	"boss": "综合验收"
}
const CATEGORY_COLORS := {
	"采集": Color("#b95748"),
	"接口": Color("#287f8a"),
	"处理": Color("#6d5598"),
	"防护": Color("#487b58"),
	"输出": Color("#a96c22"),
	"能力": Color("#8a732c"),
	"普通故障": Color("#65777a"),
	"精英故障": Color("#9a6336"),
	"综合验收": Color("#9d3f45")
}

var card_definitions: Dictionary = {}
var fault_definitions: Dictionary = {}
var progress: Dictionary = {"cards": [], "faults": []}
var active_tab := "cards"
var selected_index := 0
var entry_models: Array = []

var cards_tab: Button
var faults_tab: Button
var progress_label: Label
var entry_list: VBoxContainer
var detail_title: Label
var detail_meta: Label
var detail_body: Label
var detail_visual: Control
var body_font: Font
var strong_font: Font
var card_detail_font: Font


static func build_entry_models(definitions: Dictionary, unlocked_ids: Array, kind: String) -> Array:
	var ids: Array = definitions.keys()
	ids.sort()
	var result: Array = []
	for index in range(ids.size()):
		var content_id := str(ids[index])
		var definition := definitions.get(content_id, {}) as Dictionary
		var category := _category_name(definition, kind)
		if unlocked_ids.has(content_id):
			result.append({
				"slot": index + 1,
				"unlocked": true,
				"id": content_id,
				"title": str(definition.get("name", content_id)),
				"category": category,
				"data": definition.duplicate(true)
			})
		else:
			result.append({
				"slot": index + 1,
				"unlocked": false,
				"title": "尚未记录",
				"category": category
			})
	return result


static func _category_name(definition: Dictionary, kind: String) -> String:
	if kind == "cards":
		return str(CARD_TYPE_NAMES.get(str(definition.get("type", "")), "工程卡牌"))
	return str(FAULT_TIER_NAMES.get(str(definition.get("tier", "")), "故障档案"))


func _ready() -> void:
	name = "CodexView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_font := load(UI_FONT_PATH) as Font
	body_font = VisualTheme.font_for_role(base_font, "body")
	strong_font = VisualTheme.font_for_role(base_font, "strong")
	card_detail_font = VisualTheme.font_for_role(load(CARD_DETAIL_FONT_PATH) as Font, "body")
	add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f4f8f9f7"), Color("#91a5af")))
	_build_ui()
	var frame := TechFrame.new() as Control
	frame.name = "CodexTacticalFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.configure("codex", VisualTheme.color("focus"), "tactical")
	add_child(frame)
	_refresh()


func configure(cards: Dictionary, faults: Dictionary, discovery_progress: Dictionary) -> void:
	card_definitions = cards.duplicate(true)
	fault_definitions = faults.duplicate(true)
	progress = discovery_progress.duplicate(true)
	selected_index = 0
	_refresh()


func select_tab(tab: String) -> bool:
	if tab not in ["cards", "faults"]:
		return false
	active_tab = tab
	selected_index = 0
	_refresh()
	return true


func select_entry(index: int) -> bool:
	if index < 0 or index >= entry_models.size():
		return false
	selected_index = index
	_render_entry_selection()
	_render_detail()
	return true


func select_entry_by_id(content_id: String) -> bool:
	for index in range(entry_models.size()):
		if str((entry_models[index] as Dictionary).get("id", "")) == content_id:
			return select_entry(index)
	return false


func _build_ui() -> void:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 30)
	outer.add_theme_constant_override("margin_right", 30)
	outer.add_theme_constant_override("margin_top", 22)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	outer.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)
	var back := Button.new()
	back.name = "CodexBack"
	back.text = "‹  返回菜单"
	back.custom_minimum_size = Vector2(136, 42)
	back.add_theme_font_size_override("font_size", 15)
	VisualTheme.apply_tactical_button(back, Color("#65778c"), strong_font)
	back.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back)

	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	var eyebrow := Label.new()
	eyebrow.text = "ENGINEERING ARCHIVE  /  CHAPTER 09"
	VisualTheme.apply_secondary(eyebrow, strong_font, 11)
	eyebrow.add_theme_color_override("font_color", VisualTheme.color("focus"))
	heading.add_child(eyebrow)
	var title := Label.new()
	title.text = "工程图鉴"
	VisualTheme.apply_heading(title, strong_font, 26)
	heading.add_child(title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	progress_label = Label.new()
	progress_label.name = "CodexProgress"
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	VisualTheme.apply_secondary(progress_label, strong_font, 14)
	header.add_child(progress_label)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	page.add_child(tab_row)
	cards_tab = _tab_button("CodexTabCards", "卡牌档案", "cards")
	faults_tab = _tab_button("CodexTabFaults", "故障档案", "faults")
	tab_row.add_child(cards_tab)
	tab_row.add_child(faults_tab)
	var tab_rule := HSeparator.new()
	tab_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tab_rule)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	page.add_child(content)

	var index_panel := PanelContainer.new()
	index_panel.custom_minimum_size = Vector2(430, 0)
	index_panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#e9f0f3f2"), Color("#7895a4")))
	content.add_child(index_panel)
	var index_margin := MarginContainer.new()
	index_margin.add_theme_constant_override("margin_left", 12)
	index_margin.add_theme_constant_override("margin_right", 8)
	index_margin.add_theme_constant_override("margin_top", 12)
	index_margin.add_theme_constant_override("margin_bottom", 12)
	index_panel.add_child(index_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_margin.add_child(scroll)
	entry_list = VBoxContainer.new()
	entry_list.name = "CodexEntryList"
	entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_list.add_theme_constant_override("separation", 6)
	scroll.add_child(entry_list)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f9fbfbf7"), Color("#7895a4")))
	content.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 24)
	detail_margin.add_theme_constant_override("margin_right", 24)
	detail_margin.add_theme_constant_override("margin_top", 20)
	detail_margin.add_theme_constant_override("margin_bottom", 20)
	detail_panel.add_child(detail_margin)
	var detail_layout := HBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 26)
	detail_margin.add_child(detail_layout)
	detail_visual = Control.new()
	detail_visual.name = "CodexDetailVisual"
	detail_visual.custom_minimum_size = Vector2(240, 330)
	detail_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_layout.add_child(detail_visual)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	detail_layout.add_child(copy)
	detail_meta = Label.new()
	detail_meta.name = "CodexDetailMeta"
	VisualTheme.apply_secondary(detail_meta, strong_font, 13)
	detail_meta.add_theme_color_override("font_color", VisualTheme.color("focus"))
	copy.add_child(detail_meta)
	detail_title = Label.new()
	detail_title.name = "CodexDetailTitle"
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	VisualTheme.apply_heading(detail_title, strong_font, 24)
	copy.add_child(detail_title)
	var detail_rule := HSeparator.new()
	copy.add_child(detail_rule)
	detail_body = Label.new()
	detail_body.name = "CodexDetailBody"
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	VisualTheme.apply_secondary(detail_body, body_font, 15)
	copy.add_child(detail_body)


func _tab_button(node_name: String, label: String, tab: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(160, 42)
	button.add_theme_font_size_override("font_size", 15)
	VisualTheme.apply_tactical_button(button, VisualTheme.color("focus"), strong_font)
	button.pressed.connect(func() -> void: select_tab(tab))
	return button


func _refresh() -> void:
	if entry_list == null:
		return
	var definitions := card_definitions if active_tab == "cards" else fault_definitions
	var unlocked := progress.get(active_tab, []) as Array
	entry_models = build_entry_models(definitions, unlocked, active_tab)
	selected_index = clampi(selected_index, 0, maxi(entry_models.size() - 1, 0))
	cards_tab.disabled = active_tab == "cards"
	faults_tab.disabled = active_tab == "faults"
	progress_label.text = "%s发现进度  %d / %d" % [
		"卡牌" if active_tab == "cards" else "故障",
		unlocked.size(),
		entry_models.size()
	]
	for child in entry_list.get_children():
		entry_list.remove_child(child)
		child.queue_free()
	for index in range(entry_models.size()):
		entry_list.add_child(_entry_button(entry_models[index] as Dictionary, index))
	_render_entry_selection()
	_render_detail()


func _entry_button(model: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "CodexEntry%d" % index
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_font_override("font", strong_font)
	button.add_theme_color_override("font_color", VisualTheme.color("button_text"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var slot := int(model.get("slot", index + 1))
	var category := str(model.get("category", "档案"))
	if bool(model.get("unlocked", false)):
		button.text = "%02d   %s\n       %s" % [slot, model.get("title", "已记录"), category]
	else:
		button.text = "%02d   ◆ 尚未记录\n       %s" % [slot, category]
	button.tooltip_text = "打开档案" if bool(model.get("unlocked", false)) else "在游戏中完成对应工程动作后记录"
	button.pressed.connect(func() -> void: select_entry(index))
	return button


func _render_entry_selection() -> void:
	if entry_list == null:
		return
	for index in range(entry_list.get_child_count()):
		var button := entry_list.get_child(index) as Button
		var model := entry_models[index] as Dictionary
		var accent: Color = CATEGORY_COLORS.get(str(model.get("category", "")), Color("#65777a"))
		var selected := index == selected_index
		var normal_surface := VisualTheme.color("button_hover") if selected else VisualTheme.color("button_surface")
		button.add_theme_stylebox_override("normal", _button_style(normal_surface, accent, 2 if selected else 1))
		button.add_theme_stylebox_override("hover", _button_style(VisualTheme.color("button_hover"), accent, 2))
		button.add_theme_stylebox_override("focus", _button_style(VisualTheme.color("button_hover"), accent, 3))


func _render_detail() -> void:
	detail_body.add_theme_font_override("font", card_detail_font if active_tab == "cards" else body_font)
	for child in detail_visual.get_children():
		child.queue_free()
	if entry_models.is_empty():
		detail_meta.text = "NO RECORDS"
		detail_title.text = "暂无档案"
		detail_body.text = ""
		return
	var model := entry_models[selected_index] as Dictionary
	var category := str(model.get("category", "档案"))
	detail_meta.text = "%02d  /  %s" % [int(model.get("slot", selected_index + 1)), category]
	if !bool(model.get("unlocked", false)):
		detail_title.text = "尚未记录"
		detail_body.text = "该条目尚未形成可靠工程记录。\n\n在正式流程、教程或开发者测试中完成对应操作后，档案才会写入。"
		detail_visual.add_child(_locked_visual(category))
		return
	var definition := model.get("data", {}) as Dictionary
	detail_title.text = str(model.get("title", "已记录"))
	if active_tab == "cards":
		var card_view := CardView.new()
		card_view.name = "CodexCardPreview"
		card_view.configure_card(definition, "choice")
		card_view.disabled = true
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_visual.add_child(card_view)
		detail_body.text = _card_detail_text(definition)
	else:
		detail_visual.add_child(_fault_visual(definition, category))
		detail_body.text = _fault_detail_text(definition)


func _locked_visual(category: String) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#26393b"), CATEGORY_COLORS.get(category, Color("#65777a")), 2))
	var lock := Label.new()
	lock.text = "◆\n\nLOCKED"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_theme_font_size_override("font_size", 20)
	lock.add_theme_color_override("font_color", Color("#b9c8c4"))
	panel.add_child(lock)
	return panel


func _fault_visual(definition: Dictionary, category: String) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var accent: Color = CATEGORY_COLORS.get(category, Color("#9d3f45"))
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#243638"), accent, 3))
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	var code := Label.new()
	code.text = "FAULT / %02d" % int(definition.get("region", 0))
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.add_theme_font_size_override("font_size", 14)
	code.add_theme_color_override("font_color", Color("#9fbab6"))
	layout.add_child(code)
	var glyph := Label.new()
	glyph.text = "!"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 76)
	glyph.add_theme_color_override("font_color", accent)
	layout.add_child(glyph)
	var status := Label.new()
	status.text = "DIAGNOSIS RECORDED"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("#dce8e5"))
	layout.add_child(status)
	return panel


func _card_detail_text(card: Dictionary) -> String:
	return "卡牌效果\n%s\n\n工程知识\n%s" % [
		str(card.get("effectText", "")),
		str(card.get("knowledgePoint", ""))
	]


func _fault_detail_text(fault: Dictionary) -> String:
	var sections: Array[String] = []
	sections.append("工程知识\n%s" % str(fault.get("knowledgePoint", "")))
	var weaknesses := fault.get("weaknessTags", []) as Array
	if !weaknesses.is_empty():
		sections.append("有效证据\n%s" % "  ·  ".join(weaknesses))
	var rule := fault.get("faultRule", {}) as Dictionary
	if !rule.is_empty():
		sections.append("故障行为\n%s" % str(rule.get("description", "")))
		sections.append("反制方法\n%s" % str(rule.get("counterText", "")))
	var phases := fault.get("phases", []) as Array
	if !phases.is_empty():
		var phase_lines: Array[String] = []
		for index in range(phases.size()):
			var phase := phases[index] as Dictionary
			phase_lines.append("%d. %s  %s" % [index + 1, phase.get("name", "验收阶段"), phase.get("requirementText", "")])
		sections.append("验收阶段\n%s" % "\n".join(phase_lines))
	return "\n\n".join(sections)


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var resolved := background
	if resolved.get_luminance() > 0.34:
		resolved = VisualTheme.color("surface")
	var style := VisualTheme.tactical_panel_style(resolved, border)
	style.border_width_left = maxi(width, 1)
	return style


func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := _panel_style(background, border, width)
	style.border_width_left = width + 2
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
