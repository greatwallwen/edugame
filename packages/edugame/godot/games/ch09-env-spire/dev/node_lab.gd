extends CanvasLayer

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const TechFrame = preload("res://scripts/env_spire_tech_frame.gd")
const TOOLBAR_SINGLE_HEIGHT := 60.0
const DEBUG_PANEL_DESKTOP_SIZE := Vector2(780, 620)

var game: Control
var entries: Array = []
var current_entry := {}
var deck_fixture := "starter"
var lab_root: Control
var catalog: PanelContainer
var catalog_content: VBoxContainer
var toolbar: PanelContainer
var toolbar_margin: MarginContainer
var toolbar_layout: VBoxContainer
var toolbar_primary_row: HBoxContainer
var toolbar_secondary_row: HBoxContainer
var toolbar_title: Label
var fixture_spacer: Control
var toolbar_spacer: Control
var starter_button: Button
var coverage_button: Button
var force_correct_button: Button
var force_wrong_button: Button
var debug_button: Button
var return_button: Button
var restart_button: Button
var group_grids: Array[GridContainer] = []
var debug_backdrop: ColorRect
var debug_panel: PanelContainer
var debug_card_row: BoxContainer
var debug_value_row: BoxContainer
var card_selector: OptionButton
var stability_input: SpinBox
var fault_remaining_input: SpinBox
var apply_fault_button: Button
var debug_tabs: TabContainer
var hand_list: VBoxContainer
var deck_list: VBoxContainer


func configure(game_root: Control) -> void:
	game = game_root
	game.node_lab_overlay = self
	entries = _build_catalog()
	if lab_root == null:
		_build_ui()
	show_catalog()


func catalog_entries() -> Array:
	return entries.duplicate(true)


func _build_catalog() -> Array:
	var result: Array = []
	var enemy_ids: Array = game.enemy_defs.keys()
	enemy_ids.sort()
	for raw_id in enemy_ids:
		var enemy_id := str(raw_id)
		var enemy := game.enemy_defs[enemy_id] as Dictionary
		var tier := str(enemy.get("tier", "ordinary"))
		result.append({
			"id": enemy_id,
			"group": _enemy_group(tier),
			"label": str(enemy.get("name", enemy_id)),
			"kind": "enemy",
			"contentId": enemy_id,
			"tier": tier,
			"phase": -1
		})
		if tier == "boss":
			var phases: Array = enemy.get("phases", [])
			for phase_index in range(phases.size()):
				var phase := phases[phase_index] as Dictionary
				result.append({
					"id": "boss_phase_%d" % (phase_index + 1),
					"group": "Boss 阶段",
					"label": "%s · %s" % [enemy.get("name", "综合验收"), phase.get("name", "阶段")],
					"kind": "boss_phase",
					"contentId": enemy_id,
					"tier": "boss",
					"phase": phase_index
				})
				for raw_gate in phase.get("gateOptions", []) as Array:
					var gate := raw_gate as Dictionary
					result.append({
						"id": "boss_gate_%s" % str(gate.get("id", "")),
						"group": "Boss 规则",
						"label": "%s · %s" % [phase.get("name", "阶段"), gate.get("label", "验收规则")],
						"kind": "boss_gate",
						"contentId": enemy_id,
						"tier": "boss",
						"phase": phase_index,
						"gateId": str(gate.get("id", ""))
					})
		elif !(enemy.get("faultRule", {}) as Dictionary).is_empty():
			result.append({
				"id": "fault_rule_%s" % enemy_id,
				"group": "故障规则",
				"label": str(enemy.get("name", enemy_id)),
				"kind": "fault_rule",
				"contentId": enemy_id,
				"tier": tier,
				"phase": -1
			})

	var event_ids: Array = game.event_defs.keys()
	event_ids.sort_custom(func(a, b) -> bool:
		var event_a := game.event_defs[str(a)] as Dictionary
		var event_b := game.event_defs[str(b)] as Dictionary
		var key_a := "%s:%s:%s" % [event_a.get("tier", ""), event_a.get("questionType", ""), a]
		var key_b := "%s:%s:%s" % [event_b.get("tier", ""), event_b.get("questionType", ""), b]
		return key_a < key_b
	)
	for raw_id in event_ids:
		var event_id := str(raw_id)
		var event := game.event_defs[event_id] as Dictionary
		result.append({
			"id": event_id,
			"group": "基础题事件" if str(event.get("tier", "")) == "basic" else "进阶题事件",
			"label": "%s · %s" % [_question_type_label(str(event.get("questionType", ""))), event.get("name", event_id)],
			"kind": "question_event",
			"contentId": event_id,
			"tier": str(event.get("tier", "")),
			"questionType": str(event.get("questionType", "")),
			"phase": -1
		})

	result.append_array([
		{
			"id": "question_correct",
			"group": "题目结果",
			"label": "正确答案结果",
			"kind": "question_correct",
			"contentId": "basic_mq2_warmup",
			"tier": "basic",
			"questionType": "diagnosis",
			"phase": -1
		},
		{
			"id": "question_wrong",
			"group": "题目结果",
			"label": "错误答案结果",
			"kind": "question_wrong",
			"contentId": "basic_mq2_warmup",
			"tier": "basic",
			"questionType": "diagnosis",
			"phase": -1
		},
		_catalog_entry("sensor_checkpoint", "教学检查点", "传感器接入检查", "checkpoint_sensor"),
		_catalog_entry("trust_checkpoint", "教学检查点", "数据可信检查", "checkpoint_trust"),
		_catalog_entry("component", "功能节点", "工程组件三选一", "component"),
		_catalog_entry("service", "功能节点", "工程整备室", "service"),
		_catalog_entry("ordinary_reward", "奖励节点", "普通故障奖励", "reward", "ordinary"),
		_catalog_entry("elite_reward", "奖励节点", "精英故障奖励", "reward", "elite")
	])
	return result


func _question_type_label(question_type: String) -> String:
	return {
		"diagnosis": "诊断",
		"ordering": "排序",
		"code_trace": "代码跟踪",
		"parameter": "参数",
		"waveform": "波形",
		"tradeoff": "权衡"
	}.get(question_type, question_type)


func _catalog_entry(id: String, group: String, label: String, kind: String, tier: String = "") -> Dictionary:
	return {
		"id": id,
		"group": group,
		"label": label,
		"kind": kind,
		"contentId": id,
		"tier": tier,
		"phase": -1
	}


func _enemy_group(tier: String) -> String:
	return {
		"ordinary": "普通故障",
		"elite": "精英故障",
		"boss": "综合验收"
	}.get(tier, "故障")


func _build_ui() -> void:
	layer = 50
	lab_root = Control.new()
	lab_root.name = "NodeLabRoot"
	lab_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	lab_root.size = game.size
	lab_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab_root.theme = game.ui_theme
	add_child(lab_root)

	toolbar = PanelContainer.new()
	toolbar.name = "NodeLabToolbar"
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = TOOLBAR_SINGLE_HEIGHT
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	toolbar.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f6f9faf7"), Color("#2f7f8d")))
	lab_root.add_child(toolbar)
	toolbar_margin = MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 12)
	toolbar_margin.add_theme_constant_override("margin_right", 12)
	toolbar_margin.add_theme_constant_override("margin_top", 7)
	toolbar_margin.add_theme_constant_override("margin_bottom", 7)
	toolbar.add_child(toolbar_margin)
	toolbar_layout = VBoxContainer.new()
	toolbar_layout.name = "NodeLabToolbarLayout"
	toolbar_layout.add_theme_constant_override("separation", 4)
	toolbar_margin.add_child(toolbar_layout)
	toolbar_primary_row = HBoxContainer.new()
	toolbar_primary_row.name = "NodeLabToolbarPrimary"
	toolbar_primary_row.add_theme_constant_override("separation", 8)
	toolbar_layout.add_child(toolbar_primary_row)
	toolbar_secondary_row = HBoxContainer.new()
	toolbar_secondary_row.name = "NodeLabToolbarSecondary"
	toolbar_secondary_row.add_theme_constant_override("separation", 8)
	toolbar_layout.add_child(toolbar_secondary_row)

	toolbar_title = Label.new()
	toolbar_title.text = "节点实验室"
	toolbar_title.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
	toolbar_title.add_theme_font_size_override("font_size", 18)
	toolbar_primary_row.add_child(toolbar_title)

	fixture_spacer = Control.new()
	fixture_spacer.custom_minimum_size.x = 8
	toolbar_primary_row.add_child(fixture_spacer)
	starter_button = _toolbar_button("NodeLabFixtureStarter", "基础牌组")
	starter_button.toggle_mode = true
	starter_button.pressed.connect(func() -> void: _set_fixture("starter"))
	toolbar_primary_row.add_child(starter_button)
	coverage_button = _toolbar_button("NodeLabFixtureCoverage", "全标签")
	coverage_button.toggle_mode = true
	coverage_button.pressed.connect(func() -> void: _set_fixture("coverage"))
	toolbar_primary_row.add_child(coverage_button)
	force_correct_button = _toolbar_button("NodeLabForceCorrect", "判为正确")
	force_correct_button.pressed.connect(func() -> void: game.force_lab_question_result(true))
	toolbar_primary_row.add_child(force_correct_button)
	force_wrong_button = _toolbar_button("NodeLabForceWrong", "判为错误")
	force_wrong_button.pressed.connect(func() -> void: game.force_lab_question_result(false))
	toolbar_primary_row.add_child(force_wrong_button)
	debug_button = _toolbar_button("NodeLabDebugButton", "调试")
	debug_button.tooltip_text = "打开开发者调试面板"
	debug_button.pressed.connect(_toggle_debug_panel)
	toolbar_primary_row.add_child(debug_button)

	toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_primary_row.add_child(toolbar_spacer)
	return_button = _toolbar_button("NodeLabReturn", "返回目录")
	return_button.pressed.connect(_handle_return)
	toolbar_primary_row.add_child(return_button)
	restart_button = _toolbar_button("NodeLabRestart", "重开节点")
	restart_button.pressed.connect(func() -> void:
		hide_debug_panel()
		game.restart_lab_scenario()
	)
	toolbar_primary_row.add_child(restart_button)

	catalog = PanelContainer.new()
	catalog.name = "NodeLabCatalog"
	catalog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog.offset_top = TOOLBAR_SINGLE_HEIGHT
	catalog.mouse_filter = Control.MOUSE_FILTER_STOP
	catalog.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#eef4f6f5"), VisualTheme.color("focus_soft")))
	lab_root.add_child(catalog)
	var catalog_margin := MarginContainer.new()
	catalog_margin.add_theme_constant_override("margin_left", 18)
	catalog_margin.add_theme_constant_override("margin_right", 18)
	catalog_margin.add_theme_constant_override("margin_top", 14)
	catalog_margin.add_theme_constant_override("margin_bottom", 14)
	catalog.add_child(catalog_margin)
	var catalog_layout := VBoxContainer.new()
	catalog_layout.add_theme_constant_override("separation", 8)
	catalog_margin.add_child(catalog_layout)
	var title := Label.new()
	title.name = "NodeLabCatalogTitle"
	title.text = "选择要单独体验的节点"
	VisualTheme.apply_heading(title, game.ui_font_display, 24)
	catalog_layout.add_child(title)
	var description := Label.new()
	description.text = "每次启动都会重置稳定度、牌组和组件，不影响正常课程进度。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	catalog_layout.add_child(description)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_layout.add_child(scroll)
	catalog_content = VBoxContainer.new()
	catalog_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_content.add_theme_constant_override("separation", 10)
	scroll.add_child(catalog_content)
	_rebuild_catalog()
	_add_tactical_frame(catalog, "NodeLabTacticalFrame", "node_lab", VisualTheme.color("focus"))
	_build_debug_panel()
	game.resized.connect(_apply_desktop_layout)
	_apply_desktop_layout()


func _build_debug_panel() -> void:
	debug_backdrop = ColorRect.new()
	debug_backdrop.name = "NodeLabDebugBackdrop"
	debug_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_backdrop.color = Color(0.12, 0.18, 0.22, 0.46)
	debug_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_backdrop.visible = false
	lab_root.add_child(debug_backdrop)

	debug_panel = PanelContainer.new()
	debug_panel.name = "NodeLabDebugPanel"
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_panel.add_theme_stylebox_override("panel", VisualTheme.tactical_panel_style(Color("#f8fafbfa"), VisualTheme.color("focus")))
	debug_panel.visible = false
	debug_backdrop.add_child(debug_panel)
	_add_tactical_frame(debug_panel, "NodeLabDebugTacticalFrame", "node_lab_debug", VisualTheme.category_color("process"))
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	debug_panel.add_child(panel_margin)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.name = "NodeLabDebugScroll"
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_child(panel_scroll)
	var panel_layout := VBoxContainer.new()
	panel_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_theme_constant_override("separation", 10)
	panel_scroll.add_child(panel_layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	panel_layout.add_child(header)
	var title := Label.new()
	title.name = "NodeLabDebugTitle"
	title.text = "节点状态调试"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualTheme.apply_heading(title, game.ui_font_display, 22)
	header.add_child(title)
	var close_button := _debug_action_button("NodeLabDebugClose", "×", "关闭调试面板")
	close_button.custom_minimum_size = Vector2(44, 44)
	close_button.pressed.connect(hide_debug_panel)
	header.add_child(close_button)

	var card_heading := Label.new()
	card_heading.text = "指定卡牌"
	card_heading.add_theme_font_override("font", game.ui_font_strong)
	card_heading.add_theme_color_override("font_color", VisualTheme.color("focus"))
	panel_layout.add_child(card_heading)
	debug_card_row = BoxContainer.new()
	debug_card_row.name = "NodeLabDebugCardRow"
	debug_card_row.add_theme_constant_override("separation", 8)
	panel_layout.add_child(debug_card_row)
	card_selector = OptionButton.new()
	card_selector.name = "NodeLabCardSelector"
	card_selector.custom_minimum_size = Vector2(360, 44)
	card_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_card_row.add_child(card_selector)
	_populate_card_selector()
	var add_card_button := _debug_action_button("NodeLabAddCard", "加入手牌", "把选中的卡牌直接加入当前手牌")
	add_card_button.pressed.connect(_add_selected_card)
	debug_card_row.add_child(add_card_button)

	debug_value_row = BoxContainer.new()
	debug_value_row.name = "NodeLabDebugValueRow"
	debug_value_row.add_theme_constant_override("separation", 12)
	panel_layout.add_child(debug_value_row)
	stability_input = _build_value_control(
		debug_value_row,
		"玩家稳定度",
		"NodeLabStabilityInput",
		"NodeLabApplyStability",
		_apply_stability
	)
	fault_remaining_input = _build_value_control(
		debug_value_row,
		"故障剩余值",
		"NodeLabFaultRemainingInput",
		"NodeLabApplyFaultRemaining",
		_apply_fault_remaining
	)
	apply_fault_button = debug_panel.find_child("NodeLabApplyFaultRemaining", true, false) as Button

	debug_tabs = TabContainer.new()
	debug_tabs.name = "NodeLabDebugLists"
	debug_tabs.custom_minimum_size = Vector2(0, 390)
	debug_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_tabs.add_theme_stylebox_override("panel", game._panel_style(Color("#f7faf9"), Color("#9bb3b8")))
	debug_tabs.add_theme_stylebox_override("tab_selected", game._panel_style(Color("#edf3f4"), Color("#2f7f8d")))
	debug_tabs.add_theme_stylebox_override("tab_unselected", game._panel_style(Color("#dbe7e8"), Color("#8ca1a6")))
	debug_tabs.add_theme_stylebox_override("tab_hovered", game._panel_style(Color("#e5eff0"), Color("#52717a")))
	debug_tabs.add_theme_color_override("font_selected_color", VisualTheme.color("text_primary"))
	debug_tabs.add_theme_color_override("font_unselected_color", VisualTheme.color("text_secondary"))
	debug_tabs.add_theme_color_override("font_hovered_color", Color.WHITE)
	panel_layout.add_child(debug_tabs)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "当前手牌"
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	debug_tabs.add_child(hand_scroll)
	hand_list = VBoxContainer.new()
	hand_list.name = "NodeLabHandList"
	hand_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_list.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_list)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.name = "当前牌组"
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	debug_tabs.add_child(deck_scroll)
	deck_list = VBoxContainer.new()
	deck_list.name = "NodeLabDeckList"
	deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list.add_theme_constant_override("separation", 6)
	deck_scroll.add_child(deck_list)


func _build_value_control(
	parent: BoxContainer,
	label_text: String,
	input_name: String,
	button_name: String,
	apply_callback: Callable
) -> SpinBox:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 96
	label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	row.add_child(label)
	var input := SpinBox.new()
	input.name = input_name
	input.custom_minimum_size = Vector2(112, 44)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.step = 1
	input.rounded = true
	row.add_child(input)
	var apply_button := _debug_action_button(button_name, "应用", "应用%s" % label_text)
	apply_button.pressed.connect(apply_callback)
	row.add_child(apply_button)
	return input


func _debug_action_button(button_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(92, 44)
	VisualTheme.apply_tactical_button(button, Color("#2f7f8d"), game.ui_font_strong)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _populate_card_selector() -> void:
	card_selector.clear()
	var cards: Array = []
	for raw_card_id in game.card_defs.keys():
		var card_id := str(raw_card_id)
		var card := game.card_defs[card_id] as Dictionary
		cards.append({"id": card_id, "name": str(card.get("name", card_id))})
	cards.sort_custom(func(a, b) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	for raw_entry in cards:
		var entry := raw_entry as Dictionary
		card_selector.add_item(str(entry.get("name", entry.get("id", ""))))
		card_selector.set_item_metadata(card_selector.item_count - 1, str(entry.get("id", "")))


func _toolbar_button(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(76, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	VisualTheme.apply_tactical_button(button, Color("#2f7f8d"), game.ui_font_strong)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _rebuild_catalog() -> void:
	for child in catalog_content.get_children():
		child.queue_free()
	group_grids.clear()
	var groups := {}
	var group_order: Array[String] = []
	for raw_entry in entries:
		var entry := raw_entry as Dictionary
		var group := str(entry.get("group", "节点"))
		if !groups.has(group):
			groups[group] = []
			group_order.append(group)
		(groups[group] as Array).append(entry)
	for group in group_order:
		var heading := Label.new()
		heading.text = group
		heading.add_theme_font_override("font", game.ui_font_strong)
		heading.add_theme_color_override("font_color", VisualTheme.color("focus"))
		heading.add_theme_font_size_override("font_size", 17)
		catalog_content.add_child(heading)
		var grid := GridContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		group_grids.append(grid)
		catalog_content.add_child(grid)
		for raw_entry in groups[group]:
			_add_entry_button(grid, raw_entry as Dictionary)


func _add_entry_button(parent: Container, entry: Dictionary) -> void:
	var button := Button.new()
	button.name = "NodeLabScenario_%s" % str(entry.get("id", "scenario"))
	button.text = str(entry.get("label", entry.get("id", "测试节点")))
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(260, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualTheme.apply_tactical_button(button, Color("#725c91"), game.ui_font_strong)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void:
		if game.start_lab_scenario(entry, deck_fixture):
			current_entry = entry.duplicate(true)
			show_scenario_controls()
	)
	parent.add_child(button)


func _add_tactical_frame(parent: Control, node_name: String, frame_id: String, accent: Color) -> void:
	var frame := TechFrame.new() as Control
	frame.name = node_name
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.configure(frame_id, accent, "tactical")
	parent.add_child(frame)


func _set_fixture(fixture_id: String) -> void:
	deck_fixture = fixture_id
	starter_button.set_pressed_no_signal(fixture_id == "starter")
	coverage_button.set_pressed_no_signal(fixture_id == "coverage")
	if game.node_lab_active:
		game.lab_deck_fixture = fixture_id


func show_catalog() -> void:
	hide_debug_panel()
	current_entry.clear()
	lab_root.visible = true
	catalog.visible = true
	toolbar_title.text = "节点实验室"
	return_button.visible = true
	return_button.text = "返回菜单"
	restart_button.visible = false
	starter_button.visible = true
	coverage_button.visible = true
	force_correct_button.visible = false
	force_wrong_button.visible = false
	debug_button.visible = false
	_set_fixture(deck_fixture)
	var header: PanelContainer = game.header_panel
	var game_shell: VBoxContainer = game.shell
	header.visible = true
	game_shell.offset_top = 0
	game_shell.visible = false
	_apply_desktop_layout()


func show_scenario_controls() -> void:
	hide_debug_panel()
	current_entry = game.lab_current_entry.duplicate(true)
	lab_root.visible = true
	catalog.visible = false
	toolbar_title.text = str(current_entry.get("label", "节点实验室"))
	return_button.visible = true
	return_button.text = "返回目录"
	restart_button.visible = true
	starter_button.visible = true
	coverage_button.visible = true
	var question_fixture := str(current_entry.get("kind", "")) == "question_event"
	force_correct_button.visible = question_fixture
	force_wrong_button.visible = question_fixture
	debug_button.visible = true
	var header: PanelContainer = game.header_panel
	var game_shell: VBoxContainer = game.shell
	header.visible = false
	game_shell.visible = true
	_apply_desktop_layout()


func _toggle_debug_panel() -> void:
	if debug_panel.visible:
		hide_debug_panel()
	else:
		show_debug_panel()


func _handle_return() -> void:
	if catalog != null and catalog.visible:
		game.show_start_menu()
	else:
		game.return_to_node_lab()


func show_debug_panel() -> void:
	if catalog.visible:
		return
	refresh_debug_panel()
	debug_backdrop.visible = true
	debug_panel.visible = true
	_apply_desktop_layout()


func hide_debug_panel() -> void:
	if debug_backdrop == null or debug_panel == null:
		return
	debug_panel.visible = false
	debug_backdrop.visible = false


func refresh_debug_panel() -> void:
	if debug_panel == null:
		return
	stability_input.min_value = 1
	stability_input.max_value = game.max_stability
	stability_input.value = game.stability
	var combat_active: bool = game.state == game.RunState.COMBAT and game.repair_target > 0
	fault_remaining_input.min_value = 0
	fault_remaining_input.max_value = maxi(game.repair_target, 0)
	fault_remaining_input.value = game.lab_fault_remaining() if combat_active else 0
	fault_remaining_input.editable = combat_active
	apply_fault_button.disabled = !combat_active
	_refresh_hand_list()
	_refresh_deck_list()


func _refresh_hand_list() -> void:
	_clear_list(hand_list)
	if game.hand.is_empty():
		_add_empty_list_label(hand_list, "当前手牌为空")
		return
	for hand_index in range(game.hand.size()):
		var card := game.hand[hand_index] as Dictionary
		var row := _debug_card_row(
			"%d. %s" % [hand_index + 1, card.get("name", card.get("id", "卡牌"))],
			"NodeLabDeleteHand_%d" % hand_index,
			"从手牌删除"
		)
		var captured_index := hand_index
		(row.get_child(1) as Button).pressed.connect(func() -> void:
			if game.lab_remove_hand_card(captured_index):
				refresh_debug_panel()
		)
		hand_list.add_child(row)


func _refresh_deck_list() -> void:
	_clear_list(deck_list)
	if game.deck.is_empty():
		_add_empty_list_label(deck_list, "当前牌组为空")
		return
	var counts := {}
	for raw_card in game.deck:
		var card := raw_card as Dictionary
		var card_id := str(card.get("id", ""))
		if card_id.is_empty():
			continue
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var card_ids: Array = counts.keys()
	card_ids.sort_custom(func(a, b) -> bool:
		var card_a := game.card_defs.get(str(a), {}) as Dictionary
		var card_b := game.card_defs.get(str(b), {}) as Dictionary
		return str(card_a.get("name", a)) < str(card_b.get("name", b))
	)
	for raw_card_id in card_ids:
		var card_id := str(raw_card_id)
		var definition := game.card_defs.get(card_id, {}) as Dictionary
		var row := _debug_card_row(
			"%s ×%d" % [definition.get("name", card_id), int(counts[card_id])],
			"NodeLabDeleteDeck_%s" % card_id,
			"从牌组删除一张"
		)
		var captured_id := card_id
		(row.get_child(1) as Button).pressed.connect(func() -> void:
			if game.lab_remove_deck_card(captured_id):
				refresh_debug_panel()
		)
		deck_list.add_child(row)


func _debug_card_row(label_text: String, button_name: String, tooltip: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label_text
	label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	row.add_child(label)
	var delete_button := _debug_action_button(button_name, "删除", tooltip)
	delete_button.custom_minimum_size.x = 72
	row.add_child(delete_button)
	return row


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _add_empty_list_label(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", VisualTheme.color("text_muted"))
	list.add_child(label)


func _add_selected_card() -> void:
	if card_selector.selected < 0:
		return
	var card_id := str(card_selector.get_item_metadata(card_selector.selected))
	if game.lab_add_card_to_hand(card_id):
		refresh_debug_panel()


func _apply_stability() -> void:
	if game.lab_set_stability(int(stability_input.value)):
		refresh_debug_panel()


func _apply_fault_remaining() -> void:
	if game.lab_set_fault_remaining(int(fault_remaining_input.value)):
		refresh_debug_panel()


func _apply_desktop_layout() -> void:
	if game == null:
		return
	lab_root.position = Vector2.ZERO
	lab_root.size = game.size
	_configure_toolbar_rows()
	var resolved_toolbar_height := maxf(TOOLBAR_SINGLE_HEIGHT, toolbar.get_combined_minimum_size().y)
	toolbar.offset_bottom = resolved_toolbar_height
	catalog.offset_top = resolved_toolbar_height
	if catalog.visible:
		game.shell.offset_top = 0.0
	elif game.shell.visible:
		game.shell.offset_top = resolved_toolbar_height
	toolbar_title.show()
	fixture_spacer.show()
	toolbar_spacer.show()
	toolbar_primary_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	toolbar_secondary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar_secondary_row.hide()
	starter_button.text = "基础牌组"
	coverage_button.text = "全标签"
	force_correct_button.text = "判为正确"
	force_wrong_button.text = "判为错误"
	debug_button.text = "调试"
	return_button.text = "返回菜单" if catalog.visible else "返回目录"
	restart_button.text = "重开节点"
	for button in [starter_button, coverage_button, force_correct_button, force_wrong_button, debug_button, return_button, restart_button]:
		button.custom_minimum_size.x = 76
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for grid in group_grids:
		grid.columns = 2
	debug_card_row.vertical = false
	debug_value_row.vertical = false
	debug_tabs.custom_minimum_size.y = 390
	card_selector.custom_minimum_size.x = 360
	debug_panel.set_anchors_preset(Control.PRESET_CENTER)
	debug_panel.offset_left = -DEBUG_PANEL_DESKTOP_SIZE.x / 2.0
	debug_panel.offset_top = -DEBUG_PANEL_DESKTOP_SIZE.y / 2.0
	debug_panel.offset_right = DEBUG_PANEL_DESKTOP_SIZE.x / 2.0
	debug_panel.offset_bottom = DEBUG_PANEL_DESKTOP_SIZE.y / 2.0
	debug_panel.custom_minimum_size = DEBUG_PANEL_DESKTOP_SIZE
	toolbar_primary_row.queue_sort()
	toolbar_secondary_row.queue_sort()


func _configure_toolbar_rows() -> void:
	var action_parent: HBoxContainer = toolbar_primary_row
	for control in [force_correct_button, force_wrong_button, debug_button, return_button, restart_button]:
		if control.get_parent() != action_parent:
			control.reparent(action_parent)
	var primary_order: Array[Control] = [
		toolbar_title,
		fixture_spacer,
		starter_button,
		coverage_button,
		force_correct_button,
		force_wrong_button,
		debug_button,
		toolbar_spacer,
		return_button,
		restart_button
	]
	for index in range(primary_order.size()):
		toolbar_primary_row.move_child(primary_order[index], index)
