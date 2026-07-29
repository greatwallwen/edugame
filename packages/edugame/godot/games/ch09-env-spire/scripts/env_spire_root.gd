extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")
const UI_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const TUTORIAL_VERSION := 1
const TUTORIAL_RECORD_PATH := "user://ch09_tutorial.cfg"
const STARTER_CARD_IDS := [
	"mq2_sample", "mq2_sample", "bh1750_read", "hdc1080_read",
	"adc_convert", "adc_convert", "i2c_transaction", "i2c_transaction",
	"unit_convert", "sliding_average", "sliding_average", "uart_log"
]
const SOURCE_ORDER := ["smoke", "light", "temp", "humidity"]
const STAGE_ORDER := ["collect", "interface", "process", "output"]
const BOSS_STAGE_TAG_REQUIREMENTS := [
	{"id": "source", "tags": ["smoke", "light", "temp", "humidity"]},
	{"id": "trusted", "tags": ["adc", "i2c", "calculation", "trusted_data"]},
	{"id": "filter", "tags": ["filter"]},
	{"id": "report", "tags": ["display", "uart"]},
	{"id": "control", "tags": ["alarm", "scheduler"]}
]
const BOSS_DRAW_SEED := 90909
const RUN_NODE_COUNT := 12
const TUTORIAL_ENCOUNTER := {
	"id": "training_signal_chain",
	"name": "训练故障：信号链中断",
	"tier": "tutorial",
	"repairTarget": 20,
	"weaknessTags": ["smoke", "adc", "alarm"],
	"evidenceGroups": [["smoke"], ["adc"]],
	"intentPattern": [
		{"type": "damage", "amount": 6, "text": "模拟漂移：稳定度 -6"}
	]
}
const LAB_COVERAGE_CARD_IDS := [
	"mq2_sample", "bh1750_read", "hdc1080_read", "adc_convert",
	"i2c_transaction", "sliding_average", "lcd_display",
	"uart_log", "threshold_judgement", "time_slice"
]

enum RunState { WAITING, MAP, COMBAT, REWARD, EVENT, SHOP, REST, COMPONENT, RESULT }

enum TutorialStep {
	INACTIVE,
	BRIEFING,
	READ_INTENT,
	PLAY_DEFENSE,
	END_TURN,
	PLAY_SAMPLE,
	PLAY_CONVERT,
	PLAY_OUTPUT,
	COMPLETE
}

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
var run_seed := 901
var event_history: Array[Dictionary] = []
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
var retained_cards: Array = []
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
var chain_rewards_claimed := {}
var cards_played_this_turn := 0
var reroute_available := false
var reroute_mode := false
var pending_card_selection: Dictionary = {}
var turn_effect_uses: Dictionary = {}
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
var fault_rule_state: Dictionary = {}

var current_node := {}
var current_encounter := {}
var current_intents: Array = []
var intent_index := 0
var repair_target := 0
var repair_progress := 0
var current_event := {}
var event_answer_locked := false
var event_result: Dictionary = {}
var revealed_nodes: Array[int] = []
var event_selected_answer: Variant = null
var event_ordering_answer: Array[String] = []
var reward_choices: Array = []
var component_choices: Array = []
var shop_cards: Array = []
var message_log: Array = []
var debug_reports: Array = []
var node_lab_active := false
var tutorial_step := TutorialStep.INACTIVE
var tutorial_active := false
var formal_run_active := false
var initial_experience_started := false
var tutorial_record_path := TUTORIAL_RECORD_PATH
var lab_current_entry := {}
var lab_deck_fixture := "starter"
var node_lab_overlay: CanvasLayer

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
var tutorial_view: PanelContainer
var tutorial_briefing_content: VBoxContainer
var tutorial_route_summary: Label
var tutorial_start_button: Button
var tutorial_coach_layer: PanelContainer
var tutorial_coach_text: Label
var tutorial_completion_summary: Label
var tutorial_coach_actions: HBoxContainer
var tutorial_skip_button: Button
var tutorial_intent_button: Button
var tutorial_complete_button: Button
var map_view: PanelContainer
var map_title: Label
var map_composition: BoxContainer
var map_mission_summary: Label
var map_route_scroll: ScrollContainer
var map_route: VBoxContainer
var map_next_detail: Label
var map_enter_button: Button
var combat_view: PanelContainer
var combat_layout: BoxContainer
var encounter_arena: BoxContainer
var hand_dock: VBoxContainer
var tutorial_combat_spacer: Control
var dock_header: HBoxContainer
var hand_title: Label
var engineering_chain_strip: HBoxContainer
var chain_stage_labels := {}
var combat_actions: HBoxContainer
var processing_point_counter: Label
var encounter_name_label: Label
var encounter_meta_label: Label
var intent_label: Label
var fault_intent_row: Label
var fault_rule_row: Label
var fault_counter_row: Label
var fault_rule_state_label: Label
var repair_label: Label
var repair_bar: ProgressBar
var gate_label: Label
var data_label: Label
var evidence_bridge: PanelContainer
var status_label: Label
var hand_scroll: ScrollContainer
var hand_row: HBoxContainer
var end_turn_button: Button
var reroute_button: Button
var reroute_cancel_button: Button
var action_trailing_spacer: Control
var card_selection_modal: PanelContainer
var card_selection_title: Label
var card_selection_options: GridContainer
var choice_view: PanelContainer
var choice_title: Label
var choice_description: Label
var choice_list: GridContainer
var reward_encounter_backdrop: BoxContainer
var resolved_device_context: Label
var resolved_evidence_context: Label
var resolved_fault_context: Label
var reward_cards: GridContainer
var reward_skip_button: Button
var question_event_frame: PanelContainer
var question_knowledge_tag: Label
var question_prompt: Label
var question_interaction: VBoxContainer
var question_submit: Button
var question_explanation: Label
var question_consequence: VBoxContainer
var question_continue: Button
var service_bench: PanelContainer
var result_view: PanelContainer
var result_title: Label
var result_metrics: Label
var result_learning_summary: Label
var log_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local_content()
	_load_ui()
	_build_ui()
	_setup_runtime()
	state = RunState.WAITING
	_render_state()
	if _node_lab_requested():
		call_deferred("_start_initial_experience")
	else:
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
	if initial_experience_started:
		_start_clean_formal_run()
	else:
		_start_initial_experience()
	runtime.log_info("Ch09 environment spire initialized.")


func _on_runtime_reset() -> void:
	if tutorial_active:
		_start_tutorial_briefing()
		_render_state()
		return
	_reset_run()
	_render_state()


func _start_standalone_preview_if_needed() -> void:
	if !OS.has_feature("web"):
		return
	var top_level := bool(JavaScriptBridge.eval("window.self === window.parent", true))
	if top_level:
		_start_initial_experience()


func _start_standalone_preview(top_level: bool) -> bool:
	if !top_level or state != RunState.WAITING:
		return false
	if initial_experience_started:
		_start_clean_formal_run()
	else:
		_start_initial_experience()
	return true


func _select_initial_experience(
	node_lab_requested: bool,
	tutorial_forced: bool,
	completed_version: int
) -> String:
	if node_lab_requested:
		return "node_lab"
	if tutorial_forced or completed_version != TUTORIAL_VERSION:
		return "tutorial"
	return "run"


func _resolve_tutorial_record_path(path: String) -> String:
	return tutorial_record_path if path.is_empty() else path


func _load_tutorial_completed_version(path: String = "") -> int:
	path = _resolve_tutorial_record_path(path)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0
	if !bool(config.get_value("tutorial", "completed", false)):
		return 0
	return int(config.get_value("tutorial", "version", 0))


func _save_tutorial_completion(path: String = "") -> bool:
	path = _resolve_tutorial_record_path(path)
	var config := ConfigFile.new()
	config.set_value("tutorial", "version", TUTORIAL_VERSION)
	config.set_value("tutorial", "completed", true)
	var result := config.save(path)
	if result != OK:
		push_warning("Could not persist Ch09 tutorial completion.")
	return result == OK


func _tutorial_forced() -> bool:
	if OS.get_cmdline_user_args().has("--tutorial"):
		return true
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('tutorial')",
			true
		)
		return str(value) == "1"
	return false


func _start_initial_experience() -> void:
	if initial_experience_started:
		return
	initial_experience_started = true
	var mode := _select_initial_experience(
		_node_lab_requested(),
		_tutorial_forced(),
		_load_tutorial_completed_version()
	)
	match mode:
		"node_lab":
			_enter_node_lab()
		"tutorial":
			_start_tutorial_briefing()
		_:
			_reset_run()
	_render_state()


func _start_tutorial_briefing() -> void:
	formal_run_active = false
	tutorial_active = true
	tutorial_step = TutorialStep.BRIEFING
	state = RunState.WAITING


func _start_clean_formal_run() -> void:
	tutorial_active = false
	tutorial_step = TutorialStep.INACTIVE
	_reset_run()
	_render_state()


func _skip_tutorial(record_path: String = "") -> bool:
	return _complete_tutorial(record_path)


func _complete_tutorial(record_path: String = "") -> bool:
	var persisted := _save_tutorial_completion(record_path)
	_start_clean_formal_run()
	return persisted


func _node_lab_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--node-lab":
			return true
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('nodeLab')",
			true
		)
		return str(value) == "1"
	return false


func _enter_node_lab() -> void:
	formal_run_active = false
	tutorial_active = false
	if node_lab_overlay != null:
		node_lab_active = true
		node_lab_overlay.show_catalog()
		return
	for child in get_children():
		var script = child.get_script()
		if script != null and str(script.resource_path) == "res://dev/node_lab.gd":
			node_lab_overlay = child as CanvasLayer
			break
	if node_lab_overlay == null:
		var lab_script := load("res://dev/node_lab.gd")
		node_lab_overlay = lab_script.new() as CanvasLayer
		add_child(node_lab_overlay)
		node_lab_overlay.configure(self)
	node_lab_active = true
	state = RunState.WAITING
	node_lab_overlay.show_catalog()
	_render_state()


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
	header_panel.name = "RunHud"
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
	main_area.name = "SceneStage"
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.custom_minimum_size = Vector2(0, 420)
	shell.add_child(main_area)
	main_area.add_child(_build_scene_grid())
	map_view = _scene_panel("MapView", Color("#f7faf9e8"), Color("#68818a"))
	combat_view = _scene_panel("CombatView", Color("#f7faf9e8"), Color("#68818a"))
	choice_view = _scene_panel("ChoiceView", Color("#f7faf9e8"), Color("#68818a"))
	result_view = _scene_panel("ResultView", Color("#f7faf9e8"), Color("#68818a"))
	main_area.add_child(map_view)
	main_area.add_child(combat_view)
	main_area.add_child(choice_view)
	main_area.add_child(result_view)
	_build_map_view()
	_build_combat_view()
	_build_choice_view()
	_build_result_view()
	_build_card_selection_modal()
	_build_tutorial_view()

	var footer := PanelContainer.new()
	footer.name = "RunFooter"
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


func _grid_texture() -> Texture2D:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var line := Color("#d9e7e9")
	for pixel in range(48):
		image.set_pixel(pixel, 0, line)
		image.set_pixel(0, pixel, line)
	return ImageTexture.create_from_image(image)


func _build_scene_grid() -> TextureRect:
	var grid := TextureRect.new()
	grid.name = "SceneGrid"
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.texture = _grid_texture()
	grid.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grid.stretch_mode = TextureRect.STRETCH_TILE
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid


func _header_metric(parent: HBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#294b54"))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _state_panel(node_name: String) -> PanelContainer:
	return _scene_panel(node_name, Color("#f7faf9"), Color("#68818a"))


func _scene_panel(node_name: String, background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(background, border))
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


func _build_tutorial_view() -> void:
	tutorial_view = _scene_panel("TutorialView", Color("#f7faf9e8"), Color("#68818a"))
	tutorial_view.theme = ui_theme
	main_area.add_child(tutorial_view)
	var margin := _content_margin()
	tutorial_view.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "TutorialBriefingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	tutorial_briefing_content = VBoxContainer.new()
	tutorial_briefing_content.name = "TutorialBriefingContent"
	tutorial_briefing_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_briefing_content.add_theme_constant_override("separation", 12)
	scroll.add_child(tutorial_briefing_content)
	var title := Label.new()
	title.text = "训练导览 / 环境监测调试"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#17343c"))
	tutorial_briefing_content.add_child(title)
	tutorial_route_summary = Label.new()
	tutorial_route_summary.name = "TutorialRouteSummary"
	tutorial_route_summary.text = "12 节点单线调试\n故障与检查点：验证工程证据\n事件、组件、商店与休整：调整卡组\n节点 11：Boss 前整备\n节点 12：三阶段综合验收"
	tutorial_route_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_route_summary.add_theme_color_override("font_color", Color("#3e565d"))
	tutorial_route_summary.add_theme_font_size_override("font_size", 16)
	tutorial_briefing_content.add_child(tutorial_route_summary)
	var briefing_note := Label.new()
	briefing_note.text = "训练战斗将依次练习：读取故障意图、建立防御、结束回合与工程数据链。"
	briefing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_note.add_theme_color_override("font_color", Color("#486068"))
	tutorial_briefing_content.add_child(briefing_note)
	tutorial_start_button = Button.new()
	tutorial_start_button.name = "TutorialStartButton"
	tutorial_start_button.text = "开始训练"
	tutorial_start_button.disabled = true
	tutorial_start_button.tooltip_text = "训练场景将在战斗引导就绪后启用"
	tutorial_start_button.pressed.connect(_start_tutorial_encounter)
	tutorial_start_button.disabled = false
	tutorial_start_button.tooltip_text = ""
	_skin_button(tutorial_start_button, Color("#2f7f8d"))
	tutorial_start_button.custom_minimum_size = Vector2(260, 44)
	tutorial_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_briefing_content.add_child(tutorial_start_button)

	tutorial_coach_layer = PanelContainer.new()
	tutorial_coach_layer.name = "TutorialCoachLayer"
	tutorial_coach_layer.theme = ui_theme
	tutorial_coach_layer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_coach_layer.offset_left = 18
	tutorial_coach_layer.offset_top = -84
	tutorial_coach_layer.offset_right = -18
	tutorial_coach_layer.offset_bottom = -12
	tutorial_coach_layer.add_theme_stylebox_override("panel", _panel_style(Color("#e6f1f1"), Color("#2f7f8d")))
	main_area.add_child(tutorial_coach_layer)
	var coach_content := VBoxContainer.new()
	coach_content.add_theme_constant_override("separation", 6)
	tutorial_coach_layer.add_child(coach_content)
	tutorial_coach_text = Label.new()
	tutorial_coach_text.name = "TutorialCoachText"
	tutorial_coach_text.text = "按教练提示完成训练步骤。"
	tutorial_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_coach_text.add_theme_color_override("font_color", Color("#173f47"))
	coach_content.add_child(tutorial_coach_text)
	tutorial_completion_summary = Label.new()
	tutorial_completion_summary.name = "TutorialCompletionSummary"
	tutorial_completion_summary.text = "循环：读取意图 -> 消耗处理点 -> 建立证据 -> 修复故障 -> 改善牌组\n战斗奖励加牌；功能节点改变本局。\nLED 仅用于训练；正式起始牌组会重置。"
	tutorial_completion_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_completion_summary.add_theme_color_override("font_color", Color("#173f47"))
	coach_content.add_child(tutorial_completion_summary)
	tutorial_coach_actions = HBoxContainer.new()
	tutorial_coach_actions.name = "TutorialCoachActions"
	tutorial_coach_actions.add_theme_constant_override("separation", 8)
	coach_content.add_child(tutorial_coach_actions)
	var coach_spacer := Control.new()
	coach_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_coach_actions.add_child(coach_spacer)
	tutorial_skip_button = Button.new()
	tutorial_skip_button.name = "TutorialSkipButton"
	tutorial_skip_button.text = "跳过教程"
	_skin_button(tutorial_skip_button, Color("#697b80"))
	tutorial_skip_button.custom_minimum_size = Vector2(128, 44)
	tutorial_skip_button.pressed.connect(func() -> void:
		_skip_tutorial()
	)
	tutorial_coach_actions.add_child(tutorial_skip_button)
	tutorial_intent_button = Button.new()
	tutorial_intent_button.name = "TutorialIntentButton"
	tutorial_intent_button.text = "查看故障意图"
	_skin_button(tutorial_intent_button, Color("#2f7f8d"))
	tutorial_intent_button.custom_minimum_size = Vector2(0, 44)
	tutorial_intent_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	tutorial_intent_button.pressed.connect(confirm_tutorial_intent)
	tutorial_coach_actions.add_child(tutorial_intent_button)
	tutorial_complete_button = Button.new()
	tutorial_complete_button.name = "TutorialCompleteButton"
	tutorial_complete_button.text = "开始正式调试"
	_skin_button(tutorial_complete_button, Color("#2f7f8d"))
	tutorial_complete_button.custom_minimum_size = Vector2(0, 44)
	tutorial_complete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	tutorial_complete_button.pressed.connect(func() -> void:
		_complete_tutorial()
	)
	tutorial_coach_actions.add_child(tutorial_complete_button)


func _build_map_view() -> void:
	var margin := _content_margin()
	map_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	map_title = Label.new()
	map_title.add_theme_font_size_override("font_size", 24)
	map_title.add_theme_color_override("font_color", Color("#17343c"))
	content.add_child(map_title)
	map_composition = BoxContainer.new()
	map_composition.name = "MapComposition"
	map_composition.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_composition.add_theme_constant_override("separation", 14)
	content.add_child(map_composition)
	map_mission_summary = Label.new()
	map_mission_summary.name = "MapMissionSummary"
	map_mission_summary.custom_minimum_size = Vector2(190, 0)
	map_mission_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_mission_summary.add_theme_color_override("font_color", Color("#3e565d"))
	map_mission_summary.add_theme_font_size_override("font_size", 16)
	map_composition.add_child(map_mission_summary)
	map_route_scroll = ScrollContainer.new()
	map_route_scroll.name = "MapRouteScroll"
	map_route_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_route_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_route_scroll.custom_minimum_size = Vector2(260, 252)
	map_route_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_composition.add_child(map_route_scroll)
	map_route = VBoxContainer.new()
	map_route.name = "MapRoute"
	map_route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_route.add_theme_constant_override("separation", 8)
	map_route_scroll.add_child(map_route)
	var next_column := VBoxContainer.new()
	next_column.custom_minimum_size = Vector2(210, 0)
	next_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	next_column.add_theme_constant_override("separation", 10)
	map_composition.add_child(next_column)
	map_next_detail = Label.new()
	map_next_detail.name = "MapNextDetail"
	map_next_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_next_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_next_detail.add_theme_color_override("font_color", Color("#3e565d"))
	next_column.add_child(map_next_detail)
	map_enter_button = Button.new()
	map_enter_button.name = "MapEnterButton"
	map_enter_button.text = "进入下一节点"
	_skin_button(map_enter_button, Color("#b75a3a"))
	map_enter_button.custom_minimum_size = Vector2(0, 44)
	map_enter_button.pressed.connect(func() -> void:
		choose_node(0)
		_render_state()
	)
	next_column.add_child(map_enter_button)


func _build_combat_view() -> void:
	var margin := _content_margin()
	combat_view.add_child(margin)
	combat_layout = BoxContainer.new()
	combat_layout.name = "CombatLayout"
	combat_layout.vertical = true
	combat_layout.add_theme_constant_override("separation", 12)
	margin.add_child(combat_layout)
	encounter_arena = BoxContainer.new()
	encounter_arena.name = "EncounterArena"
	encounter_arena.vertical = false
	encounter_arena.custom_minimum_size = Vector2(0, 172)
	encounter_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encounter_arena.add_theme_constant_override("separation", 10)
	combat_layout.add_child(encounter_arena)
	var device_unit := PanelContainer.new()
	device_unit.name = "DeviceUnit"
	device_unit.custom_minimum_size = Vector2(220, 0)
	device_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	device_unit.add_theme_stylebox_override("panel", _panel_style(Color("#edf4f2"), Color("#7b9a91")))
	encounter_arena.add_child(device_unit)
	var device_content := VBoxContainer.new()
	device_content.add_theme_constant_override("separation", 8)
	device_unit.add_child(device_content)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#52666b"))
	device_content.add_child(status_label)
	data_label = Label.new()
	data_label.name = "TutorialDataValues"
	data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_label.add_theme_color_override("font_color", Color("#24434b"))
	device_content.add_child(data_label)

	evidence_bridge = PanelContainer.new()
	evidence_bridge.name = "EvidenceBridge"
	evidence_bridge.custom_minimum_size = Vector2(220, 0)
	evidence_bridge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_bridge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_bridge.add_theme_stylebox_override("panel", _panel_style(Color("#e8f1ee"), Color("#3c8d72")))
	encounter_arena.add_child(evidence_bridge)
	var evidence_content := VBoxContainer.new()
	evidence_content.add_theme_constant_override("separation", 8)
	evidence_bridge.add_child(evidence_content)
	repair_label = Label.new()
	repair_label.add_theme_font_size_override("font_size", 18)
	repair_label.add_theme_color_override("font_color", Color("#226c59"))
	evidence_content.add_child(repair_label)
	repair_bar = ProgressBar.new()
	repair_bar.name = "RepairBar"
	repair_bar.show_percentage = false
	repair_bar.custom_minimum_size = Vector2(0, 16)
	repair_bar.add_theme_stylebox_override("background", _button_style(Color("#dce7e5"), Color("#8aa09d")))
	repair_bar.add_theme_stylebox_override("fill", _button_style(Color("#3c8d72"), Color("#226c59")))
	evidence_content.add_child(repair_bar)
	gate_label = Label.new()
	gate_label.name = "GateLabel"
	gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_label.add_theme_font_size_override("font_size", 14)
	gate_label.add_theme_color_override("font_color", Color("#486068"))
	evidence_content.add_child(gate_label)

	var fault_unit := PanelContainer.new()
	fault_unit.name = "FaultUnit"
	fault_unit.custom_minimum_size = Vector2(220, 0)
	fault_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fault_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_unit.add_theme_stylebox_override("panel", _panel_style(Color("#fff4ee"), Color("#b75a3a")))
	encounter_arena.add_child(fault_unit)
	var fault_content := VBoxContainer.new()
	fault_content.add_theme_constant_override("separation", 8)
	fault_unit.add_child(fault_content)
	intent_label = Label.new()
	intent_label.name = "EnemyIntent"
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_label.add_theme_stylebox_override("normal", _button_style(Color("#fff0df"), Color("#b16a2c")))
	intent_label.add_theme_color_override("font_color", Color("#693914"))
	fault_content.add_child(intent_label)
	fault_intent_row = Label.new()
	fault_intent_row.name = "FaultIntentRow"
	fault_intent_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_intent_row.add_theme_font_size_override("font_size", 13)
	fault_intent_row.add_theme_color_override("font_color", Color("#693914"))
	fault_content.add_child(fault_intent_row)
	fault_rule_row = Label.new()
	fault_rule_row.name = "FaultRuleRow"
	fault_rule_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_rule_row.add_theme_font_size_override("font_size", 13)
	fault_rule_row.add_theme_color_override("font_color", Color("#3e565d"))
	fault_content.add_child(fault_rule_row)
	fault_counter_row = Label.new()
	fault_counter_row.name = "FaultCounterRow"
	fault_counter_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_counter_row.add_theme_font_size_override("font_size", 13)
	fault_counter_row.add_theme_color_override("font_color", Color("#226c59"))
	fault_content.add_child(fault_counter_row)
	fault_rule_state_label = Label.new()
	fault_rule_state_label.name = "FaultRuleState"
	fault_rule_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_rule_state_label.add_theme_font_size_override("font_size", 13)
	fault_content.add_child(fault_rule_state_label)
	encounter_name_label = Label.new()
	encounter_name_label.add_theme_font_size_override("font_size", 24)
	encounter_name_label.add_theme_color_override("font_color", Color("#8d2f2a"))
	fault_content.add_child(encounter_name_label)
	encounter_meta_label = Label.new()
	encounter_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_meta_label.add_theme_color_override("font_color", Color("#3e565d"))
	fault_content.add_child(encounter_meta_label)

	hand_dock = VBoxContainer.new()
	hand_dock.name = "HandDock"
	hand_dock.custom_minimum_size = Vector2(0, 274)
	hand_dock.add_theme_constant_override("separation", 8)
	combat_layout.add_child(hand_dock)
	tutorial_combat_spacer = Control.new()
	tutorial_combat_spacer.name = "TutorialCombatSpacer"
	tutorial_combat_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_layout.add_child(tutorial_combat_spacer)
	dock_header = HBoxContainer.new()
	dock_header.add_theme_constant_override("separation", 10)
	hand_dock.add_child(dock_header)
	hand_title = Label.new()
	hand_title.name = "HandTitle"
	hand_title.text = "手牌 / 点击执行工程动作"
	hand_title.add_theme_color_override("font_color", Color("#294b54"))
	dock_header.add_child(hand_title)
	engineering_chain_strip = HBoxContainer.new()
	engineering_chain_strip.name = "EngineeringChainStrip"
	engineering_chain_strip.add_theme_constant_override("separation", 4)
	dock_header.add_child(engineering_chain_strip)
	for stage in STAGE_ORDER:
		var stage_label := Label.new()
		stage_label.name = "Chain%s" % stage.capitalize()
		stage_label.text = {"collect": "采", "interface": "接", "process": "理", "output": "出"}.get(stage, stage)
		stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stage_label.custom_minimum_size = Vector2(24, 28)
		stage_label.add_theme_color_override("font_color", Color("#52666b"))
		engineering_chain_strip.add_child(stage_label)
		chain_stage_labels[stage] = stage_label
	var dock_spacer := Control.new()
	dock_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_header.add_child(dock_spacer)
	processing_point_counter = Label.new()
	processing_point_counter.name = "ProcessingPointCounter"
	processing_point_counter.add_theme_color_override("font_color", Color("#226c59"))
	dock_header.add_child(processing_point_counter)
	hand_scroll = ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size = Vector2(0, 192)
	hand_dock.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.name = "HandRow"
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.custom_minimum_size = Vector2(0, 188)
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)
	combat_actions = HBoxContainer.new()
	combat_actions.name = "CombatActions"
	combat_actions.alignment = BoxContainer.ALIGNMENT_END
	combat_actions.add_theme_constant_override("separation", 10)
	hand_dock.add_child(combat_actions)
	reroute_button = Button.new()
	reroute_button.name = "RerouteButton"
	reroute_button.text = "换牌"
	reroute_button.custom_minimum_size = Vector2(74, 44)
	_skin_button(reroute_button, Color("#2f7f8d"))
	reroute_button.pressed.connect(func() -> void:
		begin_reroute()
	)
	combat_actions.add_child(reroute_button)
	reroute_cancel_button = Button.new()
	reroute_cancel_button.name = "RerouteCancelButton"
	reroute_cancel_button.text = "取消"
	reroute_cancel_button.custom_minimum_size = Vector2(74, 44)
	_skin_button(reroute_cancel_button, Color("#697b80"))
	reroute_cancel_button.pressed.connect(func() -> void:
		cancel_reroute()
	)
	combat_actions.add_child(reroute_cancel_button)
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "结束回合"
	_skin_button(end_turn_button, Color("#b16a2c"))
	end_turn_button.custom_minimum_size = Vector2(104, 44)
	end_turn_button.pressed.connect(func() -> void:
		end_turn()
		_render_state()
	)
	combat_actions.add_child(end_turn_button)
	action_trailing_spacer = Control.new()
	action_trailing_spacer.custom_minimum_size = Vector2(1, 0)
	combat_actions.add_child(action_trailing_spacer)


func _build_card_selection_modal() -> void:
	card_selection_modal = PanelContainer.new()
	card_selection_modal.name = "CardSelectionModal"
	card_selection_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_selection_modal.add_theme_stylebox_override("panel", _panel_style(Color("#f7fbf8"), Color("#2f7f8d")))
	card_selection_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	card_selection_modal.visible = false
	main_area.add_child(card_selection_modal)
	var selection_margin := MarginContainer.new()
	selection_margin.add_theme_constant_override("margin_left", 24)
	selection_margin.add_theme_constant_override("margin_top", 24)
	selection_margin.add_theme_constant_override("margin_right", 24)
	selection_margin.add_theme_constant_override("margin_bottom", 24)
	card_selection_modal.add_child(selection_margin)
	var selection_content := VBoxContainer.new()
	selection_content.add_theme_constant_override("separation", 14)
	selection_margin.add_child(selection_content)
	card_selection_title = Label.new()
	card_selection_title.name = "CardSelectionTitle"
	card_selection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_selection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_selection_title.add_theme_font_size_override("font_size", 20)
	card_selection_title.add_theme_color_override("font_color", Color("#24434b"))
	selection_content.add_child(card_selection_title)
	card_selection_options = GridContainer.new()
	card_selection_options.name = "CardSelectionOptions"
	card_selection_options.columns = 3
	card_selection_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_selection_options.add_theme_constant_override("h_separation", 10)
	card_selection_options.add_theme_constant_override("v_separation", 10)
	selection_content.add_child(card_selection_options)


func _build_choice_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "SceneChoiceBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#dbe7e7")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_view.add_child(backdrop)
	reward_encounter_backdrop = BoxContainer.new()
	reward_encounter_backdrop.name = "ResolvedEncounterBackdrop"
	reward_encounter_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_encounter_backdrop.offset_left = 18
	reward_encounter_backdrop.offset_top = 18
	reward_encounter_backdrop.offset_right = -18
	reward_encounter_backdrop.offset_bottom = -18
	reward_encounter_backdrop.add_theme_constant_override("separation", 10)
	reward_encounter_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.modulate = Color(1, 1, 1, 0.58)
	backdrop.add_child(reward_encounter_backdrop)
	var resolved_device_panel := PanelContainer.new()
	resolved_device_panel.name = "ResolvedDeviceUnit"
	resolved_device_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_device_panel.add_theme_stylebox_override("panel", _button_style(Color("#dce9e6"), Color("#8da39e")))
	resolved_device_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_device_panel)
	resolved_device_context = Label.new()
	resolved_device_context.name = "ResolvedDeviceContext"
	resolved_device_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_device_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_device_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_device_context.add_theme_color_override("font_color", Color("#627875"))
	resolved_device_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_device_panel.add_child(resolved_device_context)
	var resolved_evidence_panel := PanelContainer.new()
	resolved_evidence_panel.name = "ResolvedEvidenceBridge"
	resolved_evidence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_evidence_panel.add_theme_stylebox_override("panel", _button_style(Color("#e2e8e5"), Color("#91a39c")))
	resolved_evidence_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_evidence_panel)
	resolved_evidence_context = Label.new()
	resolved_evidence_context.name = "ResolvedEvidenceContext"
	resolved_evidence_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_evidence_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_evidence_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_evidence_context.add_theme_color_override("font_color", Color("#667773"))
	resolved_evidence_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_evidence_panel.add_child(resolved_evidence_context)
	var resolved_fault_panel := PanelContainer.new()
	resolved_fault_panel.name = "ResolvedFaultUnit"
	resolved_fault_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_fault_panel.add_theme_stylebox_override("panel", _button_style(Color("#eee4df"), Color("#b49a8c")))
	resolved_fault_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_fault_panel)
	resolved_fault_context = Label.new()
	resolved_fault_context.name = "ResolvedFaultContext"
	resolved_fault_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_fault_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_fault_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_fault_context.add_theme_color_override("font_color", Color("#826b62"))
	resolved_fault_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_fault_panel.add_child(resolved_fault_context)
	var margin := _content_margin()
	choice_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var context := VBoxContainer.new()
	context.name = "SceneChoiceContext"
	context.add_theme_constant_override("separation", 4)
	content.add_child(context)
	choice_title = Label.new()
	choice_title.add_theme_font_size_override("font_size", 24)
	choice_title.add_theme_color_override("font_color", Color("#17343c"))
	context.add_child(choice_title)
	choice_description = Label.new()
	choice_description.name = "ChoiceDescription"
	choice_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_description.add_theme_color_override("font_color", Color("#486068"))
	context.add_child(choice_description)
	var scroll := ScrollContainer.new()
	scroll.name = "ChoiceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var scroll_content := VBoxContainer.new()
	scroll_content.name = "ChoiceScrollContent"
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_content)
	reward_cards = GridContainer.new()
	reward_cards.name = "RewardCards"
	reward_cards.columns = 3
	reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_cards.add_theme_constant_override("h_separation", 10)
	reward_cards.add_theme_constant_override("v_separation", 10)
	scroll_content.add_child(reward_cards)
	reward_skip_button = Button.new()
	reward_skip_button.name = "RewardSkipButton"
	reward_skip_button.text = "跳过奖励"
	_skin_button(reward_skip_button, Color("#697b80"))
	reward_skip_button.custom_minimum_size = Vector2(180, 44)
	reward_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reward_skip_button.pressed.connect(func() -> void:
		choose_reward("")
		_render_state()
	)
	scroll_content.add_child(reward_skip_button)
	question_event_frame = PanelContainer.new()
	question_event_frame.name = "QuestionEventFrame"
	question_event_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_event_frame.add_theme_stylebox_override("panel", _panel_style(Color("#edf4f1"), Color("#2f7f8d")))
	var question_margin := MarginContainer.new()
	question_margin.add_theme_constant_override("margin_left", 16)
	question_margin.add_theme_constant_override("margin_top", 14)
	question_margin.add_theme_constant_override("margin_right", 16)
	question_margin.add_theme_constant_override("margin_bottom", 14)
	question_event_frame.add_child(question_margin)
	var question_content := VBoxContainer.new()
	question_content.add_theme_constant_override("separation", 10)
	question_margin.add_child(question_content)
	question_knowledge_tag = Label.new()
	question_knowledge_tag.name = "QuestionKnowledgeTag"
	question_knowledge_tag.add_theme_color_override("font_color", Color("#226c59"))
	question_content.add_child(question_knowledge_tag)
	question_prompt = Label.new()
	question_prompt.name = "QuestionPrompt"
	question_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_prompt.add_theme_font_size_override("font_size", 18)
	question_prompt.add_theme_color_override("font_color", Color("#17343c"))
	question_content.add_child(question_prompt)
	question_interaction = VBoxContainer.new()
	question_interaction.name = "QuestionInteraction"
	question_interaction.add_theme_constant_override("separation", 8)
	question_content.add_child(question_interaction)
	question_submit = Button.new()
	question_submit.name = "QuestionSubmit"
	question_submit.text = "提交答案"
	question_submit.custom_minimum_size = Vector2(180, 44)
	question_submit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skin_button(question_submit, Color("#2f7f8d"))
	question_submit.pressed.connect(func() -> void:
		var answer: Variant = event_ordering_answer.duplicate() if str(current_event.get("questionType", "")) == "ordering" else event_selected_answer
		submit_event_answer(answer)
		_render_state()
	)
	question_content.add_child(question_submit)
	question_explanation = Label.new()
	question_explanation.name = "QuestionExplanation"
	question_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_explanation.add_theme_color_override("font_color", Color("#355158"))
	question_content.add_child(question_explanation)
	question_consequence = VBoxContainer.new()
	question_consequence.name = "QuestionConsequence"
	question_consequence.add_theme_constant_override("separation", 8)
	question_content.add_child(question_consequence)
	question_continue = Button.new()
	question_continue.name = "QuestionContinue"
	question_continue.text = "继续路线"
	question_continue.custom_minimum_size = Vector2(180, 44)
	question_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skin_button(question_continue, Color("#517943"))
	question_continue.pressed.connect(func() -> void:
		continue_event()
		_render_state()
	)
	question_content.add_child(question_continue)
	scroll_content.add_child(question_event_frame)
	service_bench = PanelContainer.new()
	service_bench.name = "ServiceBench"
	service_bench.custom_minimum_size = Vector2(0, 58)
	service_bench.add_theme_stylebox_override("panel", _panel_style(Color("#e7efea"), Color("#517943")))
	var bench_label := Label.new()
	bench_label.text = "工程维护台 / 诊断、清理与固件整备"
	bench_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bench_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bench_label.add_theme_color_override("font_color", Color("#315f45"))
	service_bench.add_child(bench_label)
	scroll_content.add_child(service_bench)
	choice_list = GridContainer.new()
	choice_list.name = "ChoiceList"
	choice_list.columns = 2
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("h_separation", 10)
	choice_list.add_theme_constant_override("v_separation", 10)
	scroll_content.add_child(choice_list)


func _build_result_view() -> void:
	var margin := _content_margin()
	result_view.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	result_title = Label.new()
	result_title.name = "RunResultHeading"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	content.add_child(result_title)
	result_metrics = Label.new()
	result_metrics.name = "RunResultMetrics"
	result_metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_metrics.add_theme_color_override("font_color", Color("#355158"))
	content.add_child(result_metrics)
	result_learning_summary = Label.new()
	result_learning_summary.name = "RunLearningSummary"
	result_learning_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_learning_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_learning_summary.add_theme_color_override("font_color", Color("#355158"))
	content.add_child(result_learning_summary)
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
	combat_layout.vertical = true
	if encounter_arena != null:
		encounter_arena.vertical = compact
		encounter_arena.custom_minimum_size.y = 248.0 if compact else 260.0
		var device_unit := encounter_arena.get_node_or_null("DeviceUnit")
		var evidence_bridge := encounter_arena.get_node_or_null("EvidenceBridge")
		var fault_unit := encounter_arena.get_node_or_null("FaultUnit")
		if compact:
			encounter_arena.move_child(fault_unit, 0)
			encounter_arena.move_child(evidence_bridge, 1)
			encounter_arena.move_child(device_unit, 2)
		else:
			encounter_arena.move_child(device_unit, 0)
			encounter_arena.move_child(evidence_bridge, 1)
			encounter_arena.move_child(fault_unit, 2)
	if hand_dock != null:
		hand_dock.custom_minimum_size.y = 274.0 if compact else 176.0
	if hand_title != null:
		hand_title.visible = !tutorial_active
	var tutorial_completion_visible := tutorial_active and tutorial_step == TutorialStep.COMPLETE
	var tutorial_coach_height := (208.0 if compact else 148.0) if tutorial_completion_visible else (108.0 if compact else 84.0)
	if tutorial_combat_spacer != null:
		tutorial_combat_spacer.visible = tutorial_active and state == RunState.COMBAT
		tutorial_combat_spacer.custom_minimum_size.y = tutorial_coach_height
	if end_turn_button != null and dock_header != null and combat_actions != null:
		var action_parent := combat_actions if compact and !tutorial_active else dock_header
		for action in [reroute_button, reroute_cancel_button, end_turn_button, action_trailing_spacer]:
			if action != null and action.get_parent() != action_parent:
				action.reparent(action_parent)
		if action_trailing_spacer != null:
			action_parent.move_child(action_trailing_spacer, -1)
		combat_actions.visible = compact
	if map_composition != null:
		map_composition.vertical = compact
	if map_mission_summary != null:
		map_mission_summary.visible = !compact
	if map_route_scroll != null:
		map_route_scroll.custom_minimum_size.y = 228.0 if compact else 252.0
		if compact and state == RunState.MAP:
			call_deferred("_reveal_available_map_node")
	if choice_list != null:
		choice_list.columns = 1 if compact else 2
	if reward_cards != null:
		reward_cards.columns = 1 if compact else 3
	if reward_encounter_backdrop != null:
		reward_encounter_backdrop.vertical = false
		var resolved_device_unit := reward_encounter_backdrop.get_node_or_null("ResolvedDeviceUnit")
		var resolved_evidence_bridge := reward_encounter_backdrop.get_node_or_null("ResolvedEvidenceBridge")
		var resolved_fault_unit := reward_encounter_backdrop.get_node_or_null("ResolvedFaultUnit")
		reward_encounter_backdrop.move_child(resolved_device_unit, 0)
		reward_encounter_backdrop.move_child(resolved_evidence_bridge, 1)
		reward_encounter_backdrop.move_child(resolved_fault_unit, 2)
		var resolved_font_size := 12 if compact else 16
		resolved_device_context.add_theme_font_size_override("font_size", resolved_font_size)
		resolved_evidence_context.add_theme_font_size_override("font_size", resolved_font_size)
		resolved_fault_context.add_theme_font_size_override("font_size", resolved_font_size)
	if budget_label != null:
		budget_label.visible = !compact
	if deck_label != null:
		deck_label.visible = !compact
	if brand_label != null:
		brand_label.text = "ENV" if compact else "ENV / SPIRE"
	if hand_scroll != null:
		hand_scroll.custom_minimum_size.y = 192.0 if compact else 124.0
	if hand_row != null:
		hand_row.custom_minimum_size.y = 188.0 if compact else 120.0
		for child in hand_row.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(154, 188) if compact else Vector2(176, 120)
	if tutorial_briefing_content != null:
		tutorial_briefing_content.add_theme_constant_override("separation", 10 if compact else 12)
	if tutorial_coach_layer != null:
		tutorial_coach_layer.offset_left = 10.0 if compact else 18.0
		tutorial_coach_layer.offset_top = -tutorial_coach_height
		tutorial_coach_layer.offset_right = -10.0 if compact else -18.0
		tutorial_coach_layer.offset_bottom = -12.0
	if tutorial_coach_text != null:
		tutorial_coach_text.max_lines_visible = 2
		tutorial_coach_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if tutorial_completion_summary != null:
		tutorial_completion_summary.max_lines_visible = 4
		tutorial_completion_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _render_state() -> void:
	if map_view == null:
		return
	map_view.visible = state == RunState.MAP
	combat_view.visible = state == RunState.COMBAT
	choice_view.visible = [RunState.REWARD, RunState.EVENT, RunState.SHOP, RunState.REST, RunState.COMPONENT].has(state)
	result_view.visible = state == RunState.RESULT
	_render_tutorial()
	if service_bench != null:
		service_bench.visible = state == RunState.REST
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
	_render_card_selection_overlay()
	if log_label != null:
		log_label.text = "  /  ".join(message_log.slice(maxi(0, message_log.size() - 2), message_log.size()))
	_apply_responsive_layout()


func _render_tutorial() -> void:
	if tutorial_view != null:
		tutorial_view.visible = tutorial_active and tutorial_step == TutorialStep.BRIEFING
	if tutorial_coach_layer != null:
		tutorial_coach_layer.visible = tutorial_active
	if tutorial_skip_button != null:
		tutorial_skip_button.visible = tutorial_active
	if tutorial_intent_button != null:
		tutorial_intent_button.visible = tutorial_active and tutorial_step == TutorialStep.READ_INTENT
		tutorial_intent_button.disabled = !tutorial_active or tutorial_step != TutorialStep.READ_INTENT
	if tutorial_complete_button != null:
		tutorial_complete_button.visible = tutorial_active and tutorial_step == TutorialStep.COMPLETE
		tutorial_complete_button.disabled = !tutorial_active or tutorial_step != TutorialStep.COMPLETE
	if tutorial_completion_summary != null:
		tutorial_completion_summary.visible = tutorial_active and tutorial_step == TutorialStep.COMPLETE
	if tutorial_coach_text != null and tutorial_active:
		match tutorial_step:
			TutorialStep.BRIEFING:
				tutorial_coach_text.text = "跟随训练步骤完成环境监测调试。"
			TutorialStep.READ_INTENT:
				tutorial_coach_text.text = "先读取故障意图，再选择防御动作。"
			TutorialStep.PLAY_DEFENSE:
				tutorial_coach_text.text = "使用滑动平均滤波，建立防护。"
			TutorialStep.END_TURN:
				tutorial_coach_text.text = "防护已建立。结束回合，观察它抵消漂移。"
			TutorialStep.PLAY_SAMPLE:
				tutorial_coach_text.text = "使用 MQ-2 采样，获取烟雾原始数据。"
			TutorialStep.PLAY_CONVERT:
				tutorial_coach_text.text = "使用 ADC 转换，将原始数据变为可信数据。"
			TutorialStep.PLAY_OUTPUT:
				tutorial_coach_text.text = "使用 LED 报警，将可信烟雾数据输出为行动。"
			TutorialStep.COMPLETE:
				tutorial_coach_text.text = "训练完成。"


func _render_header() -> void:
	layer_label.text = "节点 %d / %d" % [current_layer, RUN_NODE_COUNT]
	stability_label.text = "稳定度 %d / %d" % [stability, max_stability]
	budget_label.text = "预算 %d" % budget
	deck_label.text = "牌组 %d" % deck.size()


func _render_map() -> void:
	map_title.text = "第 %d 个调试节点" % (current_layer + 1) if current_layer < RUN_NODE_COUNT else "路线完成"
	var layers: Array = run_map.get("layers", [])
	map_mission_summary.text = "环境监测塔\n十二层调试攀登\n\n当前进度 %d / %d" % [current_layer, RUN_NODE_COUNT]
	_render_map_route(layers)
	if current_layer >= layers.size():
		map_next_detail.text = "路线已完成\n综合验收已结束。"
		map_enter_button.disabled = true
		return
	var choices: Array = (layers[current_layer] as Dictionary).get("choices", [])
	if choices.is_empty():
		map_next_detail.text = "下一节点暂不可用。"
		map_enter_button.disabled = true
		return
	var node := choices[0] as Dictionary
	map_next_detail.text = "下一节点\n%02d  %s\n%s" % [current_layer + 1, node.get("label", "调试节点"), _node_type_name(str(node.get("type", "")))]
	map_enter_button.disabled = false


func _render_map_route(layers: Array) -> void:
	_clear_children(map_route)
	for layer_number in range(1, RUN_NODE_COUNT + 1):
		var marker := Button.new()
		var layer_data := (layers[layer_number - 1] as Dictionary) if layer_number - 1 < layers.size() else {}
		var layer_choices: Array = layer_data.get("choices", [])
		var marker_node := layer_choices[0] as Dictionary if !layer_choices.is_empty() else {}
		var marker_type := str(marker_node.get("type", ""))
		var node_state := _map_node_state(layer_number)
		var details_revealed := node_state != "future" or revealed_nodes.has(layer_number)
		var background := Color("#dfe7e8")
		var accent := Color("#8ca0a5")
		var text_color := Color("#50656b")
		if node_state == "completed":
			background = Color("#2f7f8d")
			accent = Color("#2f7f8d")
			text_color = Color.WHITE
		elif details_revealed and marker_type == "boss":
			background = Color("#e6e0ed")
			accent = Color("#725c91")
			text_color = Color("#4f4066")
		elif node_state == "available":
			background = Color("#f2d5cc")
			accent = Color("#b75a3a")
			text_color = Color("#7b3324")
		if details_revealed:
			marker.text = "%02d  %s\n%s" % [layer_number, str(marker_node.get("label", "调试节点")), _node_type_name(marker_type)]
		else:
			marker.text = "%02d  未揭示\n内容待侦察" % layer_number
		marker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skin_button(marker, accent)
		marker.custom_minimum_size = Vector2(0, 48)
		marker.add_theme_stylebox_override("normal", _button_style(background, accent))
		marker.add_theme_stylebox_override("hover", _button_style(background, accent))
		marker.add_theme_stylebox_override("pressed", _button_style(background, accent))
		marker.add_theme_stylebox_override("disabled", _button_style(background, accent))
		marker.add_theme_color_override("font_color", text_color)
		marker.add_theme_color_override("font_disabled_color", text_color)
		marker.add_theme_font_size_override("font_size", 13)
		marker.disabled = node_state != "available"
		if node_state == "available":
			marker.pressed.connect(func() -> void:
				choose_node(0)
				_render_state()
			)
		map_route.add_child(marker)


func _reveal_available_map_node() -> void:
	if map_route_scroll == null or map_route == null or map_route.get_child_count() == 0:
		return
	var available_index := mini(current_layer, map_route.get_child_count() - 1)
	var first_visible_index := maxi(0, available_index - 1)
	var first_visible_marker := map_route.get_child(first_visible_index) as Control
	map_route_scroll.scroll_vertical = int(first_visible_marker.position.y)


func _map_node_state(layer_number: int) -> String:
	if layer_number <= current_layer:
		return "completed"
	if layer_number == current_layer + 1:
		return "available"
	return "future"


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
	var selection_open := !pending_card_selection.is_empty()
	encounter_name_label.text = str(current_encounter.get("name", "故障诊断"))
	var tier := str(current_encounter.get("tier", "ordinary"))
	var phase_text := " · 阶段 %d/3" % (boss_phase + 1) if tier == "boss" else ""
	encounter_meta_label.text = "%s%s\n弱点：%s" % [_node_type_name(tier), phase_text, " / ".join(current_encounter.get("weaknessTags", []))]
	intent_label.text = _current_intent_text()
	var fault_preview := _fault_rule_preview()
	var fault_rows_visible := !fault_preview.is_empty()
	fault_intent_row.visible = fault_rows_visible
	fault_rule_row.visible = fault_rows_visible
	fault_counter_row.visible = fault_rows_visible
	fault_rule_state_label.visible = fault_rows_visible
	if fault_preview.is_empty():
		fault_intent_row.text = "故障规则：无"
		fault_rule_row.text = "触发：无"
		fault_counter_row.text = "应对：无"
		fault_rule_state_label.text = "待触发"
	else:
		fault_intent_row.text = "意图：%s" % _current_intent_text()
		fault_rule_row.text = "规则：%s" % fault_preview.get("description", "")
		fault_counter_row.text = "应对：%s" % fault_preview.get("counterText", "")
		fault_rule_state_label.text = "已触发" if bool(fault_preview.get("triggered", false)) else ("本回合已抑制" if bool(fault_preview.get("suppressed", false)) else "待触发")
	fault_rule_state_label.add_theme_color_override("font_color", Color("#9b4f2f") if bool(fault_preview.get("triggered", false)) else (Color("#226c59") if bool(fault_preview.get("suppressed", false)) else Color("#725c91")))
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
	processing_point_counter.text = "处理点 %d" % processing_points
	for stage in STAGE_ORDER:
		var stage_label := chain_stage_labels.get(stage, null) as Label
		if stage_label == null:
			continue
		var preview := _chain_preview_for_stage(stage)
		var stage_color := Color("#52666b")
		if bool(preview.get("current", false)):
			stage_color = Color("#226c59")
		elif bool(preview.get("completed", false)):
			stage_color = Color("#2f7f8d")
		elif bool(preview.get("next", false)):
			stage_color = Color("#b16a2c")
		stage_label.add_theme_color_override("font_color", stage_color)
	if reroute_button != null:
		reroute_button.visible = !tutorial_active
		reroute_button.disabled = selection_open or tutorial_active or reroute_mode or !reroute_available or cards_played_this_turn > 0
	if reroute_cancel_button != null:
		reroute_cancel_button.visible = !tutorial_active and reroute_mode
		reroute_cancel_button.disabled = selection_open or tutorial_active or !reroute_mode
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
			button.text = "[%d]\n%s\n%s\n\n%s" % [cost, card.get("name", "卡牌"), card.get("type", ""), card.get("upgradedEffectText", "") if bool(card.get("upgraded", false)) else card.get("effectText", "")]
			button.tooltip_text = str(card.get("knowledgePoint", ""))
			button.disabled = selection_open or (!reroute_mode and (processing_points < cost or !_card_requirements_met(card) or (tutorial_active and !_tutorial_card_allowed(str(card.get("id", ""))))))
			_skin_button(button, _card_accent(card))
			button.pressed.connect(func() -> void:
				if reroute_mode:
					reroute_card(index)
				else:
					play_card(index)
				_render_state()
			)
		button.custom_minimum_size = Vector2(154 if size.x < 720.0 else 176, 188 if size.x < 720.0 else 120)
		if tutorial_active and str(card.get("id", "")) == _tutorial_expected_card_id():
			button.name = "TutorialRequiredCard"
			_apply_tutorial_card_focus(button)
		hand_row.add_child(button)
	end_turn_button.disabled = selection_open or (tutorial_active and !_tutorial_end_turn_allowed())
	_render_tutorial_focus()
	if tutorial_active and !_tutorial_expected_card_id().is_empty():
		call_deferred("_reveal_tutorial_required_card")


func _render_card_selection_overlay() -> void:
	if card_selection_modal == null:
		return
	var owner := str(pending_card_selection.get("owner", "combat"))
	var selection_open := !pending_card_selection.is_empty() and _selection_owner_matches_state(owner)
	card_selection_modal.visible = selection_open
	if selection_open:
		_render_card_selection_modal()


func _render_card_selection_modal() -> void:
	if card_selection_title == null or card_selection_options == null:
		return
	_clear_children(card_selection_options)
	var kind := str(pending_card_selection.get("kind", ""))
	card_selection_title.text = {
		"draw_one": "从检索结果中选择 1 张牌",
		"discard_one": "选择 1 张手牌弃置",
		"retain_one": "选择 1 张手牌保留到下回合",
		"raw_source": "选择 1 个原始数据源"
	}.get(kind, "选择一个工程动作")
	if kind == "event_card":
		card_selection_title.text = "Select an event card"
	elif kind == "event_component":
		card_selection_title.text = "Select an event component"
	card_selection_options.columns = 1 if size.x < 720.0 else 3
	var options: Array = pending_card_selection.get("options", []) as Array
	for index in range(options.size()):
		var option = options[index]
		var button := Button.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if kind == "event_component" and option is Dictionary:
			var component := option as Dictionary
			button.text = "%s\n%s" % [component.get("name", "component"), component.get("description", "")]
			_skin_button(button, Color("#8b6b23"))
		elif option is Dictionary:
			var card := option as Dictionary
			button.text = "%s  [%d]\n%s" % [card.get("name", "卡牌"), _card_cost_preview(card), card.get("upgradedEffectText", "") if bool(card.get("upgraded", false)) else card.get("effectText", "")]
			button.tooltip_text = str(card.get("knowledgePoint", ""))
			_skin_button(button, _card_accent(card))
		else:
			button.text = _source_name(str(option))
			_skin_button(button, Color("#2f7f8d"))
		button.custom_minimum_size = Vector2(0, 88)
		button.pressed.connect(func() -> void:
			choose_pending_card(index)
			_render_state()
		)
		card_selection_options.add_child(button)


func _source_name(source: String) -> String:
	return {"smoke": "烟雾", "light": "光照", "temp": "温度", "humidity": "湿度"}.get(source, source)


func _apply_tutorial_card_focus(button: Button) -> void:
	for state_name in ["normal", "hover", "pressed"]:
		var base_style := button.get_theme_stylebox(state_name)
		if base_style is StyleBoxFlat:
			var focus_style := (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
			focus_style.border_color = Color("#2f7f8d")
			focus_style.set_border_width_all(3)
			button.add_theme_stylebox_override(state_name, focus_style)


func _render_tutorial_focus() -> void:
	if intent_label != null:
		intent_label.add_theme_stylebox_override("normal", _button_style(Color("#fff0df"), Color("#b16a2c")))
	if end_turn_button != null:
		_skin_button(end_turn_button, Color("#b16a2c"))
	if data_label != null:
		data_label.remove_theme_stylebox_override("normal")
	if evidence_bridge != null:
		evidence_bridge.add_theme_stylebox_override("panel", _panel_style(Color("#e8f1ee"), Color("#3c8d72")))
	if !tutorial_active:
		return
	match tutorial_step:
		TutorialStep.READ_INTENT:
			_apply_tutorial_focus(intent_label)
		TutorialStep.END_TURN:
			_apply_tutorial_focus(end_turn_button)
		TutorialStep.PLAY_CONVERT, TutorialStep.PLAY_OUTPUT:
			_apply_tutorial_focus(data_label)
		TutorialStep.COMPLETE:
			_apply_tutorial_focus(evidence_bridge)


func _apply_tutorial_focus(control: Control) -> void:
	if control == null:
		return
	var base_style := control.get_theme_stylebox("normal")
	var focus_style := (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat if base_style is StyleBoxFlat else _panel_style(Color("#eff9f8"), Color("#2f7f8d"))
	focus_style.border_color = Color("#2f7f8d")
	focus_style.set_border_width_all(3)
	control.add_theme_stylebox_override("normal", focus_style)
	if control is Button:
		for state_name in ["hover", "pressed"]:
			var state_style := control.get_theme_stylebox(state_name)
			if state_style is StyleBoxFlat:
				var focused_state_style := (state_style as StyleBoxFlat).duplicate() as StyleBoxFlat
				focused_state_style.border_color = Color("#2f7f8d")
				focused_state_style.set_border_width_all(3)
				control.add_theme_stylebox_override(state_name, focused_state_style)


func _reveal_tutorial_required_card() -> void:
	if hand_scroll == null:
		return
	var required_card := find_child("TutorialRequiredCard", true, false) as Control
	if required_card != null:
		hand_scroll.scroll_horizontal = int(required_card.position.x)


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
	if str(card.get("type", "")) == "interface" and int(powers.get("interface_discount", 0)) > 0:
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
	_clear_children(reward_cards)
	var scene_kind := _choice_scene_kind()
	var question_event_active := scene_kind == "event" and current_event.has("questionType")
	reward_encounter_backdrop.visible = scene_kind == "reward"
	reward_cards.visible = scene_kind == "reward"
	reward_skip_button.visible = scene_kind == "reward"
	question_event_frame.visible = question_event_active
	service_bench.visible = scene_kind == "service"
	choice_list.visible = scene_kind != "reward" and !question_event_active
	match state:
		RunState.REWARD:
			var evidence_tags: Array[String] = []
			for raw_tag in encounter_evidence_tags.keys():
				if bool(encounter_evidence_tags.get(raw_tag, false)):
					evidence_tags.append(str(raw_tag))
			evidence_tags.sort()
			resolved_device_context.text = "环境监测设备 · 已恢复\n稳定度 %d / %d" % [stability, max_stability]
			resolved_evidence_context.text = "已验证工程证据\n%s" % (" / ".join(evidence_tags) if !evidence_tags.is_empty() else "无额外证据")
			resolved_fault_context.text = "已解决故障\n%s\n%s" % [current_encounter.get("name", "故障诊断"), _node_type_name(str(current_encounter.get("tier", "ordinary")))]
			choice_title.text = "故障已解决 · 选择后续工具"
			choice_description.text = "本次故障已定位并完成修复。"
			var debug_summary := _latest_debug_summary()
			if !debug_summary.is_empty():
				choice_description.text += "\n" + debug_summary
			for raw_card in reward_choices:
				var card := raw_card as Dictionary
				var button := Button.new()
				button.text = "%s  [%d]  ·  %s\n%s" % [card.get("name", "卡牌"), card.get("cost", 0), _reward_reason(card), card.get("effectText", "")]
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, _card_accent(card))
				_size_choice_button(button, 104)
				button.pressed.connect(func() -> void:
					choose_reward(str(card.get("id", "")))
					_render_state()
				)
				reward_cards.add_child(button)
		RunState.EVENT:
			choice_title.text = str(current_event.get("name", "调试事件"))
			if question_event_active:
				choice_description.text = ""
				_render_question_event()
			else:
				choice_description.text = str(current_event.get("description", ""))
				var options: Array = current_event.get("options", []) as Array
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


func _render_question_event() -> void:
	if question_event_frame == null:
		return
	if !event_answer_locked and !_event_data_valid(current_event):
		_resolve_malformed_event()
	_clear_children(question_interaction)
	_clear_children(question_consequence)
	var tags: Array = current_event.get("knowledgeTags", []) as Array
	question_knowledge_tag.text = "知识点  %s" % " / ".join(tags)
	question_prompt.text = str(current_event.get("prompt", ""))
	var code_snippet := str(current_event.get("codeSnippet", ""))
	if !code_snippet.is_empty():
		question_prompt.text += "\n\n" + code_snippet
	var question_type := str(current_event.get("questionType", ""))
	if question_type == "waveform":
		_render_question_waveform()
	if question_type == "ordering":
		_render_question_ordering()
	else:
		_render_question_options()

	var answer_missing := event_ordering_answer.is_empty() if question_type == "ordering" else event_selected_answer == null
	question_submit.visible = !event_answer_locked
	question_submit.disabled = event_answer_locked or answer_missing or !pending_card_selection.is_empty()
	question_explanation.visible = event_answer_locked
	question_explanation.text = "解析\n%s" % str(event_result.get("explanation", ""))
	question_consequence.visible = event_answer_locked
	if event_answer_locked:
		_render_question_consequence()
	var can_continue := event_answer_locked and bool(event_result.get("resolved", false)) and !bool(event_result.get("rewardPending", false)) and pending_card_selection.is_empty()
	question_continue.visible = can_continue
	question_continue.disabled = !can_continue


func _render_question_options() -> void:
	for raw_option in current_event.get("options", []) as Array:
		var option := raw_option as Dictionary
		var option_id := str(option.get("id", ""))
		var button := Button.new()
		button.name = "QuestionOption_%s" % option_id
		button.text = str(option.get("label", option_id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.button_pressed = str(event_selected_answer) == option_id
		button.disabled = event_answer_locked or !pending_card_selection.is_empty()
		_skin_button(button, Color("#725c91") if button.button_pressed else Color("#2f7f8d"))
		_size_choice_button(button, 52)
		button.pressed.connect(func() -> void:
			event_selected_answer = option_id
			_render_state()
		)
		question_interaction.add_child(button)


func _render_question_ordering() -> void:
	if event_ordering_answer.is_empty():
		for raw_option in current_event.get("options", []) as Array:
			event_ordering_answer.append(str((raw_option as Dictionary).get("id", "")))
	for index in range(event_ordering_answer.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "%d. %s" % [index + 1, _event_option_label(event_ordering_answer[index])]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var up := Button.new()
		up.name = "QuestionOrderUp_%d" % index
		up.text = "↑"
		up.tooltip_text = "上移"
		up.custom_minimum_size = Vector2(44, 44)
		up.disabled = event_answer_locked or index == 0
		_skin_button(up, Color("#2f7f8d"))
		up.pressed.connect(func() -> void: _move_event_order_item(index, -1))
		row.add_child(up)
		var down := Button.new()
		down.name = "QuestionOrderDown_%d" % index
		down.text = "↓"
		down.tooltip_text = "下移"
		down.custom_minimum_size = Vector2(44, 44)
		down.disabled = event_answer_locked or index == event_ordering_answer.size() - 1
		_skin_button(down, Color("#2f7f8d"))
		down.pressed.connect(func() -> void: _move_event_order_item(index, 1))
		row.add_child(down)
		question_interaction.add_child(row)


func _move_event_order_item(index: int, offset: int) -> void:
	if event_answer_locked or !pending_card_selection.is_empty():
		return
	var target := index + offset
	if index < 0 or index >= event_ordering_answer.size() or target < 0 or target >= event_ordering_answer.size():
		return
	var option_id := event_ordering_answer[index]
	event_ordering_answer.remove_at(index)
	event_ordering_answer.insert(target, option_id)
	_render_state()


func _event_option_label(option_id: String) -> String:
	for raw_option in current_event.get("options", []) as Array:
		var option := raw_option as Dictionary
		if str(option.get("id", "")) == option_id:
			return str(option.get("label", option_id))
	return option_id


func _render_question_waveform() -> void:
	var waveform := current_event.get("waveform", {}) as Dictionary
	var series: Array[Dictionary] = []
	for series_key in ["samples", "raw", "filtered"]:
		var values: Array = waveform.get(series_key, []) as Array
		if !values.is_empty():
			series.append({"id": series_key, "values": values})
	if series.is_empty():
		var fallback := Label.new()
		fallback.name = "QuestionWaveformFallback"
		fallback.text = "样本 | 1 | 2 | 3\n读数 | -- | -- | --"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_color_override("font_color", Color("#486068"))
		question_interaction.add_child(fallback)
		return

	var minimum := INF
	var maximum := -INF
	for item in series:
		for raw_value in item.get("values", []) as Array:
			minimum = minf(minimum, float(raw_value))
			maximum = maxf(maximum, float(raw_value))
	var plot := Control.new()
	plot.name = "QuestionWaveformPlot"
	plot.custom_minimum_size = Vector2(0, 120)
	plot.clip_contents = true
	question_interaction.add_child(plot)
	var plot_width := 300.0 if size.x < 720.0 else 520.0
	var plot_height := 108.0
	var colors := [Color("#2f7f8d"), Color("#b75a3a"), Color("#517943")]
	for series_index in range(series.size()):
		var item := series[series_index]
		var values: Array = item.get("values", []) as Array
		var line := Line2D.new()
		line.name = "QuestionWaveform_%s" % item.get("id", series_index)
		line.width = 3.0
		line.default_color = colors[series_index % colors.size()]
		line.antialiased = true
		for value_index in range(values.size()):
			var x := 12.0 + (plot_width - 24.0) * float(value_index) / float(maxi(values.size() - 1, 1))
			var normalized := 0.5 if is_equal_approx(maximum, minimum) else (float(values[value_index]) - minimum) / (maximum - minimum)
			var y := plot_height - 10.0 - normalized * (plot_height - 20.0)
			line.add_point(Vector2(x, y))
		plot.add_child(line)
	var reading_table := Label.new()
	reading_table.name = "QuestionWaveformReadings"
	var reading_rows: Array[String] = []
	for item in series:
		var value_texts: Array[String] = []
		for raw_value in item.get("values", []) as Array:
			value_texts.append(str(raw_value))
		reading_rows.append("%s | %s" % [str(item.get("id", "samples")), " | ".join(value_texts)])
	reading_table.text = "\n".join(reading_rows)
	reading_table.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reading_table.add_theme_color_override("font_color", Color("#486068"))
	question_interaction.add_child(reading_table)


func _render_question_consequence() -> void:
	var result_label := Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(event_result.get("dataError", false)):
		result_label.text = "未应用奖励或惩罚。"
	elif !bool(event_result.get("correct", false)):
		result_label.text = "回答错误 · %s" % _event_effect_text(current_event.get("penalty", {}) as Dictionary)
	elif bool(event_result.get("rewardPending", false)):
		result_label.text = "回答正确 · 选择一项奖励"
	else:
		result_label.text = "回答正确 · 奖励已确认"
	question_consequence.add_child(result_label)
	if !bool(event_result.get("rewardPending", false)):
		return
	var rewards: Array = event_result.get("rewardChoices", []) as Array
	for index in range(rewards.size()):
		var reward := rewards[index] as Dictionary
		var reward_button := Button.new()
		reward_button.name = "QuestionReward_%s" % str(reward.get("id", index))
		reward_button.text = str(reward.get("label", "选择奖励"))
		reward_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skin_button(reward_button, Color("#517943"))
		_size_choice_button(reward_button, 52)
		reward_button.pressed.connect(func() -> void:
			choose_event_reward(index)
			_render_state()
		)
		question_consequence.add_child(reward_button)


func _event_effect_text(effect: Dictionary) -> String:
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
		"budget":
			return "预算 %s%d" % ["+" if amount >= 0 else "", amount]
		"heal":
			return "稳定度 %s%d" % ["+" if amount >= 0 else "", amount]
		"add_negative":
			var card_id := str(effect.get("cardId", ""))
			return "加入 %s" % (negative_defs.get(card_id, {}) as Dictionary).get("name", card_id)
		"reveal_nodes":
			var node_ids: Array[String] = []
			for raw_node in effect.get("nodes", []) as Array:
				node_ids.append(str(raw_node))
			return "预览节点 %s" % ", ".join(node_ids)
		_:
			return "结果已记录"


func _choice_scene_kind() -> String:
	return {
		RunState.REWARD: "reward",
		RunState.EVENT: "event",
		RunState.SHOP: "shop",
		RunState.REST: "service",
		RunState.COMPONENT: "component"
	}.get(state, "choice")


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
	result_metrics.text = "得分 %d / 100\n到达节点 %d / %d\n稳定度 %d / %d\n检查点 %d / 2\n牌组 %d 张" % [
		score, current_layer, RUN_NODE_COUNT, stability, max_stability, checkpoints_passed, deck.size()
	]
	result_learning_summary.text = _learning_summary()


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


func _select_question_event(tier: String, node_id: String) -> Dictionary:
	var tier_ids: Array[String] = []
	for raw_id in event_defs.keys():
		var event_id := str(raw_id)
		var event := event_defs[event_id] as Dictionary
		if str(event.get("tier", "")) == tier:
			tier_ids.append(event_id)
	tier_ids.sort()
	if tier_ids.is_empty():
		return {}

	var prior_types := {}
	var prior_primary_tags := {}
	for event in event_history:
		prior_types[str(event.get("questionType", ""))] = true
		var tags: Array = event.get("knowledgeTags", []) as Array
		if !tags.is_empty():
			prior_primary_tags[str(tags[0])] = true
	var eligible_ids: Array[String] = []
	for event_id in tier_ids:
		var event := event_defs[event_id] as Dictionary
		var tags: Array = event.get("knowledgeTags", []) as Array
		var primary_tag := str(tags[0]) if !tags.is_empty() else ""
		if !prior_types.has(str(event.get("questionType", ""))) and !prior_primary_tags.has(primary_tag):
			eligible_ids.append(event_id)
	if eligible_ids.is_empty():
		eligible_ids = tier_ids.duplicate()
		_log("事件去重约束已放宽")
	var selection_hash := hash("%d:%s" % [run_seed, node_id]) & 0x7FFFFFFF
	var selected_id := eligible_ids[selection_hash % eligible_ids.size()]
	return (event_defs[selected_id] as Dictionary).duplicate(true)


func _reset_run() -> void:
	formal_run_active = !node_lab_active
	tutorial_active = false
	tutorial_step = TutorialStep.INACTIVE
	if runtime != null and formal_run_active:
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
	current_event.clear()
	event_answer_locked = false
	event_result.clear()
	revealed_nodes.clear()
	event_selected_answer = null
	event_ordering_answer.clear()
	deck.clear()
	for card_id in STARTER_CARD_IDS:
		deck.append(_card_copy(card_id))
	run_map = (map_defs.get(run_map_id, map_defs.get("mvp_a", {})) as Dictionary).duplicate(true)
	run_seed = int(run_map.get("seedId", 901))
	event_history.clear()
	rng.seed = run_seed
	draw_pile = deck.duplicate(true)
	_shuffle(draw_pile)
	discard_pile.clear()
	exhaust_pile.clear()
	hand.clear()
	retained_cards.clear()
	pending_card_selection.clear()
	turn_effect_uses.clear()
	_reset_combat_resources()
	_draw_cards(5)
	state = RunState.MAP
	_log("调试路线已初始化。")


func _reset_combat_resources() -> void:
	fault_rule_state = {
		"cardTagCounts": {},
		"stageCounts": {},
		"suppressed": false,
		"triggered": false,
		"nextEnergyPenalty": 0
	}
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
	chain_rewards_claimed.clear()
	cards_played_this_turn = 0
	reroute_available = false
	reroute_mode = false
	pending_card_selection.clear()
	turn_effect_uses.clear()
	retained_cards.clear()
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


func _start_tutorial_encounter() -> void:
	var missing_card_id := _tutorial_missing_fixture_card_id()
	if !missing_card_id.is_empty():
		push_warning("Missing Ch09 tutorial fixture card: %s; starting formal run." % missing_card_id)
		_start_clean_formal_run()
		return
	tutorial_active = true
	tutorial_step = TutorialStep.READ_INTENT
	formal_run_active = false
	state = RunState.COMBAT
	_reset_combat_resources()
	current_node = {"type": "tutorial", "contentId": "training_signal_chain"}
	current_encounter = TUTORIAL_ENCOUNTER.duplicate(true)
	current_intents = (current_encounter.get("intentPattern", []) as Array).duplicate(true)
	repair_target = 20
	repair_progress = 0
	intent_index = 0
	stability = max_stability
	turn_number = 1
	hand = [_card_copy("sliding_average")]
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_render_state()


func _tutorial_fixture_available() -> bool:
	return _tutorial_missing_fixture_card_id().is_empty()


func _tutorial_missing_fixture_card_id() -> String:
	for card_id in ["sliding_average", "mq2_sample", "adc_convert", "led_alarm"]:
		if !card_defs.has(card_id):
			return card_id
	return ""


func _tutorial_expected_card_id() -> String:
	return {
		TutorialStep.PLAY_DEFENSE: "sliding_average",
		TutorialStep.PLAY_SAMPLE: "mq2_sample",
		TutorialStep.PLAY_CONVERT: "adc_convert",
		TutorialStep.PLAY_OUTPUT: "led_alarm"
	}.get(tutorial_step, "")


func _tutorial_card_allowed(card_id: String) -> bool:
	return tutorial_active and card_id == _tutorial_expected_card_id()


func _tutorial_end_turn_allowed() -> bool:
	return tutorial_active and tutorial_step == TutorialStep.END_TURN


func confirm_tutorial_intent() -> bool:
	if !tutorial_active or tutorial_step != TutorialStep.READ_INTENT:
		return false
	tutorial_step = TutorialStep.PLAY_DEFENSE
	_render_state()
	return true


func _advance_tutorial_after_card(card_id: String) -> void:
	match tutorial_step:
		TutorialStep.PLAY_DEFENSE:
			if card_id == "sliding_average":
				tutorial_step = TutorialStep.END_TURN
		TutorialStep.PLAY_SAMPLE:
			if card_id == "mq2_sample":
				tutorial_step = TutorialStep.PLAY_CONVERT
		TutorialStep.PLAY_CONVERT:
			if card_id == "adc_convert":
				tutorial_step = TutorialStep.PLAY_OUTPUT
		TutorialStep.PLAY_OUTPUT:
			if card_id == "led_alarm":
				tutorial_step = TutorialStep.COMPLETE
	_render_state()


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


func _fault_rule_definition() -> Dictionary:
	if tutorial_active or str(current_encounter.get("tier", "")) == "boss":
		return {}
	return (current_encounter.get("faultRule", {}) as Dictionary).duplicate(true)


func _fault_rule_preview() -> Dictionary:
	var rule := _fault_rule_definition()
	if rule.is_empty():
		return {}
	return {
		"id": str(rule.get("id", "")),
		"description": str(rule.get("description", "")),
		"counterText": str(rule.get("counterText", "")),
		"suppressed": bool(fault_rule_state.get("suppressed", false)),
		"triggered": bool(fault_rule_state.get("triggered", false))
	}


func _prepare_fault_rule_for_card(card: Dictionary) -> void:
	var rule := _fault_rule_definition()
	if rule.is_empty():
		return
	if bool(fault_rule_state.get("suppressed", false)) or bool(fault_rule_state.get("triggered", false)):
		return
	var counter := _fault_rule_counter_for_card(rule, card)
	if counter.is_empty():
		return
	fault_rule_state["suppressed"] = true
	_log("Fault rule %s suppressed by %s" % [rule.get("id", ""), counter])


func _resolve_fault_rule_after_card(card: Dictionary) -> void:
	var rule := _fault_rule_definition()
	if rule.is_empty() or str(rule.get("timing", "")) != "after_card":
		return
	var tag_counts := fault_rule_state.get("cardTagCounts", {}) as Dictionary
	for raw_tag in card.get("tags", []) as Array:
		var tag := str(raw_tag)
		tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	fault_rule_state["cardTagCounts"] = tag_counts
	var stage_counts := fault_rule_state.get("stageCounts", {}) as Dictionary
	var stage := str(card.get("stage", ""))
	if !stage.is_empty():
		stage_counts[stage] = int(stage_counts.get(stage, 0)) + 1
	fault_rule_state["stageCounts"] = stage_counts
	if bool(fault_rule_state.get("suppressed", false)) or bool(fault_rule_state.get("triggered", false)):
		return
	var threshold := int(rule.get("triggerCount", 1))
	var trigger_tag := str(rule.get("triggerTag", ""))
	var trigger_stage := str(rule.get("triggerStage", ""))
	var trigger_count := int(tag_counts.get(trigger_tag, 0)) if !trigger_tag.is_empty() else int(stage_counts.get(trigger_stage, 0))
	if trigger_count < threshold:
		return
	_resolve_fault_rule(rule)


func _resolve_fault_rule_end_turn() -> void:
	var rule := _fault_rule_definition()
	if rule.is_empty() or str(rule.get("timing", "")) != "end_turn":
		return
	if bool(fault_rule_state.get("suppressed", false)) or bool(fault_rule_state.get("triggered", false)):
		return
	var counter := _fault_rule_behavior_counter(rule)
	if !counter.is_empty():
		fault_rule_state["suppressed"] = true
		_log("Fault rule %s suppressed by %s" % [rule.get("id", ""), counter])
		return
	var source := str(rule.get("source", ""))
	if source.is_empty() or int(raw_data.get(source, 0)) <= 0:
		return
	_resolve_fault_rule(rule)


func _fault_rule_counter_for_card(rule: Dictionary, card: Dictionary) -> String:
	if _fault_rule_will_trigger(rule, card):
		return ""
	var counter_tags: Array = rule.get("counterTags", []) as Array
	for raw_tag in card.get("tags", []) as Array:
		var tag := str(raw_tag)
		if counter_tags.has(tag):
			return tag
	return _fault_rule_behavior_counter(rule)


func _fault_rule_will_trigger(rule: Dictionary, card: Dictionary) -> bool:
	if str(rule.get("timing", "")) != "after_card":
		return false
	var threshold := int(rule.get("triggerCount", 1))
	var trigger_tag := str(rule.get("triggerTag", ""))
	if !trigger_tag.is_empty() and (card.get("tags", []) as Array).has(trigger_tag):
		var tag_counts := fault_rule_state.get("cardTagCounts", {}) as Dictionary
		return int(tag_counts.get(trigger_tag, 0)) + 1 >= threshold
	var trigger_stage := str(rule.get("triggerStage", ""))
	if !trigger_stage.is_empty() and str(card.get("stage", "")) == trigger_stage:
		var stage_counts := fault_rule_state.get("stageCounts", {}) as Dictionary
		return int(stage_counts.get(trigger_stage, 0)) + 1 >= threshold
	return false


func _fault_rule_behavior_counter(rule: Dictionary) -> String:
	var rule_id := str(rule.get("id", ""))
	match rule_id:
		"bh1750_stale_raw":
			return "cache_retention" if retain_data else ""
		"alarm_without_trust":
			return "trusted_data" if _trusted_total() > 0 else ""
		"i2c_second_transaction":
			return "chain3" if chain_count >= 2 else ""
	return ""


func _resolve_fault_rule(rule: Dictionary) -> void:
	var rule_id := str(rule.get("id", ""))
	fault_rule_state["triggered"] = true
	match rule_id:
		"mq2_uncalibrated", "adc_second_collect", "alarm_without_trust":
			discard_pile.append(_negative_card(str(rule.get("negativeCard", ""))))
		"lcd_unprepared_output":
			fault_rule_state["nextEnergyPenalty"] = int(rule.get("nextEnergy", 0))
		"i2c_second_transaction":
			_take_damage(int(rule.get("damage", 0)))
			discard_pile.append(_negative_card(str(rule.get("negativeCard", ""))))
		"bh1750_stale_raw":
			discard_pile.append(_negative_card(str(rule.get("negativeCard", ""))))
	_log("Fault rule %s triggered" % rule_id)


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
	if runtime != null and !node_lab_active:
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
			var event_tier := str(current_node.get("eventTier", "basic" if current_layer <= RUN_NODE_COUNT / 2 else "advanced"))
			var event_content_id := str(current_node.get("contentId", ""))
			var selected_event := {}
			if event_content_id.begins_with("random_"):
				selected_event = _select_question_event(event_tier, str(current_node.get("id", current_layer)))
			else:
				selected_event = (event_defs.get(event_content_id, {}) as Dictionary).duplicate(true)
			_begin_question_event(selected_event, true)
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
	next_turn_energy += int(fault_rule_state.get("nextEnergyPenalty", 0))
	fault_rule_state["nextEnergyPenalty"] = 0
	processing_points = 3 + next_turn_energy
	next_turn_energy = 0
	block = 0
	chain_count = 0
	last_stage = ""
	chain_rewards_claimed.clear()
	cards_played_this_turn = 0
	reroute_available = !tutorial_active
	reroute_mode = false
	pending_card_selection.clear()
	turn_effect_uses.clear()
	turn_card_types.clear()
	turn_sources.clear()
	pending_i2c_count = 0
	fault_rule_state["cardTagCounts"] = {}
	fault_rule_state["stageCounts"] = {}
	fault_rule_state["suppressed"] = false
	fault_rule_state["triggered"] = false
	if !first_turn:
		hand.clear()
		for raw_card in retained_cards:
			hand.append(raw_card)
		retained_cards.clear()
		_draw_cards(5)


func play_card(hand_index: int) -> bool:
	if state != RunState.COMBAT or !pending_card_selection.is_empty() or hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)):
		return false
	var card_id := str(card.get("id", ""))
	if tutorial_active and !_tutorial_card_allowed(card_id):
		_log("请先完成当前教学操作。")
		return false
	var cost := _card_cost_preview(card)
	if processing_points < cost:
		return false
	if !_card_requirements_met(card):
		return false
	_consume_card_discounts(card)
	processing_points -= cost
	hand.remove_at(hand_index)
	_prepare_fault_rule_for_card(card)
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
	_apply_card_effects(effects, card)
	var card_finalizer := {
		"card": card.duplicate(true),
		"repairBefore": repair_before
	}
	if !pending_card_selection.is_empty():
		pending_card_selection["cardFinalizer"] = card_finalizer
	else:
		_finalize_played_card(card_finalizer)
	return true


func _finalize_played_card(finalizer: Dictionary) -> void:
	var card := finalizer.get("card", {}) as Dictionary
	if card.is_empty():
		return
	_resolve_fault_rule_after_card(card)
	var repair_before := int(finalizer.get("repairBefore", repair_progress))
	var matched_weaknesses := _matched_weakness_tags(card)
	if !matched_weaknesses.is_empty():
		var bonus_text := "  ·  诊断修复 +2" if diagnosis > 0 and repair_progress > repair_before else ""
		_log("%s 命中弱点：%s%s" % [card.get("name", card.get("id", "card")), "/".join(matched_weaknesses), bonus_text])
	if str(card.get("type", "")) == "power" or bool(card.get("exhaust", false)):
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	cards_played_this_turn += 1
	if repair_progress >= repair_target:
		if tutorial_active:
			pass
		elif str(current_encounter.get("tier", "")) != "checkpoint" or _checkpoint_requirements_met():
			_finish_encounter()
	if tutorial_active:
		_advance_tutorial_after_card(str(card.get("id", "")))


func begin_reroute() -> bool:
	if state != RunState.COMBAT or !pending_card_selection.is_empty() or tutorial_active or !reroute_available or cards_played_this_turn > 0:
		return false
	reroute_mode = true
	_render_state()
	return true


func cancel_reroute() -> bool:
	if !reroute_mode:
		return false
	reroute_mode = false
	_render_state()
	return true


func reroute_card(hand_index: int) -> bool:
	if !reroute_mode or hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)):
		return false
	hand.remove_at(hand_index)
	discard_pile.append(card)
	if draw_pile.is_empty():
		discard_pile.erase(card)
		hand.insert(hand_index, card)
		reroute_mode = false
		_render_state()
		return false
	var before_draw := hand.size()
	_draw_cards(1)
	if hand.size() == before_draw:
		discard_pile.erase(card)
		hand.insert(hand_index, card)
		reroute_mode = false
		_render_state()
		return false
	reroute_available = false
	reroute_mode = false
	_render_state()
	return true


func _consume_card_discounts(card: Dictionary) -> void:
	var tags: Array = card.get("tags", [])
	if tags.has("i2c") and int(powers.get("i2c_discount", 0)) > 0:
		powers["i2c_discount"] = int(powers.get("i2c_discount", 0)) - 1
	if str(card.get("type", "")) == "process" and int(powers.get("process_discount", 0)) > 0:
		powers["process_discount"] = int(powers.get("process_discount", 0)) - 1
	if str(card.get("type", "")) == "interface" and int(powers.get("interface_discount", 0)) > 0:
		powers["interface_discount"] = int(powers.get("interface_discount", 0)) - 1


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
	if stage_index < 0:
		return
	var last_index := STAGE_ORDER.find(last_stage)
	if stage_index == 0:
		chain_count = 0
	elif last_index >= 0 and stage_index == last_index + 1:
		chain_count = mini(chain_count + 1, 3)
		_apply_chain_threshold_rewards()
	elif stage != last_stage:
		chain_count = 0
	last_stage = stage


func _apply_chain_threshold_rewards() -> void:
	if chain_count >= 1 and !bool(chain_rewards_claimed.get("two", false)):
		block += 3
		chain_rewards_claimed["two"] = true
	if chain_count >= 2 and !bool(chain_rewards_claimed.get("three", false)):
		processing_points += 1
		chain_rewards_claimed["three"] = true
	if chain_count >= 3 and !bool(chain_rewards_claimed.get("four", false)):
		repair_progress = mini(repair_target, repair_progress + 8)
		diagnosis = mini(diagnosis + 1, 3)
		if int(powers.get("chain_draw", 0)) > 0:
			_draw_cards(1)
		chain_rewards_claimed["four"] = true


func _chain_preview_for_stage(stage: String) -> Dictionary:
	var stage_index := STAGE_ORDER.find(stage)
	var current_index := STAGE_ORDER.find(last_stage)
	return {
		"stage": stage,
		"current": stage == last_stage,
		"completed": stage_index >= 0 and current_index >= stage_index and chain_count == current_index,
		"next": stage_index >= 0 and stage_index == current_index + 1
	}


func _apply_card_effects(effects: Array, card: Dictionary, trusted_spent: int = 0) -> int:
	var spent := trusted_spent
	for index in range(effects.size()):
		spent += _apply_card_effect(effects[index] as Dictionary, card, spent)
		if !pending_card_selection.is_empty():
			var remaining: Array = []
			for remaining_index in range(index + 1, effects.size()):
				remaining.append(effects[remaining_index])
			pending_card_selection["remainingEffects"] = remaining
			pending_card_selection["card"] = card.duplicate(true)
			pending_card_selection["trustedSpent"] = spent
			break
	return spent


func _effect_is_available(effect: Dictionary, card: Dictionary) -> bool:
	var limit := int(effect.get("perTurnLimit", 0))
	if limit <= 0:
		return true
	var effect_id := str(effect.get("effectId", "%s_%s" % [card.get("id", "card"), effect.get("op", "effect")]))
	return int(turn_effect_uses.get(effect_id, 0)) < limit


func _mark_effect_use(effect: Dictionary, card: Dictionary) -> void:
	if int(effect.get("perTurnLimit", 0)) <= 0:
		return
	var effect_id := str(effect.get("effectId", "%s_%s" % [card.get("id", "card"), effect.get("op", "effect")]))
	turn_effect_uses[effect_id] = int(turn_effect_uses.get(effect_id, 0)) + 1


func _open_card_selection(kind: String, options: Array, hand_indexes: Array = [], owner: String = "combat", context: Dictionary = {}) -> void:
	if options.is_empty():
		return
	pending_card_selection = {"owner": owner, "kind": kind, "options": options.duplicate(true)}
	if !hand_indexes.is_empty():
		pending_card_selection["handIndexes"] = hand_indexes.duplicate()
	if !context.is_empty():
		pending_card_selection["context"] = context.duplicate(true)


func _open_hand_selection(kind: String) -> void:
	var options: Array = []
	var indexes: Array = []
	for index in range(hand.size()):
		options.append(hand[index])
		indexes.append(index)
	_open_card_selection(kind, options, indexes)


func _inspect_top_cards(amount: int) -> Array:
	var inspected: Array = []
	for _index in range(amount):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate(true)
			discard_pile.clear()
			_shuffle(draw_pile)
		if draw_pile.is_empty():
			break
		inspected.append(draw_pile.pop_back())
	return inspected


func _return_cards_to_draw_top(cards: Array) -> void:
	for index in range(cards.size() - 1, -1, -1):
		draw_pile.append(cards[index])


func choose_pending_card(index: int) -> bool:
	if pending_card_selection.is_empty():
		return false
	var selection := pending_card_selection.duplicate(true)
	var owner := str(selection.get("owner", "combat"))
	if !_selection_owner_matches_state(owner):
		return false
	var options: Array = selection.get("options", []) as Array
	if index < 0 or index >= options.size():
		return false
	var kind := str(selection.get("kind", ""))
	var selected = options[index]
	match kind:
		"raw_source":
			var source := str(selected)
			_add_data(raw_data, source, int(selection.get("amount", 1)))
			source_coverage[source] = true
			if str(current_encounter.get("tier", "")) == "boss":
				phase_source_coverage[source] = true
		"draw_one":
			if !(selected is Dictionary):
				return false
			hand.append(selected)
			var unchosen: Array = []
			for option_index in range(options.size()):
				if option_index != index:
					unchosen.append(options[option_index])
			_return_cards_to_draw_top(unchosen)
		"discard_one", "retain_one":
			var hand_indexes: Array = selection.get("handIndexes", []) as Array
			if index >= hand_indexes.size():
				return false
			var hand_index := int(hand_indexes[index])
			if hand_index < 0 or hand_index >= hand.size():
				return false
			var card := hand[hand_index] as Dictionary
			hand.remove_at(hand_index)
			if kind == "discard_one":
				discard_pile.append(card)
			else:
				retained_cards.append(card)
		"event_card":
			if !(selected is Dictionary):
				return false
			var card := (selected as Dictionary).duplicate(true)
			var context := selection.get("context", {}) as Dictionary
			var action := str(context.get("action", ""))
			var deck_index := int(card.get("_deckIndex", -1))
			card.erase("_deckIndex")
			match action:
				"add_card":
					deck.append(card)
				"upgrade_card":
					if deck_index < 0 or deck_index >= deck.size():
						return false
					(deck[deck_index] as Dictionary)["upgraded"] = true
				"remove_card":
					if deck_index < 0 or deck_index >= deck.size():
						return false
					deck.remove_at(deck_index)
				_:
					return false
		"event_component":
			if !(selected is Dictionary):
				return false
			var component := selected as Dictionary
			var component_context := selection.get("context", {}) as Dictionary
			var component_id := str(component.get("id", ""))
			if str(component_context.get("action", "")) != "add_component" or component_id.is_empty() or relics.has(component_id):
				return false
			relics.append(component_id)
			_activate_relic(component_id)
		_:
			return false
	pending_card_selection.clear()
	if owner == "combat":
		_resume_pending_card_effects(selection)
	elif owner == "event":
		_resume_pending_event_effects(selection)
	else:
		return false
	return true


func _selection_owner_matches_state(owner: String) -> bool:
	return (owner == "combat" and state == RunState.COMBAT) or (owner == "event" and state == RunState.EVENT)


func _resume_pending_card_effects(selection: Dictionary) -> void:
	var card := selection.get("card", {}) as Dictionary
	var remaining: Array = selection.get("remainingEffects", []) as Array
	var finalizer := selection.get("cardFinalizer", {}) as Dictionary
	if !card.is_empty() and !remaining.is_empty():
		_apply_card_effects(remaining, card, int(selection.get("trustedSpent", 0)))
	if !pending_card_selection.is_empty():
		if !finalizer.is_empty():
			pending_card_selection["cardFinalizer"] = finalizer.duplicate(true)
		return
	_finalize_played_card(finalizer)


func _prepare_counter(counter_tag: String) -> void:
	var rule := _fault_rule_definition()
	if rule.is_empty() or bool(fault_rule_state.get("suppressed", false)) or bool(fault_rule_state.get("triggered", false)):
		return
	if (rule.get("counterTags", []) as Array).has(counter_tag):
		fault_rule_state["suppressed"] = true


func _apply_card_effect(effect: Dictionary, card: Dictionary, trusted_spent: int) -> int:
	if int(effect.get("requiresDiagnosis", 0)) > diagnosis:
		return 0
	if int(effect.get("requiresChain", 0)) > chain_count:
		return 0
	if int(effect.get("requiresTrustedSpent", 0)) > trusted_spent:
		return 0
	if bool(effect.get("requiresFaultSuppressed", false)) and !bool(fault_rule_state.get("suppressed", false)):
		return 0
	if bool(effect.get("requiresFaultUnsuppressed", false)) and bool(fault_rule_state.get("suppressed", false)):
		return 0
	if !_effect_is_available(effect, card):
		return 0
	_mark_effect_use(effect, card)
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
		"gain_raw":
			var source_options: Array = effect.get("sourceOptions", []) as Array
			if !source_options.is_empty():
				_open_card_selection("raw_source", source_options)
				pending_card_selection["amount"] = amount
				return 0
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
			return _convert_data(str(effect.get("source", "any")), amount)
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
		"draw_discard":
			_draw_cards(amount)
			_open_hand_selection("discard_one")
		"select_draw":
			var inspected := _inspect_top_cards(amount)
			_open_card_selection("draw_one", inspected)
		"draw_if_removed":
			var removed := _remove_negative(str(effect.get("kind", "")), amount)
			if removed > 0:
				_draw_cards(int(effect.get("drawAmount", 1)))
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
		"retain_card":
			_open_hand_selection("retain_one")
		"prepare_counter":
			_prepare_counter(str(effect.get("tag", "")))
		"multi_source_repair":
			var consumed_sources := 0
			for source in SOURCE_ORDER:
				if consumed_sources >= amount:
					break
				if int(trusted_data.get(source, 0)) <= 0:
					continue
				trusted_data[source] = int(trusted_data.get(source, 0)) - 1
				consumed_sources += 1
			_add_repair(consumed_sources * int(effect.get("repairPer", 0)), card)
			return consumed_sources
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


func end_turn() -> bool:
	if state != RunState.COMBAT or !pending_card_selection.is_empty():
		return false
	if tutorial_active and !_tutorial_end_turn_allowed():
		_log("请先完成当前教学操作。")
		return false
	for raw_card in hand:
		discard_pile.append(raw_card)
	hand.clear()
	if tutorial_active and tutorial_step == TutorialStep.END_TURN:
		_resolve_intent()
		_reset_turn_state(true)
		hand = [
			_card_copy("mq2_sample"),
			_card_copy("adc_convert"),
			_card_copy("led_alarm")
		]
		tutorial_step = TutorialStep.PLAY_SAMPLE
		_render_state()
		return true
	_resolve_fault_rule_end_turn()
	_resolve_intent()
	if stability <= 0:
		_handle_defeat()
		return true
	if str(current_encounter.get("tier", "")) == "checkpoint" and turn_number >= 2:
		_finish_checkpoint(repair_progress >= repair_target)
		return true
	if !retain_data and str(current_encounter.get("tier", "")) != "checkpoint":
		raw_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
		trusted_data = {"smoke": 0, "light": 0, "temp": 0, "humidity": 0}
	retain_data = false
	_reset_turn_state(false)
	return true


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
	var full_pool: Array[String] = []
	var deck_tags := {}
	var deck_stages := {}
	for raw_card in deck:
		var deck_card := raw_card as Dictionary
		for raw_tag in deck_card.get("tags", []) as Array:
			deck_tags[str(raw_tag)] = true
		var stage := str(deck_card.get("stage", ""))
		if !stage.is_empty():
			deck_stages[stage] = true
	for card_id in card_defs.keys():
		var card := card_defs[card_id] as Dictionary
		if str(card.get("rarity", "")) != "starter":
			full_pool.append(str(card_id))
	full_pool.sort()
	var missing_stages: Array[String] = []
	for stage in STAGE_ORDER:
		if !deck_stages.has(stage):
			missing_stages.append(stage)
	var counter_tags: Array = (_fault_rule_definition().get("counterTags", []) as Array).duplicate()
	var synergy_candidates: Array[String] = []
	var chain_candidates: Array[String] = []
	var counter_candidates: Array[String] = []
	for card_id in full_pool:
		var card := card_defs[card_id] as Dictionary
		var tags: Array = card.get("tags", []) as Array
		for raw_tag in tags:
			if deck_tags.has(str(raw_tag)):
				synergy_candidates.append(card_id)
				break
		if missing_stages.has(str(card.get("stage", ""))):
			chain_candidates.append(card_id)
		if str(card.get("type", "")) == "defense" or _card_has_draw_effect(card) or _arrays_intersect(tags, counter_tags):
			counter_candidates.append(card_id)
	var used := {}
	for bucket in [
		{"candidates": synergy_candidates, "reason": "协同"},
		{"candidates": chain_candidates, "reason": "补链"},
		{"candidates": counter_candidates, "reason": "反制"}
	]:
		var reward := _pick_reward_card(bucket.get("candidates", []) as Array, full_pool, used, str(bucket.get("reason", "")))
		if !reward.is_empty():
			reward_choices.append(reward)
	state = RunState.REWARD


func _pick_reward_card(candidates: Array, full_pool: Array, used: Dictionary, reason: String) -> Dictionary:
	var available: Array[String] = []
	for raw_card_id in candidates:
		var card_id := str(raw_card_id)
		if !used.has(card_id):
			available.append(card_id)
	if available.is_empty():
		for raw_card_id in full_pool:
			var card_id := str(raw_card_id)
			if !used.has(card_id):
				available.append(card_id)
	if available.is_empty():
		return {}
	available.sort()
	var selected_id := available[rng.randi_range(0, available.size() - 1)]
	used[selected_id] = true
	var reward := _card_copy(selected_id)
	reward["rewardReason"] = reason
	return reward


func _card_has_draw_effect(card: Dictionary) -> bool:
	for effects in [card.get("effects", []), card.get("upgradeEffects", [])]:
		for raw_effect in effects:
			if ["draw", "draw_discard", "select_draw", "draw_if_removed"].has(str((raw_effect as Dictionary).get("op", ""))):
				return true
	return false


func _reward_reason(card: Dictionary) -> String:
	return str(card.get("rewardReason", ""))


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


func _begin_question_event(event: Dictionary, record_history: bool = false) -> void:
	pending_card_selection.clear()
	current_event = event.duplicate(true)
	event_answer_locked = false
	event_result.clear()
	event_selected_answer = null
	event_ordering_answer.clear()
	if str(current_event.get("questionType", "")) == "ordering":
		for raw_option in current_event.get("options", []) as Array:
			event_ordering_answer.append(str((raw_option as Dictionary).get("id", "")))
	if record_history and !current_event.is_empty():
		event_history.append(current_event.duplicate(true))
	state = RunState.EVENT
	if !_event_data_valid(current_event):
		_resolve_malformed_event()


func _event_data_valid(event: Dictionary) -> bool:
	var question_type := str(event.get("questionType", ""))
	var options: Array = event.get("options", []) as Array
	var rewards: Array = event.get("rewardChoices", []) as Array
	var penalty := event.get("penalty", {}) as Dictionary
	if !["diagnosis", "ordering", "code_trace", "parameter", "waveform", "tradeoff"].has(question_type):
		return false
	if options.is_empty() or rewards.size() != 2 or penalty.is_empty() or !event.has("correctAnswer"):
		return false
	if str(event.get("explanation", "")).is_empty():
		return false
	var option_ids: Array[String] = []
	for raw_option in options:
		if !(raw_option is Dictionary):
			return false
		var option_id := str((raw_option as Dictionary).get("id", ""))
		if option_id.is_empty() or option_ids.has(option_id):
			return false
		option_ids.append(option_id)
	for raw_reward in rewards:
		if !(raw_reward is Dictionary) or ((raw_reward as Dictionary).get("effect", {}) as Dictionary).is_empty():
			return false
	if question_type == "ordering":
		var answer = event.get("correctAnswer")
		if !(answer is Array) or (answer as Array).size() != option_ids.size():
			return false
		for raw_id in answer as Array:
			if !option_ids.has(str(raw_id)):
				return false
		return true
	return option_ids.has(str(event.get("correctAnswer", "")))


func _event_answer_is_valid(answer: Variant) -> bool:
	var option_ids: Array[String] = []
	for raw_option in current_event.get("options", []) as Array:
		option_ids.append(str((raw_option as Dictionary).get("id", "")))
	if str(current_event.get("questionType", "")) == "ordering":
		if !(answer is Array) or (answer as Array).size() != option_ids.size():
			return false
		var seen := {}
		for raw_id in answer as Array:
			var answer_id := str(raw_id)
			if !option_ids.has(answer_id) or seen.has(answer_id):
				return false
			seen[answer_id] = true
		return true
	if !(answer is String or answer is StringName):
		return false
	return option_ids.has(str(answer))


func _event_answer_matches(answer: Variant, expected: Variant) -> bool:
	if answer is Array and expected is Array:
		var answer_ids: Array = answer as Array
		var expected_ids: Array = expected as Array
		if answer_ids.size() != expected_ids.size():
			return false
		for index in range(answer_ids.size()):
			if str(answer_ids[index]) != str(expected_ids[index]):
				return false
		return true
	return str(answer) == str(expected)


func _resolve_malformed_event() -> void:
	event_answer_locked = true
	event_result = {
		"correct": false,
		"dataError": true,
		"explanation": "事件数据无效",
		"rewardChoices": [],
		"rewardPending": false,
		"resolved": true
	}


func submit_event_answer(answer: Variant) -> bool:
	if state != RunState.EVENT or !pending_card_selection.is_empty() or event_answer_locked:
		return false
	if !_event_data_valid(current_event):
		_resolve_malformed_event()
		return true
	if !_event_answer_is_valid(answer):
		return false
	var correct := _event_answer_matches(answer, current_event.get("correctAnswer"))
	var recorded_answer = answer.duplicate(true) if answer is Array or answer is Dictionary else answer
	event_answer_locked = true
	event_result = {
		"answer": recorded_answer,
		"correctAnswer": current_event.get("correctAnswer"),
		"correct": correct,
		"explanation": str(current_event.get("explanation", "")),
		"rewardChoices": (current_event.get("rewardChoices", []) as Array).duplicate(true),
		"rewardPending": correct,
		"resolved": false
	}
	if !correct:
		event_result["consequenceApplied"] = _apply_event_consequence(current_event.get("penalty", {}) as Dictionary)
		event_result["resolved"] = true
	return true


func choose_event_reward(index: int) -> bool:
	if state != RunState.EVENT or !event_answer_locked or !pending_card_selection.is_empty():
		return false
	if !bool(event_result.get("correct", false)) or !bool(event_result.get("rewardPending", false)):
		return false
	var rewards: Array = event_result.get("rewardChoices", []) as Array
	if index < 0 or index >= rewards.size():
		return false
	var reward := rewards[index] as Dictionary
	var effect := reward.get("effect", {}) as Dictionary
	var applied := _apply_event_consequence(effect)
	if !applied and pending_card_selection.is_empty():
		return false
	event_result["rewardPending"] = false
	event_result["chosenRewardId"] = str(reward.get("id", ""))
	event_result["resolved"] = false
	event_result["consequenceApplied"] = applied
	if pending_card_selection.is_empty():
		event_result["resolved"] = true
	return true


func continue_event() -> bool:
	if state != RunState.EVENT or !pending_card_selection.is_empty():
		return false
	if !event_answer_locked or !bool(event_result.get("resolved", false)) or bool(event_result.get("rewardPending", false)):
		return false
	current_event.clear()
	event_answer_locked = false
	event_result.clear()
	state = RunState.MAP
	return true


func force_lab_question_result(correct: bool) -> bool:
	if !node_lab_active or state != RunState.EVENT or !current_event.has("questionType"):
		return false
	var answer: Variant
	if correct:
		var expected = current_event.get("correctAnswer")
		answer = expected.duplicate(true) if expected is Array or expected is Dictionary else expected
	else:
		answer = _lab_incorrect_event_answer()
	if answer == null or !submit_event_answer(answer):
		return false
	_render_state()
	return true


func _lab_incorrect_event_answer() -> Variant:
	var expected = current_event.get("correctAnswer")
	if expected is Array:
		var reordered := (expected as Array).duplicate(true)
		if reordered.size() < 2:
			return null
		var first = reordered[0]
		reordered[0] = reordered[1]
		reordered[1] = first
		return reordered
	for raw_option in current_event.get("options", []) as Array:
		var option_id := str((raw_option as Dictionary).get("id", ""))
		if option_id != str(expected):
			return option_id
	return null


func choose_event_option(option_index: int) -> bool:
	if state != RunState.EVENT or !pending_card_selection.is_empty():
		return false
	if current_event.has("questionType"):
		return false
	var options: Array = current_event.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return false
	var option := options[option_index] as Dictionary
	_apply_event_effects(option.get("effects", []) as Array)
	return true


func _apply_event_effects(effects: Array) -> void:
	for index in range(effects.size()):
		_apply_run_effect(effects[index] as Dictionary)
		if !pending_card_selection.is_empty():
			var remaining: Array = []
			for remaining_index in range(index + 1, effects.size()):
				remaining.append(effects[remaining_index])
			pending_card_selection["eventRemainingEffects"] = remaining
			return
	_finish_event_option()


func _resume_pending_event_effects(selection: Dictionary) -> void:
	var context := selection.get("context", {}) as Dictionary
	if str(context.get("eventFlow", "")) == "question_reward":
		event_result["resolved"] = true
		return
	var remaining: Array = selection.get("eventRemainingEffects", []) as Array
	if remaining.is_empty():
		_finish_event_option()
		return
	_apply_event_effects(remaining)


func _finish_event_option() -> void:
	current_event = {}
	state = RunState.MAP


func _apply_event_consequence(effect: Dictionary) -> bool:
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
		"budget":
			budget = maxi(int(effect.get("minimum", 0)), budget + amount)
		"heal":
			stability = clampi(stability + amount, int(effect.get("minimum", 1)), max_stability)
		"add_negative":
			var negative_id := str(effect.get("cardId", ""))
			if !negative_defs.has(negative_id):
				return false
			deck.append(_negative_card(negative_id))
		"reveal_nodes":
			var nodes: Array = effect.get("nodes", []) as Array
			if nodes.is_empty():
				return false
			for raw_node in nodes:
				var node_id := int(raw_node)
				if node_id > 0 and !revealed_nodes.has(node_id):
					revealed_nodes.append(node_id)
			revealed_nodes.sort()
		"choose_card":
			return _open_question_card_selection(effect, "add_card")
		"add_upgraded_card":
			var card_id := str(effect.get("cardId", ""))
			if !card_defs.has(card_id):
				return false
			var card := _card_copy(card_id)
			card["upgraded"] = true
			deck.append(card)
		"upgrade_card":
			return _open_question_deck_selection(effect, "upgrade_card")
		"remove_card":
			return _open_question_deck_selection(effect, "remove_card")
		"choose_component":
			return _open_question_component_selection(effect)
		_:
			return false
	return true


func _open_question_card_selection(effect: Dictionary, action: String) -> bool:
	var card_ids: Array[String] = []
	for raw_id in effect.get("cardIds", []) as Array:
		card_ids.append(str(raw_id))
	if effect.has("cardId"):
		card_ids.append(str(effect.get("cardId", "")))
	if card_ids.is_empty():
		for raw_id in card_defs.keys():
			card_ids.append(str(raw_id))
	card_ids.sort()
	var options: Array = []
	var expected_rarity := str(effect.get("rarity", ""))
	var expected_type := str(effect.get("type", ""))
	var expected_tag := str(effect.get("tag", ""))
	for card_id in card_ids:
		if !card_defs.has(card_id):
			continue
		var card := card_defs[card_id] as Dictionary
		if !expected_rarity.is_empty() and str(card.get("rarity", "")) != expected_rarity:
			continue
		if !expected_type.is_empty() and str(card.get("type", "")) != expected_type:
			continue
		if !expected_tag.is_empty() and !(card.get("tags", []) as Array).has(expected_tag):
			continue
		options.append(_card_copy(card_id))
	if options.is_empty():
		return false
	_open_card_selection("event_card", options, [], "event", {"action": action, "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


func _open_question_deck_selection(effect: Dictionary, action: String) -> bool:
	var expected_rarity := str(effect.get("rarity", ""))
	var expected_type := str(effect.get("type", ""))
	var options: Array = []
	for index in range(deck.size()):
		var deck_card := deck[index] as Dictionary
		if bool(deck_card.get("negative", false)):
			continue
		if !expected_rarity.is_empty() and str(deck_card.get("rarity", "")) != expected_rarity:
			continue
		if !expected_type.is_empty() and str(deck_card.get("type", "")) != expected_type:
			continue
		if action == "upgrade_card" and bool(deck_card.get("upgraded", false)):
			continue
		var option := deck_card.duplicate(true)
		option["_deckIndex"] = index
		options.append(option)
	if options.is_empty():
		return false
	_open_card_selection("event_card", options, [], "event", {"action": action, "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


func _open_question_component_selection(effect: Dictionary) -> bool:
	var component_ids: Array[String] = []
	for raw_id in effect.get("componentIds", []) as Array:
		component_ids.append(str(raw_id))
	if effect.has("componentId"):
		component_ids.append(str(effect.get("componentId", "")))
	if component_ids.is_empty():
		for raw_id in relic_defs.keys():
			component_ids.append(str(raw_id))
	component_ids.sort()
	var options: Array = []
	for component_id in component_ids:
		if relic_defs.has(component_id) and !relics.has(component_id):
			options.append((relic_defs[component_id] as Dictionary).duplicate(true))
	if options.is_empty():
		return false
	_open_card_selection("event_component", options, [], "event", {"action": "add_component", "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


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
		"select_card":
			_open_event_card_selection(effect)
		"select_component":
			_open_event_component_selection(effect)


func _open_event_card_selection(effect: Dictionary) -> void:
	var options: Array = []
	var card_ids: Array = effect.get("cardIds", []) as Array
	if effect.has("cardId"):
		card_ids.append(effect.get("cardId", ""))
	for raw_card_id in card_ids:
		var card_id := str(raw_card_id)
		if card_defs.has(card_id):
			options.append(_card_copy(card_id))
	_open_card_selection("event_card", options, [], "event", {"action": "add_card"})


func _open_event_component_selection(effect: Dictionary) -> void:
	var options: Array = []
	var component_ids: Array = effect.get("componentIds", []) as Array
	if effect.has("componentId"):
		component_ids.append(effect.get("componentId", ""))
	for raw_component_id in component_ids:
		var component_id := str(raw_component_id)
		if relic_defs.has(component_id) and !relics.has(component_id):
			options.append((relic_defs[component_id] as Dictionary).duplicate(true))
	_open_card_selection("event_component", options, [], "event", {"action": "add_component"})


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
	var boss_preparation_shop := current_layer == 9 or current_layer == 11
	var guaranteed_id := _guaranteed_boss_shop_card_id() if boss_preparation_shop else _boss_gap_card_id()
	if !guaranteed_id.is_empty() and ids.has(guaranteed_id):
		var guaranteed_card := _card_copy(guaranteed_id)
		guaranteed_card["price"] = (
			mini(_card_price(guaranteed_card), budget)
			if boss_preparation_shop
			else _card_price(guaranteed_card)
		)
		shop_cards.append(guaranteed_card)
		ids.erase(guaranteed_id)
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


func _missing_boss_stage_tags() -> Array[String]:
	var missing: Array[String] = []
	for raw_requirement in BOSS_STAGE_TAG_REQUIREMENTS:
		var requirement := raw_requirement as Dictionary
		if !_deck_has_any_tag(requirement.get("tags", []) as Array):
			missing.append(str(requirement.get("id", "")))
	return missing


func _guaranteed_boss_shop_card_id() -> String:
	var missing := _missing_boss_stage_tags()
	if missing.is_empty():
		return ""
	var required_tags: Array = []
	for raw_requirement in BOSS_STAGE_TAG_REQUIREMENTS:
		var requirement := raw_requirement as Dictionary
		if str(requirement.get("id", "")) == missing[0]:
			required_tags = requirement.get("tags", []) as Array
			break

	var best_id := ""
	var best_price := 0
	for raw_id in card_defs.keys():
		var card_id := str(raw_id)
		var card := card_defs[card_id] as Dictionary
		if !["common", "uncommon"].has(str(card.get("rarity", ""))):
			continue
		var card_tags: Array = card.get("tags", [])
		var fills_gap := false
		for raw_tag in required_tags:
			if card_tags.has(str(raw_tag)):
				fills_gap = true
				break
		if !fills_gap:
			continue
		var price := _card_price(card)
		if best_id.is_empty() or price < best_price:
			best_id = card_id
			best_price = price
	return best_id


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
		_activate_relic(component_id)
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
			_activate_relic(str(relic_id))
			return


func _activate_relic(relic_id: String) -> void:
	var effect := (relic_defs.get(relic_id, {}) as Dictionary).get("effect", {}) as Dictionary
	var effect_id := str(effect.get("id", ""))
	if effect_id.is_empty():
		return
	powers[effect_id] = int(powers.get(effect_id, 0)) + int(effect.get("amount", 0))


func _reset_lab_fixture(deck_fixture: String) -> void:
	node_lab_active = true
	_reset_run()
	formal_run_active = false
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
	run_seed = int(selected_entry.get("seedId", run_seed))
	rng.seed = run_seed
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
		"event", "question_event":
			var selected_event := (event_defs.get(str(selected_entry.get("contentId", "")), {}) as Dictionary).duplicate(true)
			if selected_event.is_empty():
				return false
			_begin_question_event(selected_event)
		"question_correct", "question_wrong":
			var result_event := (event_defs.get(str(selected_entry.get("contentId", "")), {}) as Dictionary).duplicate(true)
			if result_event.is_empty():
				return false
			_begin_question_event(result_event)
			if !force_lab_question_result(kind == "question_correct"):
				return false
		"fault_rule":
			var fault_enemy_id := str(selected_entry.get("contentId", ""))
			var fault_tier := str(selected_entry.get("tier", "ordinary"))
			current_node = {"type": fault_tier, "contentId": fault_enemy_id}
			_start_encounter(fault_enemy_id, fault_tier)
			if current_encounter.is_empty() or !_prepare_lab_fault_rule_hand():
				return false
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
	if node_lab_overlay != null:
		node_lab_overlay.show_scenario_controls()
	return true


func _prepare_lab_fault_rule_hand() -> bool:
	var rule_id := str(_fault_rule_definition().get("id", ""))
	var card_ids := _lab_fault_rule_hand_ids(rule_id)
	if card_ids.is_empty():
		return false
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	for card_id in card_ids:
		var card := _card_copy(card_id)
		if card.is_empty():
			return false
		hand.append(card)
	processing_points = 6
	if rule_id == "lcd_unprepared_output":
		trusted_data["smoke"] = 1
	elif rule_id == "alarm_without_trust":
		alarm_markers = 1
	elif rule_id == "i2c_second_transaction":
		raw_data["light"] = 2
	return true


func _lab_fault_rule_hand_ids(rule_id: String) -> Array[String]:
	var ids: Array[String] = []
	match rule_id:
		"mq2_uncalibrated":
			ids.append_array(["mq2_sample", "mq2_sample", "environment_baseline"])
		"bh1750_stale_raw":
			ids.append_array(["bh1750_read", "data_cache"])
		"adc_second_collect":
			ids.append_array(["mq2_sample", "bh1750_read", "outlier_reject"])
		"lcd_unprepared_output":
			ids.append_array(["lcd_display", "data_cache"])
		"alarm_without_trust":
			ids.append_array(["led_alarm", "sliding_average"])
		"i2c_second_transaction":
			ids.append_array(["i2c_transaction", "i2c_transaction", "environment_baseline"])
	return ids


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
	if node_lab_overlay != null:
		node_lab_overlay.show_catalog()
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
	if !formal_run_active:
		_render_state()
		return
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
