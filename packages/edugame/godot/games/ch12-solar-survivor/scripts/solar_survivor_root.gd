extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")

const DEFAULT_SIZE := Vector2(1280, 720)
const ENERGY_MAX := 100.0
const ORDINARY_PARTICLE_LIMIT := 42
const ERROR_BLOCK_LIMIT := 10
const NOISE_PROJECTILE_LIMIT := 12
const SHADOW_ZONE_LIMIT := 4
const OSCILLATION_ZONE_LIMIT := 4
const ENERGY_REFUND_ON_CORRECT_MAX := 45.0
const CORRECTION_COOLDOWN_REDUCE_MAX := 1.2
const CORRECTION_RANGE_BOOST_MAX := 240.0
const CORRECTION_TARGET_COUNT_MAX := 4
const CORRECTION_DAMAGE_MAX := 2
const UI_FONT_PATH := "res://assets/fonts/NotoSansSC-VF.ttf"
const UI_BODY_ART_FONT_PATH := "res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"
const UI_DISPLAY_FONT_PATH := "res://assets/fonts/DingTalkJinBuTi.ttf"
const UI_TECH_FONT_PATH := "res://assets/fonts/Orbitron-wght.ttf"
const UI_BLUE := Color(0.07, 0.64, 0.70)
const UI_BLUE_DARK := Color(0.06, 0.18, 0.22)
const UI_BLUE_SOFT := Color(0.91, 0.98, 0.99)
const UI_BORDER := Color(0.48, 0.73, 0.77)
const UI_TEXT := Color(0.07, 0.18, 0.22)
const UI_MUTED := Color(0.20, 0.34, 0.38)
const UI_WHITE := Color(0.98, 1.0, 1.0)
const UI_PANEL_BG := Color(0.965, 0.99, 0.995, 0.97)
const UI_PANEL_LINE := Color(0.42, 0.67, 0.71, 0.48)
const UI_HEADER_BG := Color(0.89, 0.97, 0.98, 0.96)
const UI_TEACHING_ACCENT := Color(0.04, 0.43, 0.48)
const UI_SUCCESS := Color(0.16, 0.72, 0.53)
const UI_WARNING := Color(0.93, 0.63, 0.18)
const UI_FAULT := Color(0.88, 0.27, 0.17)
const UI_SHELL := Color(0.018, 0.035, 0.041, 0.98)
const ENEMY_ASSET_PROFILE := "v4_simplified"

enum Phase { WAITING, PLAYING, QUESTION, FINISHED }

var runtime
var phase := Phase.WAITING

var duration_sec := 180.0
var max_faults := 5
var question_time_sec := 15.0
var time_left := 180.0
var started_at := 0

var player_pos := DEFAULT_SIZE * 0.5
var move_speed := 210.0
var energy := 0.0
var passive_energy_boost := 0.0
var band_radius_boost := 0.0
var offset_bonus := 0.0
var fault_penalty_reduce := 0.0
var wrong_shield_charges := 0
var fatal_save_charges := 0
var energy_refund_on_correct := 0.0
var last_wrong_absorbed := false

var stability := 100.0
var tracking_efficiency := 70.0
var solar_score := 0
var correct_count := 0
var wrong_count := 0
var faults := 0
var combo := 0
var max_combo := 0
var offset_captures := 0
var shutdown := false

var particle_timer := 0.0
var progress_emit_timer := 0.0
var ordinary_particles: Array = []
var error_blocks: Array = []
var noise_projectiles: Array = []
var shadow_zones: Array = []
var oscillation_zones: Array = []
var error_spawn_timer := 6.0
var noise_source_spawn_timer := 12.0
var stray_light_spawn_timer := 45.0
var shadow_cloud_spawn_timer := 40.0
var saturation_block_spawn_timer := 60.0
var oscillation_core_spawn_timer := 90.0
var correction_timer := 1.8
var correction_cooldown := 2.2
var correction_range := 275.0
var correction_cooldown_reduce := 0.0
var correction_range_boost := 0.0
var correction_target_count := 1
var correction_damage := 1
var correction_beams: Array = []
var error_blocks_destroyed := 0
var noise_sources_destroyed := 0
var stray_lights_destroyed := 0
var shadow_clouds_destroyed := 0
var saturation_blocks_destroyed := 0
var oscillation_cores_destroyed := 0
var shadowed_time := 0.0

var offset_timer := 3.0
var offset_life := 0.0
var offset_rect := Rect2()
var offset_active := false
var offset_scored := false

var questions: Array = []
var upgrades: Array = []
var knowledge_bindings = {}
var upgrade_counts: Dictionary = {}
var active_question: Dictionary = {}
var last_question_id := ""
var used_question_ids: Dictionary = {}
var question_time_left := 0.0
var question_mode := "answer"
var seen_enemy_kinds: Dictionary = {}
var enemy_info_active := false

var hud_label: Label
var hint_label: Label
var hud_shell: PanelContainer
var hud_screen: PanelContainer
var hud_hint_card: PanelContainer
var hud_metric_labels: Dictionary = {}
var hud_control_label: Label
var question_title_label: Label
var question_panel: PanelContainer
var question_box: VBoxContainer
var pause_button: Button
var pause_panel: PanelContainer
var pause_box: VBoxContainer
var enemy_info_panel: PanelContainer
var enemy_info_box: VBoxContainer
var background_texture: Texture2D
var rover_texture: Texture2D
var light_orb_texture: Texture2D
var offset_band_texture: Texture2D
var energy_panel_texture: Texture2D
var error_block_texture: Texture2D
var sampling_noise_texture: Texture2D
var noise_pulse_texture: Texture2D
var shadow_cloud_texture: Texture2D
var stray_light_texture: Texture2D
var saturation_block_texture: Texture2D
var oscillation_core_texture: Texture2D
var ui_font: Font
var ui_font_regular: Font
var ui_font_medium: Font
var ui_font_semibold: Font
var ui_font_bold: Font
var ui_body_art_font: Font
var ui_body_art_font_regular: Font
var ui_body_art_font_bold: Font
var ui_display_font: Font
var ui_display_font_regular: Font
var ui_display_font_bold: Font
var ui_tech_font: Font
var ui_tech_font_regular: Font
var ui_tech_font_bold: Font
var paused := false

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	background_texture = load("res://assets/v2/backgrounds/light-pcb-background-v2.png")
	rover_texture = load("res://assets/v4_simplified/sprites/player_rover_simplified_v4.png")
	light_orb_texture = load("res://assets/v2/sprites/light_orb_v2.png")
	offset_band_texture = load("res://assets/v2/sprites/offset_band_v2.png")
	energy_panel_texture = load("res://assets/v2/sprites/energy_panel_v2_no_arrow.png")
	error_block_texture = load(_enemy_asset_path("res://assets/v2/sprites/error_block_v2.png", "res://assets/v4/sprites/error_board_realistic_v4.png", "res://assets/v4_simplified/sprites/error_board_simplified_v4.png"))
	sampling_noise_texture = load(_enemy_asset_path("res://assets/v2/sprites/sampling_noise_source_v2.png", "res://assets/v4/sprites/noise_source_realistic_v4.png", "res://assets/v4_simplified/sprites/noise_source_simplified_v4.png"))
	noise_pulse_texture = load("res://assets/v2/sprites/noise_pulse_v2.png")
	shadow_cloud_texture = load("res://assets/v2/sprites/shadow_cloud_v2.png")
	stray_light_texture = load(_enemy_asset_path("res://assets/v2/sprites/stray_light_v2.png", "res://assets/v4/sprites/stray_light_fixture_realistic_v4.png", "res://assets/v4_simplified/sprites/stray_light_fixture_simplified_v4.png"))
	saturation_block_texture = load(_enemy_asset_path("res://assets/v2/sprites/control_saturation_block_v2.png", "res://assets/v4/sprites/pwm_driver_realistic_v4.png", "res://assets/v4_simplified/sprites/pwm_driver_simplified_v4.png"))
	oscillation_core_texture = load(_enemy_asset_path("res://assets/v2/sprites/actuator_oscillation_core_v2.png", "res://assets/v4/sprites/servo_oscillation_realistic_v4.png", "res://assets/v4_simplified/sprites/servo_oscillation_simplified_v4.png"))
	_load_ui_fonts()
	_install_ui_theme()
	upgrade_counts.clear()
	_build_ui()
	_setup_runtime()
	_update_hud()
	queue_redraw()

func _enemy_asset_path(v2_path: String, v4_realistic_path: String, v4_simplified_path: String) -> String:
	if ENEMY_ASSET_PROFILE == "v2":
		return v2_path
	if ENEMY_ASSET_PROFILE == "v4_realistic":
		return v4_realistic_path
	return v4_simplified_path

func _setup_runtime() -> void:
	runtime = DGBRuntime.new()
	runtime.setup({
		"game_id": "ch12-solar-survivor",
		"fallbacks": {
			"questions": "res://data/questions.local.json",
			"upgrades": "res://data/upgrades.local.json"
		},
		"defaults": {
			"duration_sec": 180.0,
			"max_faults": 5,
			"question_time_sec": 15.0
		}
	})
	runtime.initialized.connect(_on_session_initialized)
	runtime.reset_requested.connect(_reset_run)
	runtime.pause_requested.connect(func() -> void: _set_paused(true))
	runtime.resume_requested.connect(func() -> void: _set_paused(false))
	add_child(runtime)

func _on_session_initialized(session: Dictionary) -> void:
	var config: Dictionary = session.get("config", {})
	var knowledge: Dictionary = session.get("knowledge", {})
	duration_sec = float(config.get("duration_sec", duration_sec))
	max_faults = int(config.get("max_faults", max_faults))
	question_time_sec = float(config.get("question_time_sec", question_time_sec))
	questions = knowledge.get("questions", [])
	upgrades = knowledge.get("upgrades", [])
	knowledge_bindings = knowledge.get("bindings", {})
	upgrade_counts.clear()
	_reset_run()
	runtime.log_info("Ch12 solar survivor initialized.")

func _install_ui_theme() -> void:
	if ui_font == null:
		return
	var ui_theme := Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 16
	ui_theme.set_stylebox("panel", "PanelContainer", _panel_style())
	ui_theme.set_stylebox("normal", "Button", _button_style(UI_WHITE, UI_BORDER))
	ui_theme.set_stylebox("hover", "Button", _button_style(UI_BLUE_SOFT, UI_BLUE))
	ui_theme.set_stylebox("pressed", "Button", _button_style(Color(0.82, 0.93, 1.0), UI_BLUE))
	ui_theme.set_stylebox("disabled", "Button", _button_style(Color(0.91, 0.94, 0.96), Color(0.78, 0.86, 0.92)))
	ui_theme.set_color("font_color", "Button", UI_BLUE_DARK)
	ui_theme.set_color("font_hover_color", "Button", UI_BLUE_DARK)
	ui_theme.set_color("font_pressed_color", "Button", UI_BLUE_DARK)
	ui_theme.set_color("font_disabled_color", "Button", Color(0.48, 0.58, 0.66))
	theme = ui_theme

func _load_ui_fonts() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		ui_font = load(UI_FONT_PATH)
		ui_font_regular = _make_font_variation(ui_font, 0.04)
		ui_font_medium = _make_font_variation(ui_font, 0.14)
		ui_font_semibold = _make_font_variation(ui_font, 0.22)
		ui_font_bold = _make_font_variation(ui_font, 0.30)
	else:
		push_warning("Missing UI font: " + UI_FONT_PATH)
	if ResourceLoader.exists(UI_BODY_ART_FONT_PATH):
		ui_body_art_font = load(UI_BODY_ART_FONT_PATH)
		ui_body_art_font_regular = _make_font_variation(ui_body_art_font, 0.06)
		ui_body_art_font_bold = _make_font_variation(ui_body_art_font, 0.16)
	else:
		push_warning("Missing body art font: " + UI_BODY_ART_FONT_PATH)
	if ResourceLoader.exists(UI_DISPLAY_FONT_PATH):
		ui_display_font = load(UI_DISPLAY_FONT_PATH)
		ui_display_font_regular = _make_font_variation(ui_display_font, 0.04)
		ui_display_font_bold = _make_font_variation(ui_display_font, 0.16)
	else:
		push_warning("Missing display font: " + UI_DISPLAY_FONT_PATH)
	if ResourceLoader.exists(UI_TECH_FONT_PATH):
		ui_tech_font = load(UI_TECH_FONT_PATH)
		ui_tech_font_regular = _make_font_variation(ui_tech_font, 0.02)
		ui_tech_font_bold = _make_font_variation(ui_tech_font, 0.12)
	else:
		push_warning("Missing technical font: " + UI_TECH_FONT_PATH)

func _make_font_variation(base_font: Font, embolden: float) -> Font:
	if base_font == null:
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_embolden = embolden
	return variation

func _use_ui_font(control: Control) -> void:
	control.add_theme_font_override("font", ui_font_regular if ui_font_regular != null else ThemeDB.fallback_font)

func _apply_text_role(control: Control, role: String) -> void:
	var role_font: Font = ui_font_regular if ui_font_regular != null else ThemeDB.fallback_font
	var role_size := 15
	var role_color := UI_TEXT
	match role:
		"title":
			role_font = ui_display_font_bold if ui_display_font_bold != null else ui_font_bold
			role_size = 23
		"display":
			role_font = ui_display_font_regular if ui_display_font_regular != null else ui_font_semibold
			role_size = 18
		"tech":
			role_font = ui_tech_font_bold if ui_tech_font_bold != null else ui_font_semibold
			role_size = 16
		"body":
			role_font = ui_font_medium if ui_font_medium != null else ui_font_regular
			role_size = 16
		"muted":
			role_font = ui_font_regular if ui_font_regular != null else ThemeDB.fallback_font
			role_size = 14
			role_color = UI_MUTED
		"success":
			role_font = ui_display_font_bold if ui_display_font_bold != null else ui_font_bold
			role_size = 21
			role_color = UI_SUCCESS
		"warning":
			role_font = ui_font_semibold if ui_font_semibold != null else ui_font_regular
			role_size = 15
			role_color = UI_WARNING
		"fault":
			role_font = ui_display_font_bold if ui_display_font_bold != null else ui_font_bold
			role_size = 21
			role_color = UI_FAULT
	control.add_theme_font_override("font", role_font)
	control.add_theme_font_size_override("font_size", role_size)
	control.add_theme_color_override("font_color", role_color)

func _make_watch_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_SHELL
	style.border_color = Color(0.34, 0.47, 0.50, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.01, 0.04, 0.05, 0.32)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style

func _make_screen_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.97, 0.98, 0.985)
	style.border_color = Color(0.58, 0.78, 0.80, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(17)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	return style

func _make_surface_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.975, 0.997, 1.0, 0.985)
	style.border_color = Color(0.36, 0.68, 0.72, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.10, 0.31, 0.34, 0.13)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style

func _make_metric_tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.97, 0.98, 0.96)
	style.border_color = Color(0.42, 0.72, 0.75, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style

func _make_state_card_style(accent: Color) -> StyleBoxFlat:
	var style := _make_surface_card_style()
	style.border_color = Color(accent.r, accent.g, accent.b, 0.52)
	style.border_width_left = 4
	return style

func _make_watch_modal_style() -> StyleBoxFlat:
	var style := _make_screen_surface_style()
	style.border_color = Color(0.025, 0.055, 0.064, 0.98)
	style.set_border_width_all(9)
	style.set_corner_radius_all(24)
	style.content_margin_left = 30
	style.content_margin_top = 24
	style.content_margin_right = 30
	style.content_margin_bottom = 26
	style.shadow_color = Color(0.01, 0.04, 0.05, 0.40)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style

func _apply_modal_shell(panel: PanelContainer) -> void:
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_watch_modal_style())

func _add_modal_kicker(container: VBoxContainer, text: String, accent: Color = UI_BLUE) -> Label:
	var kicker := Label.new()
	kicker.text = text
	_apply_text_role(kicker, "tech")
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", accent)
	container.add_child(kicker)
	return kicker

func _panel_style() -> StyleBoxFlat:
	var style := _make_surface_card_style()
	style.content_margin_left = 26
	style.content_margin_top = 24
	style.content_margin_right = 26
	style.content_margin_bottom = 24
	return style

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	return style

func _primary_button_style() -> StyleBoxFlat:
	return _button_style(Color(0.05, 0.58, 0.64), Color(0.03, 0.38, 0.43))

func _apply_button_skin(button: Button, primary := false) -> void:
	button.add_theme_font_override("font", ui_display_font_bold if ui_display_font_bold != null else ui_font_semibold)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UI_WHITE if primary else UI_BLUE_DARK)
	button.add_theme_color_override("font_hover_color", UI_WHITE if primary else UI_BLUE_DARK)
	button.add_theme_color_override("font_pressed_color", UI_WHITE if primary else UI_BLUE_DARK)
	button.add_theme_constant_override("h_separation", 8)
	if primary:
		button.add_theme_stylebox_override("normal", _primary_button_style())
		button.add_theme_stylebox_override("hover", _button_style(Color(0.07, 0.68, 0.73), Color(0.03, 0.45, 0.50)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.48, 0.54), Color(0.02, 0.34, 0.39)))

func _apply_choice_button_layout(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _build_ui() -> void:
	_build_watch_hud()

	pause_button = Button.new()
	_apply_button_skin(pause_button)
	pause_button.text = "暂停"
	pause_button.position = Vector2(1180, 18)
	pause_button.custom_minimum_size = Vector2(92, 36)
	pause_button.pressed.connect(_toggle_pause)
	add_child(pause_button)

	question_panel = PanelContainer.new()
	question_panel.visible = false
	question_panel.custom_minimum_size = Vector2(760, 430)
	_apply_modal_shell(question_panel)
	add_child(question_panel)

	question_box = VBoxContainer.new()
	question_box.add_theme_constant_override("separation", 12)
	question_panel.add_child(question_box)

	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.custom_minimum_size = Vector2(460, 280)
	_apply_modal_shell(pause_panel)
	add_child(pause_panel)

	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_box)
	_build_pause_panel()

	enemy_info_panel = PanelContainer.new()
	enemy_info_panel.visible = false
	enemy_info_panel.custom_minimum_size = Vector2(560, 360)
	_apply_modal_shell(enemy_info_panel)
	add_child(enemy_info_panel)

	enemy_info_box = VBoxContainer.new()
	enemy_info_box.add_theme_constant_override("separation", 12)
	enemy_info_panel.add_child(enemy_info_box)

func _build_watch_hud() -> void:
	hud_metric_labels.clear()
	hud_shell = PanelContainer.new()
	hud_shell.name = "WatchHudShell"
	hud_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_shell.position = Vector2(22, 16)
	hud_shell.size = Vector2(356, 342)
	hud_shell.custom_minimum_size = Vector2(356, 342)
	hud_shell.add_theme_stylebox_override("panel", _make_watch_shell_style())
	add_child(hud_shell)

	hud_screen = PanelContainer.new()
	hud_screen.name = "WatchHudScreen"
	hud_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_screen.add_theme_stylebox_override("panel", _make_screen_surface_style())
	hud_shell.add_child(hud_screen)

	var dashboard := VBoxContainer.new()
	dashboard.add_theme_constant_override("separation", 7)
	hud_screen.add_child(dashboard)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	dashboard.add_child(header)

	var status_dot := Label.new()
	status_dot.text = "●"
	_apply_text_role(status_dot, "success")
	status_dot.add_theme_font_size_override("font_size", 13)
	header.add_child(status_dot)

	var header_label := Label.new()
	header_label.text = "追光链路运行"
	_apply_text_role(header_label, "display")
	header_label.add_theme_font_size_override("font_size", 15)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_label)

	hud_label = Label.new()
	hud_label.visible = false
	add_child(hud_label)

	var metric_grid := GridContainer.new()
	metric_grid.columns = 3
	metric_grid.add_theme_constant_override("h_separation", 6)
	metric_grid.add_theme_constant_override("v_separation", 6)
	dashboard.add_child(metric_grid)
	var metric_defs := [
		["time", "时间"],
		["energy", "光能"],
		["faults", "系统故障"],
		["efficiency", "追光效率"],
		["stability", "稳定度"],
		["correction", "校正脉冲"],
		["shadow", "云影"],
		["protection", "保护"],
		["score", "追光分"]
	]
	for metric_def in metric_defs:
		metric_grid.add_child(_create_hud_metric(str(metric_def[0]), str(metric_def[1])))

	hud_hint_card = PanelContainer.new()
	hud_hint_card.add_theme_stylebox_override("panel", _make_state_card_style(UI_BLUE))
	dashboard.add_child(hud_hint_card)
	var hint_box := VBoxContainer.new()
	hint_box.add_theme_constant_override("separation", 2)
	hud_hint_card.add_child(hint_box)
	var hint_kicker := Label.new()
	hint_kicker.text = "系统提示"
	_apply_text_role(hint_kicker, "display")
	hint_kicker.add_theme_font_size_override("font_size", 10)
	hint_kicker.add_theme_color_override("font_color", UI_TEACHING_ACCENT)
	hint_box.add_child(hint_kicker)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.text = "普通光能会自动吸收；金色偏移带需要主动靠近。"
	_apply_text_role(hint_label, "muted")
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.max_lines_visible = 2
	hint_box.add_child(hint_label)
	hud_control_label = Label.new()
	hud_control_label.text = "WASD 控制移动"
	_apply_text_role(hud_control_label, "body")
	hud_control_label.add_theme_font_size_override("font_size", 10)
	hud_control_label.add_theme_color_override("font_color", UI_MUTED)
	hint_box.add_child(hud_control_label)

func _create_hud_metric(metric_id: String, metric_title: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(101, 52)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _make_metric_tile_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	tile.add_child(box)
	var title := Label.new()
	title.text = metric_title
	_apply_text_role(title, "muted")
	title.add_theme_font_size_override("font_size", 10)
	title.clip_text = true
	box.add_child(title)
	var value := Label.new()
	value.text = "--"
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_text_role(value, "body" if metric_id in ["stability", "shadow"] else "tech")
	value.add_theme_font_size_override("font_size", 12 if metric_id in ["correction", "shadow", "protection"] else 14)
	box.add_child(value)
	hud_metric_labels[metric_id] = value
	return tile

func _build_pause_panel() -> void:
	for child in pause_box.get_children():
		pause_box.remove_child(child)
		child.queue_free()

	_add_modal_kicker(pause_box, "SYSTEM HOLD", UI_WARNING)
	var title := Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_text_role(title, "title")
	pause_box.add_child(title)

	var hint := Label.new()
	hint.text = "当前追光状态已冻结，继续后计时和光能流动恢复。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(hint, "muted")
	pause_box.add_child(hint)

	var resume_button := Button.new()
	_apply_button_skin(resume_button, true)
	resume_button.text = "继续"
	resume_button.custom_minimum_size = Vector2(0, 46)
	resume_button.pressed.connect(func() -> void: _set_paused(false))
	pause_box.add_child(resume_button)

	var restart_button := Button.new()
	_apply_button_skin(restart_button)
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(0, 42)
	restart_button.pressed.connect(_reset_run)
	pause_box.add_child(restart_button)

func _show_enemy_info(kind: String, hp: int) -> void:
	if seen_enemy_kinds.has(kind):
		return
	seen_enemy_kinds[kind] = true
	enemy_info_active = true
	_clear_enemy_info_box()
	_layout_system_controls()
	enemy_info_panel.visible = true

	_add_modal_kicker(enemy_info_box, "INTERFERENCE PROFILE", UI_WARNING)
	var title := Label.new()
	title.text = "干扰图鉴：%s" % _enemy_display_name(kind)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_text_role(title, "title")
	enemy_info_box.add_child(title)

	var icon := TextureRect.new()
	icon.texture = _enemy_texture(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(140, 96)
	enemy_info_box.add_child(icon)

	var body := Label.new()
	body.text = _enemy_description(kind, hp)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(body, "body")
	enemy_info_box.add_child(body)

	var button := Button.new()
	_apply_button_skin(button, true)
	button.text = "知道了"
	button.custom_minimum_size = Vector2(0, 46)
	button.pressed.connect(_close_enemy_info)
	enemy_info_box.add_child(button)

func _enemy_display_name(kind: String) -> String:
	if kind == "oscillation":
		return "执行器振荡核心"
	if kind == "saturation":
		return "控制饱和块"
	if kind == "stray":
		return "杂散光干扰"
	if kind == "noise":
		return "采样噪声源"
	if kind == "shadow":
		return "遮挡云影"
	return "错误信号块"

func _enemy_description(kind: String, hp: int) -> String:
	if kind == "oscillation":
		return "闭环控制过度修正时，执行器可能围绕目标位置来回振荡。\n血量：%d。会周期性投射范围振荡区，预警结束后站在区域内会造成系统故障 +1。" % hp
	if kind == "saturation":
		return "控制输出超过执行范围后形成饱和块，追光系统会变得更难纠正。\n血量：%d。需要被校正脉冲命中三次才会清除。\n碰撞后果：系统故障 +1，并大幅扣除稳定度。" % hp
	if kind == "stray":
		return "环境反射或旁路光源进入传感器，可能让追光方向误判。\n血量：%d。需要被校正脉冲命中两次才会清除。\n碰撞后果：系统故障 +1，并扣除更多稳定度。" % hp
	if kind == "noise":
		return "采样链路中的噪声源会远距离发射噪声脉冲，干扰传感器读数。\n血量：%d。校正脉冲命中一次即可清除。\n命中后果：系统故障 +1，并扣除稳定度。" % hp
	if kind == "shadow":
		return "云影遮挡会降低太阳能输入，让追光系统行动变慢。\n血量：%d。需要被校正脉冲命中两次才会清除。\n特殊效果：投射云影区，进入后移动速度降低 28%，常态光能吸收降低 65%。" % hp
	return "控制链路中出现的异常方波信号，会扰乱追光系统。\n血量：%d。校正脉冲命中一次即可清除。\n碰撞后果：系统故障 +1，并扣除稳定度。" % hp

func _enemy_texture(kind: String) -> Texture2D:
	if kind == "oscillation":
		return oscillation_core_texture
	if kind == "saturation":
		return saturation_block_texture
	if kind == "stray":
		return stray_light_texture
	if kind == "noise":
		return sampling_noise_texture
	if kind == "shadow":
		return shadow_cloud_texture
	return error_block_texture

func _enemy_draw_size(kind: String) -> Vector2:
	if kind == "oscillation":
		return Vector2(108, 81)
	if kind == "saturation":
		return Vector2(94, 70)
	if kind == "stray":
		return Vector2(88, 66)
	if kind == "noise":
		return Vector2(84, 63)
	if kind == "shadow":
		return Vector2(92, 69)
	return Vector2(80, 60)

func _enemy_glow_color(kind: String) -> Color:
	if kind == "oscillation":
		return Color(0.12, 0.78, 1.0, 0.18)
	if kind == "saturation":
		return Color(1.0, 0.66, 0.12, 0.16)
	if kind == "stray":
		return Color(1.0, 0.62, 0.10, 0.13)
	if kind == "noise":
		return Color(0.10, 0.72, 1.0, 0.14)
	if kind == "shadow":
		return Color(0.32, 0.56, 0.72, 0.15)
	return Color(1.0, 0.18, 0.14, 0.12)

func _close_enemy_info() -> void:
	enemy_info_active = false
	enemy_info_panel.visible = false

func _toggle_pause() -> void:
	_set_paused(!paused)

func _set_paused(next_paused: bool) -> void:
	if phase == Phase.FINISHED:
		next_paused = false
	paused = next_paused
	pause_panel.visible = paused
	pause_button.text = "继续" if paused else "暂停"
	_layout_system_controls()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			_toggle_pause()

func _reset_run() -> void:
	if runtime != null:
		runtime.begin_attempt()
	var size := _screen_size()
	phase = Phase.PLAYING
	paused = false
	enemy_info_active = false
	time_left = duration_sec
	started_at = Time.get_ticks_msec()
	player_pos = size * 0.5
	move_speed = 210.0
	energy = 0.0
	passive_energy_boost = 0.0
	band_radius_boost = 0.0
	offset_bonus = 0.0
	fault_penalty_reduce = 0.0
	wrong_shield_charges = 0
	fatal_save_charges = 0
	energy_refund_on_correct = 0.0
	last_wrong_absorbed = false
	stability = 100.0
	tracking_efficiency = 70.0
	solar_score = 0
	correct_count = 0
	wrong_count = 0
	faults = 0
	combo = 0
	max_combo = 0
	offset_captures = 0
	error_blocks_destroyed = 0
	noise_sources_destroyed = 0
	stray_lights_destroyed = 0
	shadow_clouds_destroyed = 0
	saturation_blocks_destroyed = 0
	oscillation_cores_destroyed = 0
	shadowed_time = 0.0
	shutdown = false
	ordinary_particles.clear()
	error_blocks.clear()
	noise_projectiles.clear()
	shadow_zones.clear()
	oscillation_zones.clear()
	seen_enemy_kinds.clear()
	upgrade_counts.clear()
	progress_emit_timer = 0.0
	error_spawn_timer = 6.0
	noise_source_spawn_timer = randf_range(12.0, 15.0)
	stray_light_spawn_timer = randf_range(18.0, 28.0)
	shadow_cloud_spawn_timer = randf_range(35.0, 43.0)
	saturation_block_spawn_timer = 60.0
	oscillation_core_spawn_timer = 90.0
	correction_timer = 1.8
	correction_cooldown_reduce = 0.0
	correction_range_boost = 0.0
	correction_target_count = 1
	correction_damage = 1
	correction_beams.clear()
	offset_timer = 3.0
	offset_life = 0.0
	offset_active = false
	offset_scored = false
	last_question_id = ""
	used_question_ids.clear()
	question_panel.visible = false
	pause_panel.visible = false
	enemy_info_panel.visible = false
	pause_button.text = "暂停"
	_update_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_layout_system_controls()
	if paused or enemy_info_active:
		queue_redraw()
		return
	if phase == Phase.PLAYING:
		_update_playing(delta)
	elif phase == Phase.QUESTION and question_mode == "answer":
		question_time_left -= delta
		if question_time_left <= 0.0:
			_handle_wrong(-1)
		else:
			_update_question_timer_label()
	queue_redraw()

func _update_playing(delta: float) -> void:
	time_left = max(0.0, time_left - delta)
	_update_player(delta)
	_update_particles(delta)
	_update_error_blocks(delta)
	_update_noise_projectiles(delta)
	_update_shadow_zones(delta)
	_update_oscillation_zones(delta)
	_update_correction_pulse(delta)
	_update_offset_band(delta)
	energy = min(ENERGY_MAX, energy + (0.72 + passive_energy_boost) * _shadow_energy_multiplier() * delta)
	tracking_efficiency = clampf(tracking_efficiency - 0.8 * delta, 0.0, 100.0)
	if energy >= ENERGY_MAX:
		_begin_question()
	if time_left <= 0.0:
		_finish_run(false)
	_update_hud()
	progress_emit_timer -= delta
	if runtime and progress_emit_timer <= 0.0:
		progress_emit_timer = 0.5
		runtime.report_progress(1.0 - time_left / max(1.0, duration_sec), "追光分 %d" % solar_score, _stats(false))

func _update_player(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if input.length() > 0.0:
		player_pos += input.normalized() * move_speed * _shadow_move_multiplier() * delta
	var size := _screen_size()
	player_pos.x = clampf(player_pos.x, 70.0, size.x - 70.0)
	player_pos.y = clampf(player_pos.y, 90.0, size.y - 70.0)

func _update_particles(delta: float) -> void:
	particle_timer -= delta
	if particle_timer <= 0.0 and ordinary_particles.size() < ORDINARY_PARTICLE_LIMIT:
		particle_timer = 0.34
		_spawn_particle()

	for i in range(ordinary_particles.size() - 1, -1, -1):
		var p: Dictionary = ordinary_particles[i]
		var pos: Vector2 = p["pos"]
		var burst_vel: Vector2 = p.get("burstVel", Vector2.ZERO)
		var life := float(p.get("life", 0.0))
		if life > 0.0:
			pos += burst_vel * delta
			burst_vel = burst_vel.move_toward(Vector2.ZERO, 340.0 * delta)
			life = max(0.0, life - delta)
			p["burstVel"] = burst_vel
			p["life"] = life
		var to_player := player_pos - pos
		var speed: float = 210.0 + min(240.0, to_player.length() * 0.8)
		if str(p.get("kind", "ordinary")) == "enemyReward":
			speed = 260.0 + min(340.0, to_player.length() * 1.0)
		if to_player.length() > 1.0:
			pos += to_player.normalized() * speed * delta
		p["pos"] = pos
		ordinary_particles[i] = p
		if pos.distance_to(player_pos) < 22.0:
			energy = min(ENERGY_MAX, energy + float(p.get("value", 1.05)))
			solar_score += int(p.get("rewardScore", 0))
			ordinary_particles.remove_at(i)

func _spawn_particle() -> void:
	var size := _screen_size()
	ordinary_particles.append({
		"pos": Vector2(randf_range(60.0, size.x - 60.0), randf_range(90.0, size.y - 60.0)),
		"value": 1.05,
		"kind": "ordinary",
		"scale": 1.0,
		"rewardScore": 0
	})

func _spawn_enemy_reward_orbs(origin: Vector2, total_energy: float, total_score: int, count: int) -> void:
	var safe_count: int = max(1, count)
	var energy_each: float = total_energy / float(safe_count)
	var score_left: int = total_score
	for i in range(safe_count):
		var angle: float = randf_range(0.0, TAU)
		var burst: Vector2 = Vector2(cos(angle), sin(angle)) * randf_range(80.0, 160.0)
		var score_each: int = int(round(float(total_score) / float(safe_count)))
		if i == safe_count - 1:
			score_each = score_left
		score_left -= score_each
		ordinary_particles.append({
			"pos": origin + Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0)),
			"value": energy_each,
			"kind": "enemyReward",
			"scale": 1.35,
			"rewardScore": score_each,
			"burstVel": burst,
			"life": 0.22
		})

func _update_error_blocks(delta: float) -> void:
	error_spawn_timer -= delta
	if error_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("error")
		error_spawn_timer = randf_range(4.8, 7.2)
	noise_source_spawn_timer -= delta
	if noise_source_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("noise")
		noise_source_spawn_timer = randf_range(14.0, 18.0)
	stray_light_spawn_timer -= delta
	if stray_light_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("stray")
		stray_light_spawn_timer = randf_range(9.0, 13.0)
	shadow_cloud_spawn_timer -= delta
	if shadow_cloud_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("shadow")
		shadow_cloud_spawn_timer = randf_range(18.0, 24.0)
	saturation_block_spawn_timer -= delta
	if saturation_block_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("saturation")
		saturation_block_spawn_timer = randf_range(24.0, 32.0)
	oscillation_core_spawn_timer -= delta
	if oscillation_core_spawn_timer <= 0.0 and error_blocks.size() < ERROR_BLOCK_LIMIT:
		_spawn_enemy("oscillation")
		oscillation_core_spawn_timer = randf_range(34.0, 46.0)

	for i in range(error_blocks.size() - 1, -1, -1):
		var enemy: Dictionary = error_blocks[i]
		var kind := str(enemy.get("kind", "error"))
		var pos: Vector2 = enemy["pos"]
		var drift: Vector2 = enemy["drift"]
		var to_player := player_pos - pos
		if kind == "noise":
			var fire_timer := float(enemy.get("fireTimer", 1.0)) - delta
			if fire_timer <= 0.0 and noise_projectiles.size() < NOISE_PROJECTILE_LIMIT:
				_spawn_noise_projectile(pos)
				fire_timer = randf_range(2.4, 3.2)
			enemy["fireTimer"] = fire_timer
			if to_player.length() > 1.0:
				pos += to_player.normalized() * float(enemy.get("speed", 38.0)) * delta
			pos += drift * delta
		elif kind == "shadow":
			var cast_timer := float(enemy.get("castTimer", 2.0)) - delta
			if cast_timer <= 0.0 and shadow_zones.size() < SHADOW_ZONE_LIMIT:
				_spawn_shadow_zone()
				cast_timer = randf_range(4.8, 6.4)
			enemy["castTimer"] = cast_timer
			if to_player.length() > 1.0:
				pos += to_player.normalized() * float(enemy.get("speed", 36.0)) * delta
			pos += drift * 0.7 * delta
		elif kind == "oscillation":
			var oscillation_timer := float(enemy.get("oscillationTimer", 2.2)) - delta
			if oscillation_timer <= 0.0 and oscillation_zones.size() < OSCILLATION_ZONE_LIMIT:
				_spawn_oscillation_zone()
				oscillation_timer = randf_range(4.6, 6.0)
			enemy["oscillationTimer"] = oscillation_timer
			if to_player.length() > 1.0:
				pos += to_player.normalized() * float(enemy.get("speed", 34.0)) * delta
			pos += drift * 0.55 * delta
		elif to_player.length() > 1.0:
			pos += to_player.normalized() * float(enemy.get("speed", 54.0)) * delta
			pos += drift * delta
		enemy["pos"] = pos
		error_blocks[i] = enemy
		if pos.distance_to(player_pos) < 42.0:
			error_blocks.remove_at(i)
			_on_enemy_hit(kind)

func _spawn_enemy(kind: String) -> void:
	var size := _screen_size()
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0:
			pos = Vector2(randf_range(80.0, size.x - 80.0), -40.0)
		1:
			pos = Vector2(randf_range(80.0, size.x - 80.0), size.y + 40.0)
		2:
			pos = Vector2(-50.0, randf_range(110.0, size.y - 70.0))
		_:
			pos = Vector2(size.x + 50.0, randf_range(110.0, size.y - 70.0))
	var hp := 3 if kind == "saturation" or kind == "oscillation" else 2 if kind == "stray" or kind == "shadow" else 1
	var speed := randf_range(44.0, 62.0)
	if kind == "stray":
		speed = randf_range(38.0, 54.0)
	elif kind == "noise":
		speed = randf_range(30.0, 44.0)
	elif kind == "shadow":
		speed = randf_range(28.0, 40.0)
	elif kind == "saturation":
		speed = randf_range(32.0, 44.0)
	elif kind == "oscillation":
		speed = randf_range(28.0, 38.0)
	_show_enemy_info(kind, hp)
	error_blocks.append({
		"kind": kind,
		"hp": hp,
		"maxHp": hp,
		"pos": pos,
		"speed": speed,
		"fireTimer": randf_range(0.8, 1.6),
		"castTimer": randf_range(1.8, 2.8),
		"oscillationTimer": randf_range(1.2, 2.0),
		"drift": Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
	})

func _spawn_noise_projectile(source_pos: Vector2) -> void:
	var direction := player_pos - source_pos
	if direction.length() <= 1.0:
		direction = Vector2.RIGHT
	noise_projectiles.append({
		"pos": source_pos,
		"vel": direction.normalized() * 125.0,
		"life": 5.6
	})

func _update_noise_projectiles(delta: float) -> void:
	for i in range(noise_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = noise_projectiles[i]
		var pos: Vector2 = projectile["pos"]
		var vel: Vector2 = projectile["vel"]
		pos += vel * delta
		projectile["pos"] = pos
		projectile["life"] = float(projectile.get("life", 0.0)) - delta
		var screen_rect := Rect2(Vector2.ZERO, _screen_size()).grow(90.0)
		if float(projectile["life"]) <= 0.0 or !screen_rect.has_point(pos):
			noise_projectiles.remove_at(i)
			continue
		if pos.distance_to(player_pos) < 30.0:
			noise_projectiles.remove_at(i)
			_on_noise_projectile_hit()
			continue
		noise_projectiles[i] = projectile

func _spawn_shadow_zone() -> void:
	var size := _screen_size()
	var offset := Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0))
	var pos := player_pos + offset
	pos.x = clampf(pos.x, 120.0, size.x - 120.0)
	pos.y = clampf(pos.y, 125.0, size.y - 95.0)
	shadow_zones.append({
		"pos": pos,
		"radius": randf_range(92.0, 118.0),
		"warn": 0.8,
		"warnMax": 0.8,
		"life": 4.4,
		"lifeMax": 4.4
	})

func _update_shadow_zones(delta: float) -> void:
	var shadowing := false
	for i in range(shadow_zones.size() - 1, -1, -1):
		var zone: Dictionary = shadow_zones[i]
		zone["life"] = float(zone.get("life", 0.0)) - delta
		zone["warn"] = max(0.0, float(zone.get("warn", 0.0)) - delta)
		if float(zone["life"]) <= 0.0:
			shadow_zones.remove_at(i)
			continue
		if _is_shadow_zone_active(zone) and Vector2(zone["pos"]).distance_to(player_pos) <= float(zone.get("radius", 100.0)):
			shadowing = true
		shadow_zones[i] = zone
	if shadowing:
		shadowed_time += delta

func _is_shadow_zone_active(zone: Dictionary) -> bool:
	return float(zone.get("warn", 0.0)) <= 0.0

func _is_player_shadowed() -> bool:
	for zone in shadow_zones:
		if _is_shadow_zone_active(zone) and Vector2(zone["pos"]).distance_to(player_pos) <= float(zone.get("radius", 100.0)):
			return true
	return false

func _shadow_move_multiplier() -> float:
	return 0.72 if _is_player_shadowed() else 1.0

func _shadow_energy_multiplier() -> float:
	return 0.35 if _is_player_shadowed() else 1.0

func _spawn_oscillation_zone() -> void:
	var size := _screen_size()
	var offset := Vector2(randf_range(-90.0, 90.0), randf_range(-70.0, 70.0))
	var pos := player_pos + offset
	pos.x = clampf(pos.x, 120.0, size.x - 120.0)
	pos.y = clampf(pos.y, 125.0, size.y - 95.0)
	oscillation_zones.append({
		"pos": pos,
		"radius": randf_range(78.0, 96.0),
		"warn": 0.85,
		"warnMax": 0.85,
		"life": 1.55,
		"lifeMax": 1.55,
		"hit": false
	})

func _update_oscillation_zones(delta: float) -> void:
	for i in range(oscillation_zones.size() - 1, -1, -1):
		var zone: Dictionary = oscillation_zones[i]
		zone["life"] = float(zone.get("life", 0.0)) - delta
		zone["warn"] = max(0.0, float(zone.get("warn", 0.0)) - delta)
		if float(zone["life"]) <= 0.0:
			oscillation_zones.remove_at(i)
			continue
		if _is_oscillation_zone_active(zone) and !bool(zone.get("hit", false)):
			if Vector2(zone["pos"]).distance_to(player_pos) <= float(zone.get("radius", 88.0)):
				zone["hit"] = true
				_on_oscillation_zone_hit()
		oscillation_zones[i] = zone

func _is_oscillation_zone_active(zone: Dictionary) -> bool:
	return float(zone.get("warn", 0.0)) <= 0.0

func _update_correction_pulse(delta: float) -> void:
	correction_timer -= delta
	for i in range(correction_beams.size() - 1, -1, -1):
		var beam: Dictionary = correction_beams[i]
		beam["life"] = float(beam.get("life", 0.0)) - delta
		if float(beam["life"]) <= 0.0:
			correction_beams.remove_at(i)
		else:
			correction_beams[i] = beam
	if correction_timer > 0.0 or error_blocks.is_empty():
		return
	var effective_range := _effective_correction_range()
	correction_timer = _effective_correction_cooldown()
	var target_indices := _pick_correction_targets(effective_range, correction_target_count)
	target_indices.sort()
	target_indices.reverse()
	for target_index in target_indices:
		_apply_correction_hit(int(target_index))

func _pick_correction_targets(effective_range: float, target_count: int) -> Array:
	var selected: Array = []
	for _shot in range(target_count):
		var nearest_index := -1
		var nearest_distance := effective_range
		for i in range(error_blocks.size()):
			if selected.has(i):
				continue
			var enemy: Dictionary = error_blocks[i]
			var pos: Vector2 = enemy["pos"]
			var distance := pos.distance_to(player_pos)
			if distance <= nearest_distance:
				nearest_distance = distance
				nearest_index = i
		if nearest_index >= 0:
			selected.append(nearest_index)
	return selected

func _apply_correction_hit(target_index: int) -> void:
	if target_index < 0 or target_index >= error_blocks.size():
		return
	var target: Dictionary = error_blocks[target_index]
	var target_pos: Vector2 = target["pos"]
	correction_beams.append({
		"from": player_pos,
		"to": target_pos,
		"life": 0.16
	})
	target["hp"] = int(target.get("hp", 1)) - correction_damage
	if int(target["hp"]) <= 0:
		error_blocks.remove_at(target_index)
		var target_kind := str(target.get("kind", "error"))
		if target_kind == "stray":
			stray_lights_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 10.0, 320, 5)
			stability = clampf(stability + 3.0, 0.0, 100.0)
		elif target_kind == "noise":
			noise_sources_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 8.0, 240, 4)
			stability = clampf(stability + 1.5, 0.0, 100.0)
		elif target_kind == "shadow":
			shadow_clouds_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 11.0, 360, 6)
			stability = clampf(stability + 2.5, 0.0, 100.0)
		elif target_kind == "saturation":
			saturation_blocks_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 15.0, 520, 8)
			stability = clampf(stability + 4.0, 0.0, 100.0)
		elif target_kind == "oscillation":
			oscillation_cores_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 18.0, 680, 10)
			stability = clampf(stability + 4.5, 0.0, 100.0)
		else:
			error_blocks_destroyed += 1
			_spawn_enemy_reward_orbs(target_pos, 6.0, 180, 3)
		tracking_efficiency = clampf(tracking_efficiency + 1.8, 0.0, 100.0)
	else:
		error_blocks[target_index] = target

func _on_enemy_hit(kind: String) -> void:
	combo = 0
	var penalty := 24.0
	var score_penalty := 500
	if kind == "stray":
		penalty = 31.0
		score_penalty = 800
	elif kind == "noise":
		penalty = 27.0
		score_penalty = 650
	elif kind == "shadow":
		penalty = 28.0
		score_penalty = 700
	elif kind == "saturation":
		penalty = 34.0
		score_penalty = 900
	elif kind == "oscillation":
		penalty = 36.0
		score_penalty = 980
	var continued := _apply_system_fault(penalty, score_penalty, true)
	if last_wrong_absorbed:
		hint_label.text = "保护触发：干扰故障已抵消。"
	elif kind == "stray":
		hint_label.text = "杂散光干扰传感器：系统故障 +1。"
	elif kind == "noise":
		hint_label.text = "采样噪声源撞入追光系统：系统故障 +1。"
	elif kind == "shadow":
		hint_label.text = "遮挡云影压入追光系统：系统故障 +1。"
	else:
		hint_label.text = "错误信号撞入追光系统：系统故障 +1。"
	if kind == "saturation" and not last_wrong_absorbed:
		hint_label.text = "控制饱和块撞入追光系统：系统故障 +1。"
	if continued:
		_update_hud()

func _on_noise_projectile_hit() -> void:
	combo = 0
	var continued := _apply_system_fault(25.0, 620, true)
	hint_label.text = "保护触发：噪声脉冲故障已抵消。" if last_wrong_absorbed else "噪声脉冲命中传感器：系统故障 +1。"
	if continued:
		_update_hud()

func _on_oscillation_zone_hit() -> void:
	combo = 0
	var continued := _apply_system_fault(32.0, 860, true)
	hint_label.text = "保护触发：振荡冲击故障已抵消。" if last_wrong_absorbed else "执行器振荡区命中：系统故障 +1。"
	if continued:
		_update_hud()

func _stability_tier() -> String:
	if stability >= 70.0:
		return "稳定"
	if stability >= 40.0:
		return "波动"
	return "危险"

func _effective_correction_cooldown() -> float:
	var base_cooldown: float = max(0.85, correction_cooldown - correction_cooldown_reduce)
	if stability >= 70.0:
		return base_cooldown
	if stability >= 40.0:
		return base_cooldown * 1.25
	return base_cooldown * 1.65

func _effective_correction_range() -> float:
	var base_range: float = correction_range + correction_range_boost
	if stability >= 70.0:
		return base_range
	if stability >= 40.0:
		return base_range * 0.82
	return base_range * 0.62

func _update_offset_band(delta: float) -> void:
	if offset_active:
		offset_life -= delta
		var capture_rect := offset_rect.grow(32.0 + band_radius_boost)
		if capture_rect.has_point(player_pos):
			if !offset_scored:
				solar_score += 300
				offset_captures += 1
				offset_scored = true
			energy = min(ENERGY_MAX, energy + (12.0 + offset_bonus * 4.0) * delta)
			tracking_efficiency = clampf(tracking_efficiency + 12.0 * delta, 0.0, 100.0)
			stability = clampf(stability + 2.5 * delta, 0.0, 100.0)
		if offset_life <= 0.0:
			offset_active = false
			offset_timer = randf_range(12.0, 18.0)
	else:
		offset_timer -= delta
		if offset_timer <= 0.0:
			_spawn_offset_band()

func _spawn_offset_band() -> void:
	var size := _screen_size()
	var band_size := Vector2(270, 120)
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0:
			pos = Vector2(randf_range(100, size.x - band_size.x - 100), 90)
		1:
			pos = Vector2(randf_range(100, size.x - band_size.x - 100), size.y - band_size.y - 70)
		2:
			pos = Vector2(70, randf_range(120, size.y - band_size.y - 90))
		_:
			pos = Vector2(size.x - band_size.x - 70, randf_range(120, size.y - band_size.y - 90))
	offset_rect = Rect2(pos, band_size)
	offset_life = 13.0
	offset_active = true
	offset_scored = false
	hint_label.text = "太阳方向偏移：靠近金色偏移带可获得更高追光分。"

func _begin_question() -> void:
	if questions.is_empty():
		return
	phase = Phase.QUESTION
	question_mode = "answer"
	question_time_left = question_time_sec
	active_question = _pick_next_question()
	_show_question()

func _question_key(question: Dictionary) -> String:
	var qid := str(question.get("id", ""))
	if qid.is_empty():
		qid = str(question.get("prompt", ""))
	return qid

func _pick_next_question() -> Dictionary:
	if questions.is_empty():
		return {}
	if questions.size() == 1:
		var only_question: Dictionary = questions[0]
		last_question_id = _question_key(only_question)
		used_question_ids[last_question_id] = true
		return only_question

	var candidates: Array = []
	for question in questions:
		var q: Dictionary = question
		var qid := _question_key(q)
		if qid != last_question_id and !used_question_ids.has(qid):
			candidates.append(q)
	if candidates.is_empty():
		used_question_ids.clear()
		for question in questions:
			var q: Dictionary = question
			if _question_key(q) != last_question_id:
				candidates.append(q)
	if candidates.is_empty():
		candidates = questions.duplicate()
	var picked: Dictionary = candidates[randi() % candidates.size()]
	last_question_id = _question_key(picked)
	used_question_ids[last_question_id] = true
	return picked

func _show_question() -> void:
	_clear_question_box()
	_layout_question_panel()
	question_panel.visible = true

	_add_modal_kicker(question_box, "UPGRADE CHECK", UI_BLUE)
	var title := Label.new()
	question_title_label = title
	_update_question_timer_label()
	_apply_text_role(title, "display")
	title.add_theme_font_size_override("font_size", 16)
	question_box.add_child(title)

	var prompt := Label.new()
	prompt.text = str(active_question.get("prompt", ""))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(prompt, "title")
	prompt.add_theme_font_size_override("font_size", 21)
	question_box.add_child(prompt)

	var choices: Array = active_question.get("choices", [])
	var letters := ["A", "B", "C", "D", "E", "F"]
	for i in range(choices.size()):
		var button := Button.new()
		_apply_button_skin(button)
		_apply_choice_button_layout(button)
		button.text = "%s. %s" % [letters[i], str(choices[i])]
		button.custom_minimum_size = Vector2(0, 46)
		button.pressed.connect(_on_answer_pressed.bind(i))
		question_box.add_child(button)

func _update_question_timer_label() -> void:
	if question_title_label == null or !is_instance_valid(question_title_label):
		return
	question_title_label.text = "升级校验  倒计时 %d 秒" % max(0, int(ceil(question_time_left)))

func _on_answer_pressed(index: int) -> void:
	if phase != Phase.QUESTION or question_mode != "answer":
		return
	var answer_index := int(active_question.get("answerIndex", -1))
	if index == answer_index:
		_handle_correct()
	else:
		_handle_wrong(index)

func _handle_correct() -> void:
	correct_count += 1
	combo += 1
	max_combo = max(max_combo, combo)
	var combo_bonus: int = min(500, combo * 100)
	solar_score += 500 + combo_bonus
	energy = min(ENERGY_MAX, energy_refund_on_correct)
	question_mode = "upgrade"
	_show_upgrade_choices()

func _handle_wrong(_index: int) -> void:
	wrong_count += 1
	combo = 0
	energy = 0.0
	if !_apply_system_fault(34.0, 1200, true):
		return
	_show_wrong_feedback()

func _apply_system_fault(base_penalty: float, score_penalty: int, allow_shield: bool) -> bool:
	last_wrong_absorbed = false
	var penalty: float = max(8.0, base_penalty - fault_penalty_reduce)
	if stability < 40.0:
		penalty *= 1.18
	elif stability < 70.0:
		penalty *= 1.08
	if allow_shield and wrong_shield_charges > 0:
		wrong_shield_charges -= 1
		last_wrong_absorbed = true
		penalty = max(5.0, penalty * 0.35)
	else:
		faults += 1
	stability = clampf(stability - penalty, 0.0, 100.0)
	solar_score = max(0, solar_score - score_penalty)
	if faults >= max_faults:
		if fatal_save_charges > 0:
			fatal_save_charges -= 1
			faults = max_faults - 1
			stability = max(stability, 22.0)
			last_wrong_absorbed = true
			return true
		_finish_run(true)
		return false
	return true

func _show_upgrade_choices() -> void:
	_clear_question_box()
	_layout_question_panel()

	_add_modal_kicker(question_box, "CONTROL MODULE", UI_SUCCESS)
	var title := Label.new()
	title.text = "答对了：选择一项升级"
	_apply_text_role(title, "success")
	question_box.add_child(title)

	var explanation := Label.new()
	explanation.text = str(active_question.get("explanation", ""))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(explanation, "muted")
	question_box.add_child(explanation)

	var options := _available_upgrades()
	options.shuffle()
	if options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前升级模块都已达到上限，本次转化为追光分 +600。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_text_role(empty_label, "body")
		question_box.add_child(empty_label)
		solar_score += 600
		var continue_button := Button.new()
		_apply_button_skin(continue_button, true)
		continue_button.text = "继续追光"
		continue_button.custom_minimum_size = Vector2(0, 48)
		continue_button.pressed.connect(_resume_play)
		question_box.add_child(continue_button)
		return
	for i in range(min(3, options.size())):
		var upgrade: Dictionary = options[i]
		var button := Button.new()
		_apply_button_skin(button)
		_apply_choice_button_layout(button)
		var max_stacks := int(upgrade.get("maxStacks", 0))
		var stack_text := ""
		if max_stacks > 0:
			stack_text = "  (%d/%d)" % [_upgrade_stack_count(upgrade), max_stacks]
		button.text = "%s  %s%s\n%s" % [
			str(upgrade.get("shortLabel", "")),
			str(upgrade.get("title", "")),
			stack_text,
			str(upgrade.get("description", ""))
		]
		button.custom_minimum_size = Vector2(0, 64)
		button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
		question_box.add_child(button)

func _available_upgrades() -> Array:
	var available: Array = []
	for item in upgrades:
		var upgrade: Dictionary = item
		if _is_upgrade_available(upgrade):
			available.append(upgrade)
	return available

func _is_upgrade_available(upgrade: Dictionary) -> bool:
	var max_stacks := int(upgrade.get("maxStacks", 0))
	if max_stacks > 0 and _upgrade_stack_count(upgrade) >= max_stacks:
		return false
	var required_enemy_kind := str(upgrade.get("requiresSeenEnemyKind", ""))
	if !required_enemy_kind.is_empty() and !seen_enemy_kinds.has(required_enemy_kind):
		return false
	var effects: Dictionary = upgrade.get("effects", {})
	if effects.has("energyRefundOnCorrect") and energy_refund_on_correct >= ENERGY_REFUND_ON_CORRECT_MAX:
		return false
	if effects.has("correctionCooldownReduce") and correction_cooldown_reduce >= CORRECTION_COOLDOWN_REDUCE_MAX:
		return false
	if effects.has("correctionRangeBoost") and correction_range_boost >= CORRECTION_RANGE_BOOST_MAX:
		return false
	if effects.has("correctionTargets") and correction_target_count >= CORRECTION_TARGET_COUNT_MAX:
		return false
	if effects.has("correctionDamageBoost") and correction_damage >= CORRECTION_DAMAGE_MAX:
		return false
	return true

func _upgrade_stack_count(upgrade: Dictionary) -> int:
	var id := str(upgrade.get("id", ""))
	return int(upgrade_counts.get(id, 0))

func _show_wrong_feedback() -> void:
	_clear_question_box()
	_layout_question_panel()
	question_mode = "feedback"

	_add_modal_kicker(question_box, "SYSTEM FEEDBACK", UI_SUCCESS if last_wrong_absorbed else UI_FAULT)
	var title := Label.new()
	title.text = "保护触发：故障已抵消" if last_wrong_absorbed else "系统故障 +1"
	_apply_text_role(title, "success" if last_wrong_absorbed else "fault")
	question_box.add_child(title)

	var explanation := Label.new()
	explanation.text = str(active_question.get("explanation", "请复习本题对应知识点。"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(explanation, "body")
	question_box.add_child(explanation)

	var status := Label.new()
	status.text = "系统故障：%d / %d    稳定度：%d%%（%s）    校正脉冲：%.1fs / %dpx x%d    保护：DZ %d / LIM %d" % [
		faults,
		max_faults,
		int(round(stability)),
		_stability_tier(),
		_effective_correction_cooldown(),
		int(round(_effective_correction_range())),
		correction_target_count,
		wrong_shield_charges,
		fatal_save_charges
	]
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_text_role(status, "body")
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", UI_MUTED)
	question_box.add_child(status)

	var button := Button.new()
	_apply_button_skin(button, true)
	button.text = "继续追光"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_resume_play)
	question_box.add_child(button)

func _on_upgrade_pressed(upgrade: Dictionary) -> void:
	var effects: Dictionary = upgrade.get("effects", {})
	var id := str(upgrade.get("id", ""))
	if id != "":
		upgrade_counts[id] = int(upgrade_counts.get(id, 0)) + 1
	move_speed += float(effects.get("moveSpeedBoost", 0.0))
	passive_energy_boost += float(effects.get("passiveEnergyBoost", 0.0))
	band_radius_boost += float(effects.get("bandRadiusBoost", 0.0))
	offset_bonus += float(effects.get("offsetBonus", 0.0))
	fault_penalty_reduce += float(effects.get("faultPenaltyReduce", 0.0))
	wrong_shield_charges += int(effects.get("wrongShieldCharges", 0))
	fatal_save_charges += int(effects.get("fatalSaveCharges", 0))
	energy_refund_on_correct = min(ENERGY_REFUND_ON_CORRECT_MAX, energy_refund_on_correct + float(effects.get("energyRefundOnCorrect", 0.0)))
	correction_cooldown_reduce = min(CORRECTION_COOLDOWN_REDUCE_MAX, correction_cooldown_reduce + float(effects.get("correctionCooldownReduce", 0.0)))
	correction_range_boost = min(CORRECTION_RANGE_BOOST_MAX, correction_range_boost + float(effects.get("correctionRangeBoost", 0.0)))
	correction_target_count = min(CORRECTION_TARGET_COUNT_MAX, correction_target_count + int(effects.get("correctionTargets", 0)))
	correction_damage = min(CORRECTION_DAMAGE_MAX, correction_damage + int(effects.get("correctionDamageBoost", 0)))
	tracking_efficiency = clampf(tracking_efficiency + float(effects.get("trackingBoost", 0.0)), 0.0, 100.0)
	stability = clampf(stability + float(effects.get("stabilityBoost", 0.0)), 0.0, 100.0)
	_resume_play()

func _resume_play() -> void:
	question_panel.visible = false
	phase = Phase.PLAYING
	question_mode = "answer"
	_update_hud()

func _finish_run(by_shutdown: bool) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	shutdown = by_shutdown
	question_panel.visible = false
	var completion_bonus := 0
	if !shutdown:
		completion_bonus = 2000
	solar_score += completion_bonus
	solar_score += int(round(tracking_efficiency * 20.0))
	solar_score += int(round(stability * 15.0))
	if shutdown:
		solar_score = min(solar_score, 2500)
	var host_score := clampi(int(round(float(solar_score) / 100.0)), 0, 100)
	if runtime:
		runtime.complete(host_score, -1, Time.get_ticks_msec() - started_at, _stats(shutdown))
	_show_result()

func _show_result() -> void:
	_clear_question_box()
	_layout_question_panel()
	question_panel.visible = true

	_add_modal_kicker(question_box, "RUN SUMMARY", UI_FAULT if shutdown else UI_SUCCESS)
	var title := Label.new()
	title.text = "追光系统停机" if shutdown else "追光挑战完成"
	_apply_text_role(title, "fault" if shutdown else "success")
	title.add_theme_font_size_override("font_size", 25)
	question_box.add_child(title)

	var body := Label.new()
	body.text = "追光分：%d\n称号：%s\n追光效率：%d%%\n稳定度：%d%%\n答题：%d 对 / %d 错\n系统故障：%d / %d\n消灭错误信号：%d\n清除采样噪声：%d\n清除杂散光：%d\n驱散遮挡云影：%d\n云影遮挡时间：%.1fs\n剩余保护：DZ %d / LIM %d" % [
		solar_score,
		_score_title(),
		int(round(tracking_efficiency)),
		int(round(stability)),
		correct_count,
		wrong_count,
		faults,
		max_faults,
		error_blocks_destroyed,
		noise_sources_destroyed,
		stray_lights_destroyed,
		shadow_clouds_destroyed,
		shadowed_time,
		wrong_shield_charges,
		fatal_save_charges
	]
	body.text += "\n清除控制饱和块：%d" % saturation_blocks_destroyed
	body.text += "\n清除执行器振荡核心：%d" % oscillation_cores_destroyed
	_apply_text_role(body, "body")
	body.add_theme_font_size_override("font_size", 16)
	question_box.add_child(body)

	var button := Button.new()
	_apply_button_skin(button, true)
	button.text = "重新开始"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(_reset_run)
	question_box.add_child(button)

func _score_title() -> String:
	if shutdown:
		return "追光系统停机"
	if solar_score >= 8500:
		return "稳态追光专家"
	if solar_score >= 7000:
		return "高效追光手"
	if solar_score >= 5000:
		return "系统调参员"
	return "待复习上机"

func _stats(include_shutdown: bool) -> Dictionary:
	return {
		"solarScore": solar_score,
		"correct": correct_count,
		"wrong": wrong_count,
		"maxCombo": max_combo,
		"trackingEfficiency": int(round(tracking_efficiency)),
		"stability": int(round(stability)),
		"stabilityTier": _stability_tier(),
		"correctionCooldown": _effective_correction_cooldown(),
		"correctionRange": int(round(_effective_correction_range())),
		"correctionTargets": correction_target_count,
		"correctionDamage": correction_damage,
		"faults": faults,
		"offsetCaptures": offset_captures,
		"errorBlocksDestroyed": error_blocks_destroyed,
		"noiseSourcesDestroyed": noise_sources_destroyed,
		"strayLightsDestroyed": stray_lights_destroyed,
		"shadowCloudsDestroyed": shadow_clouds_destroyed,
		"saturationBlocksDestroyed": saturation_blocks_destroyed,
		"oscillationCoresDestroyed": oscillation_cores_destroyed,
		"shadowedTime": snappedf(shadowed_time, 0.1),
		"wrongShieldCharges": wrong_shield_charges,
		"fatalSaveCharges": fatal_save_charges,
		"energyRefundOnCorrect": int(round(energy_refund_on_correct)),
		"shutdown": 1 if include_shutdown else 0
	}

func _update_hud() -> void:
	var minutes := int(int(time_left) / 60)
	var seconds := int(time_left) % 60
	var shadow_status := "云影中：移速 -28% / 充能 -65%" if _is_player_shadowed() else "云影：无"
	if !hud_metric_labels.is_empty():
		(hud_metric_labels.get("time") as Label).text = "%02d:%02d" % [minutes, seconds]
		(hud_metric_labels.get("energy") as Label).text = "%d%%" % int(round(energy))
		(hud_metric_labels.get("faults") as Label).text = "%d / %d" % [faults, max_faults]
		(hud_metric_labels.get("efficiency") as Label).text = "%d%%" % int(round(tracking_efficiency))
		(hud_metric_labels.get("stability") as Label).text = "%d%% · %s" % [int(round(stability)), _stability_tier()]
		(hud_metric_labels.get("correction") as Label).text = "%.1fs · %dpx ×%d" % [_effective_correction_cooldown(), int(round(_effective_correction_range())), correction_target_count]
		(hud_metric_labels.get("shadow") as Label).text = shadow_status
		(hud_metric_labels.get("protection") as Label).text = "DZ %d / LIM %d" % [wrong_shield_charges, fatal_save_charges]
		(hud_metric_labels.get("score") as Label).text = "%d" % solar_score
	hud_label.text = "时间 %02d:%02d\n光能 %d%%\n系统故障 %d / %d\n追光效率 %d%%\n稳定度 %d%%（%s）\n校正脉冲 %.1fs / %dpx x%d\n%s\n保护 DZ %d / LIM %d\n追光分 %d" % [
		minutes,
		seconds,
		int(round(energy)),
		faults,
		max_faults,
		int(round(tracking_efficiency)),
		int(round(stability)),
		_stability_tier(),
		_effective_correction_cooldown(),
		int(round(_effective_correction_range())),
		correction_target_count,
		shadow_status,
		wrong_shield_charges,
		fatal_save_charges,
		solar_score
	]
	hud_label.text += "\nWASD 控制移动"

func _draw_countdown_ring(center: Vector2, radius: float, remaining_ratio: float, base_color: Color, active_color: Color, width: float) -> void:
	var clamped_ratio := clampf(remaining_ratio, 0.0, 1.0)
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * clamped_ratio
	draw_arc(center, radius, 0.0, TAU, 72, base_color, width)
	if clamped_ratio > 0.01:
		draw_arc(center, radius, start_angle, end_angle, 72, active_color, width + 1.0)

func _draw_teaching_ui_frames(_size: Vector2) -> void:
	pass

func _draw() -> void:
	var size := _screen_size()
	if background_texture:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.92))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.96, 0.98), true)
	_draw_teaching_ui_frames(size)

	if energy_panel_texture:
		var energy_rect := Rect2(Vector2(size.x * 0.5 - 268.0, 28.0), Vector2(535.0, 120.0))
		draw_texture_rect(energy_panel_texture, energy_rect, false, Color(1, 1, 1, 0.92))
		var energy_ratio := clampf(energy / ENERGY_MAX, 0.0, 1.0)
		var fill_width := 344.0 * energy_ratio
		var fill_origin := energy_rect.position + Vector2(138.0, 43.0)
		draw_rect(Rect2(fill_origin, Vector2(fill_width, 36.0)), Color(0.35, 0.90, 0.96, 0.45), true)
		var pointer_x := fill_origin.x + fill_width
		pointer_x = clampf(pointer_x, fill_origin.x + 4.0, fill_origin.x + 344.0 - 4.0)
		var pointer_tip := Vector2(pointer_x, fill_origin.y - 3.0)
		var pointer_points := PackedVector2Array([
			pointer_tip,
			pointer_tip + Vector2(-12.0, -20.0),
			pointer_tip + Vector2(12.0, -20.0)
		])
		draw_colored_polygon(pointer_points, Color(0.34, 0.92, 1.0, 0.92))
		draw_polyline(pointer_points + PackedVector2Array([pointer_tip]), Color(0.08, 0.42, 0.58, 0.95), 2.0)

	if offset_active:
		if offset_band_texture:
			var visual_rect := Rect2(offset_rect.position - Vector2(38.0, 78.0), offset_rect.size + Vector2(76.0, 156.0))
			draw_texture_rect(offset_band_texture, visual_rect, false, Color(1, 1, 1, 0.86))
		draw_rect(offset_rect, Color(1.0, 0.73, 0.12, 0.20), true)
		draw_rect(offset_rect, Color(0.98, 0.62, 0.04, 0.75), false, 3.0)
		for i in range(9):
			var x := offset_rect.position.x + 24.0 + i * (offset_rect.size.x - 48.0) / 8.0
			var y := offset_rect.position.y + offset_rect.size.y * 0.5 + sin(float(i)) * 18.0
			draw_circle(Vector2(x, y), 8.0, Color(1.0, 0.72, 0.12, 0.88))

	for zone in oscillation_zones:
		var zone_pos: Vector2 = zone["pos"]
		var zone_radius := float(zone.get("radius", 88.0))
		var active := _is_oscillation_zone_active(zone)
		if active:
			var active_total: float = max(0.1, float(zone.get("lifeMax", 1.55)) - float(zone.get("warnMax", 0.85)))
			var active_ratio: float = clampf(float(zone.get("life", 0.0)) / active_total, 0.0, 1.0)
			draw_circle(zone_pos, zone_radius, Color(0.18, 0.72, 1.0, 0.13))
			draw_circle(zone_pos, zone_radius * 0.58, Color(1.0, 0.72, 0.18, 0.10))
			for i in range(4):
				var ring_radius := zone_radius * (0.40 + float(i) * 0.16)
				draw_arc(zone_pos, ring_radius, 0.0, TAU, 56, Color(0.14, 0.68, 1.0, 0.22), 2.0)
			_draw_countdown_ring(zone_pos, zone_radius, active_ratio, Color(0.18, 0.58, 0.82, 0.24), Color(0.10, 0.72, 1.0, 0.88), 4.0)
		else:
			var warn_total: float = max(0.1, float(zone.get("warnMax", 0.85)))
			var warn_ratio: float = clampf(float(zone.get("warn", 0.0)) / warn_total, 0.0, 1.0)
			draw_circle(zone_pos, zone_radius, Color(1.0, 0.63, 0.18, 0.08 + 0.10 * warn_ratio))
			draw_arc(zone_pos, zone_radius * 0.68, 0.0, TAU, 48, Color(1.0, 0.72, 0.22, 0.25), 2.0)
			_draw_countdown_ring(zone_pos, zone_radius, warn_ratio, Color(1.0, 0.63, 0.18, 0.24), Color(1.0, 0.43, 0.08, 0.90), 4.0)

	for zone in shadow_zones:
		var zone_pos: Vector2 = zone["pos"]
		var zone_radius := float(zone.get("radius", 100.0))
		var active := _is_shadow_zone_active(zone)
		if active:
			var active_total: float = max(0.1, float(zone.get("lifeMax", 4.4)) - float(zone.get("warnMax", 0.8)))
			var active_ratio: float = clampf(float(zone.get("life", 0.0)) / active_total, 0.0, 1.0)
			draw_circle(zone_pos, zone_radius, Color(0.36, 0.41, 0.46, 0.20))
			draw_arc(zone_pos, zone_radius * 0.72, 0.0, TAU, 48, Color(0.24, 0.30, 0.36, 0.26), 2.0)
			_draw_countdown_ring(zone_pos, zone_radius, active_ratio, Color(0.42, 0.48, 0.54, 0.28), Color(0.62, 0.68, 0.74, 0.82), 4.0)
			for i in range(6):
				var angle := float(i) * TAU / 6.0
				var mark_pos := zone_pos + Vector2(cos(angle), sin(angle)) * zone_radius * 0.62
				draw_circle(mark_pos, 7.0, Color(0.72, 0.78, 0.84, 0.26))
		else:
			var warn_total: float = max(0.1, float(zone.get("warnMax", 0.8)))
			var warn_ratio: float = clampf(float(zone.get("warn", 0.0)) / warn_total, 0.0, 1.0)
			draw_circle(zone_pos, zone_radius, Color(1.0, 0.47, 0.52, 0.08 + 0.10 * warn_ratio))
			draw_arc(zone_pos, zone_radius * 0.72, 0.0, TAU, 48, Color(1.0, 0.56, 0.60, 0.20), 2.0)
			_draw_countdown_ring(zone_pos, zone_radius, warn_ratio, Color(0.95, 0.42, 0.46, 0.25), Color(1.0, 0.22, 0.30, 0.90), 4.0)

	for p in ordinary_particles:
		var pos: Vector2 = p["pos"]
		var is_reward := str(p.get("kind", "ordinary")) == "enemyReward"
		var orb_scale := float(p.get("scale", 1.0))
		draw_circle(pos, 14.0 * orb_scale, Color(1.0, 0.80, 0.22, 0.28 if is_reward else 0.18))
		if is_reward:
			draw_circle(pos, 20.0, Color(0.18, 0.76, 1.0, 0.16))
			draw_arc(pos, 15.0, 0.0, TAU, 28, Color(0.22, 0.78, 1.0, 0.58), 2.0)
		if light_orb_texture:
			var tex_size := Vector2(36, 36) * orb_scale
			draw_texture_rect(light_orb_texture, Rect2(pos - tex_size * 0.5, tex_size), false, Color(1, 1, 1, 0.98 if is_reward else 0.95))
		else:
			draw_circle(pos, 8.0 * orb_scale, Color(1.0, 0.72, 0.12, 0.90 if is_reward else 0.82))

	for enemy in error_blocks:
		var enemy_pos: Vector2 = enemy["pos"]
		var enemy_kind: String = str(enemy.get("kind", "error"))
		var enemy_hp: int = int(enemy.get("hp", 1))
		var enemy_max_hp: int = max(1, int(enemy.get("maxHp", 1)))
		var texture: Texture2D = _enemy_texture(enemy_kind)
		draw_circle(enemy_pos, 42.0 if enemy_kind == "oscillation" else 38.0 if enemy_kind == "stray" or enemy_kind == "saturation" else 34.0, _enemy_glow_color(enemy_kind))
		if texture:
			var tex_size: Vector2 = _enemy_draw_size(enemy_kind)
			draw_texture_rect(texture, Rect2(enemy_pos - tex_size * 0.5, tex_size), false, Color(1, 1, 1, 0.96))
		else:
			draw_rect(Rect2(enemy_pos - Vector2(32, 24), Vector2(64, 48)), Color(0.95, 0.22, 0.20, 0.85), true)
		if enemy_max_hp > 1:
			for hp_i in range(enemy_max_hp):
				var pip_pos: Vector2 = enemy_pos + Vector2(-12 + hp_i * 18, 40)
				var pip_color: Color = Color(1.0, 0.58, 0.18, 0.95) if hp_i < enemy_hp else Color(0.74, 0.80, 0.86, 0.75)
				draw_circle(pip_pos, 5.0, pip_color)

	for projectile in noise_projectiles:
		var projectile_pos: Vector2 = projectile["pos"]
		var vel: Vector2 = projectile["vel"]
		var dir := vel.normalized() if vel.length() > 0.1 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x)
		var angle := dir.angle()
		var tail := projectile_pos - dir * 28.0
		var nose := projectile_pos + dir * 24.0
		draw_line(tail, projectile_pos - dir * 6.0, Color(0.10, 0.72, 1.0, 0.20), 12.0)
		draw_line(tail + side * 4.0, projectile_pos - dir * 10.0 + side * 2.0, Color(0.85, 0.96, 1.0, 0.28), 4.0)
		draw_circle(projectile_pos, 14.0, Color(0.13, 0.78, 1.0, 0.14))
		if noise_pulse_texture:
			var pulse_size := Vector2(58, 38)
			var transform := Transform2D(angle, projectile_pos)
			draw_set_transform_matrix(transform)
			draw_texture_rect(noise_pulse_texture, Rect2(-pulse_size * 0.5, pulse_size), false, Color(1, 1, 1, 0.94))
			draw_set_transform_matrix(Transform2D())
		else:
			draw_circle(projectile_pos, 7.0, Color(0.02, 0.72, 1.0, 0.9))
		var arrow_points := PackedVector2Array([
			nose,
			projectile_pos + side * 7.0 - dir * 5.0,
			projectile_pos - side * 7.0 - dir * 5.0
		])
		draw_colored_polygon(arrow_points, Color(0.82, 0.97, 1.0, 0.70))
		draw_polyline(arrow_points + PackedVector2Array([nose]), Color(0.02, 0.48, 0.78, 0.78), 2.0)

	if rover_texture:
		draw_texture_rect(rover_texture, Rect2(player_pos - Vector2(64, 92), Vector2(128, 161)), false, Color(1, 1, 1, 0.98))
	else:
		draw_circle(player_pos, 32.0, Color(0.10, 0.34, 0.50, 0.95))
		draw_circle(player_pos, 20.0, Color(0.30, 0.74, 0.95, 0.95))
		draw_rect(Rect2(player_pos + Vector2(-34, -54), Vector2(68, 22)), Color(0.10, 0.28, 0.62, 0.95), true)
		draw_rect(Rect2(player_pos + Vector2(-34, -54), Vector2(68, 22)), Color(0.78, 0.88, 0.96, 0.90), false, 2.0)

	for beam in correction_beams:
		var beam_life: float = float(beam.get("life", 0.0))
		var alpha: float = clampf(beam_life / 0.16, 0.0, 1.0)
		var beam_from: Vector2 = beam["from"]
		var beam_to: Vector2 = beam["to"]
		draw_line(beam_from, beam_to, Color(0.02, 0.62, 0.92, alpha), 5.0)
		draw_circle(beam_to, 18.0, Color(0.20, 0.90, 1.0, alpha * 0.35))

	if paused or enemy_info_active:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.04, 0.52), true)

func _layout_question_panel() -> void:
	var size := _screen_size()
	var panel_size := Vector2(780, 470)
	question_panel.size = panel_size
	question_panel.position = (size - panel_size) * 0.5

func _layout_system_controls() -> void:
	var size := _screen_size()
	if hud_shell:
		hud_shell.position = Vector2(22, 16)
		hud_shell.size = Vector2(356, 342)
	if pause_button:
		pause_button.position = Vector2(max(24.0, size.x - 102.0), 18.0)
		pause_button.visible = phase != Phase.FINISHED
	if pause_panel:
		var panel_size := Vector2(460, 280)
		pause_panel.size = panel_size
		pause_panel.position = (size - panel_size) * 0.5
	if enemy_info_panel:
		var info_size := Vector2(560, 360)
		enemy_info_panel.size = info_size
		enemy_info_panel.position = (size - info_size) * 0.5

func _clear_question_box() -> void:
	question_title_label = null
	for child in question_box.get_children():
		question_box.remove_child(child)
		child.queue_free()

func _clear_enemy_info_box() -> void:
	for child in enemy_info_box.get_children():
		enemy_info_box.remove_child(child)
		child.queue_free()

func _screen_size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return DEFAULT_SIZE
	return size
