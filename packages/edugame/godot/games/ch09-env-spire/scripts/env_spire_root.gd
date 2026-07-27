extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")
const UI_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const STARTER_CARD_IDS := [
	"mq2_sample", "mq2_sample", "bh1750_read", "hdc1080_read",
	"adc_convert", "adc_convert", "i2c_transaction", "i2c_transaction",
	"unit_convert", "unit_convert", "sliding_average", "uart_log"
]
const SOURCE_ORDER := ["smoke", "light", "temp", "humidity"]
const STAGE_ORDER := ["collect", "interface", "process", "output"]
const BOSS_DRAW_SEED := 90909
const RUN_NODE_COUNT := 12
const LAB_COVERAGE_CARD_IDS := [
	"mq2_sample", "bh1750_read", "hdc1080_read", "adc_convert",
	"i2c_transaction", "sliding_average", "lcd_display",
	"uart_log", "threshold_judgement", "time_slice"
]

enum RunState { WAITING, MAP, COMBAT, REWARD, EVENT, SHOP, REST, COMPONENT, RESULT }

var runtime
var state := RunState.WAITING
var card_defs := {}
var enemy_defs := {}
var negative_defs := {}
var event_defs := {}
var relic_defs := {}
var map_defs := {}

var run_map_id := "mvp_a"
var run_map := {}
var rng := RandomNumberGenerator.new()
var max_stability := 70
var stability := 70
var budget := 30
var current_layer := 0
var visited_nodes: Array = []
var checkpoints_passed := 0
var checkpoint_results: Array = []
var boss_phase := 0
var boss_review_used := false
var pre_boss_stability := 70
var completed := false
var victory := false
var score := 0
var started_at := 0

var deck: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var hand: Array = []
var relics: Array = []
var powers := {}

var processing_points := 3
var next_turn_energy := 0
var block := 0
var raw_data := {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
var trusted_data := {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
var retain_data := false
var diagnosis := 0
var alarm_markers := 0
var chain_count := 0
var last_stage := ""
var turn_number := 0
var turn_card_types := {}
var turn_sources := {}
var source_coverage := {}
var output_types := {}
var trusted_sources_seen := {}
var filters_played := 0
var encounter_evidence_tags := {}
var phase_source_coverage := {}
var phase_trusted_sources := {}
var phase_filters_played := 0
var phase_output_types := {}
var persistent_output_types := {}
var repair_penalty := 0
var i2c_cost_penalty := 0
var pending_i2c_count := 0

var current_node := {}
var current_encounter := {}
var current_intents: Array = []
var intent_index := 0
var repair_target := 0
var repair_progress := 0
var current_event := {}
var reward_choices: Array = []
var component_choices: Array = []
var shop_cards: Array = []
var message_log: Array = []
var debug_reports: Array = []
var node_lab_active := false
var lab_current_entry := {}
var lab_deck_fixture := "starter"

var ui_font: Font
var ui_theme: Theme
var shell: VBoxContainer
var header_panel: PanelContainer
var brand_label: Label
var layer_label: Label
var stability_label: Label
var budget_label: Label
var deck_label: Label
var main_area: Control
var map_view: PanelContainer
var map_title: Label
var map_timeline: HBoxContainer
var map_choices: GridContainer
var combat_view: PanelContainer
var combat_layout: BoxContainer
var encounter_name_label: Label
var encounter_meta_label: Label
var intent_label: Label
var repair_label: Label
var repair_bar: ProgressBar
var gate_label: Label
var data_label: Label
var status_label: Label
var hand_scroll: ScrollContainer
var hand_row: HBoxContainer
var end_turn_button: Button
var choice_view: PanelContainer
var choice_title: Label
var choice_description: Label
var choice_list: GridContainer
var result_view: PanelContainer
var result_title: Label
var result_summary: Label
var log_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local_content()
	_load_ui()
	_build_ui()
	_setup_runtime()
	state = RunState.WAITING
	_render_state()
	call_deferred("_start_standalone_preview_if_needed")


func _setup_runtime() -> void:
	runtime = DGBRuntime.new()
	runtime.setup({
		"game_id": "ch09-env-spire",
		"fallbacks": {},
		"defaults": {
			"runMapId": "mvp_a",
			"maxStability": 70
		}
	})
	runtime.initialized.connect(_on_session_initialized)
	runtime.reset_requested.connect(_on_runtime_reset)
	runtime.pause_requested.connect(func() -> void: get_tree().paused = true)
	runtime.resume_requested.connect(func() -> void: get_tree().paused = false)
	add_child(runtime)


func _on_session_initialized(session: Dictionary) -> void:
	var config := session.get("config", {}) as Dictionary
	run_map_id = str(config.get("runMapId", run_map_id))
	max_stability = int(config.get("maxStability", max_stability))
	_reset_run()
	_render_state()
	runtime.log_info("Ch09 environment spire initialized.")


func _on_runtime_reset() -> void:
	_reset_run()
	_render_state()


func _start_standalone_preview_if_needed() -> void:
	if !OS.has_feature("web"):
		return
	var top_level := bool(JavaScriptBridge.eval("window.self === window.parent", true))
	_start_standalone_preview(top_level)


func _start_standalone_preview(top_level: bool) -> bool:
	if !top_level or state != RunState.WAITING:
		return false
	_reset_run()
	_render_state()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and combat_layout != null:
		_apply_responsive_layout()


func _load_ui() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		ui_font = load(UI_FONT_PATH) as Font
	if ui_font == null:
		push_warning("Missing UI font: " + UI_FONT_PATH)
		ui_font = ThemeDB.fallback_font
	ui_theme = Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 16
	theme = ui_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#12191d")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	shell = VBoxContainer.new()
	shell.name = "Shell"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 8)
	add_child(shell)

	header_panel = PanelContainer.new()
	header_panel.name = "Header"
	header_panel.theme = ui_theme
	header_panel.custom_minimum_size = Vector2(0, 66)
	header_panel.add_theme_stylebox_override("panel", _panel_style(Color("#ecf3f4"), Color("#52717a")))
	shell.add_child(header_panel)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 18)
	header_margin.add_theme_constant_override("margin_right", 18)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	header_panel.add_child(header_margin)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header_margin.add_child(header_row)
	var brand_icon := TextureRect.new()
	brand_icon.custom_minimum_size = Vector2(34, 34)
	brand_icon.texture = _load_svg_texture("res://icon.svg")
	brand_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(brand_icon)
	brand_label = Label.new()
	brand_label.text = "ENV / SPIRE"
	brand_label.add_theme_color_override("font_color", Color("#17343c"))
	brand_label.add_theme_font_size_override("font_size", 20)
	header_row.add_child(brand_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	layer_label = _header_metric(header_row)
	stability_label = _header_metric(header_row)
	budget_label = _header_metric(header_row)
	deck_label = _header_metric(header_row)
	main_area = Control.new()
	main_area.name = "Main"
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.custom_minimum_size = Vector2(0, 420)
	shell.add_child(main_area)
	map_view = _state_panel("MapView")
	combat_view = _state_panel("CombatView")
	choice_view = _state_panel("ChoiceView")
	result_view = _state_panel("ResultView")
	main_area.add_child(map_view)
	main_area.add_child(combat_view)
	main_area.add_child(choice_view)
	main_area.add_child(result_view)
	_build_map_view()
	_build_combat_view()
	_build_choice_view()
	_build_result_view()

	var footer := PanelContainer.new()
	footer.name = "Footer"
	footer.custom_minimum_size = Vector2(0, 58)
	footer.add_theme_stylebox_override("panel", _panel_style(Color("#1c272c"), Color("#3a555e")))
	shell.add_child(footer)
	log_label = Label.new()
	log_label.name = "LogLabel"
	log_label.offset_left = 16
	log_label.offset_right = -16
	log_label.offset_top = 8
	log_label.offset_bottom = -8
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", Color("#d8e5e8"))
	footer.add_child(log_label)
	_apply_responsive_layout()


func _load_svg_texture(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var image := Image.new()
	if image.load_svg_from_string(file.get_as_text(), 1.0) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _header_metric(parent: HBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#294b54"))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _state_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#f7faf9"), Color("#68818a")))
	return panel


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _skin_button(button: Button, accent: Color = Color("#2f7f8d")) -> void:
	button.custom_minimum_size = Vector2(120, 44)
	button.add_theme_stylebox_override("normal", _button_style(Color("#e6eff1"), accent))
	button.add_theme_stylebox_override("hover", _button_style(Color("#d5e9ec"), accent.lightened(0.1)))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#c3dde1"), accent.darkened(0.1)))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#e6e8e8"), Color("#9aa7aa")))
	button.add_theme_color_override("font_color", Color("#17343c"))
	button.add_theme_color_override("font_disabled_color", Color("#6d797c"))
	button.add_theme_font_size_override("font_size", 15)


func _content_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	return margin


func _build_map_view() -> void:
	var margin := _content_margin()
	map_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	map_title = Label.new()
	map_title.add_theme_font_size_override("font_size", 24)
	map_title.add_theme_color_override("font_color", Color("#17343c"))
	content.add_child(map_title)
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	timeline_scroll.custom_minimum_size = Vector2(0, 76)
	content.add_child(timeline_scroll)
	map_timeline = HBoxContainer.new()
	map_timeline.name = "MapTimeline"
	map_timeline.add_theme_constant_override("separation", 8)
	timeline_scroll.add_child(map_timeline)
	var divider := HSeparator.new()
	content.add_child(divider)
	map_choices = GridContainer.new()
	map_choices.name = "MapChoices"
	map_choices.columns = 2
	map_choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_choices.add_theme_constant_override("h_separation", 10)
	map_choices.add_theme_constant_override("v_separation", 10)
	content.add_child(map_choices)


func _build_combat_view() -> void:
	var margin := _content_margin()
	combat_view.add_child(margin)
	combat_layout = BoxContainer.new()
	combat_layout.name = "CombatLayout"
	combat_layout.add_theme_constant_override("separation", 14)
	margin.add_child(combat_layout)
	var left_column := VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.custom_minimum_size = Vector2(260, 0)
	left_column.add_theme_constant_override("separation", 10)
	combat_layout.add_child(left_column)
	encounter_name_label = Label.new()
	encounter_name_label.add_theme_font_size_override("font_size", 24)
	encounter_name_label.add_theme_color_override("font_color", Color("#8d2f2a"))
	left_column.add_child(encounter_name_label)
	encounter_meta_label = Label.new()
	encounter_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_meta_label.add_theme_color_override("font_color", Color("#3e565d"))
	left_column.add_child(encounter_meta_label)
	intent_label = Label.new()
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_label.add_theme_stylebox_override("normal", _button_style(Color("#fff0df"), Color("#b16a2c")))
	intent_label.add_theme_color_override("font_color", Color("#693914"))
	left_column.add_child(intent_label)
	repair_label = Label.new()
	repair_label.add_theme_font_size_override("font_size", 18)
	repair_label.add_theme_color_override("font_color", Color("#226c59"))
	left_column.add_child(repair_label)
	repair_bar = ProgressBar.new()
	repair_bar.name = "RepairBar"
	repair_bar.show_percentage = false
	repair_bar.custom_minimum_size = Vector2(0, 16)
	repair_bar.add_theme_stylebox_override("background", _button_style(Color("#dce7e5"), Color("#8aa09d")))
	repair_bar.add_theme_stylebox_override("fill", _button_style(Color("#3c8d72"), Color("#226c59")))
	left_column.add_child(repair_bar)
	gate_label = Label.new()
	gate_label.name = "GateLabel"
	gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_label.add_theme_font_size_override("font_size", 14)
	gate_label.add_theme_color_override("font_color", Color("#486068"))
	left_column.add_child(gate_label)
	data_label = Label.new()
	data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_label.add_theme_stylebox_override("normal", _button_style(Color("#edf4f2"), Color("#7b9a91")))
	data_label.add_theme_color_override("font_color", Color("#24434b"))
	left_column.add_child(data_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_stylebox_override("normal", _button_style(Color("#f1f0f6"), Color("#8b7ca6")))
	status_label.add_theme_color_override("font_color", Color("#52666b"))
	left_column.add_child(status_label)

	var right_column := VBoxContainer.new()
	right_column.name = "RightColumn"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	combat_layout.add_child(right_column)
	var hand_title := Label.new()
	hand_title.text = "手牌 / 点击执行工程动作"
	hand_title.add_theme_color_override("font_color", Color("#294b54"))
	right_column.add_child(hand_title)
	hand_scroll = ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.custom_minimum_size = Vector2(0, 190)
	right_column.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.name = "HandRow"
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.custom_minimum_size = Vector2(0, 260)
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)
	var combat_actions := HBoxContainer.new()
	combat_actions.name = "CombatActions"
	combat_actions.alignment = BoxContainer.ALIGNMENT_END
	combat_actions.add_theme_constant_override("separation", 10)
	right_column.add_child(combat_actions)
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "结束回合"
	_skin_button(end_turn_button, Color("#b16a2c"))
	end_turn_button.pressed.connect(func() -> void:
		end_turn()
		_render_state()
	)
	combat_actions.add_child(end_turn_button)


func _build_choice_view() -> void:
	var margin := _content_margin()
	choice_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	choice_title = Label.new()
	choice_title.add_theme_font_size_override("font_size", 24)
	choice_title.add_theme_color_override("font_color", Color("#17343c"))
	content.add_child(choice_title)
	choice_description = Label.new()
	choice_description.name = "ChoiceDescription"
	choice_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_description.add_theme_color_override("font_color", Color("#486068"))
	content.add_child(choice_description)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	choice_list = GridContainer.new()
	choice_list.name = "ChoiceList"
	choice_list.columns = 2
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("h_separation", 10)
	choice_list.add_theme_constant_override("v_separation", 10)
	scroll.add_child(choice_list)


func _build_result_view() -> void:
	var margin := _content_margin()
	result_view.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	content.add_child(result_title)
	result_summary = Label.new()
	result_summary.name = "ResultSummary"
	result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_summary.add_theme_color_override("font_color", Color("#355158"))
	content.add_child(result_summary)
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "重新开始调试"
	_skin_button(restart, Color("#2f7f8d"))
	restart.custom_minimum_size = Vector2(300, 44)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void:
		_reset_run()
		_render_state()
	)
	content.add_child(restart)


func _apply_responsive_layout() -> void:
	if combat_layout == null:
		return
	var compact := size.x < 720.0
	combat_layout.vertical = compact
	if map_choices != null:
		map_choices.columns = 1 if compact else 2
	if choice_list != null:
		choice_list.columns = 1 if compact else 2
	if budget_label != null:
		budget_label.visible = !compact
	if deck_label != null:
		deck_label.visible = !compact
	if brand_label != null:
		brand_label.text = "ENV" if compact else "ENV / SPIRE"
	if hand_scroll != null:
		hand_scroll.custom_minimum_size.y = 192.0 if compact else 276.0
	if hand_row != null:
		hand_row.custom_minimum_size.y = 188.0 if compact else 260.0
		for child in hand_row.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(154, 188) if compact else Vector2(176, 260)


func _render_state() -> void:
	if map_view == null:
		return
	map_view.visible = state == RunState.MAP
	combat_view.visible = state == RunState.COMBAT
	choice_view.visible = [RunState.REWARD, RunState.EVENT, RunState.SHOP, RunState.REST, RunState.COMPONENT].has(state)
	result_view.visible = state == RunState.RESULT
	_render_header()
	match state:
		RunState.MAP:
			_render_map()
		RunState.COMBAT:
			_render_combat()
		RunState.REWARD, RunState.EVENT, RunState.SHOP, RunState.REST, RunState.COMPONENT:
			_render_choices()
		RunState.RESULT:
			_render_result()
	if log_label != null:
		log_label.text = "  /  ".join(message_log.slice(maxi(0, message_log.size() - 2), message_log.size()))
	_apply_responsive_layout()


func _render_header() -> void:
	layer_label.text = "节点 %d / %d" % [current_layer, RUN_NODE_COUNT]
	stability_label.text = "稳定度 %d / %d" % [stability, max_stability]
	budget_label.text = "预算 %d" % budget
	deck_label.text = "牌组 %d" % deck.size()


func _render_map() -> void:
	map_title.text = "第 %d 个调试节点" % (current_layer + 1) if current_layer < RUN_NODE_COUNT else "路线完成"
	_clear_children(map_timeline)
	var layers: Array = run_map.get("layers", [])
	for layer_number in range(1, RUN_NODE_COUNT + 1):
		var marker := Label.new()
		var layer_data := (layers[layer_number - 1] as Dictionary) if layer_number - 1 < layers.size() else {}
		var layer_choices: Array = layer_data.get("choices", [])
		var marker_type := str((layer_choices[0] as Dictionary).get("type", "")) if !layer_choices.is_empty() else ""
		marker.text = "%02d\n%s" % [layer_number, _node_type_short(marker_type)]
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.custom_minimum_size = Vector2(96, 58)
		marker.add_theme_stylebox_override("normal", _button_style(
			Color("#2f7f8d") if layer_number <= current_layer else Color("#dfe7e8"),
			Color("#2f7f8d") if layer_number == current_layer + 1 else Color("#8ca0a5")
		))
		marker.add_theme_color_override("font_color", Color.WHITE if layer_number <= current_layer else Color("#50656b"))
		marker.add_theme_font_size_override("font_size", 13)
		map_timeline.add_child(marker)
	_clear_children(map_choices)
	if current_layer >= layers.size():
		return
	var choices: Array = (layers[current_layer] as Dictionary).get("choices", [])
	for index in range(choices.size()):
		var node := choices[index] as Dictionary
		var button := Button.new()
		button.text = "%02d  %s\n%s" % [current_layer + 1, node.get("label", "调试节点"), _node_type_name(str(node.get("type", "")))]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skin_button(button, _lane_color(str(node.get("lane", ""))))
		button.custom_minimum_size = Vector2(280, 112)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(func() -> void:
			choose_node(index)
			_render_state()
		)
		map_choices.add_child(button)


func _node_type_name(node_type: String) -> String:
	return {
		"ordinary": "普通故障", "elite": "精英故障", "event": "调试事件",
		"shop": "器材商店", "service": "整备", "checkpoint_sensor": "教学检查点",
		"checkpoint_trust": "教学检查点", "checkpoint": "教学检查点",
		"component": "工程组件", "boss": "综合验收"
	}.get(node_type, node_type)


func _node_type_short(node_type: String) -> String:
	return {
		"ordinary": "故障", "elite": "精英", "event": "事件", "shop": "商店",
		"service": "整备", "checkpoint_sensor": "接入检查", "checkpoint_trust": "可信检查",
		"component": "组件", "boss": "综合验收"
	}.get(node_type, "节点")


func _lane_name(lane: String) -> String:
	return {"field": "现场采样线", "bus": "总线调试线", "system": "系统联调线", "merge": "必经节点"}.get(lane, lane)


func _lane_color(lane: String) -> Color:
	return {"field": Color("#b75a3a"), "bus": Color("#2f7f8d"), "system": Color("#517943"), "merge": Color("#725c91")}.get(lane, Color("#60757b"))


func _render_combat() -> void:
	encounter_name_label.text = str(current_encounter.get("name", "故障诊断"))
	var tier := str(current_encounter.get("tier", "ordinary"))
	var phase_text := " · 阶段 %d/3" % (boss_phase + 1) if tier == "boss" else ""
	encounter_meta_label.text = "%s%s\n弱点：%s" % [_node_type_name(tier), phase_text, " / ".join(current_encounter.get("weaknessTags", []))]
	intent_label.text = "下一行动：%s" % _current_intent_text()
	repair_label.text = "修复进度 %d / %d" % [repair_progress, repair_target]
	repair_bar.max_value = maxi(repair_target, 1)
	repair_bar.value = repair_progress
	gate_label.text = _gate_status_text(tier)
	gate_label.add_theme_color_override("font_color", Color("#226c59") if _active_gate_met(tier) else Color("#9b4f2f"))
	data_label.text = "原始  烟%d 光%d 温%d 湿%d\n可信  烟%d 光%d 温%d 湿%d" % [
		int(raw_data.smoke), int(raw_data.light), int(raw_data.temp), int(raw_data.humidity),
		int(trusted_data.smoke), int(trusted_data.light), int(trusted_data.temp), int(trusted_data.humidity)
	]
	status_label.text = "处理点 %d  ·  防护 %d  ·  连携 %d  ·  诊断 %d  ·  报警 %d" % [processing_points, block, chain_count, diagnosis, alarm_markers]
	_clear_children(hand_row)
	for index in range(hand.size()):
		var card := hand[index] as Dictionary
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if bool(card.get("negative", false)):
			button.text = "%s\n\n负面状态\n%s" % [card.get("name", "状态"), _negative_effect_text(card)]
			button.disabled = true
			_skin_button(button, Color("#9b3f3b"))
		else:
			var cost := _card_cost_preview(card)
			button.text = "%s  [%d]\n%s\n\n%s" % [card.get("name", "卡牌"), cost, card.get("type", ""), card.get("upgradedEffectText", "") if bool(card.get("upgraded", false)) else card.get("effectText", "")]
			button.tooltip_text = str(card.get("knowledgePoint", ""))
			button.disabled = processing_points < cost or !_card_requirements_met(card)
			_skin_button(button, _card_accent(card))
			button.pressed.connect(func() -> void:
				play_card(index)
				_render_state()
			)
		button.custom_minimum_size = Vector2(154 if size.x < 720.0 else 176, 188 if size.x < 720.0 else 260)
		hand_row.add_child(button)
	end_turn_button.disabled = false


func _active_gate_met(tier: String) -> bool:
	if tier == "boss":
		return _boss_phase_requirements_met()
	if tier == "checkpoint":
		return _checkpoint_requirements_met()
	return repair_progress >= repair_target and _encounter_requirements_met()


func _gate_status_text(tier: String) -> String:
	if tier == "boss":
		match boss_phase:
			0:
				return "验收证据  ·  来源覆盖 %d / 2" % phase_source_coverage.size()
			1:
				return "验收证据  ·  可信来源 %d / 2  ·  滤波 %d / 1" % [phase_trusted_sources.size(), mini(phase_filters_played, 1)]
			2:
				var has_report := bool(phase_output_types.get("display", false)) or bool(phase_output_types.get("uart", false)) or bool(persistent_output_types.get("display", false)) or bool(persistent_output_types.get("uart", false))
				var has_control := bool(phase_output_types.get("alarm", false)) or bool(phase_output_types.get("scheduler", false)) or bool(persistent_output_types.get("alarm", false)) or bool(persistent_output_types.get("scheduler", false))
				return "验收证据  ·  显示/上报 %d / 1  ·  报警/调度 %d / 1" % [1 if has_report else 0, 1 if has_control else 0]
	if tier == "checkpoint":
		if str(current_node.get("type", "")) == "checkpoint_sensor":
			return "检查目标  ·  完成来源链路 %d / 2" % trusted_sources_seen.size()
		return "检查目标  ·  可信来源 %d / 2  ·  滤波 %d / 1" % [trusted_sources_seen.size(), mini(filters_played, 1)]
	var groups: Array = current_encounter.get("evidenceGroups", [])
	if groups.is_empty():
		return "修复目标  ·  达到目标值后完成当前故障"
	var missing := _missing_evidence_labels()
	return "工程证据  ·  %d / %d%s" % [_completed_evidence_group_count(), groups.size(), "" if missing.is_empty() else "  ·  缺少 " + "、".join(missing)]


func _card_cost_preview(card: Dictionary) -> int:
	var cost := int(card.get("upgradeCost", card.get("cost", 0))) if bool(card.get("upgraded", false)) else int(card.get("cost", 0))
	var tags: Array = card.get("tags", [])
	if tags.has("i2c"):
		cost += i2c_cost_penalty
		if int(powers.get("i2c_discount", 0)) > 0:
			cost -= 1
	if str(card.get("type", "")) == "process" and int(powers.get("process_discount", 0)) > 0:
		cost -= 1
	return maxi(cost, 0)


func _card_accent(card: Dictionary) -> Color:
	match str(card.get("type", "")):
		"collect": return Color("#b75a3a")
		"interface": return Color("#2f7f8d")
		"process": return Color("#725c91")
		"defense": return Color("#517943")
		"output": return Color("#b16a2c")
		"power": return Color("#8b6b23")
	return Color("#60757b")


func _negative_effect_text(card: Dictionary) -> String:
	var effect := card.get("drawEffect", {}) as Dictionary
	return "%s %s" % [effect.get("type", "影响"), effect.get("amount", "")]


func _current_intent_text() -> String:
	if current_intents.is_empty():
		return "观察系统状态"
	return str((current_intents[intent_index % current_intents.size()] as Dictionary).get("text", "故障行动"))


func _render_choices() -> void:
	_clear_children(choice_list)
	match state:
		RunState.REWARD:
			choice_title.text = "选择一张工程卡牌"
			choice_description.text = "补足当前链路，或跳过以保持牌组精简。"
			var debug_summary := _latest_debug_summary()
			if !debug_summary.is_empty():
				choice_description.text += "\n" + debug_summary
			for raw_card in reward_choices:
				var card := raw_card as Dictionary
				var button := Button.new()
				button.text = "%s  [%d]\n%s" % [card.get("name", "卡牌"), card.get("cost", 0), card.get("effectText", "")]
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, _card_accent(card))
				_size_choice_button(button, 104)
				button.pressed.connect(func() -> void:
					choose_reward(str(card.get("id", "")))
					_render_state()
				)
				choice_list.add_child(button)
			var skip := Button.new()
			skip.text = "跳过奖励"
			_skin_button(skip, Color("#697b80"))
			_size_choice_button(skip, 72)
			skip.pressed.connect(func() -> void:
				choose_reward("")
				_render_state()
			)
			choice_list.add_child(skip)
		RunState.EVENT:
			choice_title.text = str(current_event.get("name", "调试事件"))
			choice_description.text = str(current_event.get("description", ""))
			var options: Array = current_event.get("options", [])
			for index in range(options.size()):
				var option := options[index] as Dictionary
				var button := Button.new()
				button.text = str(option.get("label", "选择"))
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, Color("#725c91"))
				_size_choice_button(button, 88)
				button.pressed.connect(func() -> void:
					choose_event_option(index)
					_render_state()
				)
				choice_list.add_child(button)
		RunState.SHOP:
			choice_title.text = "器材商店 · 预算 %d" % budget
			choice_description.text = "购买卡牌，或离开继续调试。"
			for raw_card in shop_cards:
				var card := raw_card as Dictionary
				var button := Button.new()
				button.text = "%s · %d 预算\n%s" % [card.get("name", "卡牌"), card.get("price", 0), card.get("effectText", "")]
				button.disabled = budget < int(card.get("price", 0))
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, _card_accent(card))
				_size_choice_button(button, 96)
				button.pressed.connect(func() -> void:
					purchase_shop_card(str(card.get("id", "")))
					_render_state()
				)
				choice_list.add_child(button)
			var leave := Button.new()
			leave.text = "离开商店"
			_skin_button(leave, Color("#697b80"))
			_size_choice_button(leave, 72)
			leave.pressed.connect(func() -> void:
				leave_shop()
				_render_state()
			)
			choice_list.add_child(leave)
		RunState.REST:
			choice_title.text = str(current_node.get("label", "阶段维护"))
			choice_description.text = "选择一项整备操作。" if current_layer < RUN_NODE_COUNT - 1 else "Boss 前最后一次整备。"
			_add_service_button("设备维护 · 恢复 30% 稳定度", "maintenance", Color("#517943"))
			_add_service_button("固件优化 · 升级一张牌", "upgrade", Color("#2f7f8d"))
			_add_service_button("线束整理 · 删除基础牌，稳定度 -5", "remove", Color("#b16a2c"))
			_add_service_button("进入器材商店", "shop", Color("#725c91"))
		RunState.COMPONENT:
			choice_title.text = "选择工程组件"
			choice_description.text = "组件在本局后续战斗中持续生效。"
			for raw_component in component_choices:
				var component := raw_component as Dictionary
				var button := Button.new()
				button.text = "%s\n%s" % [component.get("name", "工程组件"), component.get("description", "")]
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, Color("#8b6b23"))
				_size_choice_button(button, 96)
				button.pressed.connect(func() -> void:
					choose_component(str(component.get("id", "")))
					_render_state()
				)
				choice_list.add_child(button)


func _add_service_button(text: String, action_id: String, accent: Color) -> void:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skin_button(button, accent)
	_size_choice_button(button, 82)
	button.pressed.connect(func() -> void:
		choose_service(action_id)
		_render_state()
	)
	choice_list.add_child(button)


func _size_choice_button(button: Button, minimum_height: float) -> void:
	button.custom_minimum_size = Vector2(260, minimum_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _render_result() -> void:
	result_title.text = "综合验收通过" if victory else "调试中止"
	result_title.add_theme_color_override("font_color", Color("#226c59") if victory else Color("#8d2f2a"))
	result_summary.text = "得分 %d / 100\n到达节点 %d / %d\n稳定度 %d / %d\n检查点 %d / 2\n牌组 %d 张\n%s" % [
		score, current_layer, RUN_NODE_COUNT, stability, max_stability, checkpoints_passed, deck.size(), _learning_summary()
	]


func _learning_summary() -> String:
	var base_summary := ""
	if checkpoints_passed >= 2:
		base_summary = "采集、可信处理与输出闭环已完成。"
	elif checkpoint_results.is_empty():
		base_summary = "建议先建立采集到输出的完整链路。"
	else:
		base_summary = "建议复习未通过的教学检查点。"
	if debug_reports.is_empty():
		return base_summary
	var latest := debug_reports.back() as Dictionary
	return "%s\n调试报告 %d 份  ·  最近结论：%s" % [base_summary, debug_reports.size(), latest.get("knowledgePoint", "已完成工程证据验证")]


func _record_debug_report(passed: bool = true, title_override: String = "") -> void:
	var evidence: Array[String] = []
	for raw_tag in encounter_evidence_tags.keys():
		evidence.append(str(raw_tag))
	evidence.sort()
	var title := title_override
	if title.is_empty():
		title = str(current_encounter.get("name", current_encounter.get("id", "调试节点")))
	var knowledge_point := str(current_encounter.get("knowledgePoint", ""))
	if knowledge_point.is_empty():
		knowledge_point = "已验证采集、处理与输出所需的工程证据。" if passed else "工程证据尚未完整。"
	debug_reports.append({
		"encounterId": str(current_encounter.get("id", "")),
		"title": title,
		"evidence": evidence,
		"passed": passed,
		"knowledgePoint": knowledge_point
	})
	while debug_reports.size() > 12:
		debug_reports.pop_front()


func _latest_debug_summary() -> String:
	if debug_reports.is_empty():
		return ""
	var report := debug_reports.back() as Dictionary
	var evidence: Array = report.get("evidence", [])
	var evidence_text := "无" if evidence.is_empty() else "、".join(evidence)
	return "调试报告：%s  ·  证据 %s  ·  %s" % [report.get("title", "调试节点"), evidence_text, report.get("knowledgePoint", "")]


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _load_local_content() -> void:
	card_defs = _index_by_id(_load_json_array("res://data/cards.local.json", "cards"))
	var enemy_payload := _load_json("res://data/enemies.local.json")
	enemy_defs = _index_by_id(enemy_payload.get("enemies", []))
	negative_defs = _index_by_id(enemy_payload.get("negativeCards", []))
	event_defs = _index_by_id(_load_json_array("res://data/events.local.json", "events"))
	relic_defs = _index_by_id(_load_json_array("res://data/relics.local.json", "relics"))
	map_defs = _index_by_id(_load_json_array("res://data/run_maps.local.json", "maps"))


func _load_json(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		push_error("Missing Ch09 data file: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid Ch09 data file: %s" % path)
		return {}
	return parsed as Dictionary


func _load_json_array(path: String, key: String) -> Array:
	var payload := _load_json(path)
	var value = payload.get(key, [])
	return value as Array if typeof(value) == TYPE_ARRAY else []


func _index_by_id(items: Array) -> Dictionary:
	var result := {}
	for raw_item in items:
		var item := raw_item as Dictionary
		result[str(item.get("id", ""))] = item
	return result


func _reset_run() -> void:
	if runtime != null:
		runtime.begin_attempt()
	completed = false
	victory = false
	score = 0
	started_at = Time.get_ticks_msec()
	stability = max_stability
	budget = 30
	current_layer = 0
	visited_nodes.clear()
	checkpoints_passed = 0
	checkpoint_results.clear()
	boss_phase = 0
	boss_review_used = false
	pre_boss_stability = max_stability
	relics.clear()
	powers.clear()
	message_log.clear()
	debug_reports.clear()
	component_choices.clear()
	deck.clear()
	for card_id in STARTER_CARD_IDS:
		deck.append(_card_copy(card_id))
	run_map = (map_defs.get(run_map_id, map_defs.get("mvp_a", {})) as Dictionary).duplicate(true)
	rng.seed = int(run_map.get("seedId", 901))
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	_reset_combat_resources()
	_draw_cards(5)
	state = RunState.MAP
	_log("调试路线已初始化。")


func _reset_combat_resources() -> void:
	processing_points = 3
	next_turn_energy = 0
	block = 0
	raw_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	trusted_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	retain_data = false
	diagnosis = 0
	alarm_markers = 0
	chain_count = 0
	last_stage = ""
	turn_number = 0
	turn_card_types.clear()
	turn_sources.clear()
	source_coverage.clear()
	output_types.clear()
	trusted_sources_seen.clear()
	filters_played = 0
	encounter_evidence_tags.clear()
	_reset_boss_phase_metrics()
	persistent_output_types.clear()
	repair_penalty = 0
	i2c_cost_penalty = 0
	pending_i2c_count = 0
	current_node = {}
	current_encounter = {}
	current_intents.clear()
	intent_index = 0
	repair_target = 0
	repair_progress = 0


func _card_copy(card_id: String) -> Dictionary:
	if !card_defs.has(card_id):
		return {}
	var result := (card_defs[card_id] as Dictionary).duplicate(true)
	result["upgraded"] = bool(result.get("upgraded", false))
	return result


func _negative_card(card_id: String) -> Dictionary:
	var result := (negative_defs.get(card_id, {"id": card_id, "name": card_id, "group": "status"}) as Dictionary).duplicate(true)
	result["negative"] = true
	return result


func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temp


func _draw_cards(amount: int) -> void:
	for _index in range(amount):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				return
			draw_pile = discard_pile.duplicate(true)
			discard_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			return
		var card = draw_pile.pop_back()
		hand.append(card)
		if bool((card as Dictionary).get("negative", false)):
			_apply_negative_draw(card as Dictionary)


func _start_encounter(enemy_id: String, tier: String = "ordinary") -> void:
	var selected_node := current_node.duplicate(true)
	_reset_combat_resources()
	current_node = selected_node
	draw_pile = deck.duplicate(true)
	if tier == "boss":
		rng.seed = BOSS_DRAW_SEED
	_shuffle(draw_pile)
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	current_encounter = (enemy_defs.get(enemy_id, {}) as Dictionary).duplicate(true)
	if current_encounter.is_empty():
		push_error("Unknown encounter: %s" % enemy_id)
		return
	current_encounter["tier"] = tier if tier != "" else current_encounter.get("tier", "ordinary")
	if str(current_encounter.get("tier", "")) == "boss":
		boss_phase = clampi(boss_phase, 0, 2)
		_apply_boss_phase()
	else:
		repair_target = int(current_encounter.get("repairTarget", 24))
		current_intents = (current_encounter.get("intentPattern", []) as Array).duplicate(true)
	repair_progress = 0
	intent_index = 0
	state = RunState.COMBAT
	_reset_turn_state(true)
	_draw_cards(5)
	_log("进入故障：%s" % current_encounter.get("name", enemy_id))


func choose_node(choice_index: int) -> bool:
	if state != RunState.MAP:
		return false
	var layers: Array = run_map.get("layers", [])
	if current_layer < 0 or current_layer >= layers.size():
		return false
	var layer := layers[current_layer] as Dictionary
	var choices: Array = layer.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return false
	current_node = (choices[choice_index] as Dictionary).duplicate(true)
	visited_nodes.append(current_node.duplicate(true))
	current_layer += 1
	if runtime != null:
		runtime.report_progress(_run_progress(), str(current_node.get("label", "调试节点")), _run_stats())
	var node_type := str(current_node.get("type", ""))
	match node_type:
		"ordinary", "elite":
			_start_encounter(str(current_node.get("contentId", "")), node_type)
		"checkpoint_sensor":
			_start_checkpoint(true)
		"checkpoint_trust":
			_start_checkpoint(false)
		"boss":
			pre_boss_stability = stability
			boss_phase = 0
			_start_encounter(str(current_node.get("contentId", "warehouse_acceptance")), "boss")
		"event":
			current_event = (event_defs.get(str(current_node.get("contentId", "")), {}) as Dictionary).duplicate(true)
			state = RunState.EVENT
		"shop":
			_open_shop()
		"service":
			state = RunState.REST
		"component":
			_open_component_choice()
		_:
			return false
	return true


func _start_checkpoint(sensor_checkpoint: bool) -> void:
	var selected_node := current_node.duplicate(true)
	_reset_combat_resources()
	current_node = selected_node
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	current_encounter = {
		"id": "sensor_checkpoint" if sensor_checkpoint else "trust_checkpoint",
		"name": "传感器接入检查" if sensor_checkpoint else "数据可信检查",
		"tier": "checkpoint",
		"weaknessTags": ["smoke", "light", "temp", "humidity"] if sensor_checkpoint else ["filter", "calibration", "calculation"]
	}
	repair_target = 18 if sensor_checkpoint else 21
	repair_progress = 0
	current_intents = [
		{"type": "damage", "amount": 4, "text": "检查时间流逝：稳定度 -4"}
	]
	state = RunState.COMBAT
	_reset_turn_state(true)
	var guided_hand := ["mq2_sample", "bh1750_read", "adc_convert", "i2c_transaction", "unit_convert"] if sensor_checkpoint else ["mq2_sample", "bh1750_read", "adc_convert", "i2c_transaction", "sliding_average"]
	for card_id in guided_hand:
		hand.append(_card_copy(card_id))
	var guided_second_hand := ["sliding_average", "bh1750_read", "hdc1080_read", "i2c_transaction", "unit_convert"] if sensor_checkpoint else ["adc_convert", "i2c_transaction", "sliding_average", "mq2_sample", "hdc1080_read"]
	for index in range(guided_second_hand.size() - 1, -1, -1):
		draw_pile.append(_card_copy(guided_second_hand[index]))
	_log("进入教学检查点。")


func _run_progress() -> float:
	return clampf(float(current_layer) / float(RUN_NODE_COUNT), 0.0, 1.0)


func _apply_boss_phase() -> void:
	var phases: Array = current_encounter.get("phases", [])
	if phases.is_empty():
		return
	var phase_data := phases[boss_phase] as Dictionary
	repair_target = int(phase_data.get("repairTarget", 28))
	current_intents = (phase_data.get("intentPattern", []) as Array).duplicate(true)
	_reset_boss_phase_metrics()


func _reset_boss_phase_metrics() -> void:
	phase_source_coverage.clear()
	phase_trusted_sources.clear()
	phase_filters_played = 0
	phase_output_types.clear()


func _reset_turn_state(first_turn: bool = false) -> void:
	turn_number += 1
	processing_points = 3 + next_turn_energy
	next_turn_energy = 0
	block = 0
	chain_count = 0
	last_stage = ""
	turn_card_types.clear()
	turn_sources.clear()
	pending_i2c_count = 0
	if !first_turn:
		hand.clear()
		_draw_cards(5)


func play_card(hand_index: int) -> bool:
	if state != RunState.COMBAT or hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)):
		return false
	var cost := _card_cost_preview(card)
	if processing_points < cost:
		return false
	if !_card_requirements_met(card):
		return false
	_consume_card_discounts(card)
	processing_points -= cost
	hand.remove_at(hand_index)
	_advance_chain(str(card.get("stage", "")))
	var tags: Array = card.get("tags", [])
	for raw_tag in tags:
		var tag := str(raw_tag)
		encounter_evidence_tags[tag] = true
		if SOURCE_ORDER.has(tag):
			turn_sources[tag] = true
		if ["display", "uart", "alarm", "scheduler"].has(tag):
			output_types[tag] = true
			if str(current_encounter.get("tier", "")) == "boss":
				phase_output_types[tag] = true
			if str(card.get("type", "")) == "power":
				persistent_output_types[tag] = true
	turn_card_types[str(card.get("type", ""))] = true
	if tags.has("filter"):
		filters_played += 1
		if str(current_encounter.get("tier", "")) == "boss":
			phase_filters_played += 1
	var repair_before := repair_progress
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	var trusted_spent := 0
	for raw_effect in effects:
		trusted_spent += _apply_card_effect(raw_effect as Dictionary, card, trusted_spent)
	var matched_weaknesses := _matched_weakness_tags(card)
	if !matched_weaknesses.is_empty():
		var bonus_text := "  ·  诊断修复 +2" if diagnosis > 0 and repair_progress > repair_before else ""
		_log("%s 命中弱点：%s%s" % [card.get("name", card.get("id", "card")), "/".join(matched_weaknesses), bonus_text])
	if str(card.get("type", "")) == "power":
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	if repair_progress >= repair_target:
		if str(current_encounter.get("tier", "")) != "checkpoint" or _checkpoint_requirements_met():
			_finish_encounter()
	return true


func _consume_card_discounts(card: Dictionary) -> void:
	var tags: Array = card.get("tags", [])
	if tags.has("i2c") and int(powers.get("i2c_discount", 0)) > 0:
		powers["i2c_discount"] = int(powers.get("i2c_discount", 0)) - 1
	if str(card.get("type", "")) == "process" and int(powers.get("process_discount", 0)) > 0:
		powers["process_discount"] = int(powers.get("process_discount", 0)) - 1


func _card_requirements_met(card: Dictionary) -> bool:
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if effect.has("consumeTrusted") and _trusted_total() < int(effect.get("consumeTrusted", 0)):
			return false
		if effect.has("consumeTrustedSource"):
			var source := str(effect.get("consumeTrustedSource", ""))
			if int(trusted_data.get(source, 0)) <= 0 and alarm_markers < int(effect.get("consumeAlarmFallback", 0)):
				return false
	return true


func _advance_chain(stage: String) -> void:
	var stage_index := STAGE_ORDER.find(stage)
	var last_index := STAGE_ORDER.find(last_stage)
	if stage_index == 0:
		chain_count = 0
	elif last_index >= 0 and stage_index == last_index + 1:
		chain_count = mini(chain_count + 1, 3)
	elif stage != last_stage:
		chain_count = 0
	last_stage = stage
	if chain_count >= 3 and int(powers.get("chain_energy", 0)) > 0 and !bool(powers.get("chain_energy_used", false)):
		processing_points += int(powers.get("chain_energy", 0))
		powers["chain_energy_used"] = true


func _apply_card_effect(effect: Dictionary, card: Dictionary, trusted_spent: int) -> int:
	if int(effect.get("requiresDiagnosis", 0)) > diagnosis:
		return 0
	if int(effect.get("requiresChain", 0)) > chain_count:
		return 0
	if int(effect.get("requiresTrustedSpent", 0)) > trusted_spent:
		return 0
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
		"gain_raw":
			var source := str(effect.get("source", "smoke"))
			_add_data(raw_data, source, amount)
			source_coverage[source] = true
			if str(current_encounter.get("tier", "")) == "boss":
				phase_source_coverage[source] = true
		"gain_trusted":
			var source := str(effect.get("source", "smoke"))
			_add_data(trusted_data, source, amount)
			trusted_sources_seen[source] = true
			source_coverage[source] = true
			if str(current_encounter.get("tier", "")) == "boss":
				phase_trusted_sources[source] = true
				phase_source_coverage[source] = true
		"convert":
			_convert_data(str(effect.get("source", "any")), amount)
		"repair":
			var spent := _consume_for_effect(effect)
			if effect.has("consumeTrusted") or effect.has("consumeTrustedSource"):
				if spent <= 0:
					return 0
			_add_repair(amount, card)
			return spent
		"batch_repair":
			var spent := _consume_trusted(amount)
			_add_repair(spent * int(effect.get("repairPer", 0)), card)
			return spent
		"block":
			block += amount
		"draw":
			_draw_cards(amount)
		"diagnose":
			diagnosis = mini(diagnosis + amount, 3)
		"gain_alarm":
			var spent := _consume_trusted(int(effect.get("consumeTrusted", 0)))
			if spent > 0 or !effect.has("consumeTrusted"):
				alarm_markers = mini(alarm_markers + amount, 3)
			return spent
		"remove_negative":
			_remove_negative(str(effect.get("kind", "")), amount)
		"next_energy":
			next_turn_energy += amount
		"retain_data":
			retain_data = true
		"heal":
			stability = mini(max_stability, stability + amount)
		"power":
			var power_id := str(effect.get("id", ""))
			powers[power_id] = int(powers.get(power_id, 0)) + amount
	return 0


func _consume_for_effect(effect: Dictionary) -> int:
	if effect.has("consumeTrustedSource"):
		var source := str(effect.get("consumeTrustedSource", ""))
		if int(trusted_data.get(source, 0)) > 0:
			trusted_data[source] = int(trusted_data.get(source, 0)) - 1
			return 1
		var fallback := int(effect.get("consumeAlarmFallback", 0))
		if fallback > 0 and alarm_markers >= fallback:
			alarm_markers -= fallback
			return fallback
	if effect.has("consumeTrusted"):
		return _consume_trusted(int(effect.get("consumeTrusted", 0)))
	return 0


func _convert_data(source: String, amount: int) -> int:
	var converted := 0
	var candidates: Array = SOURCE_ORDER.duplicate()
	if source == "smoke":
		candidates = ["smoke"]
	elif source == "i2c_any":
		candidates = ["light", "temp", "humidity"]
	for candidate in candidates:
		while converted < amount and int(raw_data.get(candidate, 0)) > 0:
			raw_data[candidate] = int(raw_data.get(candidate, 0)) - 1
			trusted_data[candidate] = int(trusted_data.get(candidate, 0)) + 1
			trusted_sources_seen[candidate] = true
			source_coverage[candidate] = true
			if str(current_encounter.get("tier", "")) == "boss":
				phase_trusted_sources[candidate] = true
				phase_source_coverage[candidate] = true
			converted += 1
		if converted >= amount:
			break
	return converted


func _add_data(target: Dictionary, source: String, amount: int) -> void:
	target[source] = int(target.get(source, 0)) + amount


func _trusted_total() -> int:
	var total := 0
	for source in SOURCE_ORDER:
		total += int(trusted_data.get(source, 0))
	return total


func _consume_trusted(amount: int) -> int:
	var consumed := 0
	for source in SOURCE_ORDER:
		while consumed < amount and int(trusted_data.get(source, 0)) > 0:
			trusted_data[source] = int(trusted_data.get(source, 0)) - 1
			consumed += 1
		if consumed >= amount:
			break
	return consumed


func _add_repair(amount: int, card: Dictionary) -> void:
	var adjusted := maxi(amount - repair_penalty, 0)
	var tags: Array = card.get("tags", [])
	if tags.has("smoke"):
		adjusted += int(powers.get("smoke_repair", 0))
	var weakness: Array = current_encounter.get("weaknessTags", [])
	if diagnosis > 0 and _arrays_intersect(tags, weakness):
		adjusted += 2
	if str(current_encounter.get("tier", "")) == "boss":
		adjusted = adjusted * 2 if boss_phase < 2 else adjusted + int(ceil(adjusted * 0.5))
	repair_progress = mini(repair_target, repair_progress + adjusted)


func _arrays_intersect(left: Array, right: Array) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _matched_weakness_tags(card: Dictionary) -> Array[String]:
	var matched: Array[String] = []
	var tags: Array = card.get("tags", [])
	var weakness: Array = current_encounter.get("weaknessTags", [])
	for raw_tag in tags:
		var tag := str(raw_tag)
		if weakness.has(tag):
			matched.append(tag)
	return matched


func _encounter_requirements_met() -> bool:
	var groups: Array = current_encounter.get("evidenceGroups", [])
	for raw_group in groups:
		var group := raw_group as Array
		var group_met := false
		for raw_tag in group:
			if bool(encounter_evidence_tags.get(str(raw_tag), false)):
				group_met = true
				break
		if !group_met:
			return false
	return true


func _completed_evidence_group_count() -> int:
	var completed_groups := 0
	var groups: Array = current_encounter.get("evidenceGroups", [])
	for raw_group in groups:
		var group := raw_group as Array
		for raw_tag in group:
			if bool(encounter_evidence_tags.get(str(raw_tag), false)):
				completed_groups += 1
				break
	return completed_groups


func _missing_evidence_labels() -> Array[String]:
	var missing: Array[String] = []
	var groups: Array = current_encounter.get("evidenceGroups", [])
	for raw_group in groups:
		var group := raw_group as Array
		var group_met := false
		var labels: Array[String] = []
		for raw_tag in group:
			var tag := str(raw_tag)
			labels.append(tag)
			if bool(encounter_evidence_tags.get(tag, false)):
				group_met = true
		if !group_met:
			missing.append("/".join(labels))
	return missing


func _remove_negative(kind: String, amount: int) -> int:
	var removed := 0
	for pile in [hand, draw_pile, discard_pile]:
		for index in range(pile.size() - 1, -1, -1):
			if removed >= amount:
				return removed
			var card := pile[index] as Dictionary
			if !bool(card.get("negative", false)):
				continue
			if kind == "noise" and str(card.get("group", "")) == "noise":
				pile.remove_at(index)
				removed += 1
			elif kind == "i2c" and str(card.get("group", "")) == "i2c":
				pile.remove_at(index)
				removed += 1
			elif str(card.get("id", "")) == kind:
				pile.remove_at(index)
				removed += 1
	return removed


func _pile_has_card(card_id: String) -> bool:
	for pile in [hand, draw_pile, discard_pile, exhaust_pile]:
		for raw_card in pile:
			if str((raw_card as Dictionary).get("id", "")) == card_id:
				return true
	return false


func _hand_has_card(card_id: String) -> bool:
	for raw_card in hand:
		if str((raw_card as Dictionary).get("id", "")) == card_id:
			return true
	return false


func _apply_negative_draw(card: Dictionary) -> void:
	var effect := card.get("drawEffect", {}) as Dictionary
	match str(effect.get("type", "")):
		"damage":
			_take_damage(int(effect.get("amount", 0)))
		"repair_penalty":
			repair_penalty += int(effect.get("amount", 0))
		"energy":
			processing_points = maxi(0, processing_points + int(effect.get("amount", 0)))
		"i2c_cost":
			i2c_cost_penalty += int(effect.get("amount", 0))
		"raw_loss":
			_remove_raw(int(effect.get("amount", 0)))


func _remove_raw(amount: int) -> void:
	var remaining := amount
	for source in SOURCE_ORDER:
		var removed := mini(remaining, int(raw_data.get(source, 0)))
		raw_data[source] = int(raw_data.get(source, 0)) - removed
		remaining -= removed
		if remaining <= 0:
			return


func _take_damage(amount: int) -> void:
	var blocked := mini(block, amount)
	block -= blocked
	stability = maxi(0, stability - (amount - blocked))


func end_turn() -> void:
	if state != RunState.COMBAT:
		return
	for raw_card in hand:
		discard_pile.append(raw_card)
	hand.clear()
	_resolve_intent()
	if stability <= 0:
		_handle_defeat()
		return
	if str(current_encounter.get("tier", "")) == "checkpoint" and turn_number >= 2:
		_finish_checkpoint(repair_progress >= repair_target)
		return
	if !retain_data and str(current_encounter.get("tier", "")) != "checkpoint":
		raw_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
		trusted_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	retain_data = false
	powers.erase("chain_energy_used")
	_reset_turn_state(false)


func _resolve_intent() -> void:
	if current_intents.is_empty():
		return
	var intent := current_intents[intent_index % current_intents.size()] as Dictionary
	intent_index += 1
	match str(intent.get("type", "")):
		"damage":
			_take_damage(int(intent.get("amount", 0)))
		"negative":
			discard_pile.append(_negative_card(str(intent.get("card", ""))))
	_log(str(intent.get("text", "故障行动")))


func _finish_encounter() -> void:
	if state != RunState.COMBAT:
		return
	var tier := str(current_encounter.get("tier", "ordinary"))
	if tier == "boss":
		if !_boss_phase_requirements_met():
			_log("修复值已达标，但阶段验收证据不足。")
			return
		var phases: Array = current_encounter.get("phases", [])
		var phase_title := str((phases[boss_phase] as Dictionary).get("name", "验收阶段")) if boss_phase < phases.size() else "验收阶段"
		_record_debug_report(true, phase_title)
		if boss_phase < 2:
			boss_phase += 1
			_apply_boss_phase()
			repair_progress = 0
			intent_index = 0
			block = 0
			processing_points = mini(processing_points + 1, 3)
			chain_count = 0
			last_stage = ""
			for raw_card in hand:
				discard_pile.append(raw_card)
			hand.clear()
			_draw_cards(5)
			_log("验收进入阶段 %d。" % (boss_phase + 1))
			return
		_finish_run(true)
		return
	if tier == "checkpoint":
		_finish_checkpoint(true)
		return
	if !_encounter_requirements_met():
		_log("修复进度达标，但缺少工程证据：%s" % "、".join(_missing_evidence_labels()))
		return
	_record_debug_report(true)
	budget += 45 if tier == "elite" else 24
	if tier == "elite":
		_grant_random_relic()
	_open_reward()


func _boss_phase_requirements_met() -> bool:
	match boss_phase:
		0:
			return phase_source_coverage.size() >= 2
		1:
			return phase_trusted_sources.size() >= 2 and phase_filters_played > 0
		2:
			var has_report := bool(phase_output_types.get("display", false)) or bool(phase_output_types.get("uart", false)) or bool(persistent_output_types.get("display", false)) or bool(persistent_output_types.get("uart", false))
			var has_control := bool(phase_output_types.get("alarm", false)) or bool(phase_output_types.get("scheduler", false)) or bool(persistent_output_types.get("alarm", false)) or bool(persistent_output_types.get("scheduler", false))
			return has_report and has_control
	return false
	_log("故障修复完成。")


func _finish_checkpoint(repaired: bool) -> void:
	var sensor_checkpoint := str(current_node.get("type", "")) == "checkpoint_sensor"
	var passed := repaired and _checkpoint_requirements_met()
	_record_debug_report(passed)
	checkpoint_results.append({
		"id": "sensor" if sensor_checkpoint else "trust",
		"passed": passed
	})
	if passed:
		checkpoints_passed += 1
		stability = mini(max_stability, stability + 6)
	else:
		stability = maxi(1, stability - 8)
		if !sensor_checkpoint:
			deck.append(_negative_card("unverified_config"))
	_open_reward()


func _checkpoint_requirements_met() -> bool:
	var sensor_checkpoint := str(current_node.get("type", "")) == "checkpoint_sensor"
	if sensor_checkpoint:
		return trusted_sources_seen.size() >= 2
	return trusted_sources_seen.size() >= 2 and filters_played > 0 and !_hand_has_card("abnormal_reading")


func _open_reward() -> void:
	reward_choices.clear()
	var candidates: Array = []
	for card_id in card_defs.keys():
		var card := card_defs[card_id] as Dictionary
		if str(card.get("rarity", "")) != "starter":
			candidates.append(str(card_id))
	candidates.sort()
	_shuffle(candidates)
	for index in range(mini(3, candidates.size())):
		reward_choices.append(_card_copy(str(candidates[index])))
	state = RunState.REWARD


func choose_reward(card_id: String) -> bool:
	if state != RunState.REWARD:
		return false
	if !card_id.is_empty():
		var valid := false
		for raw_card in reward_choices:
			if str((raw_card as Dictionary).get("id", "")) == card_id:
				valid = true
				break
		if !valid:
			return false
		deck.append(_card_copy(card_id))
	reward_choices.clear()
	state = RunState.MAP
	return true


func choose_event_option(option_index: int) -> bool:
	if state != RunState.EVENT:
		return false
	var options: Array = current_event.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return false
	var option := options[option_index] as Dictionary
	for raw_effect in option.get("effects", []):
		_apply_run_effect(raw_effect as Dictionary)
	current_event = {}
	state = RunState.MAP
	return true


func _apply_run_effect(effect: Dictionary) -> void:
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
		"budget":
			budget = maxi(0, budget + amount)
		"heal":
			stability = mini(max_stability, stability + amount)
		"add_card":
			deck.append(_card_copy(str(effect.get("cardId", ""))))
		"add_upgraded_card":
			var card := _card_copy(str(effect.get("cardId", "")))
			card["upgraded"] = true
			deck.append(card)
		"add_negative":
			deck.append(_negative_card(str(effect.get("cardId", ""))))
		"upgrade_card":
			_upgrade_first_card()
		"remove_card":
			_remove_first_basic_card()
		"remove_all_negative":
			for index in range(deck.size() - 1, -1, -1):
				if bool((deck[index] as Dictionary).get("negative", false)):
					deck.remove_at(index)
		"next_diagnosis":
			powers["next_diagnosis"] = int(powers.get("next_diagnosis", 0)) + amount


func _upgrade_first_card() -> bool:
	for raw_card in deck:
		var card := raw_card as Dictionary
		if !bool(card.get("negative", false)) and !bool(card.get("upgraded", false)):
			card["upgraded"] = true
			return true
	return false


func _remove_first_basic_card() -> bool:
	if deck.size() <= 6:
		return false
	for index in range(deck.size()):
		var card := deck[index] as Dictionary
		if str(card.get("rarity", "")) == "starter":
			deck.remove_at(index)
			return true
	return false


func _open_shop() -> void:
	shop_cards.clear()
	var ids: Array = card_defs.keys()
	ids.sort()
	_shuffle(ids)
	var gap_card_id := _boss_gap_card_id()
	if gap_card_id != "" and ids.has(gap_card_id):
		var gap_card := _card_copy(gap_card_id)
		gap_card["price"] = _card_price(gap_card)
		shop_cards.append(gap_card)
		ids.erase(gap_card_id)
	for card_id in ids:
		var card := _card_copy(str(card_id))
		if str(card.get("rarity", "")) == "starter":
			continue
		card["price"] = _card_price(card)
		shop_cards.append(card)
		if shop_cards.size() >= 5:
			break
	state = RunState.SHOP


func _boss_gap_card_id() -> String:
	var has_report := _deck_has_any_tag(["display", "uart"])
	var has_control := _deck_has_any_tag(["alarm", "scheduler"])
	if !has_report:
		return "lcd_display"
	if !has_control:
		return "time_slice"
	return ""


func _deck_has_any_tag(required_tags: Array) -> bool:
	for raw_card in deck:
		var tags: Array = (raw_card as Dictionary).get("tags", [])
		for tag in required_tags:
			if tags.has(tag):
				return true
	return false


func _card_price(card: Dictionary) -> int:
	match str(card.get("rarity", "common")):
		"rare":
			return 110
		"uncommon":
			return 65
		_:
			return 40


func purchase_shop_card(card_id: String) -> bool:
	if state != RunState.SHOP:
		return false
	for index in range(shop_cards.size()):
		var card := shop_cards[index] as Dictionary
		if str(card.get("id", "")) != card_id:
			continue
		var price := int(card.get("price", 40))
		if budget < price:
			return false
		budget -= price
		deck.append(_card_copy(card_id))
		shop_cards.remove_at(index)
		return true
	return false


func leave_shop() -> bool:
	if state != RunState.SHOP:
		return false
	state = RunState.MAP
	return true


func choose_service(action_id: String) -> bool:
	if state != RunState.REST:
		return false
	match action_id:
		"maintenance":
			stability = mini(max_stability, stability + int(ceil(max_stability * 0.3)))
		"upgrade":
			_upgrade_first_card()
		"remove":
			if _remove_first_basic_card():
				stability = maxi(1, stability - 5)
		"shop":
			_open_shop()
			return true
		_:
			return false
	state = RunState.MAP
	return true


func _component_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in relic_defs.keys():
		var component_id := str(raw_id)
		if !relics.has(component_id):
			ids.append(component_id)
	ids.sort()
	_shuffle(ids)
	return ids


func _open_component_choice() -> void:
	component_choices.clear()
	var ids := _component_choice_ids()
	for index in range(mini(3, ids.size())):
		component_choices.append((relic_defs[ids[index]] as Dictionary).duplicate(true))
	if component_choices.size() < 3:
		component_choices.append({
			"id": "upgrade_fallback",
			"name": "固件优化",
			"description": "升级牌组中的第一张未升级卡牌。"
		})
	state = RunState.COMPONENT


func choose_component(component_id: String) -> bool:
	if state != RunState.COMPONENT:
		return false
	var offered := false
	for raw_component in component_choices:
		if str((raw_component as Dictionary).get("id", "")) == component_id:
			offered = true
			break
	if !offered:
		return false
	if component_id == "upgrade_fallback":
		_upgrade_first_card()
	else:
		relics.append(component_id)
		_log("获得工程组件：%s" % (relic_defs[component_id] as Dictionary).get("name", component_id))
	component_choices.clear()
	state = RunState.MAP
	return true


func _grant_random_relic() -> void:
	var ids: Array = relic_defs.keys()
	ids.sort()
	_shuffle(ids)
	for relic_id in ids:
		if !relics.has(relic_id):
			relics.append(relic_id)
			return


func _reset_lab_fixture(deck_fixture: String) -> void:
	_reset_run()
	node_lab_active = true
	lab_deck_fixture = deck_fixture
	budget = 100
	stability = max_stability
	relics.clear()
	if deck_fixture == "coverage":
		deck.clear()
		for card_id in LAB_COVERAGE_CARD_IDS:
			deck.append(_card_copy(card_id))
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	_reset_combat_resources()


func start_lab_scenario(entry: Dictionary, deck_fixture: String = "starter") -> bool:
	if entry.is_empty():
		return false
	var selected_entry := entry.duplicate(true)
	_reset_lab_fixture(deck_fixture)
	lab_current_entry = selected_entry
	var kind := str(selected_entry.get("kind", ""))
	match kind:
		"enemy":
			var tier := str(selected_entry.get("tier", "ordinary"))
			current_node = {"type": tier, "contentId": selected_entry.get("contentId", "")}
			boss_phase = 0
			_start_encounter(str(selected_entry.get("contentId", "")), tier)
		"boss_phase":
			boss_phase = int(selected_entry.get("phase", 0))
			current_node = {"type": "boss", "contentId": selected_entry.get("contentId", "warehouse_acceptance")}
			_start_encounter(str(selected_entry.get("contentId", "warehouse_acceptance")), "boss")
		"event":
			current_event = (event_defs.get(str(selected_entry.get("contentId", "")), {}) as Dictionary).duplicate(true)
			if current_event.is_empty():
				return false
			state = RunState.EVENT
		"checkpoint_sensor":
			current_node = {"type": "checkpoint_sensor"}
			_start_checkpoint(true)
		"checkpoint_trust":
			current_node = {"type": "checkpoint_trust"}
			_start_checkpoint(false)
		"component":
			_open_component_choice()
		"shop":
			_open_shop()
		"service":
			current_node = {"type": "service", "label": "节点实验室休整"}
			state = RunState.REST
		"reward":
			_open_reward()
		_:
			return false
	_render_state()
	return true


func restart_lab_scenario() -> bool:
	if lab_current_entry.is_empty():
		return false
	return start_lab_scenario(lab_current_entry, lab_deck_fixture)


func return_to_node_lab() -> void:
	_reset_combat_resources()
	reward_choices.clear()
	component_choices.clear()
	current_event.clear()
	shop_cards.clear()
	state = RunState.WAITING
	_render_state()


func _handle_defeat() -> void:
	if str(current_encounter.get("tier", "")) == "checkpoint":
		stability = 1
		_finish_checkpoint(false)
		return
	if str(current_encounter.get("tier", "")) == "boss" and !boss_review_used:
		boss_review_used = true
		stability = maxi(pre_boss_stability, 20)
		current_layer = RUN_NODE_COUNT - 1
		state = RunState.REST
		_log("验收复盘已开启，可整备后再次挑战。")
		return
	_finish_run(false)


func _finish_run(won: bool) -> void:
	if completed:
		return
	completed = true
	victory = won
	score = _calculate_score() if won else mini(59, int(round(40.0 * _run_progress())))
	state = RunState.RESULT
	if runtime != null:
		runtime.complete(score, -1, Time.get_ticks_msec() - started_at, _run_stats())
	_render_state()


func _run_stats() -> Dictionary:
	return {
		"victory": victory,
		"visitedNodes": current_layer,
		"checkpointsPassed": checkpoints_passed,
		"bossPhase": boss_phase,
		"stability": stability,
		"maxStability": max_stability,
		"deckSize": deck.size(),
		"budget": budget,
		"debugReportCount": debug_reports.size(),
		"bossReviewUsed": boss_review_used,
		"elapsedMs": maxi(Time.get_ticks_msec() - started_at, 0)
	}


func _calculate_score() -> int:
	var result := 60
	if checkpoints_passed >= 2:
		result += 10
	if relics.size() > 0:
		result += 8
	if !boss_review_used:
		result += 8
	if stability >= int(ceil(max_stability * 0.4)):
		result += 6
	if source_coverage.size() >= 3:
		result += 4
	if trusted_sources_seen.size() >= 2 and filters_played > 0:
		result += 4
	return mini(result, 89 if boss_review_used else 100)


func _log(text: String) -> void:
	message_log.append(text)
	while message_log.size() > 8:
		message_log.pop_front()
