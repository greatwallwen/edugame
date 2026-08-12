extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")
const EnvSpireBackdrop = preload("res://scripts/env_spire_backdrop.gd")
const EnvSpireCombatVisual = preload("res://scripts/env_spire_combat_visual.gd")
const EnvSpireCombatStage = preload("res://scripts/env_spire_combat_stage.gd")
const EnvSpireTechFrame = preload("res://scripts/env_spire_tech_frame.gd")
const IntentBadge = preload("res://scripts/env_spire_intent_badge.gd")
const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const CardRules = preload("res://scripts/env_spire_card_rules.gd")
const FaultRules = preload("res://scripts/env_spire_fault_rules.gd")
const ComponentRules = preload("res://scripts/env_spire_component_rules.gd")
const RunRules = preload("res://scripts/env_spire_run_rules.gd")
const Content = preload("res://scripts/env_spire_content.gd")
const UIMotion = preload("res://scripts/env_spire_ui_motion.gd")
const CardView = preload("res://scripts/env_spire_card_view.gd")
const RoutePresenter = preload("res://scripts/env_spire_route_presenter.gd")
const ChoicePresenter = preload("res://scripts/env_spire_choice_presenter.gd")
const TutorialPresenter = preload("res://scripts/env_spire_tutorial_presenter.gd")
const FeedbackPresenter = preload("res://scripts/env_spire_feedback_presenter.gd")
const StartMenuView = preload("res://scripts/env_spire_start_menu.gd")
const CodexProgress = preload("res://scripts/env_spire_codex_progress.gd")
const CodexView = preload("res://scripts/env_spire_codex_view.gd")
const RunPersistence = preload("res://scripts/env_spire_run_persistence.gd")
const SettingsStore = preload("res://scripts/env_spire_settings_store.gd")
const SettingsView = preload("res://scripts/env_spire_settings_view.gd")
const LearningReport = preload("res://scripts/env_spire_learning_report.gd")
const MapEnergyRenderer = preload("res://scripts/env_spire_map_energy.gd")
const RunSnapshot = preload("res://scripts/env_spire_run_snapshot.gd")
const ServiceController = preload("res://scripts/env_spire_service_controller.gd")
const NodeLabController = preload("res://scripts/env_spire_node_lab_controller.gd")
const MAP_BACKDROP_TEXTURE = preload("res://assets/ui/map-spire-backdrop-v1.png")
const UI_FONT_PATH := "res://assets/fonts/DingTalkJinBuTi.ttf"
const TUTORIAL_VERSION := 1
const TUTORIAL_RECORD_PATH := "user://ch09_tutorial.cfg"
const CODEX_RECORD_PATH := "user://ch09_codex.cfg"
const RUN_SAVE_PATH := "user://ch09_run_save.json"
const SETTINGS_PATH := "user://ch09_settings.cfg"
const STARTER_CARD_IDS := [
	"mq2_sample", "mq2_sample", "bh1750_read", "hdc1080_read",
	"adc_convert", "adc_convert", "i2c_transaction", "i2c_transaction",
	"unit_convert", "sliding_average", "sliding_average", "uart_log"
]
const SOURCE_ORDER := ["smoke", "light", "temp", "humidity"]
const STAGE_ORDER := ["collect", "interface", "process", "output"]
const BOSS_OUTPUT_TAGS := ["display", "uart", "alarm", "scheduler", "acceptance"]
const KNOWLEDGE_TAG_NAMES := {
	"mq2": "MQ-2 预热与校准", "smoke": "烟雾采样", "light": "光照采样",
	"temp": "温度采样", "humidity": "湿度采样", "adc": "ADC 转换",
	"i2c": "I2C 总线事务", "uart": "UART 输出", "display": "显示输出",
	"alarm": "报警判定", "filter": "数据滤波", "calibration": "传感器校准",
	"buffer": "数据缓冲", "scheduler": "任务调度", "diagnosis": "故障诊断",
	"calculation": "数据计算", "trusted_data": "可信数据", "acceptance": "验收输出",
	"sensor-basics": "传感器基础", "data-trust": "数据可信度",
	"bus-scheduling": "总线与调度"
}
const BOSS_STAGE_TAG_REQUIREMENTS := [
	{"id": "source", "tags": ["smoke", "light", "temp", "humidity"]},
	{"id": "trusted", "tags": ["adc", "i2c", "calculation", "trusted_data"]},
	{"id": "filter", "tags": ["filter", "calibration"]}
]
const BOSS_DRAW_SEED := 90909
const RUN_NODE_COUNT := 12
const SERVICE_REPAIR_AMOUNT := 20
const SERVICE_UPGRADE_DAMAGE := 8
const SERVICE_MAINTENANCE_MAX_STABILITY_COST := 5
const SERVICE_ACTIONS := ["maintenance", "upgrade", "add", "remove", "skip"]
const MAP_TOWER_AXIS_OFFSET_X := 16.0
const MIN_DESKTOP_VIEWPORT := Vector2(1024, 576)
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

enum RunState { WAITING, MAP, COMBAT, REWARD, EVENT, REST, COMPONENT, RESULT, MENU, CODEX }

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
var event_mechanic_defs := {}
var question_defs := {}
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
var pending_service_energy_penalty := 0
var pending_service_reroute_lock := false
var current_layer := 0
var visited_nodes: Array = []
var checkpoints_passed := 0
var checkpoint_results: Array = []
var boss_phase := 0
var boss_gate_ids: Array[String] = []
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
var component_tracking: Dictionary = {}

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
var phase_calibrations_played := 0
var phase_output_types := {}
var phase_output_uses := {}
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
var message_log: Array = []
var debug_reports: Array = []
var knowledge_stats: Dictionary = {}
var node_lab_active := false
var tutorial_step := TutorialStep.INACTIVE
var tutorial_active := false
var formal_run_active := false
var initial_experience_started := false
var tutorial_record_path := TUTORIAL_RECORD_PATH
var codex_record_path := CODEX_RECORD_PATH
var run_save_path := RUN_SAVE_PATH
var settings_path := SETTINGS_PATH
var settings: Dictionary = SettingsStore.defaults()
var last_save_hash := 0
var autosave_elapsed := 0.0
var codex_progress: Dictionary = CodexProgress.empty_progress()
var lab_current_entry := {}
var lab_deck_fixture := "starter"
var node_lab_overlay: CanvasLayer
var host_paused := false
var host_pause_overlay: CanvasLayer
var desktop_only_overlay: CanvasLayer

var ui_font: Font
var ui_font_strong: Font
var ui_font_display: Font
var ui_theme: Theme
var shell: VBoxContainer
var header_panel: PanelContainer
var brand_label: Label
var layer_label: Label
var stability_label: Label
var deck_label: Label
var main_area: Control
var start_menu_view: PanelContainer
var codex_view: PanelContainer
var settings_view: PanelContainer
var run_menu_layer: CanvasLayer
var run_menu_panel: PanelContainer
var new_run_dialog: ConfirmationDialog
var run_action_dialog: ConfirmationDialog
var pending_run_action := ""
var settings_return_to_run_menu := false
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
var tutorial_menu_button: Button
var map_view: PanelContainer
var map_backdrop: TextureRect
var map_energy_overlay: TextureRect
var map_title: Label
var map_composition: BoxContainer
var map_mission_summary: Label
var map_mission_progress: ProgressBar
var map_route_scroll: ScrollContainer
var map_route: VBoxContainer
var map_next_detail: Label
var map_enter_button: Button
var map_transition_active := false
var map_transition_last_target := 0
var map_charge_animation_active := false
var combat_view: PanelContainer
var combat_layout: BoxContainer
var combat_margin: MarginContainer
var encounter_arena: BoxContainer
var hand_dock: VBoxContainer
var tutorial_combat_spacer: Control
var dock_header: HBoxContainer
var hand_title: Label
var engineering_chain_strip: HBoxContainer
var chain_stage_labels := {}
var chain_current_status: Label
var chain_next_status: Label
var chain_reward_status: Label
var combat_actions: HBoxContainer
var processing_point_counter: Label
var encounter_name_label: Label
var encounter_meta_label: Label
var intent_label: Button
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
var device_telemetry_visual: Control
var evidence_signal_visual: Control
var fault_core_visual: Control
var hand_scroll: ScrollContainer
var hand_row: HBoxContainer
var hand_body: HBoxContainer
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
var resolved_device_visual: Control
var resolved_evidence_visual: Control
var resolved_fault_visual: Control
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
var service_bench_label: Label
var component_rack: PanelContainer
var component_rack_label: Label
var result_view: PanelContainer
var result_title: Label
var result_metrics: Label
var result_learning_summary: Label
var result_review_button: Button
var log_label: Label
var combat_feedback_layer: CanvasLayer
var combat_feedback_root: Control
var combat_motion_layer: Control
var combat_feedback_banner: PanelContainer
var combat_feedback_title: Label
var combat_feedback_detail: Label
var combat_feedback_flash: ColorRect
var boss_phase_overlay: PanelContainer
var boss_phase_title: Label
var boss_phase_subtitle: Label
var boss_phase_markers: Array[Label] = []
var combat_sound_toggle: Button
var combat_feedback_audio: AudioStreamPlayer
var combat_feedback_history: Array[Dictionary] = []
var combat_feedback_queue: Array[Dictionary] = []
var combat_feedback_playing := false
var combat_feedback_active_event: Dictionary = {}
var combat_feedback_tones := {}
var combat_sound_enabled := true
var reduced_flash := false
var combat_feedback_tween: Tween
var combat_flash_tween: Tween
var boss_phase_overlay_tween: Tween
var repair_value_tween: Tween
var stability_flash_tween: Tween
var card_action_tween: Tween
var card_action_ghost: Control
var card_action_queue: Array[Dictionary] = []
var active_card_action: Dictionary = {}
var next_card_action_token := 1
var reserved_card_action_cost := 0
var settled_card_action_count := 0
var rejected_card_action_count := 0
var deferred_encounter_finish := false
var settling_card_action := false
var motion_duration_scale := 1.0
var rendered_state_for_motion := -999
var rendered_hand_size_for_motion := -1
var card_selection_was_visible := false
var rendered_repair_value := -1
var rendered_repair_target := -1
var rendered_stability_value := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local_content()
	_load_codex_progress()
	settings = SettingsStore.load(settings_path)
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
		"fallbacks": {
			"questions": "res://data/questions.local.json"
		},
		"defaults": {
			"runMapId": "mvp_a",
			"maxStability": 70
		}
	})
	runtime.initialized.connect(_on_session_initialized)
	runtime.reset_requested.connect(_on_runtime_reset)
	runtime.pause_requested.connect(func() -> void: _set_host_paused(true))
	runtime.resume_requested.connect(func() -> void: _set_host_paused(false))
	add_child(runtime)


func _on_session_initialized(session: Dictionary) -> void:
	var config := session.get("config", {}) as Dictionary
	run_map_id = str(config.get("runMapId", run_map_id))
	max_stability = int(config.get("maxStability", max_stability))
	var knowledge := session.get("knowledge", {}) as Dictionary
	var loaded_questions = knowledge.get("questions", [])
	if typeof(loaded_questions) == TYPE_ARRAY and !(loaded_questions as Array).is_empty():
		_apply_question_content(loaded_questions as Array)
	elif event_defs.is_empty():
		runtime.log_warning("Ch09 initialized without a usable question bank.")
	if !initial_experience_started:
		_start_initial_experience()
	elif _node_lab_requested():
		_enter_node_lab()
	elif _tutorial_forced():
		_start_tutorial_briefing()
		_render_state()
	else:
		show_start_menu()
	runtime.log_info("Ch09 environment spire initialized.")


func _on_runtime_reset() -> void:
	_set_host_paused(false)
	if formal_run_active:
		_delete_run_save()
	if state in [RunState.MENU, RunState.CODEX]:
		show_start_menu()
		return
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
	_completed_version: int
) -> String:
	if node_lab_requested:
		return "node_lab"
	if tutorial_forced:
		return "tutorial"
	return "menu"


func _load_codex_progress() -> void:
	var valid_card_ids: Array[String] = []
	valid_card_ids.assign(card_defs.keys())
	valid_card_ids.sort()
	var valid_fault_ids: Array[String] = []
	valid_fault_ids.assign(enemy_defs.keys())
	valid_fault_ids.sort()
	codex_progress = CodexProgress.load_progress(codex_record_path, valid_card_ids, valid_fault_ids)


func _unlock_codex_entry(kind: String, content_id: String) -> bool:
	var definitions: Dictionary = card_defs if kind == "cards" else enemy_defs if kind == "faults" else {}
	if content_id.is_empty() or !definitions.has(content_id):
		return false
	if !CodexProgress.unlock(codex_progress, kind, content_id):
		return false
	if !CodexProgress.save_progress(codex_record_path, codex_progress):
		push_warning("Unable to save Ch09 codex progress.")
	_refresh_start_menu()
	_refresh_codex()
	return true


func _refresh_start_menu() -> void:
	if start_menu_view == null:
		return
	var card_ids := codex_progress.get("cards", []) as Array
	var fault_ids := codex_progress.get("faults", []) as Array
	start_menu_view.configure(
		_load_tutorial_completed_version() != TUTORIAL_VERSION,
		Vector2i(card_ids.size(), card_defs.size()),
		Vector2i(fault_ids.size(), enemy_defs.size()),
		_has_valid_run_save()
	)


func _refresh_codex() -> void:
	if codex_view != null:
		codex_view.configure(card_defs, enemy_defs, codex_progress)


func show_start_menu() -> void:
	formal_run_active = false
	tutorial_active = false
	tutorial_step = TutorialStep.INACTIVE
	node_lab_active = false
	if node_lab_overlay != null:
		node_lab_overlay.visible = false
	if shell != null:
		shell.visible = true
		shell.offset_top = 0.0
	if header_panel != null:
		header_panel.visible = true
	_reset_card_action_queue()
	pending_card_selection.clear()
	combat_feedback_queue.clear()
	combat_feedback_active_event.clear()
	combat_feedback_playing = false
	if combat_feedback_banner != null:
		combat_feedback_banner.hide()
	state = RunState.MENU
	_refresh_start_menu()
	_render_state()


func select_start_menu_command(command: String) -> bool:
	if state != RunState.MENU:
		return false
	match command:
		"tutorial":
			_start_tutorial_briefing()
			_render_state()
		"run":
			if _has_valid_run_save():
				new_run_dialog.popup_centered()
			else:
				_start_clean_formal_run()
		"resume":
			if !_resume_formal_run():
				return false
		"settings":
			_open_settings()
		"node_lab":
			_enter_node_lab()
		"codex":
			state = RunState.CODEX
			_refresh_codex()
			_render_state()
		_:
			return false
	return true


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
			show_start_menu()
	_render_state()


func _start_tutorial_briefing() -> void:
	formal_run_active = false
	tutorial_active = true
	tutorial_step = TutorialStep.BRIEFING
	state = RunState.WAITING


func _start_clean_formal_run() -> void:
	tutorial_active = false
	tutorial_step = TutorialStep.INACTIVE
	_delete_run_save()
	_reset_run()
	_render_state()


func _skip_tutorial(record_path: String = "") -> bool:
	if !_gameplay_action_allowed():
		return false
	return _complete_tutorial(record_path)


func _complete_tutorial(record_path: String = "") -> bool:
	if !_gameplay_action_allowed():
		return false
	var persisted := _save_tutorial_completion(record_path)
	_start_clean_formal_run()
	return persisted


func _complete_tutorial_to_menu(record_path: String = "") -> bool:
	if !_gameplay_action_allowed():
		return false
	var persisted := _save_tutorial_completion(record_path)
	show_start_menu()
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


func _build_run_menu() -> void:
	new_run_dialog = ConfirmationDialog.new()
	new_run_dialog.name = "NewRunConfirmation"
	new_run_dialog.theme = ui_theme
	new_run_dialog.title = "开始新游戏"
	new_run_dialog.dialog_text = "当前正式运行会被覆盖。确认开始新游戏？"
	new_run_dialog.get_ok_button().text = "确认"
	new_run_dialog.get_cancel_button().text = "取消"
	new_run_dialog.confirmed.connect(func() -> void:
		_delete_run_save()
		_start_clean_formal_run()
	)
	add_child(new_run_dialog)
	run_action_dialog = ConfirmationDialog.new()
	run_action_dialog.name = "RunActionConfirmation"
	run_action_dialog.theme = ui_theme
	run_action_dialog.get_ok_button().text = "确认"
	run_action_dialog.get_cancel_button().text = "取消"
	run_action_dialog.confirmed.connect(_confirm_run_action)
	add_child(run_action_dialog)
	run_menu_layer = CanvasLayer.new()
	run_menu_layer.name = "RunMenuLayer"
	run_menu_layer.layer = 80
	add_child(run_menu_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.09, 0.10, 0.78)
	run_menu_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_menu_layer.add_child(center)
	run_menu_panel = PanelContainer.new()
	run_menu_panel.name = "RunMenuPanel"
	run_menu_panel.theme = ui_theme
	run_menu_panel.custom_minimum_size = Vector2(420, 420)
	run_menu_panel.add_theme_stylebox_override("panel", VisualTheme.panel_style(Color("#f8fafbfa"), VisualTheme.color("focus_soft"), 1, 6, 10))
	center.add_child(run_menu_panel)
	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 28)
	menu_margin.add_theme_constant_override("margin_right", 28)
	menu_margin.add_theme_constant_override("margin_top", 24)
	menu_margin.add_theme_constant_override("margin_bottom", 24)
	run_menu_panel.add_child(menu_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	menu_margin.add_child(column)
	var title := Label.new()
	title.name = "RunMenuTitle"
	title.text = "运行菜单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VisualTheme.apply_heading(title, ui_font_display, 26)
	column.add_child(title)
	for definition in [
		{"name": "RunMenuContinue", "text": "继续", "call": func() -> void: _close_run_menu()},
		{"name": "RunMenuSettings", "text": "设置", "call": func() -> void: _open_settings()},
		{"name": "RunMenuSaveReturn", "text": "保存并返回", "call": func() -> void: _save_and_return_to_menu()},
		{"name": "RunMenuRestart", "text": "重新开始", "call": func() -> void: _request_run_action("restart")},
		{"name": "RunMenuAbandon", "text": "放弃本局", "call": func() -> void: _request_run_action("abandon")}
	]:
		var button := Button.new()
		button.name = str(definition.name)
		button.text = str(definition.text)
		button.custom_minimum_size.y = 52
		_skin_button(button, VisualTheme.color("focus"))
		button.pressed.connect(definition.call as Callable)
		column.add_child(button)
	run_menu_layer.hide()


func _open_run_menu() -> void:
	if !formal_run_active or tutorial_active or node_lab_active or completed:
		return
	run_menu_layer.show()


func _close_run_menu() -> void:
	if settings_view != null and settings_view.visible:
		settings_view.hide()
	run_menu_layer.hide()


func _open_settings() -> void:
	settings_return_to_run_menu = run_menu_layer != null and run_menu_layer.visible
	if settings_return_to_run_menu:
		run_menu_layer.hide()
	settings_view.configure(settings)
	settings_view.show()
	settings_view.move_to_front()


func _close_settings() -> void:
	settings_view.hide()
	if settings_return_to_run_menu and formal_run_active:
		run_menu_layer.show()
	settings_return_to_run_menu = false
	if state == RunState.MENU:
		start_menu_view.show()


func _apply_settings(value: Dictionary) -> void:
	settings = SettingsStore.validate(value)
	SettingsStore.save(settings_path, settings)
	set_combat_sound_enabled(bool(settings.sfxEnabled))
	if combat_feedback_audio != null:
		combat_feedback_audio.volume_db = linear_to_db(maxf(float(settings.sfxVolume), 0.001))
	motion_duration_scale = 1.0 / float(settings.animationSpeed)
	reduced_flash = bool(settings.reducedFlash)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo and event.keycode == KEY_ESCAPE:
		if settings_view != null and settings_view.visible:
			_close_settings()
		elif run_menu_layer != null and run_menu_layer.visible:
			_close_run_menu()
		else:
			_open_run_menu()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and combat_layout != null:
		_sync_combat_feedback_viewport()
		_apply_desktop_layout()
		_update_desktop_only_overlay()


func _process(delta: float) -> void:
	if combat_feedback_playing and combat_feedback_banner != null and combat_feedback_banner.visible and !combat_feedback_active_event.is_empty():
		_position_combat_feedback(str(combat_feedback_active_event.get("kind", "")), combat_feedback_active_event)
	if DisplayServer.get_name() != "headless" and formal_run_active and !tutorial_active and !node_lab_active and !completed:
		autosave_elapsed += delta
		if autosave_elapsed >= 0.4 and !_card_actions_pending():
			autosave_elapsed = 0.0
			_save_run_now()


func _load_ui() -> void:
	var base_font: Font
	if ResourceLoader.exists(UI_FONT_PATH):
		base_font = load(UI_FONT_PATH) as Font
	if base_font == null:
		push_warning("Missing UI font: " + UI_FONT_PATH)
		base_font = ThemeDB.fallback_font
	ui_font = VisualTheme.font_for_role(base_font, "body")
	ui_font_strong = VisualTheme.font_for_role(base_font, "strong")
	ui_font_display = VisualTheme.font_for_role(base_font, "display")
	ui_theme = Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", VisualTheme.color("text_primary"))
	ui_theme.set_color("font_color", "Button", VisualTheme.color("button_text"))
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", VisualTheme.color("button_text"))
	ui_theme.set_color("font_disabled_color", "Button", VisualTheme.color("button_text_muted"))
	ui_theme.set_color("font_color", "CheckButton", VisualTheme.color("text_primary"))
	ui_theme.set_color("font_color", "OptionButton", VisualTheme.color("text_primary"))
	theme = ui_theme


func _build_ui() -> void:
	var background := EnvSpireBackdrop.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var header_style := VisualTheme.panel_style(Color("#f8fbfcf7"), Color("#91a5af"), 1, 0)
	header_style.border_width_bottom = 2
	header_panel.add_theme_stylebox_override("panel", header_style)
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
	VisualTheme.apply_heading(brand_label, ui_font_display, 20)
	header_row.add_child(brand_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	layer_label = _header_metric(header_row)
	stability_label = _header_metric(header_row)
	deck_label = _header_metric(header_row)
	main_area = Control.new()
	main_area.name = "SceneStage"
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.custom_minimum_size = Vector2(0, 420)
	shell.add_child(main_area)
	main_area.add_child(_build_scene_grid())
	start_menu_view = StartMenuView.new()
	start_menu_view.command_selected.connect(func(command: String) -> void:
		select_start_menu_command(command)
	)
	main_area.add_child(start_menu_view)
	codex_view = CodexView.new()
	codex_view.close_requested.connect(show_start_menu)
	main_area.add_child(codex_view)
	settings_view = SettingsView.new()
	settings_view.settings_changed.connect(_apply_settings)
	settings_view.close_requested.connect(_close_settings)
	main_area.add_child(settings_view)
	settings_view.hide()
	map_view = _scene_panel("MapView", Color("#f4f8f9e6"), Color("#91a5af"))
	combat_view = _scene_panel("CombatView", Color("#f4f8f9e6"), Color("#91a5af"))
	choice_view = _scene_panel("ChoiceView", Color("#f4f8f9e6"), Color("#91a5af"))
	result_view = _scene_panel("ResultView", Color("#f4f8f9e6"), Color("#91a5af"))
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
	_build_combat_feedback_layer()
	_build_host_pause_overlay()
	_build_desktop_only_overlay()
	_build_run_menu()
	_apply_settings(settings)
	_refresh_start_menu()
	_refresh_codex()

	var footer := PanelContainer.new()
	footer.name = "RunFooter"
	footer.custom_minimum_size = Vector2(0, 44)
	var footer_style := VisualTheme.panel_style(Color("#f7fafbf7"), Color("#91a5af"), 1, 0)
	footer_style.border_width_top = 2
	footer.add_theme_stylebox_override("panel", footer_style)
	shell.add_child(footer)
	log_label = Label.new()
	log_label.name = "LogLabel"
	log_label.offset_left = 16
	log_label.offset_right = -16
	log_label.offset_top = 8
	log_label.offset_bottom = -8
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	footer.add_child(log_label)
	_apply_desktop_layout()
	_update_desktop_only_overlay()


func _build_desktop_only_overlay() -> void:
	desktop_only_overlay = CanvasLayer.new()
	desktop_only_overlay.name = "DesktopOnlyOverlay"
	desktop_only_overlay.layer = 90
	desktop_only_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(desktop_only_overlay)

	var blocker := ColorRect.new()
	blocker.name = "DesktopOnlyBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = VisualTheme.color("canvas")
	blocker.theme = ui_theme
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	desktop_only_overlay.add_child(blocker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 220)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#f6faf9"), Color("#4f9c8b"))
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var heading := Label.new()
	heading.name = "DesktopOnlyHeading"
	heading.text = "请使用桌面端体验"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VisualTheme.apply_heading(heading, ui_font_display, 28)
	content.add_child(heading)

	var detail := Label.new()
	detail.name = "DesktopOnlyDetail"
	detail.text = "环境监测工程需要 1024 × 576 或更大的桌面视口。"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_override("font", ui_font)
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	content.add_child(detail)

	desktop_only_overlay.hide()


func is_desktop_viewport_supported(viewport_size: Vector2) -> bool:
	return (
		viewport_size.x >= MIN_DESKTOP_VIEWPORT.x
		and viewport_size.y >= MIN_DESKTOP_VIEWPORT.y
	)


func _effective_desktop_viewport_size() -> Vector2:
	var headless_placeholder := (
		DisplayServer.get_name() == "headless"
		and size.x <= 64.0
		and size.y <= 64.0
	)
	if size.x > 0.0 and size.y > 0.0 and !headless_placeholder:
		return size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	)


func _update_desktop_only_overlay() -> void:
	if desktop_only_overlay == null:
		return
	desktop_only_overlay.visible = !is_desktop_viewport_supported(_effective_desktop_viewport_size())


func _build_host_pause_overlay() -> void:
	host_pause_overlay = CanvasLayer.new()
	host_pause_overlay.name = "HostPauseOverlay"
	host_pause_overlay.layer = 100
	host_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(host_pause_overlay)

	var blocker := ColorRect.new()
	blocker.name = "HostPauseBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.03, 0.07, 0.08, 0.78)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	host_pause_overlay.add_child(blocker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.add_child(center)
	var status := Label.new()
	status.name = "HostPauseStatus"
	status.text = "课程已暂停"
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color("#edf7f5"))
	center.add_child(status)
	host_pause_overlay.hide()


func _set_host_paused(paused: bool) -> void:
	host_paused = paused
	if paused:
		if host_pause_overlay != null:
			host_pause_overlay.show()
		get_tree().paused = true
	else:
		get_tree().paused = false
		if host_pause_overlay != null:
			host_pause_overlay.hide()
		if bool(active_card_action.get("animationComplete", false)):
			call_deferred("_settle_active_card_action")
		else:
			call_deferred("_process_next_card_action")


func _gameplay_action_allowed() -> bool:
	return (
		!host_paused
		and is_desktop_viewport_supported(_effective_desktop_viewport_size())
	)


func _build_combat_feedback_layer() -> void:
	combat_feedback_layer = CanvasLayer.new()
	combat_feedback_layer.name = "CombatFeedbackLayer"
	combat_feedback_layer.layer = 40
	add_child(combat_feedback_layer)

	combat_feedback_root = Control.new()
	combat_feedback_root.name = "CombatFeedbackRoot"
	combat_feedback_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	combat_feedback_root.position = Vector2.ZERO
	combat_feedback_root.size = _effective_desktop_viewport_size()
	combat_feedback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback_root.theme = ui_theme
	combat_feedback_layer.add_child(combat_feedback_root)

	combat_feedback_flash = ColorRect.new()
	combat_feedback_flash.name = "CombatFeedbackFlash"
	combat_feedback_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_feedback_flash.color = Color(0.72, 0.25, 0.20, 0.0)
	combat_feedback_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback_root.add_child(combat_feedback_flash)

	combat_motion_layer = Control.new()
	combat_motion_layer.name = "CombatMotionLayer"
	combat_motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_motion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback_root.add_child(combat_motion_layer)
	_build_boss_phase_overlay()

	combat_feedback_banner = PanelContainer.new()
	combat_feedback_banner.name = "CombatFeedbackBanner"
	combat_feedback_banner.custom_minimum_size = Vector2(96, 66)
	combat_feedback_banner.position = Vector2(18, 78)
	combat_feedback_banner.size = Vector2(286, 66)
	combat_feedback_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback_banner.add_theme_stylebox_override("panel", _feedback_banner_style(Color("#2f7f8d")))
	combat_feedback_root.add_child(combat_feedback_banner)

	var banner_content := VBoxContainer.new()
	banner_content.add_theme_constant_override("separation", 1)
	combat_feedback_banner.add_child(banner_content)
	combat_feedback_title = Label.new()
	combat_feedback_title.name = "CombatFeedbackTitle"
	combat_feedback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_feedback_title.clip_text = true
	combat_feedback_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	combat_feedback_title.add_theme_font_size_override("font_size", 17)
	combat_feedback_title.add_theme_color_override("font_color", Color.WHITE)
	banner_content.add_child(combat_feedback_title)
	combat_feedback_detail = Label.new()
	combat_feedback_detail.name = "CombatFeedbackDetail"
	combat_feedback_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_feedback_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_feedback_detail.max_lines_visible = 2
	combat_feedback_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	combat_feedback_detail.add_theme_font_size_override("font_size", 12)
	combat_feedback_detail.add_theme_color_override("font_color", Color("#dceff0"))
	banner_content.add_child(combat_feedback_detail)
	combat_feedback_banner.hide()

	combat_sound_toggle = Button.new()
	combat_sound_toggle.name = "CombatSoundToggle"
	combat_sound_toggle.text = "SFX ON"
	combat_sound_toggle.tooltip_text = "战斗音效"
	combat_sound_toggle.toggle_mode = true
	combat_sound_toggle.button_pressed = true
	combat_sound_toggle.anchor_left = 1.0
	combat_sound_toggle.anchor_right = 1.0
	combat_sound_toggle.offset_left = -112
	combat_sound_toggle.offset_top = 78
	combat_sound_toggle.offset_right = -16
	combat_sound_toggle.offset_bottom = 120
	combat_sound_toggle.custom_minimum_size = Vector2(96, 44)
	combat_sound_toggle.add_theme_font_size_override("font_size", 12)
	_skin_command_button(combat_sound_toggle, Color("#20d7ee"))
	combat_sound_toggle.toggled.connect(func(enabled: bool) -> void:
		set_combat_sound_enabled(enabled)
	)
	combat_feedback_root.add_child(combat_sound_toggle)

	combat_feedback_audio = AudioStreamPlayer.new()
	combat_feedback_audio.name = "CombatFeedbackAudio"
	combat_feedback_audio.volume_db = -8.0
	combat_feedback_layer.add_child(combat_feedback_audio)


func _build_boss_phase_overlay() -> void:
	boss_phase_overlay = PanelContainer.new()
	boss_phase_overlay.name = "BossPhaseOverlay"
	boss_phase_overlay.anchor_left = 0.16
	boss_phase_overlay.anchor_right = 0.84
	boss_phase_overlay.offset_top = 82
	boss_phase_overlay.offset_bottom = 194
	boss_phase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_style := _panel_style(Color(0.035, 0.075, 0.09, 0.97), Color("#8d78a9"))
	overlay_style.border_width_left = 0
	overlay_style.border_width_right = 0
	overlay_style.border_width_top = 2
	overlay_style.border_width_bottom = 2
	overlay_style.corner_radius_top_left = 0
	overlay_style.corner_radius_top_right = 0
	overlay_style.corner_radius_bottom_left = 0
	overlay_style.corner_radius_bottom_right = 0
	boss_phase_overlay.add_theme_stylebox_override("panel", overlay_style)
	combat_feedback_root.add_child(boss_phase_overlay)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	boss_phase_overlay.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)
	boss_phase_title = Label.new()
	boss_phase_title.name = "BossPhaseTitle"
	boss_phase_title.text = "COMPREHENSIVE ACCEPTANCE // PHASE 1 OF 3"
	boss_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_title.add_theme_font_size_override("font_size", 19)
	boss_phase_title.add_theme_color_override("font_color", Color("#f3eef8"))
	content.add_child(boss_phase_title)
	boss_phase_subtitle = Label.new()
	boss_phase_subtitle.name = "BossPhaseSubtitle"
	boss_phase_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_phase_subtitle.add_theme_font_size_override("font_size", 13)
	boss_phase_subtitle.add_theme_color_override("font_color", Color("#c8bdd5"))
	content.add_child(boss_phase_subtitle)

	var marker_row := HBoxContainer.new()
	marker_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	marker_row.add_theme_constant_override("separation", 18)
	content.add_child(marker_row)
	boss_phase_markers.clear()
	for marker_index in range(3):
		var marker := Label.new()
		marker.name = "BossPhaseMarker%d" % (marker_index + 1)
		marker.custom_minimum_size = Vector2(116, 22)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 11)
		marker_row.add_child(marker)
		boss_phase_markers.append(marker)
	boss_phase_overlay.hide()


func _show_boss_phase_transition(phase: int, phase_name: String) -> void:
	if boss_phase_overlay == null:
		return
	var safe_phase := clampi(phase, 1, 3)
	boss_phase_overlay.set_meta("phase", safe_phase)
	boss_phase_title.text = "COMPREHENSIVE ACCEPTANCE // PHASE %d OF 3" % safe_phase
	boss_phase_subtitle.text = phase_name
	for marker_index in range(boss_phase_markers.size()):
		var marker := boss_phase_markers[marker_index]
		var reader_phase := marker_index + 1
		if reader_phase < safe_phase:
			marker.text = "%02d  COMPLETE" % reader_phase
			marker.add_theme_color_override("font_color", Color("#62aa91"))
		elif reader_phase == safe_phase:
			marker.text = "%02d  ACTIVE" % reader_phase
			marker.add_theme_color_override("font_color", Color("#d9c8ec"))
		else:
			marker.text = "%02d  PENDING" % reader_phase
			marker.add_theme_color_override("font_color", Color("#718087"))
	if boss_phase_overlay_tween != null and boss_phase_overlay_tween.is_valid():
		boss_phase_overlay_tween.kill()
	boss_phase_overlay.show()
	boss_phase_overlay.modulate = Color(1, 1, 1, 0)
	boss_phase_overlay_tween = create_tween().bind_node(self)
	boss_phase_overlay_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	boss_phase_overlay_tween.tween_property(boss_phase_overlay, "modulate:a", 1.0, 0.12)
	boss_phase_overlay_tween.tween_interval(0.52)
	boss_phase_overlay_tween.tween_property(boss_phase_overlay, "modulate:a", 0.0, 0.22)
	boss_phase_overlay_tween.tween_callback(boss_phase_overlay.hide)
	_flash_combat_feedback(Color("#725c91"), 0.12)


func _sync_combat_feedback_viewport() -> void:
	if combat_feedback_root == null:
		return
	combat_feedback_root.position = Vector2.ZERO
	combat_feedback_root.size = _effective_desktop_viewport_size()


func _feedback_banner_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.10, 0.12, 0.96)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _chain_stage_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func combat_feedback_snapshot() -> Array:
	return combat_feedback_history.duplicate(true)


func combat_feedback_queue_size() -> int:
	return combat_feedback_queue.size()


func clear_combat_feedback_history() -> void:
	combat_feedback_history.clear()
	combat_feedback_queue.clear()
	combat_feedback_playing = false
	combat_feedback_active_event.clear()
	if combat_feedback_tween != null and combat_feedback_tween.is_valid():
		combat_feedback_tween.kill()
	if combat_feedback_banner != null:
		combat_feedback_banner.hide()
	if boss_phase_overlay_tween != null and boss_phase_overlay_tween.is_valid():
		boss_phase_overlay_tween.kill()
	if boss_phase_overlay != null:
		boss_phase_overlay.hide()


func set_combat_sound_enabled(enabled: bool) -> bool:
	combat_sound_enabled = enabled
	if combat_sound_toggle != null:
		combat_sound_toggle.text = "SFX ON" if enabled else "SFX OFF"
	if combat_sound_toggle != null and combat_sound_toggle.button_pressed != enabled:
		combat_sound_toggle.set_pressed_no_signal(enabled)
	if !enabled and combat_feedback_audio != null:
		combat_feedback_audio.stop()
	return true


func is_combat_sound_enabled() -> bool:
	return combat_sound_enabled


func combat_feedback_cue_profile(cue: String) -> Dictionary:
	return FeedbackPresenter.cue_profile(cue)


func _emit_combat_feedback(
	kind: String,
	title: String,
	detail: String,
	accent: Color,
	cue: String,
	metadata: Dictionary = {}
) -> void:
	var event := {
		"kind": kind,
		"title": title,
		"detail": detail
	}
	for key in metadata.keys():
		event[key] = metadata[key]
	combat_feedback_history.append(event)
	while combat_feedback_history.size() > 24:
		combat_feedback_history.pop_front()
	var visual_event := event.duplicate(true)
	visual_event["_accent"] = accent
	visual_event["_cue"] = cue
	var important := ["stability", "fault_suppressed", "fault_triggered", "boss_phase"].has(kind)
	if important:
		combat_feedback_queue.clear()
		if combat_feedback_playing and combat_feedback_tween != null and combat_feedback_tween.is_valid():
			combat_feedback_tween.kill()
		if combat_feedback_banner != null:
			combat_feedback_banner.hide()
		combat_feedback_playing = false
		combat_feedback_active_event.clear()
		combat_feedback_queue.push_front(visual_event)
	else:
		combat_feedback_queue.append(visual_event)
	_pulse_combat_visuals(kind, accent, event)
	if !combat_feedback_playing:
		_show_next_combat_feedback()


func _pulse_combat_visuals(kind: String, accent: Color, event: Dictionary) -> void:
	if state != RunState.COMBAT:
		return
	match kind:
		"card":
			var target := _card_visual_target({
				"type": str(event.get("cardType", "")),
				"stage": str(event.get("stage", ""))
			})
			var target_visual := _combat_visual_for_target(target)
			if target_visual != null:
				target_visual.pulse(kind, accent)
		"repair":
			if evidence_signal_visual != null:
				evidence_signal_visual.pulse(kind, accent)
		"weakness":
			if fault_core_visual != null:
				fault_core_visual.pulse(kind, accent)
		"fault_suppressed":
			for visual in [evidence_signal_visual, fault_core_visual]:
				if visual != null:
					visual.pulse(kind, accent)
		"fault_triggered", "stability":
			if fault_core_visual != null:
				fault_core_visual.pulse(kind, accent)
		"boss_phase":
			for visual in [device_telemetry_visual, evidence_signal_visual, fault_core_visual]:
				if visual != null:
					visual.pulse(kind, accent)


func _show_next_combat_feedback() -> void:
	if combat_feedback_banner == null:
		return
	if combat_feedback_queue.is_empty():
		combat_feedback_playing = false
		return
	combat_feedback_playing = true
	var event := combat_feedback_queue.pop_front() as Dictionary
	combat_feedback_active_event = event.duplicate(true)
	var kind := str(event.get("kind", ""))
	var title := str(event.get("title", ""))
	var detail := str(event.get("detail", ""))
	var accent := event.get("_accent", Color("#2f7f8d")) as Color
	var cue := str(event.get("_cue", ""))
	if kind == "boss_phase":
		_play_combat_feedback_sound(cue)
		combat_feedback_playing = false
		combat_feedback_active_event.clear()
		_show_next_combat_feedback()
		return

	combat_feedback_title.text = title
	combat_feedback_detail.text = detail
	combat_feedback_banner.add_theme_stylebox_override("panel", _feedback_banner_style(accent))
	_position_combat_feedback(kind, event)
	combat_feedback_banner.show()
	call_deferred("_position_active_combat_feedback", kind, event)
	combat_feedback_banner.modulate = Color(1, 1, 1, 0)
	if combat_feedback_tween != null and combat_feedback_tween.is_valid():
		combat_feedback_tween.kill()
	combat_feedback_tween = create_tween().bind_node(self)
	combat_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	combat_feedback_tween.tween_property(combat_feedback_banner, "modulate:a", 1.0, 0.12)
	combat_feedback_tween.tween_interval(0.75 if ["fault_triggered", "boss_phase"].has(kind) else 0.45)
	combat_feedback_tween.tween_property(combat_feedback_banner, "modulate:a", 0.0, 0.18)
	combat_feedback_tween.tween_callback(_finish_visible_combat_feedback)
	if ["stability", "fault_suppressed", "fault_triggered", "boss_phase"].has(kind):
		_flash_combat_feedback(accent, 0.18 if kind != "boss_phase" else 0.12)
	_play_combat_feedback_sound(cue)


func _position_active_combat_feedback(kind: String, event: Dictionary) -> void:
	if combat_feedback_playing and combat_feedback_banner != null and combat_feedback_banner.visible:
		_position_combat_feedback(kind, event)


func _position_combat_feedback(kind: String, event: Dictionary) -> void:
	if combat_feedback_banner == null or combat_feedback_root == null:
		return
	var target: Control = null
	var target_key := FeedbackPresenter.target_key(kind, event)
	match target_key:
		"card":
			var visual_target := _card_visual_target({
				"type": str(event.get("cardType", "")),
				"stage": str(event.get("stage", ""))
			})
			target = _combat_visual_for_target(visual_target)
		"evidence":
			target = evidence_signal_visual
		"device":
			target = device_telemetry_visual
		"fault":
			target = fault_core_visual
	if target == null:
		target = fault_core_visual if fault_core_visual != null else encounter_arena
	if target == null:
		return
	var target_rect := target.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, _effective_desktop_viewport_size())
	var banner_size := FeedbackPresenter.banner_size(target_rect.size)
	var desired_global := Vector2(
		target_rect.get_center().x - banner_size.x * 0.5,
		target_rect.get_center().y - banner_size.y * 0.5
	)
	var margin := 14.0
	desired_global.x = clampf(desired_global.x, viewport_rect.position.x + margin, viewport_rect.end.x - banner_size.x - margin)
	desired_global.y = clampf(desired_global.y, viewport_rect.position.y + margin, viewport_rect.end.y - banner_size.y - margin)
	combat_feedback_banner.position = desired_global
	combat_feedback_banner.size = banner_size


func _finish_visible_combat_feedback() -> void:
	if combat_feedback_banner != null:
		combat_feedback_banner.hide()
	combat_feedback_playing = false
	combat_feedback_active_event.clear()
	_show_next_combat_feedback()


func _flash_combat_feedback(accent: Color, alpha: float) -> void:
	if combat_feedback_flash == null:
		return
	combat_feedback_flash.color = Color(accent.r, accent.g, accent.b, alpha * (0.25 if reduced_flash else 1.0))
	if combat_flash_tween != null and combat_flash_tween.is_valid():
		combat_flash_tween.kill()
	combat_flash_tween = create_tween().bind_node(self)
	combat_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	combat_flash_tween.tween_property(combat_feedback_flash, "color:a", 0.0, 0.42)


func _play_combat_feedback_sound(cue: String) -> void:
	if !combat_sound_enabled or combat_feedback_audio == null or cue.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		return
	if !combat_feedback_tones.has(cue):
		combat_feedback_tones[cue] = _combat_tone_sequence(combat_feedback_cue_profile(cue))
	combat_feedback_audio.stream = combat_feedback_tones[cue] as AudioStream
	combat_feedback_audio.play()


func _combat_tone_sequence(profile: Dictionary) -> AudioStreamWAV:
	return FeedbackPresenter.tone_sequence(profile)


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
	var line := Color(0.32, 0.55, 0.72, 0.055)
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
	label.add_theme_font_override("font", ui_font_strong)
	label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _state_panel(node_name: String) -> PanelContainer:
	return _scene_panel(node_name, Color("#f5f9faf5"), Color("#91a5af"))


func _scene_panel(node_name: String, background: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := _panel_style(background, border)
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _new_combat_visual(node_name: String, mode: String, minimum_height: float) -> Control:
	var visual := EnvSpireCombatVisual.new() as Control
	visual.name = node_name
	visual.custom_minimum_size = Vector2(0, minimum_height)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.configure(mode, ui_font)
	return visual


func _combat_unit_style(background: Color, accent: Color, top_margin: float = 15.0) -> StyleBoxFlat:
	var style := VisualTheme.hardware_panel_style(background, accent)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.16)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = top_margin
	style.content_margin_bottom = 14
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
	return style


func _new_tech_frame(node_name: String, frame_id: String, accent: Color, profile: String = "hardware") -> Control:
	var frame := EnvSpireTechFrame.new() as Control
	frame.name = node_name
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.configure(frame_id, accent, profile)
	return frame


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var resolved_background := background
	if resolved_background.get_luminance() > 0.34:
		resolved_background = VisualTheme.color("surface")
		resolved_background.a = minf(background.a, 0.96)
	return VisualTheme.hardware_panel_style(resolved_background, border)


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	return style


func _skin_button(button: Button, accent: Color = Color("#2f7f8d")) -> void:
	if button.custom_minimum_size == Vector2.ZERO:
		button.custom_minimum_size = Vector2(120, 44)
	VisualTheme.apply_button(button, accent, ui_font_strong)
	button.add_theme_font_size_override("font_size", 15)
	UIMotion.bind_button(self, button, motion_duration_scale)


func _skin_command_button(button: Button, accent: Color) -> void:
	if button.custom_minimum_size == Vector2.ZERO:
		button.custom_minimum_size = Vector2(120, 44)
	VisualTheme.apply_command_button(button, accent, ui_font_strong)
	button.add_theme_font_size_override("font_size", 15)
	UIMotion.bind_button(self, button, motion_duration_scale)


func _skin_card_button(button: Button, card: Dictionary) -> void:
	var accent := _card_accent(card)
	var normal_surface := VisualTheme.color("surface").lerp(accent, 0.08)
	var hover_surface := VisualTheme.color("surface_hover").lerp(accent, 0.10)
	var pressed_surface := VisualTheme.color("surface_muted").lerp(accent, 0.08)
	var disabled_accent := accent.lerp(VisualTheme.color("text_muted"), 0.70)
	var disabled_surface := VisualTheme.color("surface_muted")
	button.add_theme_stylebox_override("normal", _card_button_style(normal_surface, accent))
	button.add_theme_stylebox_override("hover", _card_button_style(hover_surface, accent.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", _card_button_style(pressed_surface, accent.darkened(0.08)))
	button.add_theme_stylebox_override("disabled", _card_button_style(disabled_surface, disabled_accent))
	button.add_theme_font_override("font", ui_font_strong)
	button.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", VisualTheme.color("text_primary"))
	button.add_theme_color_override("font_disabled_color", VisualTheme.color("text_muted"))
	UIMotion.bind_button(self, button, motion_duration_scale)


func _new_card_view(
	card: Dictionary,
	mode: String,
	cost_value: Variant,
	unavailable_reason: String = "",
	card_support_text: String = ""
) -> Button:
	var button := CardView.new() as Button
	button.call("configure_card", card, mode, cost_value, unavailable_reason, card_support_text)
	if mode == "choice":
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIMotion.bind_button(self, button, motion_duration_scale)
	return button


func _card_button_style(background: Color, accent: Color) -> StyleBoxFlat:
	var style := _button_style(background, accent)
	style.set_border_width_all(1)
	style.border_width_top = 4
	style.content_margin_top = 11
	return style


func _content_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	return margin


func _build_tutorial_view() -> void:
	tutorial_view = _scene_panel("TutorialView", Color("#edf3f0e6"), Color("#446c71"))
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
	VisualTheme.apply_heading(title, ui_font_display, 24)
	tutorial_briefing_content.add_child(title)
	tutorial_route_summary = Label.new()
	tutorial_route_summary.name = "TutorialRouteSummary"
	tutorial_route_summary.text = "正式流程：12 节点单线攀登 · 节点 11 强制休整 · 节点 12 三阶段综合验收\n事件、组件与整备室调整卡组，检查点验证工程证据。"
	tutorial_route_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	VisualTheme.apply_secondary(tutorial_route_summary, ui_font, 16)
	tutorial_briefing_content.add_child(tutorial_route_summary)
	var practice_steps := HBoxContainer.new()
	practice_steps.name = "TutorialPracticeSteps"
	practice_steps.custom_minimum_size = Vector2(0, 116)
	practice_steps.add_theme_constant_override("separation", 10)
	tutorial_briefing_content.add_child(practice_steps)
	var step_specs := TutorialPresenter.briefing_steps()
	for raw_spec in step_specs:
		var spec := raw_spec as Dictionary
		var step_panel := PanelContainer.new()
		step_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_panel.add_theme_stylebox_override("panel", _panel_style(Color("#edf3f0"), spec.get("accent", Color("#2f7f8d")) as Color))
		practice_steps.add_child(step_panel)
		var step_label := Label.new()
		step_label.text = "%s  %s\n%s" % [spec.get("number", ""), spec.get("title", ""), spec.get("detail", "")]
		step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step_label.add_theme_font_size_override("font_size", 15)
		step_label.add_theme_font_override("font", ui_font_strong)
		step_label.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
		step_panel.add_child(step_label)
	var briefing_note := Label.new()
	briefing_note.text = "连接后直接进入训练战斗；界面每次只开放当前需要操作的目标。"
	briefing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_note.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	tutorial_briefing_content.add_child(briefing_note)
	tutorial_start_button = Button.new()
	tutorial_start_button.name = "TutorialStartButton"
	tutorial_start_button.text = "连接训练设备"
	tutorial_start_button.disabled = true
	tutorial_start_button.tooltip_text = "训练场景将在战斗引导就绪后启用"
	tutorial_start_button.pressed.connect(_start_tutorial_encounter)
	tutorial_start_button.disabled = false
	tutorial_start_button.tooltip_text = ""
	_skin_command_button(tutorial_start_button, VisualTheme.color("focus"))
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
	var coach_content := HBoxContainer.new()
	coach_content.add_theme_constant_override("separation", 12)
	tutorial_coach_layer.add_child(coach_content)
	var coach_copy := VBoxContainer.new()
	coach_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_copy.add_theme_constant_override("separation", 4)
	coach_content.add_child(coach_copy)
	tutorial_coach_text = Label.new()
	tutorial_coach_text.name = "TutorialCoachText"
	tutorial_coach_text.text = "按教练提示完成训练步骤。"
	tutorial_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_coach_text.add_theme_font_override("font", ui_font_strong)
	tutorial_coach_text.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
	coach_copy.add_child(tutorial_coach_text)
	tutorial_completion_summary = Label.new()
	tutorial_completion_summary.name = "TutorialCompletionSummary"
	tutorial_completion_summary.text = "循环：读取意图 -> 消耗处理点 -> 建立证据 -> 修复故障 -> 改善牌组\n战斗奖励加牌；功能节点改变本局。\nLED 仅用于训练；正式起始牌组会重置。"
	tutorial_completion_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_completion_summary.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	coach_copy.add_child(tutorial_completion_summary)
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
	tutorial_menu_button = Button.new()
	tutorial_menu_button.name = "TutorialMenuButton"
	tutorial_menu_button.text = "返回菜单"
	_skin_button(tutorial_menu_button, Color("#697b80"))
	tutorial_menu_button.custom_minimum_size = Vector2(120, 44)
	tutorial_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	tutorial_menu_button.pressed.connect(func() -> void:
		_complete_tutorial_to_menu()
	)
	tutorial_coach_actions.add_child(tutorial_menu_button)
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
	map_view.add_theme_stylebox_override("panel", VisualTheme.panel_style(Color("#edf4f6"), Color.TRANSPARENT, 0, 0))
	map_backdrop = TextureRect.new()
	map_backdrop.name = "MapBackdrop"
	map_backdrop.texture = MAP_BACKDROP_TEXTURE
	map_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_backdrop.modulate = Color(0.96, 0.98, 1.0, 0.90)
	map_view.add_child(map_backdrop)
	map_energy_overlay = MapEnergyRenderer.new() as TextureRect
	map_energy_overlay.name = "MapEnergyOverlay"
	map_energy_overlay.call("configure", MAP_BACKDROP_TEXTURE, RUN_NODE_COUNT)
	map_energy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.add_child(map_energy_overlay)
	var side_veil_layer := Control.new()
	side_veil_layer.name = "MapSideColorVeils"
	side_veil_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_veil_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(side_veil_layer)
	for veil_spec in [
		{"name": "MapLeftColorVeil", "left": 0.0, "right": 0.30},
		{"name": "MapRightColorVeil", "left": 0.70, "right": 1.0},
	]:
		var color_veil := ColorRect.new()
		color_veil.name = str(veil_spec.get("name", "MapColorVeil"))
		color_veil.anchor_left = float(veil_spec.get("left", 0.0))
		color_veil.anchor_top = 0.0
		color_veil.anchor_right = float(veil_spec.get("right", 1.0))
		color_veil.anchor_bottom = 1.0
		color_veil.color = Color(0.95, 0.98, 1.0, 0.22)
		color_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side_veil_layer.add_child(color_veil)
	var margin := _content_margin()
	map_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	map_title = Label.new()
	VisualTheme.apply_heading(map_title, ui_font_display, 24)
	content.add_child(map_title)
	map_composition = BoxContainer.new()
	map_composition.name = "MapComposition"
	map_composition.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_composition.add_theme_constant_override("separation", 14)
	content.add_child(map_composition)
	var mission_margin := MarginContainer.new()
	mission_margin.name = "MapMissionHUD"
	mission_margin.custom_minimum_size = Vector2(236 + MAP_TOWER_AXIS_OFFSET_X * 2.0, 0)
	mission_margin.add_theme_constant_override("margin_left", 14)
	mission_margin.add_theme_constant_override("margin_top", 22)
	mission_margin.add_theme_constant_override("margin_right", 14)
	mission_margin.add_theme_constant_override("margin_bottom", 14)
	map_composition.add_child(mission_margin)
	var mission_content := VBoxContainer.new()
	mission_content.add_theme_constant_override("separation", 12)
	mission_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mission_margin.add_child(mission_content)
	var mission_heading := Label.new()
	mission_heading.name = "MapMissionHeading"
	mission_heading.text = "任务概况"
	VisualTheme.apply_heading(mission_heading, ui_font_strong, 17)
	mission_content.add_child(mission_heading)
	map_mission_summary = Label.new()
	map_mission_summary.name = "MapMissionSummary"
	map_mission_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_mission_summary.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	VisualTheme.apply_secondary(map_mission_summary, ui_font, 16)
	mission_content.add_child(map_mission_summary)
	map_mission_progress = ProgressBar.new()
	map_mission_progress.name = "MapMissionProgress"
	map_mission_progress.min_value = 0.0
	map_mission_progress.max_value = float(RUN_NODE_COUNT)
	map_mission_progress.show_percentage = false
	map_mission_progress.custom_minimum_size = Vector2(0, 7)
	map_mission_progress.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("#b9cbd2b8"), Color.TRANSPARENT, 0, 3))
	map_mission_progress.add_theme_stylebox_override("fill", VisualTheme.panel_style(Color("#248fa0"), Color.TRANSPARENT, 0, 3))
	mission_content.add_child(map_mission_progress)
	var mission_mode := Label.new()
	mission_mode.text = "路线模式  单线\n目标阶段  综合验收"
	mission_mode.add_theme_font_size_override("font_size", 14)
	mission_mode.add_theme_color_override("font_color", VisualTheme.color("text_muted"))
	mission_content.add_child(mission_mode)
	map_route_scroll = ScrollContainer.new()
	map_route_scroll.name = "MapRouteScroll"
	map_route_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_route_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_route_scroll.custom_minimum_size = Vector2(260, 252)
	map_route_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_composition.add_child(map_route_scroll)
	map_route = VBoxContainer.new()
	map_route.name = "MapRoute"
	map_route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_route.add_theme_constant_override("separation", 9)
	map_route_scroll.add_child(map_route)
	var next_margin := MarginContainer.new()
	next_margin.name = "MapNextHUD"
	next_margin.custom_minimum_size = Vector2(236, 0)
	next_margin.add_theme_constant_override("margin_left", 14)
	next_margin.add_theme_constant_override("margin_top", 22)
	next_margin.add_theme_constant_override("margin_right", 14)
	next_margin.add_theme_constant_override("margin_bottom", 14)
	map_composition.add_child(next_margin)
	var next_column := VBoxContainer.new()
	next_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	next_column.add_theme_constant_override("separation", 10)
	next_margin.add_child(next_column)
	var next_heading := Label.new()
	next_heading.name = "MapNextHeading"
	next_heading.text = "节点预告"
	VisualTheme.apply_heading(next_heading, ui_font_strong, 17)
	next_column.add_child(next_heading)
	map_next_detail = Label.new()
	map_next_detail.name = "MapNextDetail"
	map_next_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_next_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	map_next_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	VisualTheme.apply_secondary(map_next_detail, ui_font, 15)
	next_column.add_child(map_next_detail)
	map_enter_button = Button.new()
	map_enter_button.name = "MapEnterButton"
	map_enter_button.text = "进入下一节点"
	_skin_command_button(map_enter_button, VisualTheme.category_color("collect"))
	map_enter_button.custom_minimum_size = Vector2(0, 44)
	map_enter_button.pressed.connect(_enter_available_route_node)
	next_column.add_child(map_enter_button)


func _build_combat_view() -> void:
	var stage_visual := EnvSpireCombatStage.new() as Control
	stage_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_view.add_child(stage_visual)
	combat_margin = _content_margin()
	combat_view.add_child(combat_margin)
	combat_layout = BoxContainer.new()
	combat_layout.name = "CombatLayout"
	combat_layout.vertical = true
	combat_layout.add_theme_constant_override("separation", 12)
	combat_margin.add_child(combat_layout)
	encounter_arena = BoxContainer.new()
	encounter_arena.name = "EncounterArena"
	encounter_arena.vertical = false
	encounter_arena.custom_minimum_size = Vector2(0, 172)
	encounter_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	encounter_arena.add_theme_constant_override("separation", 16)
	combat_layout.add_child(encounter_arena)
	var device_unit := PanelContainer.new()
	device_unit.name = "DeviceUnit"
	device_unit.custom_minimum_size = Vector2(220, 0)
	device_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_unit.size_flags_stretch_ratio = 0.75
	device_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	device_unit.clip_contents = true
	device_unit.add_theme_stylebox_override("panel", _combat_unit_style(Color("#e8f5f8f7"), Color("#159bb0"), 28.0))
	encounter_arena.add_child(device_unit)
	var device_content := VBoxContainer.new()
	device_content.add_theme_constant_override("separation", 8)
	device_unit.add_child(device_content)
	device_telemetry_visual = _new_combat_visual("DeviceTelemetryVisual", "device", 112)
	device_content.add_child(device_telemetry_visual)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	device_content.add_child(status_label)
	data_label = Label.new()
	data_label.name = "TutorialDataValues"
	data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_label.add_theme_color_override("font_color", VisualTheme.color("text_primary"))
	device_content.add_child(data_label)
	device_unit.add_child(_new_tech_frame("DeviceTechFrame", "device", Color("#159bb0")))

	evidence_bridge = PanelContainer.new()
	evidence_bridge.name = "EvidenceBridge"
	evidence_bridge.custom_minimum_size = Vector2(220, 0)
	evidence_bridge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_bridge.size_flags_stretch_ratio = 0.75
	evidence_bridge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_bridge.clip_contents = true
	evidence_bridge.add_theme_stylebox_override("panel", _combat_unit_style(Color("#e9f6f0f7"), Color("#2f9b70"), 28.0))
	encounter_arena.add_child(evidence_bridge)
	var evidence_content := VBoxContainer.new()
	evidence_content.add_theme_constant_override("separation", 8)
	evidence_bridge.add_child(evidence_content)
	evidence_signal_visual = _new_combat_visual("EvidenceSignalVisual", "evidence", 112)
	evidence_content.add_child(evidence_signal_visual)
	repair_label = Label.new()
	VisualTheme.apply_heading(repair_label, ui_font_strong, 18, VisualTheme.color("success"))
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
	gate_label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	evidence_content.add_child(gate_label)
	evidence_bridge.add_child(_new_tech_frame("EvidenceTechFrame", "evidence", Color("#2f9b70")))

	var fault_zone := Control.new()
	fault_zone.name = "FaultZone"
	fault_zone.custom_minimum_size = Vector2(220, 0)
	fault_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fault_zone.size_flags_stretch_ratio = 1.5
	fault_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_zone.clip_contents = true
	encounter_arena.add_child(fault_zone)
	var fault_unit := PanelContainer.new()
	fault_unit.name = "FaultUnit"
	fault_unit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fault_unit.offset_bottom = -48.0
	fault_unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fault_unit.size_flags_stretch_ratio = 1.5
	fault_unit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_unit.clip_contents = true
	var fault_frame_insets := EnvSpireTechFrame.content_safe_insets_for("fault")
	fault_unit.add_theme_stylebox_override("panel", _combat_unit_style(Color("#f8e9e9f7"), Color("#d94b5f"), float(fault_frame_insets.get("top", 64.0))))
	fault_zone.add_child(fault_unit)
	var fault_content := VBoxContainer.new()
	fault_content.add_theme_constant_override("separation", 8)
	fault_unit.add_child(fault_content)
	encounter_name_label = Label.new()
	encounter_name_label.name = "EncounterName"
	VisualTheme.apply_heading(encounter_name_label, ui_font_display, 24, VisualTheme.color("danger"))
	fault_content.add_child(encounter_name_label)
	encounter_meta_label = Label.new()
	encounter_meta_label.name = "EncounterMeta"
	encounter_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_meta_label.add_theme_font_size_override("font_size", 12)
	encounter_meta_label.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	fault_content.add_child(encounter_meta_label)
	var fault_body := HBoxContainer.new()
	fault_body.name = "FaultBody"
	fault_body.custom_minimum_size = Vector2(0, 150)
	fault_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_body.add_theme_constant_override("separation", 12)
	fault_content.add_child(fault_body)
	var fault_art_stack := Control.new()
	fault_art_stack.name = "FaultArtStack"
	fault_art_stack.custom_minimum_size = Vector2(0, 150)
	fault_art_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fault_art_stack.size_flags_stretch_ratio = 1.15
	fault_art_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_art_stack.clip_contents = true
	fault_body.add_child(fault_art_stack)
	fault_core_visual = _new_combat_visual("FaultCoreVisual", "fault", 150)
	fault_art_stack.add_child(fault_core_visual)
	fault_core_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intent_label = IntentBadge.new() as Button
	fault_art_stack.add_child(intent_label)
	intent_label.anchor_left = 0.5
	intent_label.anchor_right = 0.5
	intent_label.offset_left = -77.0
	intent_label.offset_top = 6.0
	intent_label.offset_right = 77.0
	intent_label.offset_bottom = 48.0
	intent_label.z_index = 4
	intent_label.pressed.connect(_on_enemy_intent_pressed)
	var fault_details := VBoxContainer.new()
	fault_details.name = "FaultDetails"
	fault_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fault_details.size_flags_stretch_ratio = 1.0
	fault_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fault_details.add_theme_constant_override("separation", 5)
	fault_body.add_child(fault_details)
	fault_intent_row = Label.new()
	fault_intent_row.name = "FaultIntentRow"
	fault_intent_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_intent_row.add_theme_font_size_override("font_size", 13)
	fault_intent_row.add_theme_color_override("font_color", VisualTheme.color("warning"))
	fault_details.add_child(fault_intent_row)
	fault_rule_row = Label.new()
	fault_rule_row.name = "FaultRuleRow"
	fault_rule_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_rule_row.add_theme_font_size_override("font_size", 13)
	fault_rule_row.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	fault_details.add_child(fault_rule_row)
	fault_counter_row = Label.new()
	fault_counter_row.name = "FaultCounterRow"
	fault_counter_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_counter_row.add_theme_font_size_override("font_size", 13)
	fault_counter_row.add_theme_color_override("font_color", VisualTheme.color("success"))
	fault_details.add_child(fault_counter_row)
	fault_rule_state_label = Label.new()
	fault_rule_state_label.name = "FaultRuleState"
	fault_rule_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fault_rule_state_label.add_theme_font_size_override("font_size", 13)
	fault_details.add_child(fault_rule_state_label)
	var fault_frame := _new_tech_frame("FaultTechFrame", "fault", Color("#d94b5f"))
	fault_unit.add_child(fault_frame)

	hand_dock = VBoxContainer.new()
	hand_dock.name = "HandDock"
	hand_dock.custom_minimum_size = Vector2(0, 226)
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
	hand_title.add_theme_font_override("font", ui_font_strong)
	hand_title.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
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
		stage_label.add_theme_font_override("font", ui_font_strong)
		stage_label.add_theme_color_override("font_color", VisualTheme.color("text_muted"))
		engineering_chain_strip.add_child(stage_label)
		chain_stage_labels[stage] = stage_label
	for status_spec in [
		{"name": "ChainCurrentStatus", "target": "current"},
		{"name": "ChainNextStatus", "target": "next"},
		{"name": "ChainRewardStatus", "target": "reward"}
	]:
		var chain_status := Label.new()
		chain_status.name = str(status_spec.get("name", "ChainStatus"))
		chain_status.add_theme_font_size_override("font_size", 12)
		chain_status.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
		chain_status.clip_text = true
		chain_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chain_status.tooltip_text = {
			"current": "Current chain stage",
			"next": "Next chain stage",
			"reward": "Pending threshold reward"
		}.get(str(status_spec.get("target", "")), "Chain status")
		engineering_chain_strip.add_child(chain_status)
		match str(status_spec.get("target", "")):
			"current":
				chain_current_status = chain_status
			"next":
				chain_next_status = chain_status
			"reward":
				chain_reward_status = chain_status
	var dock_spacer := Control.new()
	dock_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_header.add_child(dock_spacer)
	processing_point_counter = Label.new()
	processing_point_counter.name = "ProcessingPointCounter"
	processing_point_counter.add_theme_font_override("font", ui_font_strong)
	processing_point_counter.add_theme_color_override("font_color", VisualTheme.color("success"))
	dock_header.add_child(processing_point_counter)
	hand_body = HBoxContainer.new()
	hand_body.name = "HandBody"
	hand_body.add_theme_constant_override("separation", 10)
	hand_body.custom_minimum_size = Vector2(0, 190)
	hand_dock.add_child(hand_body)
	hand_scroll = ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size = Vector2(0, 190)
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_body.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.name = "HandRow"
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.custom_minimum_size = Vector2(0, 186)
	hand_row.add_theme_constant_override("separation", 14)
	hand_scroll.add_child(hand_row)
	combat_actions = HBoxContainer.new()
	combat_actions.name = "CombatActions"
	combat_actions.alignment = BoxContainer.ALIGNMENT_END
	combat_actions.add_theme_constant_override("separation", 10)
	hand_body.add_child(combat_actions)
	reroute_button = Button.new()
	reroute_button.name = "RerouteButton"
	reroute_button.text = "换牌"
	reroute_button.custom_minimum_size = Vector2(74, 44)
	reroute_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin_button(reroute_button, Color("#2f7f8d"))
	reroute_button.pressed.connect(func() -> void:
		begin_reroute()
	)
	combat_actions.add_child(reroute_button)
	reroute_cancel_button = Button.new()
	reroute_cancel_button.name = "RerouteCancelButton"
	reroute_cancel_button.text = "取消"
	reroute_cancel_button.custom_minimum_size = Vector2(74, 44)
	reroute_cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skin_button(reroute_cancel_button, Color("#697b80"))
	reroute_cancel_button.pressed.connect(func() -> void:
		cancel_reroute()
	)
	combat_actions.add_child(reroute_cancel_button)
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "结束回合"
	end_turn_button.tooltip_text = "结束当前回合"
	_skin_command_button(end_turn_button, VisualTheme.color("warning"))
	end_turn_button.custom_minimum_size = Vector2(104, 44)
	end_turn_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	VisualTheme.apply_heading(card_selection_title, ui_font_strong, 20)
	selection_content.add_child(card_selection_title)
	card_selection_options = GridContainer.new()
	card_selection_options.name = "CardSelectionOptions"
	card_selection_options.columns = 3
	card_selection_options.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_selection_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_selection_options.add_theme_constant_override("h_separation", 10)
	card_selection_options.add_theme_constant_override("v_separation", 10)
	selection_content.add_child(card_selection_options)


func _build_choice_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "SceneChoiceBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#eef5f7e8")
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
	reward_encounter_backdrop.modulate = Color.WHITE
	backdrop.add_child(reward_encounter_backdrop)
	var resolved_device_panel := PanelContainer.new()
	resolved_device_panel.name = "ResolvedDeviceUnit"
	resolved_device_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_device_panel.add_theme_stylebox_override("panel", _button_style(Color("#dce9e6"), Color("#8da39e")))
	resolved_device_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_device_panel)
	var resolved_device_content := VBoxContainer.new()
	resolved_device_panel.add_child(resolved_device_content)
	resolved_device_visual = _new_combat_visual("ResolvedDeviceVisual", "device", 50)
	resolved_device_visual.visible = false
	resolved_device_content.add_child(resolved_device_visual)
	resolved_device_context = Label.new()
	resolved_device_context.name = "ResolvedDeviceContext"
	resolved_device_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_device_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_device_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_device_context.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	resolved_device_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_device_content.add_child(resolved_device_context)
	var resolved_evidence_panel := PanelContainer.new()
	resolved_evidence_panel.name = "ResolvedEvidenceBridge"
	resolved_evidence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_evidence_panel.add_theme_stylebox_override("panel", _button_style(Color("#e2e8e5"), Color("#91a39c")))
	resolved_evidence_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_evidence_panel)
	var resolved_evidence_content := VBoxContainer.new()
	resolved_evidence_panel.add_child(resolved_evidence_content)
	resolved_evidence_visual = _new_combat_visual("ResolvedEvidenceVisual", "evidence", 50)
	resolved_evidence_visual.visible = false
	resolved_evidence_content.add_child(resolved_evidence_visual)
	resolved_evidence_context = Label.new()
	resolved_evidence_context.name = "ResolvedEvidenceContext"
	resolved_evidence_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_evidence_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_evidence_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_evidence_context.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	resolved_evidence_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_evidence_content.add_child(resolved_evidence_context)
	var resolved_fault_panel := PanelContainer.new()
	resolved_fault_panel.name = "ResolvedFaultUnit"
	resolved_fault_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolved_fault_panel.add_theme_stylebox_override("panel", _button_style(Color("#eee4df"), Color("#b49a8c")))
	resolved_fault_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_encounter_backdrop.add_child(resolved_fault_panel)
	var resolved_fault_content := VBoxContainer.new()
	resolved_fault_panel.add_child(resolved_fault_content)
	resolved_fault_visual = _new_combat_visual("ResolvedFaultVisual", "fault", 50)
	resolved_fault_visual.visible = false
	resolved_fault_content.add_child(resolved_fault_visual)
	resolved_fault_context = Label.new()
	resolved_fault_context.name = "ResolvedFaultContext"
	resolved_fault_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_fault_context.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	resolved_fault_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_fault_context.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	resolved_fault_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_fault_content.add_child(resolved_fault_context)
	var margin := _content_margin()
	choice_view.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var context := VBoxContainer.new()
	context.name = "SceneChoiceContext"
	context.add_theme_constant_override("separation", 4)
	content.add_child(context)
	reward_encounter_backdrop.reparent(content)
	reward_encounter_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	reward_encounter_backdrop.custom_minimum_size = Vector2(0, 112)
	reward_encounter_backdrop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.move_child(reward_encounter_backdrop, 1)
	choice_title = Label.new()
	VisualTheme.apply_heading(choice_title, ui_font_display, 24)
	context.add_child(choice_title)
	choice_description = Label.new()
	choice_description.name = "ChoiceDescription"
	choice_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_description.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
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
	reward_cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	question_knowledge_tag.add_theme_font_override("font", ui_font_strong)
	question_knowledge_tag.add_theme_color_override("font_color", VisualTheme.color("success"))
	question_content.add_child(question_knowledge_tag)
	question_prompt = Label.new()
	question_prompt.name = "QuestionPrompt"
	question_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	VisualTheme.apply_heading(question_prompt, ui_font_strong, 18)
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
	_skin_command_button(question_submit, VisualTheme.color("focus"))
	question_submit.pressed.connect(func() -> void:
		var answer: Variant = event_ordering_answer.duplicate() if str(current_event.get("questionType", "")) == "ordering" else event_selected_answer
		submit_event_answer(answer)
		_render_state()
	)
	question_content.add_child(question_submit)
	question_explanation = Label.new()
	question_explanation.name = "QuestionExplanation"
	question_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_explanation.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
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
	_skin_command_button(question_continue, VisualTheme.color("success"))
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
	service_bench_label = Label.new()
	service_bench_label.name = "ServiceBenchStatus"
	service_bench_label.text = "工程维护台 / 诊断、清理与固件整备"
	service_bench_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_bench_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_bench_label.add_theme_font_override("font", ui_font_strong)
	service_bench_label.add_theme_color_override("font_color", VisualTheme.color("success"))
	service_bench.add_child(service_bench_label)
	scroll_content.add_child(service_bench)
	component_rack = PanelContainer.new()
	component_rack.name = "ComponentRack"
	component_rack.custom_minimum_size = Vector2(0, 58)
	component_rack.add_theme_stylebox_override("panel", _panel_style(Color("#e5eff2"), Color("#2f7f8d")))
	component_rack_label = Label.new()
	component_rack_label.name = "ComponentRackStatus"
	component_rack_label.text = "组件插槽  ·  选择一个工程模块"
	component_rack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	component_rack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	component_rack_label.add_theme_font_override("font", ui_font_strong)
	component_rack_label.add_theme_color_override("font_color", VisualTheme.color("focus"))
	component_rack.add_child(component_rack_label)
	scroll_content.add_child(component_rack)
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
	result_title.add_theme_font_override("font", ui_font_display)
	result_title.add_theme_font_size_override("font_size", 28)
	content.add_child(result_title)
	var report_grid := GridContainer.new()
	report_grid.name = "RunReportGrid"
	report_grid.columns = 2
	report_grid.custom_minimum_size = Vector2(860, 0)
	report_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	report_grid.add_theme_constant_override("h_separation", 14)
	content.add_child(report_grid)
	var metrics_panel := PanelContainer.new()
	metrics_panel.name = "RunMetricsPanel"
	metrics_panel.custom_minimum_size = Vector2(423, 220)
	metrics_panel.add_theme_stylebox_override("panel", _panel_style(Color("#edf4f5"), Color("#5c8792")))
	report_grid.add_child(metrics_panel)
	var metrics_margin := MarginContainer.new()
	metrics_margin.add_theme_constant_override("margin_left", 20)
	metrics_margin.add_theme_constant_override("margin_top", 18)
	metrics_margin.add_theme_constant_override("margin_right", 20)
	metrics_margin.add_theme_constant_override("margin_bottom", 18)
	metrics_panel.add_child(metrics_margin)
	var metrics_content := VBoxContainer.new()
	metrics_content.add_theme_constant_override("separation", 12)
	metrics_margin.add_child(metrics_content)
	var metrics_heading := Label.new()
	metrics_heading.text = "运行摘要"
	VisualTheme.apply_heading(metrics_heading, ui_font_strong, 18)
	metrics_content.add_child(metrics_heading)
	result_metrics = Label.new()
	result_metrics.name = "RunResultMetrics"
	result_metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_metrics.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	metrics_content.add_child(result_metrics)
	var learning_panel := PanelContainer.new()
	learning_panel.name = "RunLearningPanel"
	learning_panel.custom_minimum_size = Vector2(423, 220)
	learning_panel.add_theme_stylebox_override("panel", _panel_style(Color("#edf4f5"), Color("#725c91")))
	report_grid.add_child(learning_panel)
	var learning_margin := MarginContainer.new()
	learning_margin.add_theme_constant_override("margin_left", 20)
	learning_margin.add_theme_constant_override("margin_top", 18)
	learning_margin.add_theme_constant_override("margin_right", 20)
	learning_margin.add_theme_constant_override("margin_bottom", 18)
	learning_panel.add_child(learning_margin)
	var learning_content := VBoxContainer.new()
	learning_content.add_theme_constant_override("separation", 12)
	learning_margin.add_child(learning_content)
	var learning_heading := Label.new()
	learning_heading.text = "知识评估"
	VisualTheme.apply_heading(learning_heading, ui_font_strong, 18)
	learning_content.add_child(learning_heading)
	result_learning_summary = Label.new()
	result_learning_summary.name = "RunLearningSummary"
	result_learning_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_learning_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_learning_summary.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	learning_content.add_child(result_learning_summary)
	var result_actions := HBoxContainer.new()
	result_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	result_actions.add_theme_constant_override("separation", 10)
	content.add_child(result_actions)
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
	result_actions.add_child(restart)
	result_review_button = Button.new()
	result_review_button.name = "ResultReviewButton"
	result_review_button.text = "复习推荐故障"
	_skin_button(result_review_button, Color("#725c91"))
	result_review_button.custom_minimum_size = Vector2(210, 44)
	result_review_button.pressed.connect(_open_recommended_fault)
	result_actions.add_child(result_review_button)
	var menu_button := Button.new()
	menu_button.name = "ResultMenuButton"
	menu_button.text = "返回菜单"
	_skin_button(menu_button, Color("#697b80"))
	menu_button.custom_minimum_size = Vector2(180, 44)
	menu_button.pressed.connect(show_start_menu)
	result_actions.add_child(menu_button)


func _apply_desktop_layout() -> void:
	if combat_layout == null:
		return
	if combat_sound_toggle != null:
		combat_sound_toggle.offset_left = -112.0
		combat_sound_toggle.offset_right = -16.0
	combat_layout.vertical = true
	if combat_margin != null:
		combat_margin.add_theme_constant_override("margin_left", 18)
		combat_margin.add_theme_constant_override("margin_right", 18)
		combat_margin.add_theme_constant_override("margin_top", 14)
		combat_margin.add_theme_constant_override("margin_bottom", 14)
	if encounter_arena != null:
		encounter_arena.vertical = false
		encounter_arena.custom_minimum_size.y = 250.0
		var device_unit := encounter_arena.get_node_or_null("DeviceUnit")
		var evidence_bridge := encounter_arena.get_node_or_null("EvidenceBridge")
		var fault_zone := encounter_arena.get_node_or_null("FaultZone")
		if device_unit != null:
			encounter_arena.move_child(device_unit, 0)
		if evidence_bridge != null:
			encounter_arena.move_child(evidence_bridge, 1)
		if fault_zone != null:
			encounter_arena.move_child(fault_zone, 2)
	if hand_dock != null:
		hand_dock.custom_minimum_size.y = 250.0
	if hand_scroll != null:
		hand_scroll.custom_minimum_size.y = 214.0
	if hand_row != null:
		hand_row.custom_minimum_size.y = 210.0
	if hand_title != null:
		hand_title.visible = !tutorial_active
	if engineering_chain_strip != null:
		engineering_chain_strip.add_theme_constant_override("separation", 4)
		for stage in STAGE_ORDER:
			var stage_label := chain_stage_labels.get(stage, null) as Label
			if stage_label != null:
				stage_label.custom_minimum_size.x = 24.0
	var chain_status_nodes := [chain_current_status, chain_next_status, chain_reward_status]
	var chain_status_widths := [88.0, 88.0, 112.0]
	for status_index in range(chain_status_nodes.size()):
		var chain_status := chain_status_nodes[status_index] as Label
		if chain_status != null:
			chain_status.visible = !tutorial_active
			chain_status.custom_minimum_size.x = chain_status_widths[status_index]
			chain_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tutorial_completion_visible := tutorial_active and tutorial_step == TutorialStep.COMPLETE
	var tutorial_coach_height := 124.0 if tutorial_completion_visible else 76.0
	if tutorial_combat_spacer != null:
		tutorial_combat_spacer.visible = false
		tutorial_combat_spacer.custom_minimum_size.y = 0.0
	if end_turn_button != null and dock_header != null and combat_actions != null:
		var action_parent := hand_body
		for action in [reroute_button, reroute_cancel_button, end_turn_button, action_trailing_spacer]:
			if action != null and action.get_parent() != action_parent:
				action.reparent(action_parent)
		if action_trailing_spacer != null:
			action_parent.move_child(action_trailing_spacer, -1)
		var counter_parent := dock_header
		if processing_point_counter != null and processing_point_counter.get_parent() != counter_parent:
			processing_point_counter.reparent(counter_parent)
		if processing_point_counter != null:
			if reroute_button != null and processing_point_counter.get_index() > reroute_button.get_index():
				dock_header.move_child(processing_point_counter, reroute_button.get_index())
			processing_point_counter.size_flags_horizontal = Control.SIZE_FILL
		if reroute_button != null and reroute_cancel_button != null and end_turn_button != null:
			reroute_button.custom_minimum_size.x = 74.0
			reroute_cancel_button.custom_minimum_size.x = 74.0
			end_turn_button.custom_minimum_size.x = 104.0
			end_turn_button.text = "结束回合"
			for action_button in [reroute_button, reroute_cancel_button, end_turn_button]:
				action_button.size_flags_horizontal = Control.SIZE_FILL
		combat_actions.visible = false
	if map_composition != null:
		map_composition.vertical = false
	if map_mission_summary != null:
		map_mission_summary.visible = true
	if map_route_scroll != null:
		map_route_scroll.custom_minimum_size.y = 252.0
	if choice_list != null:
		choice_list.columns = 3 if state == RunState.COMPONENT else 2
		choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if reward_cards != null:
		reward_cards.columns = 3
		reward_cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if reward_encounter_backdrop != null:
		reward_encounter_backdrop.vertical = false
		var resolved_device_unit := reward_encounter_backdrop.get_node_or_null("ResolvedDeviceUnit")
		var resolved_evidence_bridge := reward_encounter_backdrop.get_node_or_null("ResolvedEvidenceBridge")
		var resolved_fault_unit := reward_encounter_backdrop.get_node_or_null("ResolvedFaultUnit")
		reward_encounter_backdrop.move_child(resolved_device_unit, 0)
		reward_encounter_backdrop.move_child(resolved_evidence_bridge, 1)
		reward_encounter_backdrop.move_child(resolved_fault_unit, 2)
		resolved_device_context.add_theme_font_size_override("font_size", 14)
		resolved_evidence_context.add_theme_font_size_override("font_size", 14)
		resolved_fault_context.add_theme_font_size_override("font_size", 14)
	if deck_label != null:
		deck_label.visible = state not in [RunState.MENU, RunState.CODEX]
	if brand_label != null:
		brand_label.text = "ENV / SPIRE"
	if hand_scroll != null:
		hand_scroll.custom_minimum_size.y = 214.0
	if hand_row != null:
		hand_row.custom_minimum_size.y = 210.0
		hand_row.add_theme_constant_override("separation", 16)
		for child in hand_row.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = Vector2(146, 210) if child.has_method("configure_card") else Vector2(176, 120)
	if tutorial_briefing_content != null:
		tutorial_briefing_content.add_theme_constant_override("separation", 12)
	if tutorial_coach_layer != null:
		var coach_bottom := -12.0
		if tutorial_active and state == RunState.COMBAT:
			coach_bottom = -hand_dock.custom_minimum_size.y - 18.0
		tutorial_coach_layer.anchor_left = 0.0
		tutorial_coach_layer.anchor_right = 0.0
		tutorial_coach_layer.offset_left = 18.0
		tutorial_coach_layer.offset_top = coach_bottom - tutorial_coach_height
		tutorial_coach_layer.offset_right = 638.0
		tutorial_coach_layer.offset_bottom = coach_bottom
	if tutorial_coach_text != null:
		tutorial_coach_text.max_lines_visible = 2
		tutorial_coach_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if tutorial_completion_summary != null:
		tutorial_completion_summary.max_lines_visible = 4
		tutorial_completion_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _render_state() -> void:
	if map_view == null:
		return
	var state_changed := rendered_state_for_motion != state
	if start_menu_view != null:
		start_menu_view.visible = state == RunState.MENU
	if codex_view != null:
		codex_view.visible = state == RunState.CODEX
	map_view.visible = state == RunState.MAP
	combat_view.visible = state == RunState.COMBAT
	if combat_feedback_layer != null:
		combat_feedback_layer.visible = state == RunState.COMBAT
	choice_view.visible = [RunState.REWARD, RunState.EVENT, RunState.REST, RunState.COMPONENT].has(state)
	result_view.visible = state == RunState.RESULT
	_render_tutorial()
	if service_bench != null:
		service_bench.visible = state == RunState.REST
	if component_rack != null:
		component_rack.visible = state == RunState.COMPONENT
	_render_header()
	match state:
		RunState.MENU:
			_refresh_start_menu()
		RunState.MAP:
			_render_map()
		RunState.COMBAT:
			_render_combat()
		RunState.REWARD, RunState.EVENT, RunState.REST, RunState.COMPONENT:
			_render_choices()
		RunState.RESULT:
			_render_result()
		RunState.CODEX:
			pass
	_render_card_selection_overlay()
	if log_label != null:
		log_label.text = "  /  ".join(message_log.slice(maxi(0, message_log.size() - 2), message_log.size()))
	_apply_desktop_layout()
	if state_changed:
		rendered_state_for_motion = state
		call_deferred("_animate_state_entry", state)


func _animate_state_entry(expected_state: int) -> void:
	if state != expected_state:
		return
	var active_view: Control
	match state:
		RunState.MENU:
			active_view = start_menu_view
		RunState.WAITING:
			active_view = tutorial_view
		RunState.MAP:
			active_view = map_view
		RunState.COMBAT:
			active_view = combat_view
		RunState.REWARD, RunState.EVENT, RunState.REST, RunState.COMPONENT:
			active_view = choice_view
		RunState.RESULT:
			active_view = result_view
		RunState.CODEX:
			active_view = codex_view
	if active_view != null and active_view.visible:
		UIMotion.animate_entrance(self, active_view, motion_duration_scale)
	if expected_state == RunState.MAP:
		await _animate_map_charge_entry(current_layer)


func _render_tutorial() -> void:
	if tutorial_view != null:
		tutorial_view.visible = tutorial_active and tutorial_step == TutorialStep.BRIEFING
	if tutorial_coach_layer != null:
		tutorial_coach_layer.visible = tutorial_active
	if tutorial_skip_button != null:
		tutorial_skip_button.visible = tutorial_active and tutorial_step != TutorialStep.COMPLETE
	if tutorial_intent_button != null:
		tutorial_intent_button.visible = false
		tutorial_intent_button.disabled = true
	if tutorial_complete_button != null:
		tutorial_complete_button.visible = tutorial_active and tutorial_step == TutorialStep.COMPLETE
		tutorial_complete_button.disabled = !tutorial_active or tutorial_step != TutorialStep.COMPLETE
	if tutorial_menu_button != null:
		tutorial_menu_button.visible = tutorial_active and tutorial_step == TutorialStep.COMPLETE
		tutorial_menu_button.disabled = !tutorial_active or tutorial_step != TutorialStep.COMPLETE
	if tutorial_completion_summary != null:
		tutorial_completion_summary.visible = tutorial_active and tutorial_step == TutorialStep.COMPLETE
	if tutorial_coach_text != null and tutorial_active:
		tutorial_coach_text.text = TutorialPresenter.coach_text(tutorial_step)


func _render_header() -> void:
	var run_metrics_visible := state not in [RunState.MENU, RunState.CODEX]
	for metric in [layer_label, stability_label, deck_label]:
		if metric != null:
			metric.visible = run_metrics_visible
	if rendered_stability_value >= 0 and stability < rendered_stability_value and state == RunState.COMBAT:
		stability_label.modulate = Color("#d4574f")
		if stability_flash_tween != null and stability_flash_tween.is_valid():
			stability_flash_tween.kill()
		stability_flash_tween = create_tween().bind_node(self)
		stability_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		stability_flash_tween.tween_property(stability_label, "modulate", Color.WHITE, 0.45)
	else:
		stability_label.modulate = Color.WHITE
	rendered_stability_value = stability
	layer_label.text = "节点 %d / %d" % [current_layer, RUN_NODE_COUNT]
	stability_label.text = "稳定度 %d / %d" % [stability, max_stability]
	deck_label.text = "牌组 %d" % deck.size()


func _render_map() -> void:
	map_title.text = "第 %d 个调试节点" % (current_layer + 1) if current_layer < RUN_NODE_COUNT else "路线完成"
	var layers: Array = run_map.get("layers", [])
	map_mission_summary.text = "环境监测塔\n十二层调试攀登\n\n当前进度  %d / %d" % [current_layer, RUN_NODE_COUNT]
	if map_mission_progress != null:
		map_mission_progress.value = current_layer
	_render_map_route(layers)
	call_deferred("_reveal_available_map_node")
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
	map_enter_button.disabled = map_transition_active or map_charge_animation_active or _map_charge_pending()


func _render_map_route(layers: Array) -> void:
	RoutePresenter.render_route(
		self,
		map_route,
		layers,
		RUN_NODE_COUNT,
		current_layer,
		revealed_nodes,
		Callable(self, "_enter_available_route_node")
	)
	if map_charge_animation_active or _map_charge_pending():
		RoutePresenter.set_input_enabled(map_route, false)


func _enter_available_route_node() -> void:
	if map_transition_active or map_charge_animation_active or _map_charge_pending() or state != RunState.MAP or current_layer >= RUN_NODE_COUNT:
		return
	map_transition_active = true
	map_transition_last_target = current_layer + 1
	map_enter_button.disabled = true
	RoutePresenter.set_input_enabled(map_route, false)
	await RoutePresenter.play_progress_animation(
		self,
		map_route,
		map_transition_last_target,
		RUN_NODE_COUNT,
		motion_duration_scale
	)
	if state == RunState.MAP:
		choose_node(0)
	map_transition_active = false
	_render_state()


func map_transition_snapshot() -> Dictionary:
	return {
		"active": map_transition_active,
		"lastTarget": map_transition_last_target
	}


func _animate_map_charge_entry(target_layer: int) -> void:
	if map_energy_overlay == null or state != RunState.MAP or map_charge_animation_active:
		return
	var charge_state := map_energy_overlay.call("snapshot") as Dictionary
	if int(charge_state.get("chargedLayer", 0)) >= target_layer:
		return
	map_charge_animation_active = true
	if map_enter_button != null:
		map_enter_button.disabled = true
	RoutePresenter.set_input_enabled(map_route, false)
	await map_energy_overlay.call("animate_to_layer", target_layer, motion_duration_scale, reduced_flash)
	map_charge_animation_active = false
	if state == RunState.MAP:
		var layers: Array = run_map.get("layers", [])
		map_enter_button.disabled = current_layer >= layers.size()
		RoutePresenter.set_input_enabled(map_route, true)


func map_charge_snapshot() -> Dictionary:
	if map_energy_overlay == null:
		return {"active": false, "chargedLayer": 0, "progress": 0.0}
	var result := map_energy_overlay.call("snapshot") as Dictionary
	result["active"] = map_charge_animation_active or bool(result.get("active", false))
	return result


func _map_charge_pending() -> bool:
	if map_energy_overlay == null:
		return false
	var charge_state := map_energy_overlay.call("snapshot") as Dictionary
	return int(charge_state.get("chargedLayer", 0)) < current_layer


func _reveal_available_map_node() -> void:
	if map_route_scroll == null or map_route == null or map_route.get_child_count() == 0:
		return
	var target_layer := mini(current_layer + 1, RUN_NODE_COUNT)
	await get_tree().process_frame
	await get_tree().process_frame
	if state != RunState.MAP or target_layer != mini(current_layer + 1, RUN_NODE_COUNT):
		return
	var target_step := map_route.get_node_or_null("MapStep%02d" % target_layer) as Control
	if target_step == null:
		return
	var centered_offset := target_step.position.y - (map_route_scroll.size.y - target_step.size.y) * 0.5
	map_route_scroll.scroll_vertical = maxi(0, int(centered_offset))


func _map_node_state(layer_number: int) -> String:
	return RoutePresenter.node_state(layer_number, current_layer)


func _node_type_name(node_type: String) -> String:
	return {
		"ordinary": "普通故障", "elite": "精英故障", "event": "调试事件",
		"service": "整备", "checkpoint_sensor": "教学检查点",
		"checkpoint_trust": "教学检查点", "checkpoint": "教学检查点",
		"component": "工程组件", "boss": "综合验收"
	}.get(node_type, node_type)


func _hydrate_resolved_map_labels() -> void:
	for layer_variant in run_map.get("layers", []):
		var layer := layer_variant as Dictionary
		for choice_variant in layer.get("choices", []):
			var choice := choice_variant as Dictionary
			var content_id := str(choice.get("contentId", ""))
			if content_id.is_empty() or !enemy_defs.has(content_id):
				continue
			var enemy := enemy_defs.get(content_id, {}) as Dictionary
			choice["label"] = str(enemy.get("name", choice.get("label", "调试节点")))


func _node_type_short(node_type: String) -> String:
	return {
		"ordinary": "故障", "elite": "精英", "event": "事件",
		"service": "整备", "checkpoint_sensor": "接入检查", "checkpoint_trust": "可信检查",
		"component": "组件", "boss": "综合验收"
	}.get(node_type, "节点")


func _lane_name(lane: String) -> String:
	return {"field": "现场采样线", "bus": "总线调试线", "system": "系统联调线", "merge": "必经节点"}.get(lane, lane)


func _lane_color(lane: String) -> Color:
	return {"field": Color("#b75a3a"), "bus": Color("#2f7f8d"), "system": Color("#517943"), "merge": Color("#725c91")}.get(lane, Color("#60757b"))


func _combat_visual_snapshot(resolved: bool = false) -> Dictionary:
	var intent: Dictionary = {}
	if !current_intents.is_empty():
		intent = (current_intents[intent_index % current_intents.size()] as Dictionary).duplicate(true)
	var fault_preview := _fault_rule_preview()
	var completed_stages := {}
	var current_stage_index := STAGE_ORDER.find(last_stage)
	if current_stage_index >= 0:
		for stage_index in range(current_stage_index + 1):
			completed_stages[STAGE_ORDER[stage_index]] = true
	if resolved:
		for stage in STAGE_ORDER:
			completed_stages[stage] = true
	return {
		"encounterId": str(current_encounter.get("id", "")),
		"encounterName": str(current_encounter.get("name", "")),
		"tier": str(current_encounter.get("tier", "ordinary")),
		"bossPhase": boss_phase,
		"weaknessTags": (current_encounter.get("weaknessTags", []) as Array).duplicate(true),
		"intentType": str(intent.get("type", "none")),
		"intentText": str(intent.get("text", "")),
		"rawData": raw_data.duplicate(true),
		"trustedData": trusted_data.duplicate(true),
		"processingPoints": processing_points,
		"block": block,
		"lastStage": last_stage,
		"completedStages": completed_stages,
		"repairProgress": repair_target if resolved else repair_progress,
		"repairTarget": repair_target,
		"gateMet": true if resolved else _active_gate_met(str(current_encounter.get("tier", "ordinary"))),
		"faultTriggered": false if resolved else bool(fault_preview.get("triggered", false)),
		"faultSuppressed": true if resolved else bool(fault_preview.get("suppressed", false)),
		"resolved": resolved
	}


func _update_combat_visuals() -> void:
	var snapshot := _combat_visual_snapshot()
	for visual in [device_telemetry_visual, evidence_signal_visual, fault_core_visual]:
		if visual != null:
			visual.set_snapshot(snapshot)


func _update_reward_visuals() -> void:
	var snapshot := _combat_visual_snapshot(true)
	for visual in [resolved_device_visual, resolved_evidence_visual, resolved_fault_visual]:
		if visual != null:
			visual.set_snapshot(snapshot)


func _render_combat() -> void:
	var selection_open := !pending_card_selection.is_empty()
	encounter_name_label.text = str(current_encounter.get("name", "故障诊断"))
	var tier := str(current_encounter.get("tier", "ordinary"))
	var phase_text := " · 阶段 %d/3" % (boss_phase + 1) if tier == "boss" else ""
	encounter_meta_label.text = "%s%s\n弱点：%s%s" % [
		_node_type_name(tier),
		phase_text,
		" / ".join(current_encounter.get("weaknessTags", [])),
		"\n规则：%s" % _active_boss_gate_label() if tier == "boss" else ""
	]
	intent_label.call("configure_intent", _current_intent(), ui_font_strong)
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
	fault_rule_state_label.add_theme_color_override("font_color", VisualTheme.color("danger") if bool(fault_preview.get("triggered", false)) else (VisualTheme.color("success") if bool(fault_preview.get("suppressed", false)) else VisualTheme.category_color("process")))
	repair_label.text = "修复进度 %d / %d" % [repair_progress, repair_target]
	repair_bar.max_value = maxi(repair_target, 1)
	var animate_repair := (
		rendered_repair_value >= 0
		and rendered_repair_target == repair_target
		and repair_progress > rendered_repair_value
	)
	if repair_value_tween != null and repair_value_tween.is_valid():
		repair_value_tween.kill()
	if animate_repair:
		repair_bar.value = rendered_repair_value
		repair_value_tween = create_tween().bind_node(self)
		repair_value_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		repair_value_tween.tween_property(repair_bar, "value", float(repair_progress), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		repair_bar.value = repair_progress
	rendered_repair_value = repair_progress
	rendered_repair_target = repair_target
	gate_label.text = _gate_status_text(tier)
	gate_label.add_theme_color_override("font_color", VisualTheme.color("success") if _active_gate_met(tier) else VisualTheme.color("danger"))
	data_label.text = "原始  烟%d 光%d 温%d 湿%d\n可信  烟%d 光%d 温%d 湿%d" % [
		int(raw_data.smoke), int(raw_data.light), int(raw_data.temp), int(raw_data.humidity),
		int(trusted_data.smoke), int(trusted_data.light), int(trusted_data.temp), int(trusted_data.humidity)
	]
	status_label.text = "处理点 %d  ·  防护 %d  ·  连携 %d  ·  诊断 %d  ·  报警 %d" % [processing_points, block, chain_count, diagnosis, alarm_markers]
	processing_point_counter.text = "处理点 %d" % processing_points
	_update_combat_visuals()
	var next_chain_stage := _next_chain_stage()
	var next_chain_preview := _chain_preview_for_stage(next_chain_stage)
	if chain_current_status != null:
		chain_current_status.text = "当前:%s" % (_stage_name(last_stage) if !last_stage.is_empty() else "无")
	if chain_next_status != null:
		chain_next_status.text = "下一:%s" % _stage_name(next_chain_stage)
	if chain_reward_status != null:
		chain_reward_status.text = "奖励:%s" % _chain_reward_label(str(next_chain_preview.get("pendingReward", "none")))
	for stage in STAGE_ORDER:
		var stage_label := chain_stage_labels.get(stage, null) as Label
		if stage_label == null:
			continue
		var preview := _chain_preview_for_stage(stage)
		var stage_color := VisualTheme.color("text_muted")
		var stage_background := VisualTheme.color("surface_muted")
		var stage_border := VisualTheme.color("line")
		if bool(preview.get("current", false)):
			stage_color = VisualTheme.color("success")
			stage_background = Color("#143126")
			stage_border = VisualTheme.color("success")
		elif bool(preview.get("completed", false)):
			stage_color = Color("#c8f6ff")
			stage_background = Color("#102a31")
			stage_border = VisualTheme.category_color("interface")
		elif bool(preview.get("next", false)):
			stage_color = VisualTheme.color("warning")
			stage_background = Color("#2b2113")
			stage_border = VisualTheme.color("warning")
		stage_label.add_theme_color_override("font_color", stage_color)
		stage_label.add_theme_stylebox_override("normal", _chain_stage_style(stage_background, stage_border))
	if reroute_button != null:
		reroute_button.visible = !tutorial_active
		reroute_button.disabled = selection_open or _card_actions_pending() or tutorial_active or reroute_mode or !reroute_available or cards_played_this_turn > 0
		var targeted_reroute := _boss_targeted_reroute_available()
		reroute_button.text = "检索 -1" if targeted_reroute else "换牌"
		reroute_button.tooltip_text = "消耗 1 处理点，检索当前验收牌" if targeted_reroute else "替换 1 张手牌"
	if reroute_cancel_button != null:
		reroute_cancel_button.visible = !tutorial_active and reroute_mode
		reroute_cancel_button.disabled = selection_open or _card_actions_pending() or tutorial_active or !reroute_mode
	var previous_hand_size := rendered_hand_size_for_motion
	_clear_children(hand_row)
	for index in range(hand.size()):
		var card := hand[index] as Dictionary
		var negative := bool(card.get("negative", false))
		var cost: Variant = "!" if negative else _card_cost_preview(card)
		var reason := "负面状态不可主动使用" if negative else ""
		var card_support_text := "抽取时触发"
		if !negative:
			var chain_preview := _chain_preview_for_card(card)
			reason = _card_unavailable_reason(card, int(cost), selection_open)
			if card.has("_queuedPlayToken"):
				reason = "动画队列中"
			var chain_decision := str(chain_preview.get("decision", "preserves"))
			var pending_reward := str(chain_preview.get("pendingReward", "none"))
			card_support_text = _chain_decision_label(chain_decision)
			if pending_reward != "none":
				card_support_text += " · " + _chain_reward_label(pending_reward)
		var displayed_reason := reason if !tutorial_active else ""
		var button := _new_card_view(card, "hand", cost, displayed_reason, card_support_text)
		button.name = "HandCard_%s_%d" % [str(card.get("id", "card")), index]
		if negative:
			button.disabled = true
		else:
			button.disabled = !reason.is_empty()
			button.pressed.connect(func() -> void:
				if reroute_mode:
					reroute_card(index)
					_render_state()
				else:
					queue_card_play(index, button)
			)
		if tutorial_active and str(card.get("id", "")) == _tutorial_expected_card_id():
			button.name = "TutorialRequiredCard"
			_apply_tutorial_card_focus(button)
		hand_row.add_child(button)
		if previous_hand_size < 0 or index >= previous_hand_size:
			call_deferred("_animate_hand_card_entry", button, maxi(index - maxi(previous_hand_size, 0), 0))
	rendered_hand_size_for_motion = hand.size()
	end_turn_button.disabled = selection_open or _card_actions_pending() or (tutorial_active and !_tutorial_end_turn_allowed())
	_render_tutorial_focus()
	if tutorial_active and !_tutorial_expected_card_id().is_empty():
		call_deferred("_reveal_tutorial_required_card")


func _animate_hand_card_entry(button: Button, order: int) -> void:
	if button == null or !is_instance_valid(button) or !button.is_inside_tree():
		return
	UIMotion.animate_item_entrance(self, button, order, motion_duration_scale)


func _render_card_selection_overlay() -> void:
	if card_selection_modal == null:
		return
	var owner := str(pending_card_selection.get("owner", "combat"))
	var selection_open := !pending_card_selection.is_empty() and _selection_owner_matches_state(owner)
	card_selection_modal.visible = selection_open
	if selection_open:
		_render_card_selection_modal()
		if !card_selection_was_visible:
			call_deferred("_animate_card_selection_entry")
	card_selection_was_visible = selection_open


func _animate_card_selection_entry() -> void:
	if card_selection_modal != null and card_selection_modal.visible:
		UIMotion.animate_entrance(self, card_selection_modal, motion_duration_scale, 0.0, Vector2(0.97, 0.97))


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
		var selection_owner := str(pending_card_selection.get("owner", "event"))
		var selection_context := pending_card_selection.get("context", {}) as Dictionary
		card_selection_title.text = {
			"add_card": "选择一张牌加入牌组",
			"upgrade_card": "选择一张牌进行升级",
			"remove_card": "选择一张牌移出牌组"
		}.get(str(selection_context.get("action", "")), "选择一张事件卡牌") if selection_owner == "service" else "选择一张事件卡牌"
	elif kind == "event_component":
		card_selection_title.text = "Select an event component"
	card_selection_options.columns = 3
	var options: Array = pending_card_selection.get("options", []) as Array
	for index in range(options.size()):
		var option = options[index]
		var button: Button
		if kind == "event_component" and option is Dictionary:
			var component := option as Dictionary
			button = Button.new()
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.text = "%s\n%s" % [component.get("name", "component"), component.get("description", "")]
			_skin_button(button, Color("#8b6b23"))
		elif option is Dictionary:
			var card := option as Dictionary
			button = _new_card_view(card, "choice", _card_cost_preview(card), "", "点击选择")
		else:
			button = Button.new()
			button.text = _source_name(str(option))
			_skin_button(button, Color("#2f7f8d"))
		if !button.has_method("configure_card"):
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
	if end_turn_button != null:
		_skin_command_button(end_turn_button, VisualTheme.color("warning"))
	if data_label != null:
		data_label.remove_theme_stylebox_override("normal")
	if evidence_bridge != null:
		evidence_bridge.add_theme_stylebox_override("panel", _combat_unit_style(Color("#e9f6f0f7"), Color("#2f9b70"), 28.0))
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
		match _active_boss_gate_id():
			"two_sources": return "验收规则  ·  覆盖两个来源  %d / 2" % phase_source_coverage.size()
			"three_sources": return "验收规则  ·  覆盖三个来源  %d / 3" % phase_source_coverage.size()
			"trusted_and_filter": return "验收规则  ·  可信来源 %d / 2  ·  滤波 %d / 1" % [phase_trusted_sources.size(), mini(phase_filters_played, 1)]
			"trusted_and_calibration": return "验收规则  ·  可信来源 %d / 2  ·  校准 %d / 1" % [phase_trusted_sources.size(), mini(phase_calibrations_played, 1)]
			"two_output_types": return "验收规则  ·  不同输出 %d / 2" % _boss_distinct_output_count()
			"acceptance_output": return "验收规则  ·  验收输出 %d / 1  ·  其他输出 %d / 1" % [1 if bool(phase_output_types.get("acceptance", false)) else 0, _boss_other_output_count()]
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
	var base_cost := CardRules.card_cost(card, {
		"i2cPenalty": i2c_cost_penalty,
		"i2cDiscount": int(powers.get("i2c_discount", 0)),
		"processDiscount": int(powers.get("process_discount", 0)),
		"interfaceDiscount": int(powers.get("interface_discount", 0))
	})
	return ComponentRules.adjusted_cost(base_cost, card, relic_defs, relics, component_tracking)


func _card_accent(card: Dictionary) -> Color:
	if bool(card.get("negative", false)):
		return Color("#9b3f3b")
	match str(card.get("type", "")):
		"collect": return Color("#b75a3a")
		"interface": return Color("#2f7f8d")
		"process": return Color("#725c91")
		"defense": return Color("#517943")
		"output": return Color("#b16a2c")
		"power": return Color("#8b6b23")
	return Color("#60757b")


func _card_visual_target(card: Dictionary) -> String:
	match str(card.get("type", "")):
		"collect", "interface":
			return "device"
		"process", "defense", "power":
			return "evidence"
		"output":
			return "fault"
	return "evidence"


func _combat_visual_for_target(target: String) -> Control:
	match target:
		"device":
			return device_telemetry_visual
		"fault":
			return fault_core_visual
	return evidence_signal_visual


func card_action_queue_snapshot() -> Dictionary:
	return {
		"pending": card_action_queue.size() + (0 if active_card_action.is_empty() else 1),
		"queued": card_action_queue.size(),
		"activeToken": int(active_card_action.get("token", 0)),
		"reservedCost": reserved_card_action_cost,
		"settled": settled_card_action_count,
		"rejected": rejected_card_action_count
	}


func _card_actions_pending() -> bool:
	return !active_card_action.is_empty() or !card_action_queue.is_empty()


func queue_card_play(hand_index: int, source: Control) -> bool:
	if !_gameplay_action_allowed():
		return false
	if state != RunState.COMBAT or reroute_mode or !pending_card_selection.is_empty():
		return false
	if hand_index < 0 or hand_index >= hand.size() or source == null:
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)) or card.has("_queuedPlayToken"):
		return false
	var cost := _card_cost_preview(card)
	if processing_points - reserved_card_action_cost < cost or !_card_requirements_met(card):
		return false
	if tutorial_active and !_tutorial_card_allowed(str(card.get("id", ""))):
		return false
	var token := next_card_action_token
	next_card_action_token += 1
	card["_queuedPlayToken"] = token
	reserved_card_action_cost += cost
	card_action_queue.append({
		"token": token,
		"cardId": str(card.get("id", "")),
		"card": card.duplicate(true),
		"cost": cost,
		"sourceRect": source.get_global_rect()
	})
	if source is BaseButton:
		(source as BaseButton).disabled = true
	_process_next_card_action()
	return true


func _process_next_card_action() -> void:
	if host_paused or !active_card_action.is_empty() or card_action_queue.is_empty():
		return
	if state != RunState.COMBAT or !pending_card_selection.is_empty():
		return
	active_card_action = card_action_queue.pop_front()
	_start_active_card_animation()


func _start_active_card_animation() -> void:
	if active_card_action.is_empty():
		return
	var card := active_card_action.get("card", {}) as Dictionary
	var source_rect := active_card_action.get("sourceRect", Rect2()) as Rect2
	var target_visual := _combat_visual_for_target(_card_visual_target(card))
	if combat_motion_layer == null or target_visual == null or !target_visual.is_visible_in_tree():
		active_card_action["animationComplete"] = true
		call_deferred("_settle_active_card_action")
		return
	var target_rect := target_visual.get_global_rect()
	var accent := _card_accent(card)
	var ghost := PanelContainer.new()
	ghost.name = "CardMotion_%s_%d" % [str(card.get("id", "card")), int(active_card_action.get("token", 0))]
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = source_rect.position
	ghost.size = source_rect.size
	ghost.pivot_offset = source_rect.size * 0.5
	var ghost_style := _button_style(Color(accent.r, accent.g, accent.b, 0.92), accent.lightened(0.22))
	ghost_style.border_width_top = 4
	ghost.add_theme_stylebox_override("panel", ghost_style)
	var label := Label.new()
	label.text = str(card.get("name", "工程动作"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(label)
	combat_motion_layer.add_child(ghost)
	card_action_ghost = ghost
	target_visual.pulse("card", accent)
	var duration := 0.34 * motion_duration_scale
	if duration <= 0.0:
		_on_active_card_animation_finished()
		return
	var destination := target_rect.get_center() - source_rect.size * 0.22
	card_action_tween = create_tween().bind_node(ghost)
	card_action_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	card_action_tween.set_parallel(true)
	card_action_tween.set_trans(Tween.TRANS_CUBIC)
	card_action_tween.set_ease(Tween.EASE_IN_OUT)
	card_action_tween.tween_property(ghost, "position", destination, duration)
	card_action_tween.tween_property(ghost, "scale", Vector2(0.44, 0.44), duration)
	card_action_tween.tween_property(ghost, "modulate:a", 0.15, duration)
	card_action_tween.chain().tween_callback(_on_active_card_animation_finished)


func _on_active_card_animation_finished() -> void:
	card_action_tween = null
	if card_action_ghost != null and is_instance_valid(card_action_ghost):
		card_action_ghost.queue_free()
	card_action_ghost = null
	if active_card_action.is_empty():
		return
	active_card_action["animationComplete"] = true
	_settle_active_card_action()


func _settle_active_card_action() -> void:
	if active_card_action.is_empty() or host_paused:
		return
	var token := int(active_card_action.get("token", 0))
	var reserved_cost := int(active_card_action.get("cost", 0))
	var hand_index := _queued_card_index(token)
	reserved_card_action_cost = maxi(0, reserved_card_action_cost - reserved_cost)
	var settled := false
	if hand_index >= 0:
		(hand[hand_index] as Dictionary).erase("_queuedPlayToken")
		settling_card_action = true
		settled = play_card(hand_index)
		settling_card_action = false
	if settled:
		settled_card_action_count += 1
	else:
		rejected_card_action_count += 1
		_log("已保留快速操作，但结算条件发生变化；卡牌未被消耗。")
	active_card_action.clear()
	_render_state()
	if card_action_queue.is_empty() and deferred_encounter_finish:
		deferred_encounter_finish = false
		if state == RunState.COMBAT:
			_finish_encounter()
			_render_state()
	call_deferred("_process_next_card_action")


func _queued_card_index(token: int) -> int:
	for index in range(hand.size()):
		if int((hand[index] as Dictionary).get("_queuedPlayToken", 0)) == token:
			return index
	return -1


func _animate_card_play(source: Control, card: Dictionary) -> void:
	if combat_motion_layer == null or source == null:
		return
	var target_name := _card_visual_target(card)
	var target_visual := _combat_visual_for_target(target_name)
	if target_visual == null or !target_visual.is_visible_in_tree():
		return
	var source_rect := source.get_global_rect()
	var target_rect := target_visual.get_global_rect()
	var accent := _card_accent(card)
	var ghost := PanelContainer.new()
	ghost.name = "CardMotion_%s" % str(card.get("id", "card"))
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = source_rect.position
	ghost.size = source_rect.size
	ghost.pivot_offset = source_rect.size * 0.5
	var ghost_style := _button_style(Color(accent.r, accent.g, accent.b, 0.92), accent.lightened(0.22))
	ghost_style.border_width_top = 4
	ghost.add_theme_stylebox_override("panel", ghost_style)
	var label := Label.new()
	label.text = str(card.get("name", "工程动作"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(label)
	combat_motion_layer.add_child(ghost)
	var destination := target_rect.get_center() - source_rect.size * 0.22
	var tween := create_tween().bind_node(ghost)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ghost, "position", destination, 0.34)
	tween.tween_property(ghost, "scale", Vector2(0.44, 0.44), 0.34)
	tween.tween_property(ghost, "modulate:a", 0.15, 0.34)
	tween.chain().tween_callback(ghost.queue_free)
	target_visual.pulse("card", accent)


func _negative_effect_text(card: Dictionary) -> String:
	var effect := card.get("drawEffect", {}) as Dictionary
	return "%s %s" % [effect.get("type", "影响"), effect.get("amount", "")]


func _current_intent_text() -> String:
	return str(_current_intent().get("text", "故障行动"))


func _current_intent() -> Dictionary:
	if current_intents.is_empty():
		return {"type": "warning", "text": "观察系统状态"}
	return (current_intents[intent_index % current_intents.size()] as Dictionary).duplicate(true)


func _on_enemy_intent_pressed() -> void:
	if tutorial_active and tutorial_step == TutorialStep.READ_INTENT:
		confirm_tutorial_intent()


func _render_choices() -> void:
	_clear_children(choice_list)
	_clear_children(reward_cards)
	var scene_kind := _choice_scene_kind()
	choice_list.columns = ChoicePresenter.columns_for(scene_kind)
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var question_event_active := scene_kind == "event" and current_event.has("questionType")
	reward_encounter_backdrop.visible = scene_kind == "reward"
	reward_cards.visible = scene_kind == "reward"
	reward_skip_button.visible = scene_kind == "reward"
	reward_skip_button.text = "跳过奖励"
	var choice_scroll_content := choice_list.get_parent()
	if choice_scroll_content != null:
		choice_scroll_content.move_child(reward_skip_button, reward_cards.get_index() + 1)
	question_event_frame.visible = question_event_active
	service_bench.visible = scene_kind == "service"
	component_rack.visible = scene_kind == "component"
	choice_list.visible = scene_kind != "reward" and !question_event_active
	match state:
		RunState.REWARD:
			_update_reward_visuals()
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
				var button := _new_card_view(
					card,
					ChoicePresenter.card_mode_for(scene_kind),
					int(card.get("cost", 0)),
					"",
					_reward_reason(card)
				)
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
		RunState.REST:
			choice_title.text = str(current_node.get("label", "阶段维护"))
			choice_description.text = "选择一项工程取舍，然后继续攀登。" if current_layer < RUN_NODE_COUNT - 1 else "Boss 前最后一次整备：每项方案都有独立代价。"
			if service_bench_label != null:
				service_bench_label.text = ChoicePresenter.bench_status(stability, max_stability, deck.size(), pending_service_energy_penalty, pending_service_reroute_lock)
			_add_service_button("快速检修\n恢复 20 稳定度  ·  代价：最大稳定度 -5", "maintenance", Color("#517943"), _service_action_unavailable_reason("maintenance"))
			_add_service_button("固件优化\n选择并升级一张牌  ·  代价：稳定度 -8", "upgrade", Color("#2f7f8d"), _service_action_unavailable_reason("upgrade"))
			_add_service_button("模块补充\n从三张完整卡面中选择一张  ·  代价：下一场首回合禁用重排", "add", Color("#725c91"), _service_action_unavailable_reason("add"))
			_add_service_button("线束精简\n选择并删除一张牌  ·  代价：下一场初始能量 -1", "remove", Color("#b16a2c"), _service_action_unavailable_reason("remove"))
			_add_service_button("跳过整备\n不承担代价，继续攀登", "skip", Color("#697b80"))
		RunState.COMPONENT:
			choice_title.text = "选择工程组件"
			choice_description.text = "组件在本局后续战斗中持续生效。"
			if component_rack_label != null:
				component_rack_label.text = "组件插槽  ·  已装配 %d  ·  本次选择 1" % relics.size()
			for raw_component in component_choices:
				var component := raw_component as Dictionary
				var button := Button.new()
				button.text = "%s\n%s" % [component.get("name", "工程组件"), component.get("description", "")]
				button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_skin_button(button, _component_accent(str(component.get("id", ""))))
				_size_choice_button(button, 108)
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
	question_continue.text = "无奖励，继续路线" if bool(event_result.get("rewardFallback", false)) else "继续路线"
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
		fallback.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
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
	var plot_width := 520.0
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
	reading_table.add_theme_color_override("font_color", VisualTheme.color("text_secondary"))
	question_interaction.add_child(reading_table)


func _render_question_consequence() -> void:
	var result_label := Label.new()
	result_label.name = "QuestionConsequenceStatus"
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(event_result.get("dataError", false)):
		result_label.text = "未应用奖励或惩罚。"
	elif !bool(event_result.get("correct", false)):
		result_label.text = "回答错误 · %s" % _event_effect_text(current_event.get("penalty", {}) as Dictionary)
	elif bool(event_result.get("rewardFallback", false)):
		result_label.name = "QuestionRewardFallback"
		result_label.text = "回答正确 · 当前无可用奖励，可继续路线"
	elif bool(event_result.get("rewardPending", false)):
		result_label.text = "回答正确 · 选择一项奖励"
	else:
		result_label.text = "回答正确 · 奖励已确认"
	question_consequence.add_child(result_label)
	if !bool(event_result.get("rewardPending", false)):
		return
	var rewards: Array = event_result.get("rewardChoices", []) as Array
	var available_indices: Array = event_result.get("availableRewardIndices", []) as Array
	for index in range(rewards.size()):
		var reward := rewards[index] as Dictionary
		var reward_button := Button.new()
		reward_button.name = "QuestionReward_%s" % str(reward.get("id", index))
		reward_button.text = str(reward.get("label", "选择奖励"))
		reward_button.disabled = !available_indices.has(index)
		if reward_button.disabled:
			reward_button.text += "（当前不可用）"
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
		RunState.REST: "service",
		RunState.COMPONENT: "component"
	}.get(state, "choice")


func _add_service_button(text: String, action_id: String, accent: Color, unavailable_reason: String = "") -> void:
	var button := Button.new()
	button.text = text + (("\n" + unavailable_reason) if !unavailable_reason.is_empty() else "")
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skin_button(button, accent)
	_size_choice_button(button, 108)
	button.disabled = !unavailable_reason.is_empty()
	button.tooltip_text = unavailable_reason
	button.pressed.connect(func() -> void:
		choose_service(action_id)
		_render_state()
	)
	choice_list.add_child(button)


func _component_accent(component_id: String) -> Color:
	return {
		"pullup_4k7": Color("#25a8b8"),
		"serial_helper": Color("#4c83a8"),
		"window_n8": Color("#765bb5"),
		"state_template": Color("#4f8e72"),
		"lcd_buffer": Color("#b17a27"),
		"precision_reference": Color("#2f7f8d"),
		"dma_channel": Color("#31946f"),
		"watchdog_timer": Color("#bd6940"),
		"shielded_cable": Color("#3e8796"),
		"trace_probe": Color("#725c91"),
	}.get(component_id, Color("#8b6b23")) as Color


func _size_choice_button(button: Button, minimum_height: float) -> void:
	button.custom_minimum_size = Vector2(260, minimum_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _render_result() -> void:
	result_title.text = "综合验收通过" if victory else "调试中止"
	result_title.add_theme_color_override("font_color", VisualTheme.color("success") if victory else VisualTheme.color("danger"))
	result_metrics.text = "得分 %d / 100\n到达节点 %d / %d\n稳定度 %d / %d\n检查点 %d / 2\n牌组 %d 张" % [
		score, current_layer, RUN_NODE_COUNT, stability, max_stability, checkpoints_passed, deck.size()
	]
	result_learning_summary.text = _learning_summary()
	var recommended := _unlocked_recommended_faults()
	result_review_button.visible = !recommended.is_empty()


func _unlocked_recommended_faults() -> Array[String]:
	var report := LearningReport.build(debug_reports, knowledge_stats)
	var unlocked := codex_progress.get("faults", []) as Array
	var result: Array[String] = []
	for raw_id in report.get("recommendedFaultIds", []) as Array:
		var fault_id := str(raw_id)
		if unlocked.has(fault_id):
			result.append(fault_id)
	return result


func _open_recommended_fault() -> void:
	var recommended := _unlocked_recommended_faults()
	if recommended.is_empty():
		return
	state = RunState.CODEX
	_refresh_codex()
	codex_view.select_tab("faults")
	codex_view.select_entry_by_id(recommended[0])
	_render_state()


func _learning_summary() -> String:
	var report := LearningReport.build(debug_reports, knowledge_stats)
	return "已掌握：%s\n继续加强：%s\n正在建立：%s\n答题正确率 %.0f%%  ·  弱点修复占比 %.0f%%\n结论：%s" % [
		_tag_list(report.get("mastered", []) as Array),
		_tag_list(report.get("review", []) as Array),
		_tag_list(report.get("building", []) as Array),
		float(report.get("questionAccuracy", 0.0)) * 100.0,
		float(report.get("engineeringResolutionRate", 0.0)) * 100.0,
		report.get("conclusion", "基础修复为主")
	]


func _tag_list(tags: Array) -> String:
	if tags.is_empty():
		return "无"
	var labels: Array[String] = []
	for raw_tag in tags.slice(0, 6):
		var tag := str(raw_tag)
		labels.append(str(KNOWLEDGE_TAG_NAMES.get(tag, tag)))
	return "、".join(labels)


func _observe_knowledge(tags: Array, positive: bool, fault_id: String = "") -> void:
	var tag_stats := knowledge_stats.get("tags", {}) as Dictionary
	for raw_tag in tags:
		var tag := str(raw_tag)
		if tag.is_empty():
			continue
		var stat := (tag_stats.get(tag, {}) as Dictionary).duplicate(true)
		var key := "positive" if positive else "errors"
		stat[key] = int(stat.get(key, 0)) + 1
		tag_stats[tag] = stat
	knowledge_stats["tags"] = tag_stats
	if !positive and !fault_id.is_empty():
		var review_faults := knowledge_stats.get("reviewFaultIds", []) as Array
		if !review_faults.has(fault_id):
			review_faults.append(fault_id)
		knowledge_stats["reviewFaultIds"] = review_faults


func _related_fault_for_tags(tags: Array) -> String:
	var enemy_ids: Array = enemy_defs.keys()
	enemy_ids.sort()
	for raw_id in enemy_ids:
		var enemy := enemy_defs[str(raw_id)] as Dictionary
		if str(enemy.get("tier", "")) != "boss" and _arrays_intersect(tags, enemy.get("weaknessTags", []) as Array):
			return str(raw_id)
	return ""


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
		"knowledgeTags": current_encounter.get("weaknessTags", []),
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
	event_mechanic_defs = _index_by_id(_load_json_array("res://data/events.local.json", "events"))
	question_defs = {}
	event_defs = {}
	relic_defs = _index_by_id(_load_json_array("res://data/relics.local.json", "relics"))
	map_defs = _index_by_id(_load_json_array("res://data/run_maps.local.json", "maps"))


func _load_json(path: String) -> Dictionary:
	return Content.load_json_object(path)


func _load_json_array(path: String, key: String) -> Array:
	return Content.load_json_array(path, key)


func _index_by_id(items: Array) -> Dictionary:
	return Content.index_by_id(items)


func _apply_question_content(questions: Array) -> void:
	question_defs = Content.merge_question_defs(question_defs, questions)
	event_defs = Content.compose_events(event_mechanic_defs, question_defs)


func _select_question_event(tier: String, node_id: String) -> Dictionary:
	var selection := Content.select_question_event(event_defs, tier, event_history, run_seed, node_id)
	if bool(selection.get("relaxed", false)):
		_log("事件去重约束已放宽")
	return selection.get("event", {}) as Dictionary


func _run_catalogs() -> Dictionary:
	return {
		"cards": card_defs,
		"negativeCards": negative_defs,
		"components": relic_defs,
		"enemies": enemy_defs
	}


func _has_valid_run_save() -> bool:
	var result := RunPersistence.load(run_save_path, _run_catalogs())
	if bool(result.get("ok", false)):
		return true
	if str(result.get("error", "")) != "missing":
		RunPersistence.delete(run_save_path)
	return false


func _save_run_now() -> bool:
	if !formal_run_active or tutorial_active or node_lab_active or completed or _card_actions_pending():
		return false
	var snapshot := _run_snapshot()
	var snapshot_hash := JSON.stringify(snapshot).hash()
	if snapshot_hash == last_save_hash:
		return true
	var result := RunPersistence.save(run_save_path, snapshot)
	if bool(result.get("ok", false)):
		last_save_hash = snapshot_hash
	return bool(result.get("ok", false))


func _delete_run_save() -> void:
	RunPersistence.delete(run_save_path)
	last_save_hash = 0


func _resume_formal_run() -> bool:
	var result := RunPersistence.load(run_save_path, _run_catalogs())
	if !bool(result.get("ok", false)):
		_delete_run_save()
		_refresh_start_menu()
		return false
	_restore_run_snapshot(result.get("snapshot", {}) as Dictionary)
	formal_run_active = true
	tutorial_active = false
	node_lab_active = false
	if runtime != null:
		runtime.begin_attempt()
	_render_state()
	return true


func _run_snapshot() -> Dictionary:
	return RunSnapshot.build(self)


func _restore_run_snapshot(data: Dictionary) -> void:
	RunSnapshot.restore(self, data, run_map_id, max_stability, RunState.MAP)


func _save_and_return_to_menu() -> void:
	_save_run_now()
	_close_run_menu()
	show_start_menu()


func _restart_formal_run() -> void:
	_close_run_menu()
	_start_clean_formal_run()


func _abandon_formal_run() -> void:
	_delete_run_save()
	_close_run_menu()
	show_start_menu()


func _request_run_action(action: String) -> void:
	pending_run_action = action
	run_action_dialog.title = "重新开始" if action == "restart" else "放弃本局"
	run_action_dialog.dialog_text = (
		"当前进度会被清除。确认重新开始？"
		if action == "restart"
		else "当前进度会被清除且无法恢复。确认放弃本局？"
	)
	run_action_dialog.popup_centered()


func _confirm_run_action() -> void:
	var action := pending_run_action
	pending_run_action = ""
	if action == "restart":
		_restart_formal_run()
	elif action == "abandon":
		_abandon_formal_run()


func _reset_run() -> void:
	_reset_card_action_queue()
	map_charge_animation_active = false
	if map_energy_overlay != null:
		map_energy_overlay.call("set_layer_immediate", 0)
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
	pending_service_energy_penalty = 0
	pending_service_reroute_lock = false
	current_layer = 0
	visited_nodes.clear()
	checkpoints_passed = 0
	checkpoint_results.clear()
	boss_phase = 0
	boss_review_used = false
	pre_boss_stability = max_stability
	relics.clear()
	powers.clear()
	component_tracking.clear()
	message_log.clear()
	debug_reports.clear()
	knowledge_stats = {
		"tags": {}, "questionCorrect": 0, "questionTotal": 0,
		"weaknessRepair": 0, "totalRepair": 0, "reviewFaultIds": []
	}
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
	var map_template := (map_defs.get(run_map_id, map_defs.get("mvp_a", {})) as Dictionary).duplicate(true)
	run_seed = int(map_template.get("seedId", 901))
	run_map = Content.resolve_run_map(map_template, run_seed)
	_hydrate_resolved_map_labels()
	boss_gate_ids = Content.resolve_boss_gates(((enemy_defs.get("warehouse_acceptance", {}) as Dictionary).get("phases", []) as Array), run_seed)
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
	rendered_hand_size_for_motion = -1
	_reset_combat_resources()
	_draw_cards(5)
	state = RunState.MAP
	_log("调试路线已初始化。")


func _reset_combat_resources() -> void:
	_reset_card_action_queue()
	fault_rule_state = {
		"cardTagCounts": {},
		"stageCounts": {},
		"triggerMatches": 0,
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
	rendered_hand_size_for_motion = -1


func _reset_card_action_queue() -> void:
	if card_action_tween != null and card_action_tween.is_valid():
		card_action_tween.kill()
	card_action_tween = null
	if card_action_ghost != null and is_instance_valid(card_action_ghost):
		card_action_ghost.queue_free()
	card_action_ghost = null
	for raw_card in hand:
		if raw_card is Dictionary:
			(raw_card as Dictionary).erase("_queuedPlayToken")
	card_action_queue.clear()
	active_card_action.clear()
	reserved_card_action_cost = 0
	settled_card_action_count = 0
	rejected_card_action_count = 0
	deferred_encounter_finish = false
	settling_card_action = false


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
	return TutorialPresenter.expected_card_id(tutorial_step)


func _tutorial_card_allowed(card_id: String) -> bool:
	return tutorial_active and card_id == _tutorial_expected_card_id()


func _tutorial_end_turn_allowed() -> bool:
	return tutorial_active and tutorial_step == TutorialStep.END_TURN


func confirm_tutorial_intent() -> bool:
	if !_gameplay_action_allowed():
		return false
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
	fault_rule_state["feedbackSuppressedPending"] = {
		"ruleId": str(rule.get("id", "")),
		"counter": counter
	}
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
	var evaluation := FaultRules.evaluate_after_card(rule, card, fault_rule_state, _fault_rule_snapshot())
	fault_rule_state["triggerMatches"] = int(evaluation.get("triggerMatches", fault_rule_state.get("triggerMatches", 0)))
	if bool(evaluation.get("triggered", false)) and !bool(fault_rule_state.get("triggered", false)):
		_resolve_fault_rule(rule)


func _resolve_fault_rule_end_turn() -> void:
	var rule := _fault_rule_definition()
	if rule.is_empty() or str(rule.get("timing", "")) != "end_turn":
		return
	var evaluation := FaultRules.evaluate_end_turn(rule, fault_rule_state, _fault_rule_snapshot())
	if bool(evaluation.get("suppressed", false)) and !bool(fault_rule_state.get("suppressed", false)):
		fault_rule_state["suppressed"] = true
		var counter := str(evaluation.get("reason", ""))
		_log("Fault rule %s suppressed by %s" % [rule.get("id", ""), counter])
		_emit_fault_suppressed(str(rule.get("id", "")), counter)
		return
	if bool(evaluation.get("triggered", false)) and !bool(fault_rule_state.get("triggered", false)):
		_resolve_fault_rule(rule)


func _emit_pending_fault_suppression() -> void:
	var pending := fault_rule_state.get("feedbackSuppressedPending", {}) as Dictionary
	if pending.is_empty():
		return
	fault_rule_state.erase("feedbackSuppressedPending")
	_emit_fault_suppressed(str(pending.get("ruleId", "")), str(pending.get("counter", "")))


func _emit_fault_suppressed(rule_id: String, counter: String) -> void:
	_observe_knowledge(current_encounter.get("weaknessTags", []) as Array, true)
	_emit_combat_feedback(
		"fault_suppressed",
		"故障已抑制",
		"反制条件：%s" % counter,
		Color("#3c8d72"),
		"suppressed",
		{"ruleId": rule_id, "counter": counter}
	)


func _fault_rule_counter_for_card(rule: Dictionary, card: Dictionary) -> String:
	return FaultRules.counter_for_card(rule, card, fault_rule_state, _fault_rule_snapshot())


func _fault_rule_will_trigger(rule: Dictionary, card: Dictionary) -> bool:
	return FaultRules.will_trigger(rule, card, fault_rule_state)


func _fault_rule_card_matches_trigger(rule: Dictionary, card: Dictionary) -> bool:
	return FaultRules.card_matches_trigger(rule, card)


func _fault_rule_behavior_counter(rule: Dictionary) -> String:
	return FaultRules.behavior_counter(rule, _fault_rule_snapshot())


func _fault_rule_snapshot() -> Dictionary:
	return {
		"retainData": retain_data,
		"trustedTotal": _trusted_total(),
		"chainCount": chain_count,
		"rawData": raw_data
	}


func _resolve_fault_rule(rule: Dictionary) -> void:
	var rule_id := str(rule.get("id", ""))
	fault_rule_state["triggered"] = true
	_observe_knowledge(current_encounter.get("weaknessTags", []) as Array, false, str(current_encounter.get("id", "")))
	for raw_penalty in FaultRules.penalties(rule):
		var penalty := raw_penalty as Dictionary
		match str(penalty.get("op", "")):
			"add_negative":
				var card_id := str(penalty.get("cardId", ""))
				if !card_id.is_empty():
					discard_pile.append(_negative_card(card_id))
			"damage":
				_take_damage(maxi(int(penalty.get("amount", 0)), 0))
			"next_energy":
				fault_rule_state["nextEnergyPenalty"] = int(fault_rule_state.get("nextEnergyPenalty", 0)) + int(penalty.get("amount", 0))
	_log("Fault rule %s triggered" % rule_id)
	_emit_combat_feedback(
		"fault_triggered",
		"故障触发",
		str(rule.get("description", rule_id)),
		Color("#b75a3a"),
		"fault",
		{"ruleId": rule_id}
	)


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
	_begin_component_encounter()
	if str(current_encounter.get("tier", "")) == "boss":
		boss_phase = clampi(boss_phase, 0, 2)
		var phases: Array = current_encounter.get("phases", [])
		if boss_gate_ids.size() != phases.size():
			boss_gate_ids = Content.resolve_boss_gates(phases, run_seed)
		_apply_boss_phase()
	else:
		repair_target = int(current_encounter.get("repairTarget", 24))
		current_intents = (current_encounter.get("intentPattern", []) as Array).duplicate(true)
	repair_progress = 0
	intent_index = 0
	state = RunState.COMBAT
	_reset_turn_state(true)
	_apply_pending_service_energy_penalty()
	_apply_pending_service_reroute_lock()
	_draw_cards(5)
	if str(current_encounter.get("tier", "")) == "boss":
		_ensure_boss_phase_gate_card_in_hand()
	_log("进入故障：%s" % current_encounter.get("name", enemy_id))
	if str(current_encounter.get("tier", "")) == "boss":
		_announce_boss_phase()


func choose_node(choice_index: int) -> bool:
	if !_gameplay_action_allowed():
		return false
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
	_begin_component_encounter()
	repair_target = 18 if sensor_checkpoint else 21
	repair_progress = 0
	current_intents = [
		{"type": "damage", "amount": 4, "text": "检查时间流逝：稳定度 -4"}
	]
	state = RunState.COMBAT
	_reset_turn_state(true)
	_apply_pending_service_energy_penalty()
	_apply_pending_service_reroute_lock()
	var guided_hand := ["mq2_sample", "bh1750_read", "adc_convert", "i2c_transaction", "unit_convert"] if sensor_checkpoint else ["mq2_sample", "bh1750_read", "adc_convert", "i2c_transaction", "sliding_average"]
	for card_id in guided_hand:
		hand.append(_card_copy(card_id))
	var guided_second_hand := ["sliding_average", "bh1750_read", "hdc1080_read", "i2c_transaction", "unit_convert"] if sensor_checkpoint else ["adc_convert", "i2c_transaction", "sliding_average", "mq2_sample", "hdc1080_read"]
	for index in range(guided_second_hand.size() - 1, -1, -1):
		draw_pile.append(_card_copy(guided_second_hand[index]))
	_log("进入教学检查点。")


func _apply_pending_service_energy_penalty() -> void:
	if pending_service_energy_penalty >= 0:
		return
	processing_points = maxi(0, processing_points + pending_service_energy_penalty)
	_log("整备停机代价：本场初始能量 %d。" % pending_service_energy_penalty)
	pending_service_energy_penalty = 0


func _apply_pending_service_reroute_lock() -> void:
	if !pending_service_reroute_lock:
		return
	reroute_available = false
	pending_service_reroute_lock = false
	_log("整备调试代价：本场首回合无法重排手牌。")


func _run_progress() -> float:
	return clampf(float(current_layer) / float(RUN_NODE_COUNT), 0.0, 1.0)


func _apply_boss_phase() -> void:
	var phases: Array = current_encounter.get("phases", [])
	if phases.is_empty():
		return
	var phase_data := phases[boss_phase] as Dictionary
	var gate_target_bonus := {
		"two_sources": 10,
		"trusted_and_calibration": 10,
		"two_output_types": 10
	}.get(_active_boss_gate_id(), 0) as int
	repair_target = int(phase_data.get("repairTarget", 28)) + gate_target_bonus
	current_intents = (phase_data.get("intentPattern", []) as Array).duplicate(true)
	_reset_boss_phase_metrics()


func _ensure_boss_phase_gate_card_in_hand() -> bool:
	if str(current_encounter.get("tier", "")) != "boss":
		return false
	var best_hand_score := 0
	for raw_card in hand:
		best_hand_score = maxi(best_hand_score, _boss_phase_gate_card_score(raw_card as Dictionary))

	var candidate_index := -1
	var candidate_score := best_hand_score
	var generated_candidate := {}
	for index in range(draw_pile.size()):
		var card := draw_pile[index] as Dictionary
		var score := _boss_phase_gate_card_score(card)
		if score > candidate_score:
			candidate_index = index
			candidate_score = score
	if candidate_index < 0:
		var card_ids: Array = card_defs.keys()
		card_ids.sort()
		for raw_card_id in card_ids:
			var candidate_card := card_defs[str(raw_card_id)] as Dictionary
			var score := _boss_phase_gate_card_score(candidate_card)
			if score > candidate_score:
				candidate_score = score
				generated_candidate = _card_copy(str(raw_card_id))
		if generated_candidate.is_empty():
			return false

	var replacement_index := -1
	var replacement_score := candidate_score
	for index in range(hand.size() - 1, -1, -1):
		var card := hand[index] as Dictionary
		var score := _boss_phase_gate_card_score(card)
		if !bool(card.get("negative", false)) and score < replacement_score:
			replacement_index = index
			replacement_score = score
	if replacement_index < 0:
		return false

	var candidate := generated_candidate if !generated_candidate.is_empty() else draw_pile[candidate_index] as Dictionary
	var replacement := hand[replacement_index] as Dictionary
	if generated_candidate.is_empty():
		draw_pile.remove_at(candidate_index)
	hand.remove_at(replacement_index)
	hand.append(candidate)
	draw_pile.append(replacement)
	_log("阶段援助：%s 已调入起手牌。" % str(candidate.get("name", candidate.get("id", "工程牌"))))
	return true


func _boss_phase_gate_card_score(card: Dictionary) -> int:
	if bool(card.get("negative", false)):
		return 0
	var tags: Array = card.get("tags", []) as Array
	var stage := str(card.get("stage", ""))
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	match _active_boss_gate_id():
		"two_sources", "three_sources":
			if stage != "collect":
				return 0
			var new_source_count := 0
			for source in SOURCE_ORDER:
				if tags.has(source) and !phase_source_coverage.has(source):
					new_source_count += 1
			for raw_effect in effects:
				var effect := raw_effect as Dictionary
				if str(effect.get("op", "")) != "gain_raw":
					continue
				for raw_source in effect.get("sourceOptions", []) as Array:
					if !phase_source_coverage.has(str(raw_source)):
						new_source_count += 1
			return 100 + new_source_count if new_source_count > 0 else 0
		"trusted_and_filter", "trusted_and_calibration":
			var preparation_tag := "filter" if _active_boss_gate_id() == "trusted_and_filter" else "calibration"
			if (
				int(phase_filters_played if preparation_tag == "filter" else phase_calibrations_played) == 0
				and tags.has(preparation_tag)
			):
				return 300
			if phase_trusted_sources.size() >= 2:
				return 0
			for raw_effect in effects:
				var effect := raw_effect as Dictionary
				var op := str(effect.get("op", ""))
				if op == "gain_trusted":
					var trusted_source := str(effect.get("source", "smoke"))
					if !phase_trusted_sources.has(trusted_source):
						return 240
				elif op == "convert" and _boss_conversion_can_add_trusted_source(str(effect.get("source", "any"))):
					return 220
			if stage == "collect":
				for source in SOURCE_ORDER:
					if tags.has(source) and !phase_trusted_sources.has(source):
						return 120
			return 0
		"two_output_types":
			for output_tag in BOSS_OUTPUT_TAGS:
				if (
					tags.has(output_tag)
					and !bool(phase_output_types.get(output_tag, false))
					and !bool(persistent_output_types.get(output_tag, false))
				):
					return 300
		"acceptance_output":
			if !bool(phase_output_types.get("acceptance", false)) and tags.has("acceptance"):
				return 360
			for output_tag in BOSS_OUTPUT_TAGS:
				if output_tag != "acceptance" and tags.has(output_tag) and !bool(phase_output_types.get(output_tag, false)):
					return 300
	return 0


func _boss_conversion_can_add_trusted_source(conversion_source: String) -> bool:
	var candidates: Array = SOURCE_ORDER.duplicate()
	if conversion_source == "smoke":
		candidates = ["smoke"]
	elif conversion_source == "i2c_any":
		candidates = ["light", "temp", "humidity"]
	for source in candidates:
		if int(raw_data.get(source, 0)) > 0 and !phase_trusted_sources.has(source):
			return true
	return false


func _announce_boss_phase() -> void:
	var phases: Array = current_encounter.get("phases", [])
	var phase_title := "验收阶段"
	if boss_phase >= 0 and boss_phase < phases.size():
		phase_title = str((phases[boss_phase] as Dictionary).get("name", phase_title))
	var gate_label := _active_boss_gate_label()
	_show_boss_phase_transition(boss_phase + 1, "%s · %s" % [phase_title, gate_label])
	_emit_combat_feedback(
		"boss_phase",
		"Boss 阶段 %d / 3" % (boss_phase + 1),
		"%s · %s" % [phase_title, gate_label],
		Color("#725c91"),
		"boss_%d" % (boss_phase + 1),
		{"phase": boss_phase + 1, "phaseTitle": phase_title}
	)


func _reset_boss_phase_metrics() -> void:
	phase_source_coverage.clear()
	phase_trusted_sources.clear()
	phase_filters_played = 0
	phase_calibrations_played = 0
	phase_output_types.clear()
	phase_output_uses.clear()


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
	fault_rule_state["triggerMatches"] = 0
	fault_rule_state["suppressed"] = false
	fault_rule_state["triggered"] = false
	fault_rule_state.erase("feedbackSuppressedPending")
	if !first_turn:
		hand.clear()
		for raw_card in retained_cards:
			hand.append(raw_card)
		retained_cards.clear()
		_draw_cards(5)


func play_card(hand_index: int) -> bool:
	if !_gameplay_action_allowed():
		return false
	if _card_actions_pending() and !settling_card_action:
		return false
	if state != RunState.COMBAT or reroute_mode or !pending_card_selection.is_empty() or hand_index < 0 or hand_index >= hand.size():
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
	var chain_feedback := _evaluate_chain_for_card(card)
	var feedback_repair_before := repair_progress
	_consume_card_discounts(card)
	processing_points -= cost
	hand.remove_at(hand_index)
	_prepare_fault_rule_for_card(card)
	_advance_chain_for_card(card)
	var tags: Array = card.get("tags", [])
	for raw_tag in tags:
		var tag := str(raw_tag)
		encounter_evidence_tags[tag] = true
		if SOURCE_ORDER.has(tag):
			turn_sources[tag] = true
		if BOSS_OUTPUT_TAGS.has(tag):
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
	if tags.has("calibration") and str(current_encounter.get("tier", "")) == "boss":
		phase_calibrations_played += 1
	var repair_before := repair_progress
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	_apply_card_effects(effects, card)
	var card_finalizer := {
		"card": card.duplicate(true),
		"repairBefore": repair_before,
		"feedbackRepairBefore": feedback_repair_before,
		"chainDecision": str(chain_feedback.get("decision", "preserves"))
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
	_unlock_codex_entry("cards", str(card.get("id", "")))
	var repair_before := int(finalizer.get("repairBefore", repair_progress))
	var feedback_repair_before := int(finalizer.get("feedbackRepairBefore", repair_before))
	var chain_decision := str(finalizer.get("chainDecision", "preserves"))
	_apply_component_play_result(card, chain_decision)
	var chain_detail: String = str({
		"advances": "工程链推进至 %s" % _stage_name(str(card.get("stage", ""))),
		"breaks": "工程链中断，从 %s 重新开始" % _stage_name(str(card.get("stage", ""))),
		"preserves": "保持当前工程链"
	}.get(chain_decision, "保持当前工程链"))
	_emit_combat_feedback(
		"card",
		str(card.get("name", "执行工程动作")),
		chain_detail,
		_card_accent(card),
		"chain" if chain_decision == "advances" else "card",
		{
			"cardId": str(card.get("id", "")),
			"cardType": str(card.get("type", "")),
			"stage": str(card.get("stage", "")),
			"chainDecision": chain_decision
		}
	)
	var repair_delta := repair_progress - feedback_repair_before
	if repair_delta > 0:
		_emit_combat_feedback(
			"repair",
			"修复 +%d" % repair_delta,
			"故障剩余 %d" % maxi(repair_target - repair_progress, 0),
			Color("#3c8d72"),
			"repair",
			{"amount": repair_delta}
		)
	_emit_pending_fault_suppression()
	_resolve_fault_rule_after_card(card)
	var matched_weaknesses := _matched_weakness_tags(card)
	if !matched_weaknesses.is_empty():
		_observe_knowledge(matched_weaknesses, true)
		var diagnosis_bonus := 2 if diagnosis > 0 and repair_progress > repair_before else 0
		var bonus_text := "  ·  诊断修复 +2" if diagnosis_bonus > 0 else ""
		_emit_combat_feedback(
			"weakness",
			"弱点命中",
			"%s%s" % [" / ".join(matched_weaknesses), " · 诊断增益 +2" if diagnosis_bonus > 0 else ""],
			Color("#d08a2e"),
			"weakness",
			{
				"matchedTags": matched_weaknesses.duplicate(),
				"diagnosisBonus": diagnosis_bonus
			}
		)
		_log("%s 命中弱点：%s%s" % [card.get("name", card.get("id", "card")), "/".join(matched_weaknesses), bonus_text])
	if str(card.get("type", "")) == "power" or bool(card.get("exhaust", false)):
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)
	_record_boss_output_use(card)
	cards_played_this_turn += 1
	if stability <= 0:
		_handle_defeat()
		return
	if repair_progress >= repair_target:
		if tutorial_active:
			pass
		elif str(current_encounter.get("tier", "")) != "checkpoint" or _checkpoint_requirements_met():
			if settling_card_action and !card_action_queue.is_empty():
				deferred_encounter_finish = true
			else:
				_finish_encounter()
	if tutorial_active:
		_advance_tutorial_after_card(str(card.get("id", "")))


func begin_reroute() -> bool:
	if !_gameplay_action_allowed():
		return false
	if state != RunState.COMBAT or _card_actions_pending() or !pending_card_selection.is_empty() or tutorial_active or !reroute_available or cards_played_this_turn > 0:
		return false
	reroute_mode = true
	_render_state()
	return true


func cancel_reroute() -> bool:
	if !_gameplay_action_allowed():
		return false
	if !reroute_mode:
		return false
	reroute_mode = false
	_render_state()
	return true


func reroute_card(hand_index: int) -> bool:
	if !_gameplay_action_allowed():
		return false
	if !_reroute_action_allowed() or hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)):
		return false
	hand.remove_at(hand_index)
	var before_draw := hand.size()
	var targeted_card := _take_boss_reroute_card()
	if targeted_card.is_empty():
		_draw_cards(1)
	else:
		hand.append(targeted_card)
		processing_points = maxi(0, processing_points - 1)
		_log("定向换牌：检索到 %s。" % str(targeted_card.get("name", targeted_card.get("id", "工程牌"))))
	if hand.size() == before_draw:
		hand.insert(hand_index, card)
		reroute_mode = false
		_render_state()
		return false
	discard_pile.append(card)
	reroute_available = false
	reroute_mode = false
	_render_state()
	return true


func _take_boss_reroute_card() -> Dictionary:
	var candidate_index := _best_boss_reroute_card_index()
	if candidate_index < 0:
		return {}
	var candidate := (draw_pile[candidate_index] as Dictionary).duplicate(true)
	draw_pile.remove_at(candidate_index)
	return candidate


func _boss_targeted_reroute_available() -> bool:
	return _best_boss_reroute_card_index() >= 0


func _best_boss_reroute_card_index() -> int:
	if (
		str(current_encounter.get("tier", "")) != "boss"
		or _boss_phase_requirements_met()
		or processing_points <= 0
	):
		return -1
	var candidate_index := -1
	var candidate_score := 0
	for index in range(draw_pile.size()):
		var candidate := draw_pile[index] as Dictionary
		var score := _boss_phase_gate_card_score(candidate)
		if score > candidate_score:
			candidate_index = index
			candidate_score = score
	return candidate_index


func _reroute_action_allowed() -> bool:
	return (
		state == RunState.COMBAT
		and !tutorial_active
		and pending_card_selection.is_empty()
		and reroute_available
		and cards_played_this_turn == 0
		and reroute_mode
	)


func _consume_card_discounts(card: Dictionary) -> void:
	var tags: Array = card.get("tags", [])
	if tags.has("i2c") and int(powers.get("i2c_discount", 0)) > 0:
		powers["i2c_discount"] = int(powers.get("i2c_discount", 0)) - 1
	if str(card.get("type", "")) == "process" and int(powers.get("process_discount", 0)) > 0:
		powers["process_discount"] = int(powers.get("process_discount", 0)) - 1
	if str(card.get("type", "")) == "interface" and int(powers.get("interface_discount", 0)) > 0:
		powers["interface_discount"] = int(powers.get("interface_discount", 0)) - 1


func _stage_name(stage: String) -> String:
	return {
		"collect": "采集",
		"interface": "接口",
		"process": "处理",
		"output": "输出"
	}.get(stage, "当前阶段")


func _chain_decision_label(decision: String) -> String:
	return {"advances": "推进", "preserves": "保持", "breaks": "中断"}.get(decision, "保持")


func _chain_reward_label(reward: String) -> String:
	return {
		"+3 block": "+3 防护",
		"+1 processing point": "+1 处理点",
		"+8 repair +1 diagnosis": "+8 修复 / +1 诊断",
		"none": "无"
	}.get(reward, reward)


func _card_unavailable_reason(card: Dictionary, cost: int, selection_open: bool) -> String:
	if selection_open:
		return "先完成当前选择"
	if reroute_mode:
		return ""
	if tutorial_active and !_tutorial_card_allowed(str(card.get("id", ""))):
		return "请先完成当前教学操作"
	if processing_points < cost:
		return "处理点不足，需要 %d" % cost
	if !_card_requirements_met(card):
		return "缺少原始数据、可信数据或前置条件"
	return ""


func _card_requirements_met(card: Dictionary) -> bool:
	return CardRules.requirements_met(card, _trusted_total(), trusted_data, alarm_markers)


func _advance_chain(stage: String) -> void:
	_advance_chain_for_card({"stage": stage, "type": stage})


func _advance_chain_for_card(card: Dictionary) -> void:
	var outcome := _evaluate_chain_for_card(card)
	chain_count = int(outcome.get("chainCount", chain_count))
	last_stage = str(outcome.get("lastStage", last_stage))
	if str(outcome.get("decision", "preserves")) == "advances":
		_apply_chain_threshold_rewards()


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
		chain_rewards_claimed["four"] = true


func _chain_preview_for_stage(stage: String) -> Dictionary:
	return _chain_preview_for_card({"stage": stage, "type": stage})


func _chain_preview_for_card(card: Dictionary) -> Dictionary:
	return _evaluate_chain_for_card(card)


func _evaluate_chain_for_card(card: Dictionary) -> Dictionary:
	return CardRules.chain_transition(card, {
		"stageOrder": STAGE_ORDER,
		"lastStage": last_stage,
		"chainCount": chain_count,
		"rewardsClaimed": chain_rewards_claimed
	})


func _next_chain_stage() -> String:
	return CardRules.next_chain_stage(STAGE_ORDER, last_stage)


func _pending_chain_reward(predicted_chain: int, decision: String) -> String:
	return CardRules.pending_chain_reward(predicted_chain, decision, chain_rewards_claimed)


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
	if !_gameplay_action_allowed():
		return false
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
	var selection_context := selection.get("context", {}) as Dictionary
	if owner == "service" and !_service_action_unavailable_reason(str(selection_context.get("serviceAction", ""))).is_empty():
		return false
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
	elif owner == "service":
		_apply_service_payment(str(selection_context.get("serviceAction", "")))
		state = RunState.MAP
	else:
		return false
	call_deferred("_process_next_card_action")
	return true


func _selection_owner_matches_state(owner: String) -> bool:
	return (
		(owner == "combat" and state == RunState.COMBAT)
		or (owner == "event" and state == RunState.EVENT)
		or (owner == "service" and state == RunState.REST)
	)


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
		fault_rule_state["feedbackSuppressedPending"] = {
			"ruleId": str(rule.get("id", "")),
			"counter": counter_tag
		}


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
	var progress_before := repair_progress
	var adjusted := maxi(amount - repair_penalty, 0)
	var tags: Array = card.get("tags", [])
	if tags.has("smoke"):
		adjusted += int(powers.get("smoke_repair", 0))
	var weakness: Array = current_encounter.get("weaknessTags", [])
	if diagnosis > 0 and _arrays_intersect(tags, weakness):
		adjusted += 2
	if str(current_encounter.get("tier", "")) == "boss":
		adjusted = adjusted * 2 if boss_phase < 2 else adjusted + int(ceil(adjusted * 0.5))
		if boss_phase == 2 and _boss_card_repeats_output(card):
			adjusted = floori(float(adjusted) * 0.6)
	repair_progress = mini(repair_target, repair_progress + adjusted)
	var actual_repair := maxi(repair_progress - progress_before, 0)
	knowledge_stats["totalRepair"] = int(knowledge_stats.get("totalRepair", 0)) + actual_repair
	if _arrays_intersect(tags, weakness):
		knowledge_stats["weaknessRepair"] = int(knowledge_stats.get("weaknessRepair", 0)) + actual_repair


func _boss_card_repeats_output(card: Dictionary) -> bool:
	for raw_tag in card.get("tags", []) as Array:
		var tag := str(raw_tag)
		if BOSS_OUTPUT_TAGS.has(tag) and int(phase_output_uses.get(tag, 0)) > 0:
			return true
	return false


func _record_boss_output_use(card: Dictionary) -> void:
	if str(current_encounter.get("tier", "")) != "boss" or boss_phase != 2:
		return
	for raw_tag in card.get("tags", []) as Array:
		var tag := str(raw_tag)
		if BOSS_OUTPUT_TAGS.has(tag):
			phase_output_uses[tag] = int(phase_output_uses.get(tag, 0)) + 1


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
	var result := RunRules.evidence_result(current_encounter.get("evidenceGroups", []) as Array, encounter_evidence_tags)
	return bool(result.get("met", false))


func _completed_evidence_group_count() -> int:
	var result := RunRules.evidence_result(current_encounter.get("evidenceGroups", []) as Array, encounter_evidence_tags)
	return int(result.get("completed", 0))


func _missing_evidence_labels() -> Array[String]:
	var result := RunRules.evidence_result(current_encounter.get("evidenceGroups", []) as Array, encounter_evidence_tags)
	var missing: Array[String] = []
	missing.assign(result.get("missing", []))
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
	var component_result := ComponentRules.after_play(card, {"turn": turn_number}, relic_defs, relics, component_tracking)
	component_tracking = (component_result.get("tracking", {}) as Dictionary).duplicate(true)
	for raw_action in component_result.get("actions", []) as Array:
		if str((raw_action as Dictionary).get("op", "")) == "ignore_negative":
			_emit_component_feedback("LCD 缓冲区", "阻塞延时已被吸收")
			return
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
	var damage_result := ComponentRules.modify_damage(amount, relic_defs, relics, component_tracking)
	component_tracking = (damage_result.get("tracking", {}) as Dictionary).duplicate(true)
	var original_amount := amount
	amount = int(damage_result.get("amount", amount))
	if amount < original_amount:
		_emit_component_feedback("看门狗定时器", "本次稳定度伤害减少 %d" % (original_amount - amount))
	var stability_before := stability
	var blocked := mini(block, amount)
	block -= blocked
	stability = maxi(0, stability - (amount - blocked))
	var stability_loss := stability_before - stability
	if stability_loss > 0:
		_emit_combat_feedback(
			"stability",
			"稳定度 -%d" % stability_loss,
			"防护抵消 %d，当前稳定度 %d / %d" % [blocked, stability, max_stability],
			Color("#b75a3a"),
			"damage",
			{"amount": -stability_loss, "blocked": blocked}
		)


func end_turn() -> bool:
	if !_gameplay_action_allowed():
		return false
	if state != RunState.COMBAT or _card_actions_pending() or !pending_card_selection.is_empty():
		return false
	if tutorial_active and !_tutorial_end_turn_allowed():
		_log("请先完成当前教学操作。")
		return false
	var tier := str(current_encounter.get("tier", "ordinary"))
	if !tutorial_active and repair_progress >= repair_target and _active_gate_met(tier):
		_finish_encounter()
		return true
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
			_reset_boss_phase_turn_state()
			_announce_boss_phase()
			_log("验收进入阶段 %d。" % (boss_phase + 1))
			return
		_unlock_codex_entry("faults", str(current_encounter.get("id", "")))
		_finish_run(true)
		return
	if tier == "checkpoint":
		_finish_checkpoint(true)
		return
	if !_encounter_requirements_met():
		_observe_knowledge(current_encounter.get("weaknessTags", []) as Array, false, str(current_encounter.get("id", "")))
		_log("修复进度达标，但缺少工程证据：%s" % "、".join(_missing_evidence_labels()))
		return
	_record_debug_report(true)
	_unlock_codex_entry("faults", str(current_encounter.get("id", "")))
	if tier == "elite":
		_grant_random_relic()
	_open_reward()


func _reset_boss_phase_turn_state() -> void:
	for raw_card in hand:
		discard_pile.append(raw_card)
	hand.clear()
	for raw_card in retained_cards:
		discard_pile.append(raw_card)
	retained_cards.clear()
	retain_data = false
	next_turn_energy = 0
	repair_penalty = 0
	i2c_cost_penalty = 0
	pending_i2c_count = 0
	for temporary_power in ["i2c_discount", "process_discount", "interface_discount"]:
		powers.erase(temporary_power)
	fault_rule_state["nextEnergyPenalty"] = 0
	_reset_turn_state(true)
	processing_points = 3
	_draw_cards(5)
	_ensure_boss_phase_gate_card_in_hand()


func _boss_phase_requirements_met() -> bool:
	return RunRules.boss_requirements_met(_active_boss_gate_id(), {
		"sourceCoverageCount": phase_source_coverage.size(),
		"trustedSourceCount": phase_trusted_sources.size(),
		"filtersPlayed": phase_filters_played,
		"calibrationsPlayed": phase_calibrations_played,
		"distinctOutputCount": _boss_distinct_output_count(),
		"acceptancePlayed": bool(phase_output_types.get("acceptance", false)),
		"otherOutputCount": _boss_other_output_count()
	})
	_log("故障修复完成。")


func _boss_distinct_output_count() -> int:
	return RunRules.distinct_output_count(BOSS_OUTPUT_TAGS, phase_output_types, persistent_output_types)


func _boss_other_output_count() -> int:
	var count := 0
	for output_tag in BOSS_OUTPUT_TAGS:
		if output_tag != "acceptance" and (bool(phase_output_types.get(output_tag, false)) or bool(persistent_output_types.get(output_tag, false))):
			count += 1
	return count


func _active_boss_gate_id() -> String:
	if boss_phase >= 0 and boss_phase < boss_gate_ids.size():
		return boss_gate_ids[boss_phase]
	var phases: Array = current_encounter.get("phases", [])
	if boss_phase >= 0 and boss_phase < phases.size():
		var options: Array = (phases[boss_phase] as Dictionary).get("gateOptions", [])
		if !options.is_empty():
			return str((options[0] as Dictionary).get("id", ""))
	return ""


func _active_boss_gate_label() -> String:
	var gate_id := _active_boss_gate_id()
	var phases: Array = current_encounter.get("phases", [])
	if boss_phase >= 0 and boss_phase < phases.size():
		for raw_option in (phases[boss_phase] as Dictionary).get("gateOptions", []) as Array:
			var option := raw_option as Dictionary
			if str(option.get("id", "")) == gate_id:
				return str(option.get("label", gate_id))
	return gate_id


func _finish_checkpoint(repaired: bool) -> void:
	var sensor_checkpoint := str(current_node.get("type", "")) == "checkpoint_sensor"
	var passed := repaired and _checkpoint_requirements_met()
	_observe_knowledge(["sensor_integration" if sensor_checkpoint else "data_trust"], passed)
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
	return RunRules.checkpoint_requirements_met(sensor_checkpoint, {
		"trustedSourceCount": trusted_sources_seen.size(),
		"filtersPlayed": filters_played,
		"hasAbnormalReading": _hand_has_card("abnormal_reading")
	})


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
	_play_combat_feedback_sound("reward")


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
	var effects: Array = card.get("upgradeEffects", []) if bool(card.get("upgraded", false)) else card.get("effects", [])
	for raw_effect in effects:
		if ["draw", "draw_discard", "select_draw", "draw_if_removed"].has(str((raw_effect as Dictionary).get("op", ""))):
			return true
	return false


func _reward_reason(card: Dictionary) -> String:
	return str(card.get("rewardReason", ""))


func choose_reward(card_id: String) -> bool:
	if !_gameplay_action_allowed():
		return false
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
	if !_gameplay_action_allowed():
		return false
	if state != RunState.EVENT or !pending_card_selection.is_empty() or event_answer_locked:
		return false
	if !_event_data_valid(current_event):
		_resolve_malformed_event()
		return true
	if !_event_answer_is_valid(answer):
		return false
	var correct := _event_answer_matches(answer, current_event.get("correctAnswer"))
	knowledge_stats["questionTotal"] = int(knowledge_stats.get("questionTotal", 0)) + 1
	if correct:
		knowledge_stats["questionCorrect"] = int(knowledge_stats.get("questionCorrect", 0)) + 1
	_observe_knowledge(current_event.get("knowledgeTags", []) as Array, correct, _related_fault_for_tags(current_event.get("knowledgeTags", []) as Array) if !correct else "")
	var recorded_answer = answer.duplicate(true) if answer is Array or answer is Dictionary else answer
	var reward_choices: Array = (current_event.get("rewardChoices", []) as Array).duplicate(true)
	var available_reward_indices: Array[int] = []
	if correct:
		for index in range(reward_choices.size()):
			var reward := reward_choices[index] as Dictionary
			if _event_consequence_available(reward.get("effect", {}) as Dictionary):
				available_reward_indices.append(index)
	var reward_fallback := correct and available_reward_indices.is_empty()
	event_answer_locked = true
	event_result = {
		"answer": recorded_answer,
		"correctAnswer": current_event.get("correctAnswer"),
		"correct": correct,
		"explanation": str(current_event.get("explanation", "")),
		"rewardChoices": reward_choices,
		"availableRewardIndices": available_reward_indices,
		"rewardPending": correct and !reward_fallback,
		"rewardFallback": reward_fallback,
		"resolved": reward_fallback
	}
	if !correct:
		event_result["consequenceApplied"] = _apply_event_consequence(current_event.get("penalty", {}) as Dictionary)
		event_result["resolved"] = true
	return true


func choose_event_reward(index: int) -> bool:
	if !_gameplay_action_allowed():
		return false
	if state != RunState.EVENT or !event_answer_locked or !pending_card_selection.is_empty():
		return false
	if !bool(event_result.get("correct", false)) or !bool(event_result.get("rewardPending", false)):
		return false
	var rewards: Array = event_result.get("rewardChoices", []) as Array
	if index < 0 or index >= rewards.size():
		return false
	var reward := rewards[index] as Dictionary
	var effect := reward.get("effect", {}) as Dictionary
	if !_event_consequence_available(effect):
		return false
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
	if !_gameplay_action_allowed():
		return false
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
	if !_gameplay_action_allowed():
		return false
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
	if !_gameplay_action_allowed():
		return false
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


func _event_consequence_available(effect: Dictionary) -> bool:
	match str(effect.get("op", "")):
		"heal":
			return true
		"add_negative":
			return negative_defs.has(str(effect.get("cardId", "")))
		"reveal_nodes":
			return !(effect.get("nodes", []) as Array).is_empty()
		"choose_card":
			return !_question_card_options(effect).is_empty()
		"add_upgraded_card":
			return card_defs.has(str(effect.get("cardId", "")))
		"upgrade_card":
			return !_question_deck_options(effect, "upgrade_card").is_empty()
		"remove_card":
			return !_question_deck_options(effect, "remove_card").is_empty()
		"choose_component":
			return !_question_component_options(effect).is_empty()
	return false


func _open_question_card_selection(effect: Dictionary, action: String) -> bool:
	var options := _question_card_options(effect)
	if options.is_empty():
		return false
	_open_card_selection("event_card", options, [], "event", {"action": action, "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


func _question_card_options(effect: Dictionary) -> Array:
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
	return options


func _open_question_deck_selection(effect: Dictionary, action: String) -> bool:
	var options := _question_deck_options(effect, action)
	if options.is_empty():
		return false
	_open_card_selection("event_card", options, [], "event", {"action": action, "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


func _question_deck_options(effect: Dictionary, action: String) -> Array:
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
	return options


func _open_question_component_selection(effect: Dictionary) -> bool:
	var options := _question_component_options(effect)
	if options.is_empty():
		return false
	_open_card_selection("event_component", options, [], "event", {"action": "add_component", "eventFlow": "question_reward"})
	return !pending_card_selection.is_empty()


func _question_component_options(effect: Dictionary) -> Array:
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
	return options


func _apply_run_effect(effect: Dictionary) -> void:
	var op := str(effect.get("op", ""))
	var amount := int(effect.get("amount", 0))
	match op:
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


func _boss_gap_card_id() -> String:
	return ServiceController.boss_gap_card_id(deck, card_defs, BOSS_OUTPUT_TAGS)


func _missing_boss_stage_tags() -> Array[String]:
	return ServiceController.missing_boss_stage_tags(deck, BOSS_STAGE_TAG_REQUIREMENTS, BOSS_OUTPUT_TAGS)


func _recommended_service_card_id() -> String:
	return ServiceController.recommended_card_id(deck, card_defs, BOSS_STAGE_TAG_REQUIREMENTS, BOSS_OUTPUT_TAGS)


func _deck_output_types() -> Dictionary:
	return ServiceController.deck_output_types(deck, BOSS_OUTPUT_TAGS)


func _deck_has_any_tag(required_tags: Array) -> bool:
	return ServiceController.deck_has_any_tag(deck, required_tags)


func _service_config() -> Dictionary:
	return {
		"actions": SERVICE_ACTIONS,
		"repairAmount": SERVICE_REPAIR_AMOUNT,
		"upgradeDamage": SERVICE_UPGRADE_DAMAGE,
		"maintenanceMaxCost": SERVICE_MAINTENANCE_MAX_STABILITY_COST,
		"outputTags": BOSS_OUTPUT_TAGS,
		"stageRequirements": BOSS_STAGE_TAG_REQUIREMENTS,
		"restState": RunState.REST,
		"mapState": RunState.MAP
	}


func choose_service(action_id: String) -> bool:
	return ServiceController.choose(self, action_id, _service_config())


func _service_action_unavailable_reason(action_id: String) -> String:
	return ServiceController.unavailable_reason(self, action_id, _service_config())


func _apply_service_payment(action_id: String) -> void:
	ServiceController.apply_payment(self, action_id, _service_config())


func _service_add_options() -> Array:
	return ServiceController.add_options(self, _service_config())


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
	if !_gameplay_action_allowed():
		return false
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


func _begin_component_encounter() -> void:
	var result := ComponentRules.begin_encounter(relic_defs, relics, {
		"weaknessTags": current_encounter.get("weaknessTags", [])
	})
	component_tracking = (result.get("tracking", {}) as Dictionary).duplicate(true)
	for raw_action in result.get("actions", []) as Array:
		var action := raw_action as Dictionary
		if str(action.get("op", "")) == "diagnosis":
			diagnosis = mini(diagnosis + int(action.get("amount", 0)), 3)
			_emit_component_feedback("4.7k 上拉电阻", "开战获得诊断标记")


func _apply_component_play_result(card: Dictionary, chain_decision: String) -> void:
	var result := ComponentRules.after_play(card, {
		"turn": turn_number,
		"chainCompleted": chain_count >= 3 and chain_decision == "advances"
	}, relic_defs, relics, component_tracking)
	component_tracking = (result.get("tracking", {}) as Dictionary).duplicate(true)
	for raw_action in result.get("actions", []) as Array:
		var action := raw_action as Dictionary
		var amount := int(action.get("amount", 0))
		match str(action.get("op", "")):
			"draw":
				_draw_cards(amount)
			"block":
				block += amount
			"repair":
				_add_repair(amount, card)
		_emit_component_feedback("工程组件触发", _component_action_text(action))


func _component_action_text(action: Dictionary) -> String:
	var amount := int(action.get("amount", 0))
	return {
		"draw": "额外抽 %d 张" % amount,
		"block": "获得 %d 防护" % amount,
		"repair": "额外修复 %d" % amount
	}.get(str(action.get("op", "")), "组件效果已生效")


func _emit_component_feedback(title: String, detail: String) -> void:
	_emit_combat_feedback(
		"component",
		title,
		detail,
		Color("#2f7f8d"),
		"component",
		{}
	)


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
	NodeLabController.reset_fixture(self, deck_fixture, LAB_COVERAGE_CARD_IDS)


func lab_add_card_to_hand(card_id: String) -> bool:
	return NodeLabController.add_card_to_hand(self, card_id)


func lab_remove_hand_card(hand_index: int) -> bool:
	return NodeLabController.remove_hand_card(self, hand_index)


func lab_remove_deck_card(card_id: String) -> bool:
	return NodeLabController.remove_deck_card(self, card_id)


func lab_set_stability(value: int) -> bool:
	return NodeLabController.set_stability(self, value)


func lab_set_fault_remaining(value: int) -> bool:
	return NodeLabController.set_fault_remaining(self, value, RunState.COMBAT)


func lab_fault_remaining() -> int:
	return NodeLabController.fault_remaining(self)


func _node_lab_states() -> Dictionary:
	return {"waiting": RunState.WAITING, "rest": RunState.REST}


func start_lab_scenario(entry: Dictionary, deck_fixture: String = "starter") -> bool:
	return NodeLabController.start_scenario(self, entry, deck_fixture, _node_lab_states(), LAB_COVERAGE_CARD_IDS)


func _prepare_lab_fault_rule_hand() -> bool:
	return NodeLabController.prepare_fault_rule_hand(self)


func _lab_fault_rule_hand_ids(rule_id: String) -> Array[String]:
	return NodeLabController.fault_rule_hand_ids(rule_id)


func restart_lab_scenario() -> bool:
	return NodeLabController.restart_scenario(self, _node_lab_states(), LAB_COVERAGE_CARD_IDS)


func return_to_node_lab() -> void:
	NodeLabController.return_to_catalog(self, RunState.WAITING)


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
	_delete_run_save()
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
	var stats := {
		"victory": victory,
		"visitedNodes": current_layer,
		"checkpointsPassed": checkpoints_passed,
		"bossPhase": boss_phase,
		"stability": stability,
		"maxStability": max_stability,
		"deckSize": deck.size(),
		"debugReportCount": debug_reports.size(),
		"bossReviewUsed": boss_review_used,
		"elapsedMs": maxi(Time.get_ticks_msec() - started_at, 0)
	}
	stats.merge((LearningReport.build(debug_reports, knowledge_stats).get("hostStats", {}) as Dictionary), true)
	return stats


func _calculate_score() -> int:
	return RunRules.calculate_score({
		"checkpointsPassed": checkpoints_passed,
		"relicCount": relics.size(),
		"bossReviewUsed": boss_review_used,
		"stability": stability,
		"maxStability": max_stability,
		"sourceCoverageCount": source_coverage.size(),
		"trustedSourceCount": trusted_sources_seen.size(),
		"filtersPlayed": filters_played
	})


func _log(text: String) -> void:
	message_log.append(text)
	while message_log.size() > 8:
		message_log.pop_front()
