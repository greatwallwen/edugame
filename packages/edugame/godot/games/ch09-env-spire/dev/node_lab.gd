extends CanvasLayer

var game: Control
var entries: Array = []
var current_entry := {}
var deck_fixture := "starter"
var lab_root: Control
var catalog: PanelContainer
var catalog_content: VBoxContainer
var toolbar: PanelContainer
var toolbar_title: Label
var starter_button: Button
var coverage_button: Button
var return_button: Button
var restart_button: Button
var group_grids: Array[GridContainer] = []


func configure(game_root: Control) -> void:
	game = game_root
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

	var event_ids: Array = game.event_defs.keys()
	event_ids.sort()
	for raw_id in event_ids:
		var event_id := str(raw_id)
		var event := game.event_defs[event_id] as Dictionary
		result.append({
			"id": event_id,
			"group": "调试事件",
			"label": str(event.get("name", event_id)),
			"kind": "event",
			"contentId": event_id,
			"tier": "",
			"phase": -1
		})

	result.append_array([
		_catalog_entry("sensor_checkpoint", "教学检查点", "传感器接入检查", "checkpoint_sensor"),
		_catalog_entry("trust_checkpoint", "教学检查点", "数据可信检查", "checkpoint_trust"),
		_catalog_entry("component", "功能节点", "工程组件三选一", "component"),
		_catalog_entry("shop", "功能节点", "器材商店", "shop"),
		_catalog_entry("service", "功能节点", "阶段维护", "service"),
		_catalog_entry("ordinary_reward", "奖励节点", "普通故障奖励", "reward", "ordinary"),
		_catalog_entry("elite_reward", "奖励节点", "精英故障奖励", "reward", "elite")
	])
	return result


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
	lab_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab_root)

	toolbar = PanelContainer.new()
	toolbar.name = "NodeLabToolbar"
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_bottom = 58
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	toolbar.add_theme_stylebox_override("panel", game._panel_style(Color("#17262b"), Color("#2f7f8d")))
	lab_root.add_child(toolbar)
	var toolbar_margin := MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_left", 12)
	toolbar_margin.add_theme_constant_override("margin_right", 12)
	toolbar_margin.add_theme_constant_override("margin_top", 7)
	toolbar_margin.add_theme_constant_override("margin_bottom", 7)
	toolbar.add_child(toolbar_margin)
	var toolbar_row := HBoxContainer.new()
	toolbar_row.add_theme_constant_override("separation", 8)
	toolbar_margin.add_child(toolbar_row)

	toolbar_title = Label.new()
	toolbar_title.text = "节点实验室"
	toolbar_title.add_theme_color_override("font_color", Color("#ecf3f4"))
	toolbar_title.add_theme_font_size_override("font_size", 18)
	toolbar_row.add_child(toolbar_title)

	var fixture_spacer := Control.new()
	fixture_spacer.custom_minimum_size.x = 8
	toolbar_row.add_child(fixture_spacer)
	starter_button = _toolbar_button("NodeLabFixtureStarter", "基础牌组")
	starter_button.toggle_mode = true
	starter_button.pressed.connect(func() -> void: _set_fixture("starter"))
	toolbar_row.add_child(starter_button)
	coverage_button = _toolbar_button("NodeLabFixtureCoverage", "全标签")
	coverage_button.toggle_mode = true
	coverage_button.pressed.connect(func() -> void: _set_fixture("coverage"))
	toolbar_row.add_child(coverage_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_row.add_child(spacer)
	return_button = _toolbar_button("NodeLabReturn", "返回目录")
	return_button.pressed.connect(func() -> void: game.return_to_node_lab())
	toolbar_row.add_child(return_button)
	restart_button = _toolbar_button("NodeLabRestart", "重开节点")
	restart_button.pressed.connect(func() -> void: game.restart_lab_scenario())
	toolbar_row.add_child(restart_button)

	catalog = PanelContainer.new()
	catalog.name = "NodeLabCatalog"
	catalog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog.offset_top = 58
	catalog.mouse_filter = Control.MOUSE_FILTER_STOP
	catalog.add_theme_stylebox_override("panel", game._panel_style(Color("#edf3f4"), Color("#52717a")))
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
	title.text = "选择要单独体验的节点"
	title.add_theme_color_override("font_color", Color("#17343c"))
	title.add_theme_font_size_override("font_size", 24)
	catalog_layout.add_child(title)
	var description := Label.new()
	description.text = "每次启动都会重置稳定度、预算、牌组和组件，不影响正常课程进度。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#50656b"))
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
	game.resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _toolbar_button(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(76, 44)
	game._skin_button(button, Color("#2f7f8d"))
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
		heading.add_theme_color_override("font_color", Color("#2f7f8d"))
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
	game._skin_button(button, Color("#725c91"))
	button.pressed.connect(func() -> void:
		if game.start_lab_scenario(entry, deck_fixture):
			current_entry = entry.duplicate(true)
			show_scenario_controls()
	)
	parent.add_child(button)


func _set_fixture(fixture_id: String) -> void:
	deck_fixture = fixture_id
	starter_button.set_pressed_no_signal(fixture_id == "starter")
	coverage_button.set_pressed_no_signal(fixture_id == "coverage")
	if game.node_lab_active:
		game.lab_deck_fixture = fixture_id


func show_catalog() -> void:
	current_entry.clear()
	lab_root.visible = true
	catalog.visible = true
	toolbar_title.text = "节点实验室"
	return_button.visible = false
	restart_button.visible = false
	starter_button.visible = true
	coverage_button.visible = true
	_set_fixture(deck_fixture)
	game.shell.visible = false
	_apply_responsive_layout()


func show_scenario_controls() -> void:
	current_entry = game.lab_current_entry.duplicate(true)
	lab_root.visible = true
	catalog.visible = false
	toolbar_title.text = str(current_entry.get("label", "节点实验室"))
	return_button.visible = true
	restart_button.visible = true
	starter_button.visible = true
	coverage_button.visible = true
	game.shell.visible = true
	game.shell.offset_top = 58
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if game == null:
		return
	var compact := game.size.x < 720.0
	toolbar_title.visible = !compact
	starter_button.text = "基础" if compact else "基础牌组"
	coverage_button.text = "全标签"
	return_button.text = "目录" if compact else "返回目录"
	restart_button.text = "重开" if compact else "重开节点"
	for grid in group_grids:
		grid.columns = 1 if compact else 2
