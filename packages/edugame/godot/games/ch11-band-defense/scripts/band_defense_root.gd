extends Control

const DGBRuntime = preload("res://addons/dgbook_runtime/runtime.gd")

const DESIGN_SIZE: Vector2 = Vector2(1280, 720)
const MAP_RECT: Rect2 = Rect2(24, 92, 900, 580)
const HUD_PANEL_RECT: Rect2 = Rect2(972, 24, 297, 672)
const HUD_SHELL_RECT: Rect2 = Rect2(960, 0, 320, 720)
const HUD_SCREEN_RECT: Rect2 = Rect2(963, 2, 315, 716)
const HUD_SCREEN_CORNER_RADIUS: int = 34
const HUD_SHELL_FRAME_COLOR := Color("#3E474A")
const HUD_SCREEN_COLOR := Color("#050D12")
const HUD_SCREEN_BORDER_COLOR := Color("#718086")
const MAX_LEAKS: int = 8
const TOTAL_WAVES: int = 3
const DIAGNOSIS_COST: int = 12
const DIAGNOSIS_MISS_COST: int = 4
const DIAGNOSIS_CLICK_RADIUS: float = 42.0
const PROBE_DAMAGE_MULTIPLIER: float = 0.45
const UI_FONT_PATH: String = "res://assets/fonts/NotoSansSC-VF.ttf"
const UI_BODY_ART_FONT_PATH: String = "res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"
const UI_DISPLAY_FONT_PATH: String = "res://assets/fonts/DingTalkJinBuTi.ttf"
const UI_TECH_FONT_PATH: String = "res://assets/fonts/Orbitron-wght.ttf"
const UI_STYLE_SETTING: String = "band_defense/ui_style"
const UI_STYLE_PS_LIGHT: String = "ps_light"
const UI_STYLE_WATCH_DEBUG: String = "watch_debug"
const SymptomFx = preload("res://scripts/symptom_fx.gd")
const HitFeedbackFx = preload("res://scripts/hit_feedback_fx.gd")
const WaveDiagnostics = preload("res://scripts/wave_diagnostics.gd")
const WaveLevelDirector = preload("res://scripts/wave_level_director.gd")
const LevelLayouts = preload("res://scripts/level_layouts.gd")
const RouteGeometry = preload("res://scripts/route_geometry.gd")
const SPRITE_SHEET_PATH: String = "res://assets/concept/band-defense-enemy-tower-sheet-v2-contrast.png"
const UNKNOWN_ENEMY_TEXTURE_PATH: String = "res://assets/generated/enemy_anim_unknown_fault.png"
const ENEMY_ANIM_COLUMNS: int = 4
const ENEMY_ANIM_ROWS: int = 3
const ENEMY_ANIM_FRAMES: int = 12
const ENEMY_ANIM_FPS: float = 9.0
const TOWER_ANIM_COLUMNS: int = 8
const TOWER_ANIM_ROWS: int = 2
const TOWER_IDLE_FPS: float = 7.0
const TOWER_ATTACK_FPS: float = 18.0
const TOWER_ATTACK_DURATION: float = float(TOWER_ANIM_COLUMNS) / TOWER_ATTACK_FPS
const ATTACK_EFFECT_FRAMES: int = 8
const ATTACK_EFFECT_FPS: float = 22.0
const ATTACK_EFFECT_DURATION: float = float(ATTACK_EFFECT_FRAMES) / ATTACK_EFFECT_FPS
const ATTACK_BEAM_FRAME_SIZE: Vector2 = Vector2(192, 64)
const ATTACK_RANGE_FRAME_SIZE: Vector2 = Vector2(256, 256)
const PLATFORM_BRAND := Color("#0E7C4A")
const PLATFORM_BRAND_HOVER := Color("#10915A")
const PLATFORM_BRAND_SOFT := Color("#ECFDF5")
const PLATFORM_SURFACE_BASE := Color("#F7F9FC")
const PLATFORM_SURFACE_CARD := Color("#FFFFFF")
const PLATFORM_SURFACE_MUTED := Color("#F1F5F9")
const PLATFORM_BORDER := Color("#E2E8F0")
const PLATFORM_TEXT := Color("#1A1A2E")
const PLATFORM_TEXT_SECONDARY := Color("#475569")
const PLATFORM_TEXT_TERTIARY := Color("#94A3B8")
const PLATFORM_SUCCESS := Color("#16A34A")
const PLATFORM_WARNING := Color("#F59E0B")
const GAME_UI_PANEL := Color(0.925, 0.970, 0.985, 0.88)
const GAME_UI_PANEL_SOFT := Color(0.965, 0.992, 1.000, 0.78)
const GAME_UI_PANEL_HOVER := Color(0.860, 0.960, 0.965, 0.92)
const GAME_UI_BORDER := Color(0.120, 0.640, 0.700, 0.62)
const GAME_UI_BORDER_MUTED := Color(0.360, 0.620, 0.660, 0.38)
const GAME_UI_TEXT := Color(0.070, 0.125, 0.165, 0.98)
const GAME_UI_TEXT_SECONDARY := Color(0.180, 0.290, 0.335, 0.90)
const GAME_UI_TEXT_MUTED := Color(0.440, 0.545, 0.570, 0.76)
const GAME_UI_ACCENT := Color(0.900, 0.650, 0.180, 0.98)
const GAME_UI_DANGER := Color(0.900, 0.240, 0.220, 0.94)
const PS_UI_SURFACE := Color("#FFFFFF")
const PS_UI_SURFACE_MUTED := Color("#F4F6FA")
const PS_UI_SURFACE_HOVER := Color("#EAF1FF")
const PS_UI_TEXT := Color("#0B0D12")
const PS_UI_TEXT_SECONDARY := Color("#4C5565")
const PS_UI_TEXT_MUTED := Color("#7D8797")
const PS_UI_ACCENT := Color("#3D8BFF")
const PS_UI_BORDER := Color("#D8DEE8")
const PS_UI_SUCCESS := Color("#169B62")
const PS_UI_WARNING := Color("#D99018")
const PS_UI_DANGER := Color("#D43A45")
const DRAW_BAND_MODEL_NODE_TEXT := false
const DRAW_EMPTY_TOWER_SLOT_TEXT := false
const ENEMY_SYMPTOM_LABEL_CLUSTER_RADIUS := 58.0
const POPUP_OPEN_MATERIALIZE_DURATION := 0.19
const POPUP_OPEN_SETTLE_DURATION := 0.09
const POPUP_CLOSE_MATERIALIZE_DURATION := 0.17
const POPUP_START_SCALE := Vector2(0.940, 0.880)
const POPUP_OVERSHOOT_SCALE := Vector2(1.014, 1.008)
const POPUP_CLOSE_SCALE := Vector2(0.965, 0.900)
const POPUP_START_TINT := Color(0.84, 0.97, 1.00, 0.0)
const POPUP_OVERSHOOT_TINT := Color(1.02, 1.06, 1.05, 1.0)
const POPUP_CLOSE_TINT := Color(0.86, 0.97, 1.00, 0.0)
const SLOT_MENU_RADIAL_ITEM_DURATION := 0.18
const SLOT_MENU_RADIAL_STAGGER := 0.025
const SLOT_MENU_RADIAL_CLOSE_DURATION := 0.14
const SLOT_MENU_RADIAL_START_SCALE := Vector2(0.68, 0.68)
const SLOT_MENU_RADIAL_START_TINT := Color(0.78, 0.98, 1.04, 0.0)


class WatchDebugMetricsStrip:
	extends Control

	var game: Node

	func _draw() -> void:
		var stability_ratio := _ratio("link_stability", 100.0)
		var energy_ratio := _ratio("energy", 120.0)
		_draw_ring(Vector2(28, 29), 15.0, stability_ratio, Color(0.16, 0.78, 0.62, 0.95))
		_draw_status_icon(Vector2(28, 29), "stability", Color(0.12, 0.55, 0.46, 0.96), stability_ratio)
		_draw_value_bar(Rect2(15, 55, 26, 3), stability_ratio, Color(0.16, 0.78, 0.62, 0.80))
		_draw_ring(Vector2(79, 29), 15.0, energy_ratio, Color(0.18, 0.66, 0.90, 0.90))
		_draw_status_icon(Vector2(79, 29), "energy", Color(0.12, 0.42, 0.70, 0.96), energy_ratio)
		_draw_value_bar(Rect2(66, 55, 26, 3), energy_ratio, Color(0.18, 0.66, 0.90, 0.78))
		_draw_waveform(Rect2(116, 15, maxf(60.0, size.x - 124.0), 32.0))

	func _tile_shadow_size() -> int:
		return 0

	func _draw_ios_tile(tile_rect: Rect2, accent: Color) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.985, 0.995, 1.000, 0.96)
		style.border_color = Color(0.60, 0.72, 0.78, 0.30)
		style.set_border_width_all(1)
		style.set_corner_radius_all(13)
		draw_style_box(style, tile_rect)
		draw_line(tile_rect.position + Vector2(12, 3), Vector2(tile_rect.end.x - 12, tile_rect.position.y + 3), Color(1, 1, 1, 0.78), 1.0)
		draw_circle(tile_rect.position + Vector2(9, 9), 2.2, accent)

	func _decorative_status_labels() -> Array:
		return []

	func _status_icon_count() -> int:
		return 2

	func _ratio(property_name: String, denominator: float) -> float:
		if game == null or denominator <= 0.0:
			return 0.0
		return clampf(float(game.get(property_name)) / denominator, 0.0, 1.0)

	func _metrics() -> Dictionary:
		if game != null and game.has_method("_band_link_metrics"):
			return game.call("_band_link_metrics") as Dictionary
		return {}

	func _strip_font() -> Font:
		if game != null and game.has_method("_hud_tech_font"):
			return game.call("_hud_tech_font", false) as Font
		return ThemeDB.fallback_font

	func _draw_ring(center: Vector2, radius: float, ratio: float, color: Color) -> void:
		draw_arc(center, radius, 0.0, TAU, 54, Color(0.28, 0.48, 0.50, 0.14), 4.0)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 54, color, 4.5)
		draw_circle(center, radius - 8.0, Color(1.0, 1.0, 1.0, 0.92))
		draw_circle(center, 3.2, color)

	func _draw_status_icon(center: Vector2, kind: String, color: Color, ratio: float) -> void:
		match kind:
			"stability":
				var shield := PackedVector2Array([
					center + Vector2(0, -8),
					center + Vector2(8, -4),
					center + Vector2(6, 5),
					center + Vector2(0, 9),
					center + Vector2(-6, 5),
					center + Vector2(-8, -4)
				])
				draw_colored_polygon(shield, Color(color.r, color.g, color.b, 0.18 + 0.24 * ratio))
				draw_polyline(shield + PackedVector2Array([shield[0]]), color, 1.3)
				draw_line(center + Vector2(-4, 0), center + Vector2(-1, 4), color, 1.4)
				draw_line(center + Vector2(-1, 4), center + Vector2(5, -4), color, 1.4)
			"energy":
				var body := Rect2(center + Vector2(-8, -5), Vector2(14, 10))
				draw_rect(body, Color(color.r, color.g, color.b, 0.13), true)
				draw_rect(Rect2(body.position, Vector2(body.size.x * clampf(ratio, 0.0, 1.0), body.size.y)), Color(color.r, color.g, color.b, 0.30), true)
				draw_rect(body, color, false, 1.3)
				draw_rect(Rect2(center + Vector2(6, -2), Vector2(3, 4)), color, true)

	func _draw_value_bar(bar_rect: Rect2, ratio: float, color: Color) -> void:
		draw_rect(bar_rect, Color(0.20, 0.42, 0.48, 0.10), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clampf(ratio, 0.0, 1.0), bar_rect.size.y)), color, true)

	func _diagnostic_ratio() -> float:
		var metrics := _metrics()
		var ack := clampf(float(metrics.get("ackRate", 0.0)) / 100.0, 0.0, 1.0)
		var noise := 1.0 - clampf(float(metrics.get("noiseRms", 0.0)) / 0.36, 0.0, 1.0)
		var step := 1.0 - clampf(float(metrics.get("stepErrorRate", 0.0)) / 24.0, 0.0, 1.0)
		return clampf((ack + noise + step) / 3.0, 0.0, 1.0)

	func _draw_status_dots(origin: Vector2) -> void:
		if game == null:
			return
		var metrics := _metrics()
		var warning := float(metrics.get("stepErrorRate", 0.0)) > 6.0 or float(metrics.get("averageCurrent", 0.0)) > 12.0
		var colors := [
			Color(0.16, 0.78, 0.62, 0.92),
			Color(0.18, 0.66, 0.90, 0.86),
			Color(0.92, 0.65, 0.18, 0.95) if warning else Color(0.24, 0.92, 0.72, 0.80),
			Color(0.88, 0.20, 0.18, 0.88) if int(game.get("leaks")) >= int(game.call("_leak_warning_threshold")) else Color(0.48, 0.62, 0.64, 0.48)
		]
		for i in range(colors.size()):
			draw_circle(origin + Vector2(i * 14.0, 0.0), 4.0, colors[i])

	func _draw_waveform(wave_rect: Rect2) -> void:
		var metrics := _metrics()
		var noise := clampf(float(metrics.get("noiseRms", 0.0)) / 0.25, 0.0, 1.0)
		var current := clampf(float(metrics.get("averageCurrent", 0.0)) / 20.0, 0.0, 1.0)
		draw_rect(wave_rect, Color(0.94, 0.985, 1.0, 0.86), true)
		draw_rect(wave_rect, Color(0.20, 0.62, 0.70, 0.14), false, 1.0)
		var points: Array[Vector2] = []
		for i in range(18):
			var x := wave_rect.position.x + wave_rect.size.x * float(i) / 17.0
			var phase := float(i) * 0.85 + float(Time.get_ticks_msec()) * 0.001
			var y := wave_rect.get_center().y + sin(phase) * (5.0 + 12.0 * noise) + cos(phase * 0.45) * (3.0 + 7.0 * current)
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.22, 0.92, 0.90, 0.82), 2.0)


class WatchHudWavePreview:
	extends Control

	var game: Node

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.970, 0.988, 0.996, 0.92)
		style.border_color = Color(0.18, 0.58, 0.66, 0.18)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		draw_style_box(style, rect.grow(-1.0))
		var wave_rect := Rect2(Vector2(6, 10), Vector2(maxf(8.0, size.x - 12.0), maxf(10.0, size.y - 20.0)))
		var metrics := _metrics()
		var noise := clampf(float(metrics.get("noiseRms", 0.0)) / 0.25, 0.0, 1.0)
		var current := clampf(float(metrics.get("averageCurrent", 0.0)) / 20.0, 0.0, 1.0)
		var points: Array[Vector2] = []
		for i in range(16):
			var x := wave_rect.position.x + wave_rect.size.x * float(i) / 15.0
			var phase := float(i) * 0.9 + float(Time.get_ticks_msec()) * 0.001
			var y := wave_rect.get_center().y + sin(phase) * (4.0 + 8.0 * noise) + cos(phase * 0.45) * (2.0 + 5.0 * current)
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.06, 0.62, 0.70, 0.88), 2.0)

	func _metrics() -> Dictionary:
		if game != null and game.has_method("_band_link_metrics"):
			return game.call("_band_link_metrics") as Dictionary
		return {}


class SlotMenuBackdrop:
	extends Control

	const GLASS_SHADOW_SIZE := 12.0

	func _surface_count() -> int:
		return 1

	func _outline_count() -> int:
		return 0

	func _uses_clean_window_glass() -> bool:
		return true

	func _specular_highlight_count() -> int:
		return 1

	func _glass_shadow_size() -> float:
		return GLASS_SHADOW_SIZE

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center + Vector2(0, 10), 114.0, Color(0.02, 0.07, 0.09, 0.055))
		draw_circle(center + Vector2(0, 6), 112.0, Color(0.02, 0.07, 0.09, 0.10))
		draw_circle(center, 112.0, Color(0.38, 0.49, 0.53, 0.34))
		draw_circle(center, 109.5, Color(0.965, 0.988, 0.995, 0.965))
		draw_arc(center, 108.0, PI + 0.30, TAU - 0.30, 48, Color(1.0, 1.0, 1.0, 0.88), 2.0, true)


var runtime: Node
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
var sprite_sheet: Texture2D
var background_map: Texture2D
var hud_background_map: Texture2D
var path_layer_settings := {}
var title_label: Label
var status_label: Label
var hud_label: Label
var tutorial_label: Label
var diagnostic_label: Label
var codex_button: Button
var codex_label: Label
var codex_popup: PanelContainer
var codex_grid: GridContainer
var codex_card_grid: GridContainer
var codex_entry_cards: Array = []
var codex_preview_nodes: Array = []
var codex_sprite_views := {}
var result_label: Label
var start_button: Button
var side_panel: PanelContainer
var side_hud_content_frame: MarginContainer
var hud_core_section: VBoxContainer
var hud_action_section: VBoxContainer
var hud_feedback_section: VBoxContainer
var hud_metrics_strip: WatchDebugMetricsStrip
var hud_status_tray: PanelContainer
var hud_status_text_plate: PanelContainer
var hud_status_wave_preview: Control
var tower_match_hint_label: Label
var hud_feedback_title_label: Label
var hud_section_cards := {}
var main_menu_panel: PanelContainer
var level_select_panel: PanelContainer
var tower_buttons := {}
var slot_menu_panel: Control
var slot_menu_backdrop: Control
var slot_menu_title: Label
var slot_menu_buttons := {}
var slot_menu_closing := false
var diagnostic_menu_panel: PanelContainer
var diagnostic_menu_title: Label
var diagnostic_hud_overlay: PanelContainer
var diagnostic_data_label: Label
var diagnostic_back_button: Button
var diagnostic_menu_buttons := {}
var diagnostic_fault_buttons := {}
var diagnosis_tutorial_popup: PanelContainer
var diagnosis_tutorial_title: Label
var diagnosis_tutorial_label: Label
var diagnosis_tutorial_seen := false
var pending_diagnostic_enemy = null
var pending_diagnostic_method := ""
var quiz_panel: PanelContainer
var quiz_title: Label
var quiz_prompt: Label
var quiz_feedback: Label
var quiz_buttons: Array = []
var popup_motion_tweens: Dictionary = {}
var slot_menu_motion_tween: Tween
var enemy_sprite_cells := {
	"config": Vector2(0, 0),
	"noise": Vector2(1, 0),
	"false_peak": Vector2(2, 0),
	"power_spike": Vector2(3, 0),
	"drift_noise": Vector2(1, 0),
	"hybrid_fault": Vector2(0, 0)
}
var enemy_anim_sheets := {
	"config": preload("res://assets/generated/enemy_anim_config.png"),
	"noise": preload("res://assets/generated/enemy_anim_noise.png"),
	"false_peak": preload("res://assets/generated/enemy_anim_false_peak.png"),
	"power_spike": preload("res://assets/generated/enemy_anim_power_spike.png"),
	"drift_noise": preload("res://assets/generated/enemy_anim_drift_noise.png"),
	"hybrid_fault": preload("res://assets/generated/enemy_anim_hybrid_fault.png")
}
var diagnostic_methods := {
	"read_registers": {"label": "读寄存器", "hint": "核对地址 / WHO_AM_I / 量程"},
	"inspect_waveform": {"label": "看波形窗口", "hint": "观察毛刺、抖动与漂移"},
	"inspect_current": {"label": "查看电流曲线", "hint": "检查唤醒脉冲与静止电流"},
	"check_threshold": {"label": "检查阈值/最小步间隔", "hint": "排查假峰值和连续计步"}
}
var hardware_tower_texture_paths := {
	"i2c": "res://assets/generated/tower_i2c_hardware_anim.png",
	"filter": "res://assets/generated/tower_filter_hardware_anim.png",
	"peak": "res://assets/generated/tower_peak_hardware_anim.png",
	"power": "res://assets/generated/tower_power_hardware_anim.png"
}
var hardware_tower_static_texture_paths := {
	"i2c": "res://assets/generated/tower_i2c_hardware.png",
	"filter": "res://assets/generated/tower_filter_hardware.png",
	"peak": "res://assets/generated/tower_peak_hardware.png",
	"power": "res://assets/generated/tower_power_hardware.png"
}
var attack_effect_texture_paths := {
	"i2c": {
		"beam": "res://assets/generated/tower_i2c_attack_beam.png",
		"range": "res://assets/generated/tower_i2c_attack_range.png"
	},
	"filter": {
		"beam": "res://assets/generated/tower_filter_attack_beam.png",
		"range": "res://assets/generated/tower_filter_attack_range.png"
	},
	"peak": {
		"beam": "res://assets/generated/tower_peak_attack_beam.png",
		"range": "res://assets/generated/tower_peak_attack_range.png"
	},
	"power": {
		"beam": "res://assets/generated/tower_power_attack_beam.png",
		"range": "res://assets/generated/tower_power_attack_range.png"
	}
}
var hud_texture_paths := {
	"panel": "res://assets/generated/hud_panel_frame.png",
	"button": "res://assets/generated/hud_button_plate.png",
	"button_primary": "res://assets/generated/hud_button_plate_primary.png",
	"status": "res://assets/generated/hud_status_tray.png",
	"dialog": "res://assets/generated/hud_dialog_frame.png",
	"text_plate": "res://assets/generated/hud_text_plate.png",
	"text_chip": "res://assets/generated/hud_text_chip.png",
	"section_card": "res://assets/generated/hud_section_card.png"
}
var hardware_tower_textures := {}
var hardware_tower_static_textures := {}
var attack_effect_textures := {}
var hud_textures := {}
var tower_sprite_cells := {
	"i2c": Vector2(0, 1),
	"filter": Vector2(1, 1),
	"peak": Vector2(2, 1),
	"power": Vector2(3, 1)
}

var state := "main_menu"
var started_at := 0
var run_started := false
var completed := false
var current_level := 1
var current_wave := 0
var waves_cleared := 0
var cleared_wave_keys := {}
var energy := 90
var trusted_data := 0
var leaks := 0
var max_leaks := MAX_LEAKS
var link_stability := 100
var correct_count := 0
var wrong_count := 0
var band_score := 0

var path_points := [
	Vector2(68, 360),
	Vector2(165, 190),
	Vector2(365, 190),
	Vector2(520, 360),
	Vector2(690, 530),
	Vector2(884, 360)
]

var tower_slots := [
	{"pos": Vector2(256, 263), "tower": null},
	{"pos": Vector2(439, 264), "tower": null},
	{"pos": Vector2(548, 433), "tower": null},
	{"pos": Vector2(733, 292), "tower": null}
]

var band_model_nodes := [
	{"label": "IMU 采集", "pos": Vector2(58, 78), "hint": "加速度/陀螺仪"},
	{"label": "PPG 采样", "pos": Vector2(58, 482), "hint": "心率光电信号"},
	{"label": "I2C 总线", "pos": Vector2(334, 116), "hint": "地址/ACK/寄存器"},
	{"label": "MCU 算法", "pos": Vector2(554, 542), "hint": "滤波/峰值/状态机"},
	{"label": "OLED 显示", "pos": Vector2(620, 84), "hint": "数据显示刷新"},
	{"label": "低功耗管理", "pos": Vector2(616, 598), "hint": "Stop/WOM/唤醒"}
]

var tower_defs := {
	"i2c": {
		"label": "I2C",
		"name": "I2C 初始化塔",
		"cost": 40,
		"range": 140.0,
		"damage": 32.0,
		"fireInterval": 0.75,
		"counterTags": ["config"],
		"color": Color(0.30, 0.56, 1.0),
		"attackStyle": "calibrate",
		"conceptText": "I2C 校准"
	},
	"filter": {
		"label": "滤波",
		"name": "滤波塔",
		"cost": 50,
		"range": 155.0,
		"damage": 24.0,
		"fireInterval": 0.95,
		"counterTags": ["noise", "jitter"],
		"color": Color(0.20, 0.75, 0.45),
		"attackStyle": "smooth",
		"conceptText": "滤波抑噪"
	},
	"peak": {
		"label": "峰值",
		"name": "峰值检测塔",
		"cost": 60,
		"range": 130.0,
		"damage": 44.0,
		"fireInterval": 1.05,
		"counterTags": ["false_peak", "missed_step"],
		"color": Color(0.96, 0.62, 0.14),
		"attackStyle": "threshold_burst",
		"conceptText": "峰值捕获"
	},
	"power": {
		"label": "低功耗",
		"name": "低功耗塔",
		"cost": 70,
		"range": 145.0,
		"damage": 38.0,
		"fireInterval": 1.20,
		"counterTags": ["power"],
		"color": Color(0.60, 0.45, 0.95),
		"attackStyle": "power_gate",
		"conceptText": "低功耗拦截"
	}
}

var enemy_defs := {
	"noise": {
		"label": "噪声包",
		"threatTag": "noise",
		"hp": 58.0,
		"speed": 72.0,
		"reward": 10,
		"color": Color(0.95, 0.33, 0.33),
		"codexName": "噪声包",
		"codexHint": "原始传感数据中的快速抖动、散点和毛刺。"
	},
	"drift_noise": {
		"label": "漂移噪声",
		"threatTag": "noise",
		"hp": 72.0,
		"speed": 62.0,
		"reward": 14,
		"color": Color(0.12, 0.68, 0.62),
		"codexName": "漂移噪声",
		"codexHint": "基线缓慢偏移，后段可能演变成类似计步峰值的异常。"
	},
	"false_peak": {
		"label": "假峰值",
		"threatTag": "false_peak",
		"hp": 46.0,
		"speed": 94.0,
		"reward": 12,
		"color": Color(1.0, 0.55, 0.18),
		"codexName": "假峰值",
		"codexHint": "看起来像有效步态峰值，但持续时间和间隔不可靠。"
	},
	"config": {
		"label": "配置错误",
		"threatTag": "config",
		"hp": 82.0,
		"speed": 54.0,
		"reward": 14,
		"color": Color(0.38, 0.55, 0.95),
		"codexName": "配置错误",
		"codexHint": "设备地址、寄存器、采样率或量程等初始化状态异常。"
	},
	"power_spike": {
		"label": "功耗尖峰",
		"threatTag": "power",
		"hp": 70.0,
		"speed": 64.0,
		"reward": 16,
		"color": Color(0.68, 0.42, 0.93),
		"codexName": "功耗尖峰",
		"codexHint": "高频采样、显示唤醒或休眠被打断造成的电流脉冲。"
	},
	"hybrid_fault": {
		"label": "混合故障",
		"threatTag": "config",
		"hp": 92.0,
		"speed": 56.0,
		"reward": 22,
		"color": Color(0.45, 0.55, 0.98),
		"codexName": "混合故障",
		"codexHint": "外层是综合故障包，行进过程中会表现出不同异常症状。"
	}
}

var unlocked := {
	"i2c": true,
	"filter": true,
	"peak": false,
	"power": false
}

var questions: Array = []
var waves: Array = []
var question_index := 0
var active_question := {}
var quiz_answer_locked := false
var spawn_queue: Array = []
var spawn_elapsed := 0.0
var spawn_interval := 0.68
var enemies: Array = []
var feedbacks: Array = []
var attack_effects: Array = []
var hit_effects: Array = []
var death_echoes: Array = []
var hit_effect_serial := 0
var hovered_enemy = null
var hover_health_alpha := 0.0
var hover_health_active := false
var hover_pointer_known := false
var hover_pointer_position := Vector2.ZERO
var current_wave_stats := {}
var current_level_stats := {}
var last_wave_summary := ""
var last_level_summary := ""
var selected_tower_id := "i2c"
var selected_slot_index := -1
var recording_demo_started := false
var recording_demo_build_marks := {}
var diagnosed_enemy_types := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	started_at = Time.get_ticks_msec()
	_load_sample_data()
	_load_ui_font()
	sprite_sheet = _load_png_texture(SPRITE_SHEET_PATH)
	var unknown_enemy_texture := _load_png_texture(UNKNOWN_ENEMY_TEXTURE_PATH)
	if unknown_enemy_texture != null:
		enemy_anim_sheets["unknown_fault"] = unknown_enemy_texture
	_load_hardware_tower_textures()
	_load_hud_textures()
	_apply_level_layout(current_level)
	_build_ui()
	runtime = DGBRuntime.new()
	runtime.setup({
		"game_id": "ch11-band-defense",
		"fallbacks": {
			"questions": "res://data/questions.local.json"
		},
		"defaults": {"max_leaks": MAX_LEAKS}
	})
	runtime.initialized.connect(_on_session_initialized)
	runtime.reset_requested.connect(_reset)
	runtime.pause_requested.connect(_on_pause_requested)
	runtime.resume_requested.connect(_on_resume_requested)
	runtime.custom_command_received.connect(_on_custom_command)
	add_child(runtime)
	_update_ui()
	call_deferred("_start_recording_demo_if_requested")


func _process(delta: float) -> void:
	var diagnostic_time_paused := _is_diagnostic_time_paused()
	if state == "wave_running":
		if !diagnostic_time_paused:
			_update_spawning(delta)
			_update_enemies(delta)
			_update_towers(delta)
	_cleanup_dead_enemies()
	_check_wave_end()
	_update_attack_effects(delta)
	if !diagnostic_time_paused:
		_update_enemy_hit_feedback(delta)
	_update_hover_health(delta)
	_update_feedback(delta)
	if hud_metrics_strip != null:
		hud_metrics_strip.queue_redraw()
	if hud_status_wave_preview != null:
		hud_status_wave_preview.queue_redraw()
	queue_redraw()


func _is_diagnostic_time_paused() -> bool:
	var diagnosis_menu_open := pending_diagnostic_enemy != null and diagnostic_menu_panel != null and diagnostic_menu_panel.visible
	var tutorial_open := diagnosis_tutorial_popup != null and diagnosis_tutorial_popup.visible
	var codex_open := codex_popup != null and codex_popup.visible
	return state == "wave_running" and (diagnosis_menu_open or tutorial_open or codex_open)


func _start_recording_demo_if_requested() -> void:
	if !_recording_demo_requested():
		return
	_start_recording_demo()


func _start_recording_demo() -> void:
	if recording_demo_started:
		return
	recording_demo_started = true
	_run_recording_demo()


func _recording_demo_requested() -> bool:
	if !OS.has_feature("web"):
		return false
	var raw = JavaScriptBridge.eval("(function(){ return window.location.search.indexOf('recordingDemo=1') >= 0 || window.location.hash.indexOf('recordingDemo=1') >= 0; })();", true)
	return str(raw).to_lower() == "true"


func _run_recording_demo() -> void:
	await get_tree().create_timer(1.1).timeout
	if state == "main_menu":
		start_game()
	var started := Time.get_ticks_msec()
	while state != "result" and Time.get_ticks_msec() - started < 240000:
		if state == "intro":
			await get_tree().create_timer(0.9).timeout
			start_game()
		elif state == "wave_running":
			if diagnosis_tutorial_popup != null and bool(diagnosis_tutorial_popup.visible):
				await get_tree().create_timer(1.4).timeout
				_dismiss_diagnosis_tutorial_popup()
			await _recording_demo_build_for_current_wave()
		elif state == "quiz":
			await get_tree().create_timer(0.8).timeout
			if state == "quiz" and !active_question.is_empty():
				answer_quiz(int(active_question.get("answerIndex", 0)))
			await get_tree().create_timer(1.3).timeout
		else:
			await get_tree().create_timer(0.25).timeout


func _recording_demo_build_for_current_wave() -> void:
	_apply_recording_demo_safety()
	var key := "%d-%d" % [current_level, current_wave]
	if bool(recording_demo_build_marks.get(key, false)):
		await get_tree().create_timer(0.4).timeout
		_apply_recording_demo_safety()
		return
	recording_demo_build_marks[key] = true
	await get_tree().create_timer(0.7).timeout
	for raw_action in _recording_demo_build_plan().get(key, []):
		var action := raw_action as Array
		var slot_index := int(action[0])
		if slot_index < 0 or slot_index >= tower_slots.size():
			continue
		_open_slot_menu(slot_index)
		await get_tree().create_timer(0.32).timeout
		build_tower(slot_index, str(action[1]))
		_close_slot_menu()
		await get_tree().create_timer(0.28).timeout
	_apply_recording_demo_safety()


func _recording_demo_safety_budget() -> Dictionary:
	return {
		"energy": 960,
		"towerLevel": 3,
		"unlocked": ["i2c", "filter", "peak", "power"]
	}


func _apply_recording_demo_safety() -> void:
	if !recording_demo_started:
		return
	var budget := _recording_demo_safety_budget()
	energy = maxi(energy, int(budget.get("energy", 960)))
	for tower_id in budget.get("unlocked", []) as Array:
		unlocked[str(tower_id)] = true
	var target_level := int(budget.get("towerLevel", 3))
	for i in range(tower_slots.size()):
		var slot := tower_slots[i] as Dictionary
		var tower = slot.get("tower", null)
		if tower == null:
			continue
		var tower_data := tower as Dictionary
		tower_data["level"] = maxi(int(tower_data.get("level", 1)), target_level)
		slot["tower"] = tower_data
		tower_slots[i] = slot
	leaks = mini(leaks, maxi(0, max_leaks - 2))
	link_stability = maxi(link_stability, 70)
	_update_ui()
	queue_redraw()


func _recording_demo_build_plan() -> Dictionary:
	return {
		"1-1": [[0, "i2c"], [1, "filter"]],
		"1-2": [[2, "peak"]],
		"1-3": [[3, "power"], [0, "i2c"]],
		"2-1": [[0, "i2c"], [2, "filter"]],
		"2-2": [[3, "peak"], [5, "filter"], [2, "filter"]],
		"2-3": [[4, "peak"], [3, "power"], [1, "i2c"]],
		"3-1": [[0, "i2c"], [1, "filter"], [2, "peak"], [3, "power"], [4, "peak"], [5, "filter"]],
		"3-2": [[3, "power"], [4, "peak"], [5, "filter"], [2, "peak"]],
		"3-3": [[0, "i2c"], [1, "filter"], [2, "peak"], [3, "power"], [4, "peak"], [5, "power"]]
	}


func _draw() -> void:
	_draw_map()
	_draw_path_layer()
	_draw_menu_backdrop()
	_draw_enemy_hit_backplates()
	_draw_tower_slots()
	_draw_slot_menu_guides()
	_draw_enemies()
	_draw_death_echoes()
	_draw_attack_effects()
	_draw_enemy_hit_effects()
	_draw_hover_health_chip()
	_draw_feedback()


func _gui_input(event: InputEvent) -> void:
	if state != "intro" and state != "wave_running":
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		hover_pointer_known = true
		hover_pointer_position = motion_event.position
		_refresh_hover_target()
		return
	if !(event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if !mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot_index := _slot_at_position(mouse_event.position)
	if slot_index == -1:
		if state == "wave_running" and _diagnose_enemy_at(mouse_event.position):
			accept_event()
			return
		_close_slot_menu()
		_close_diagnostic_menu()
		return
	_close_diagnostic_menu()
	if slot_menu_panel != null and slot_menu_panel.visible and slot_index == selected_slot_index:
		_close_slot_menu()
		accept_event()
		return
	_open_slot_menu(slot_index)
	accept_event()


func _load_sample_data() -> void:
	if !OS.has_feature("web"):
		var loaded_questions = _read_json("res://data/questions.local.json")
		if typeof(loaded_questions) == TYPE_ARRAY:
			questions = loaded_questions
	var loaded_waves = _read_json("res://data/waves.sample.json")
	if typeof(loaded_waves) == TYPE_ARRAY:
		waves = loaded_waves
	var loaded_level2_waves = _read_json("res://data/waves.level2.json")
	if typeof(loaded_level2_waves) == TYPE_ARRAY:
		waves.append_array(loaded_level2_waves)
	var loaded_level3_waves = _read_json("res://data/waves.level3.json")
	if typeof(loaded_level3_waves) == TYPE_ARRAY:
		waves.append_array(loaded_level3_waves)


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Missing JSON file: " + path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_warning("Invalid JSON file: " + path)
	return parsed


func _load_ui_font() -> void:
	if ResourceLoader.exists(UI_FONT_PATH):
		ui_font = load(UI_FONT_PATH)
		ui_font_regular = _make_ui_font_variation(0.06)
		ui_font_medium = _make_ui_font_variation(0.18)
		ui_font_semibold = _make_ui_font_variation(0.26)
		ui_font_bold = _make_ui_font_variation(0.30)
	else:
		push_warning("Missing UI font: " + UI_FONT_PATH)
	if ResourceLoader.exists(UI_BODY_ART_FONT_PATH):
		ui_body_art_font = load(UI_BODY_ART_FONT_PATH)
		ui_body_art_font_regular = _make_font_variation(ui_body_art_font, 0.08)
		ui_body_art_font_bold = _make_font_variation(ui_body_art_font, 0.18)
	else:
		push_warning("Missing body art UI font: " + UI_BODY_ART_FONT_PATH)
	if ResourceLoader.exists(UI_DISPLAY_FONT_PATH):
		ui_display_font = load(UI_DISPLAY_FONT_PATH)
		ui_display_font_regular = _make_font_variation(ui_display_font, 0.04)
		ui_display_font_bold = _make_font_variation(ui_display_font, 0.16)
	else:
		push_warning("Missing display UI font: " + UI_DISPLAY_FONT_PATH)
	if ResourceLoader.exists(UI_TECH_FONT_PATH):
		ui_tech_font = load(UI_TECH_FONT_PATH)
		ui_tech_font_regular = _make_font_variation(ui_tech_font, 0.02)
		ui_tech_font_bold = _make_font_variation(ui_tech_font, 0.14)
	else:
		push_warning("Missing tech UI font: " + UI_TECH_FONT_PATH)


func _make_ui_font_variation(embolden: float) -> Font:
	return _make_font_variation(ui_font, embolden)


func _make_font_variation(base_font: Font, embolden: float) -> Font:
	if base_font == null:
		return null
	var font_variation := FontVariation.new()
	font_variation.base_font = base_font
	font_variation.variation_embolden = embolden
	return font_variation


func _load_texture_or_png(path: String, warning_label: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded
	if path.ends_with(".png") and FileAccess.file_exists(path):
		var image := Image.new()
		var error := image.load(path)
		if error == OK:
			return ImageTexture.create_from_image(image)
	push_warning("Missing " + warning_label + ": " + path)
	return null


func _load_background_map(path: String) -> void:
	background_map = _load_texture_or_png(path, "background map")


func _load_hud_background_map(path: String) -> void:
	hud_background_map = _load_texture_or_png(path, "HUD background map")


func _apply_level_layout(level_number: int) -> void:
	var layout := LevelLayouts.layout_for_level(level_number)
	var path_controls := (layout.get("path", []) as Array).duplicate(true)
	tower_slots = (layout.get("towerSlots", []) as Array).duplicate(true)
	path_layer_settings = _default_path_layer_style()
	var incoming_path_layer := layout.get("pathLayer", {}) as Dictionary
	for key in incoming_path_layer.keys():
		path_layer_settings[key] = incoming_path_layer[key]
	var smooth_route := RouteGeometry.build_smooth_route(
		path_controls,
		float(path_layer_settings.get("cornerRadius", 0.0)),
		int(path_layer_settings.get("cornerSamples", 1))
	)
	path_points = []
	for point in smooth_route:
		path_points.append(point)
	_load_background_map(str(layout.get("background", LevelLayouts.LEVEL_ONE_BACKGROUND)))
	_load_hud_background_map(str(layout.get("hudBackground", "")))
	queue_redraw()


func _draw_font() -> Font:
	if ui_font != null:
		return ui_font
	return ThemeDB.fallback_font


func _hud_readable_font(strong: bool = false) -> Font:
	if strong and ui_font_bold != null:
		return ui_font_bold
	if ui_font_medium != null:
		return ui_font_medium
	if ui_font_regular != null:
		return ui_font_regular
	return _draw_font()


func _hud_medium_font() -> Font:
	if ui_font_medium != null:
		return ui_font_medium
	if ui_font_regular != null:
		return ui_font_regular
	return _draw_font()


func _ui_style_id() -> String:
	var style_id := str(ProjectSettings.get_setting(UI_STYLE_SETTING, UI_STYLE_PS_LIGHT)).strip_edges().to_lower()
	if style_id == UI_STYLE_WATCH_DEBUG:
		return UI_STYLE_WATCH_DEBUG
	return UI_STYLE_PS_LIGHT


func _uses_ps_light_ui() -> bool:
	return _ui_style_id() == UI_STYLE_PS_LIGHT


func _hud_body_art_font(strong: bool = false) -> Font:
	if strong and ui_body_art_font_bold != null:
		return ui_body_art_font_bold
	if ui_body_art_font_regular != null:
		return ui_body_art_font_regular
	return _hud_readable_font(strong)


func _hud_display_font(strong: bool = false) -> Font:
	if strong and ui_display_font_bold != null:
		return ui_display_font_bold
	if ui_display_font_regular != null:
		return ui_display_font_regular
	return _hud_medium_font() if strong else _hud_readable_font(false)


func _hit_feedback_font() -> Font:
	if ui_display_font_bold != null:
		return ui_display_font_bold
	return _hud_readable_font(true)


func _hit_feedback_font_size() -> int:
	return 22


func _hud_tech_font(strong: bool = false) -> Font:
	if strong and ui_tech_font_bold != null:
		return ui_tech_font_bold
	if ui_tech_font_regular != null:
		return ui_tech_font_regular
	return _hud_medium_font()


func _build_ui() -> void:
	if ui_font != null:
		var ui_theme := Theme.new()
		ui_theme.default_font = ui_font
		ui_theme.default_font_size = 16
		theme = ui_theme

	var header := HBoxContainer.new()
	header.position = Vector2(208, 20)
	header.size = Vector2(560, 52)
	header.add_theme_constant_override("separation", 18)
	add_child(header)

	status_label = Label.new()
	status_label.text = LevelLayouts.intro_text_for_level(1)
	status_label.custom_minimum_size = Vector2(560, 52)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = true
	status_label.visible = false
	_apply_status_banner_label_style(status_label)
	header.add_child(status_label)

	side_panel = PanelContainer.new()
	side_panel.position = HUD_PANEL_RECT.position
	side_panel.size = HUD_PANEL_RECT.size
	side_panel.clip_contents = true
	side_panel.add_theme_stylebox_override("panel", _make_game_panel_style(GAME_UI_PANEL, GAME_UI_BORDER_MUTED, 8))
	add_child(side_panel)

	side_hud_content_frame = MarginContainer.new()
	side_hud_content_frame.clip_contents = true
	side_hud_content_frame.add_theme_constant_override("margin_left", 4)
	side_hud_content_frame.add_theme_constant_override("margin_right", 4)
	side_hud_content_frame.add_theme_constant_override("margin_top", 2)
	side_hud_content_frame.add_theme_constant_override("margin_bottom", 2)
	side_panel.add_child(side_hud_content_frame)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 0)
	side_hud_content_frame.add_child(side)

	hud_section_cards.clear()
	hud_core_section = _add_hud_section_card(side, "core", "链路状态")
	hud_action_section = _add_hud_section_card(side, "action", "当前操作")
	hud_feedback_section = _add_hud_section_card(side, "feedback", "诊断反馈")

	hud_metrics_strip = WatchDebugMetricsStrip.new()
	hud_metrics_strip.game = self
	hud_metrics_strip.custom_minimum_size = Vector2(0, 78)
	hud_metrics_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_metrics_strip.clip_contents = true
	hud_core_section.add_child(hud_metrics_strip)

	hud_status_tray = PanelContainer.new()
	hud_status_tray.custom_minimum_size = Vector2(0, 88)
	hud_status_tray.clip_contents = true
	hud_status_tray.add_theme_stylebox_override("panel", _make_status_tray_style())
	hud_core_section.add_child(hud_status_tray)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	hud_status_tray.add_child(status_row)

	hud_status_text_plate = PanelContainer.new()
	hud_status_text_plate.custom_minimum_size = Vector2(0, 68)
	hud_status_text_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_status_text_plate.clip_contents = true
	var status_text_style := StyleBoxEmpty.new()
	status_text_style.set_content_margin_all(6)
	hud_status_text_plate.add_theme_stylebox_override("panel", status_text_style)
	status_row.add_child(hud_status_text_plate)

	var status_text_margin := MarginContainer.new()
	status_text_margin.add_theme_constant_override("margin_left", 8)
	status_text_margin.add_theme_constant_override("margin_right", 8)
	status_text_margin.add_theme_constant_override("margin_top", 6)
	status_text_margin.add_theme_constant_override("margin_bottom", 6)
	hud_status_text_plate.add_child(status_text_margin)

	hud_label = Label.new()
	hud_label.text = ""
	hud_label.custom_minimum_size = Vector2(0, 48)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.max_lines_visible = 2
	hud_label.clip_text = true
	_apply_level_info_label_style(hud_label, 13)
	status_text_margin.add_child(hud_label)

	start_button = Button.new()
	start_button.text = "开始第 1 关"
	start_button.custom_minimum_size = Vector2(0, 46)
	_apply_platform_button_style(start_button, true)
	start_button.pressed.connect(start_game)
	hud_action_section.add_child(start_button)

	var tower_title := Label.new()
	tower_title.text = "建塔 / 升级"
	tower_title.custom_minimum_size = Vector2(0, 18)
	_apply_hud_label_style(tower_title, GAME_UI_ACCENT, 14, 2)
	hud_action_section.add_child(tower_title)

	for tower_id in ["i2c", "filter", "peak", "power"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		_apply_platform_button_style(button, false)
		button.pressed.connect(_on_tower_button_pressed.bind(tower_id))
		hud_action_section.add_child(button)
		tower_buttons[tower_id] = button

	tower_match_hint_label = Label.new()
	tower_match_hint_label.text = "匹配 x1.8 / 错配 x0.25"
	tower_match_hint_label.custom_minimum_size = Vector2(0, 22)
	tower_match_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tower_match_hint_label.max_lines_visible = 1
	tower_match_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_watch_readout_label_style(tower_match_hint_label, 11)
	tower_match_hint_label.visible = false
	hud_action_section.add_child(tower_match_hint_label)

	codex_button = Button.new()
	codex_button.text = "敌人图鉴"
	codex_button.custom_minimum_size = Vector2(0, 42)
	_apply_platform_button_style(codex_button, false)
	codex_button.pressed.connect(_toggle_codex)
	hud_feedback_section.add_child(codex_button)

	codex_label = Label.new()
	codex_label.text = _build_codex_text()
	codex_label.visible = false
	codex_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_hud_label_style(codex_label, GAME_UI_TEXT_SECONDARY, 11, 1)
	hud_feedback_section.add_child(codex_label)

	diagnostic_label = Label.new()
	diagnostic_label.text = "链路诊断状态待机。"
	diagnostic_label.custom_minimum_size = Vector2(0, 40)
	diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostic_label.max_lines_visible = 2
	_apply_body_art_label_style(diagnostic_label, GAME_UI_TEXT, 12, true)
	hud_feedback_section.add_child(diagnostic_label)

	result_label = Label.new()
	result_label.text = ""
	result_label.custom_minimum_size = Vector2(0, 44)
	result_label.visible = false
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.max_lines_visible = 2
	result_label.clip_text = true
	result_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result_label.add_theme_font_override("font", _hud_display_font(true))
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.add_theme_color_override("font_color", Color(0.05, 0.48, 0.28, 0.98))
	hud_feedback_section.add_child(result_label)

	_build_diagnostic_hud_overlay()
	_build_slot_menu()
	_build_diagnostic_menu()
	_build_codex_popup()
	_build_quiz_panel()
	_build_main_menu()
	_build_level_select_panel()
	_build_diagnosis_tutorial_popup()
	show_main_menu()


func _build_main_menu() -> void:
	main_menu_panel = PanelContainer.new()
	main_menu_panel.position = Vector2(292, 126)
	main_menu_panel.size = Vector2(560, 380)
	main_menu_panel.clip_contents = true
	main_menu_panel.set_meta("map_style_background", true)
	main_menu_panel.set_meta("game_ui_polish", true)
	main_menu_panel.add_theme_stylebox_override("panel", _make_map_menu_panel_style())
	add_child(main_menu_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	main_menu_panel.add_child(box)

	var menu_title := Label.new()
	menu_title.text = "手环数据链路防线"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_hud_label_style(menu_title, GAME_UI_TEXT, 30, 2)
	box.add_child(menu_title)

	var menu_hint := Label.new()
	menu_hint.text = "在数据链路地图上开始闯关，或直接选择要测试的关卡。"
	menu_hint.custom_minimum_size = Vector2(0, 34)
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_art_label_style(menu_hint, GAME_UI_TEXT, 15, true)
	menu_hint.add_theme_font_override("font", _hud_display_font(false))
	box.add_child(menu_hint)

	var campaign_button := Button.new()
	campaign_button.text = "开始闯关"
	campaign_button.custom_minimum_size = Vector2(0, 54)
	_apply_platform_button_style(campaign_button, true)
	campaign_button.pressed.connect(start_game)
	box.add_child(campaign_button)

	var level_button := Button.new()
	level_button.text = "选择关卡"
	level_button.custom_minimum_size = Vector2(0, 50)
	_apply_platform_button_style(level_button, false)
	level_button.pressed.connect(show_level_select)
	box.add_child(level_button)


func _build_level_select_panel() -> void:
	level_select_panel = PanelContainer.new()
	level_select_panel.position = Vector2(278, 116)
	level_select_panel.size = Vector2(604, 490)
	level_select_panel.visible = false
	level_select_panel.clip_contents = true
	level_select_panel.set_meta("game_ui_polish", true)
	level_select_panel.add_theme_stylebox_override("panel", _make_center_hud_panel_style(Color(0.015, 0.060, 0.085, 0.94), GAME_UI_BORDER, 8))
	add_child(level_select_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	level_select_panel.add_child(box)

	var title := Label.new()
	title.text = "选择关卡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_hud_label_style(title, GAME_UI_TEXT, 28, 2)
	box.add_child(title)

	var levels := [
		{"level": 1, "label": "第 1 关  基础识别", "hint": "I2C / 滤波入门，保留部分解锁节奏。"},
		{"level": 2, "label": "第 2 关  夜跑异常", "hint": "路线更复杂，四种塔直接可用。"},
		{"level": 3, "label": "第 3 关  综合验收", "hint": "综合敌人和升级攻击的集中测试。"}
	]
	for entry in levels:
		var button := Button.new()
		button.text = "%s\n%s" % [str(entry["label"]), str(entry["hint"])]
		button.custom_minimum_size = Vector2(0, 72)
		_apply_platform_button_style(button, false)
		button.add_theme_font_override("font", _hud_display_font(false) if _uses_ps_light_ui() else _hud_readable_font(false))
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(select_level.bind(int(entry["level"])))
		box.add_child(button)

	var back_button := Button.new()
	back_button.text = "返回总菜单"
	back_button.custom_minimum_size = Vector2(0, 46)
	_apply_platform_button_style(back_button, false)
	back_button.pressed.connect(show_main_menu)
	box.add_child(back_button)


func _build_diagnosis_tutorial_popup() -> void:
	diagnosis_tutorial_popup = PanelContainer.new()
	diagnosis_tutorial_popup.visible = false
	diagnosis_tutorial_popup.position = Vector2(270, 130)
	diagnosis_tutorial_popup.size = Vector2(620, 410)
	diagnosis_tutorial_popup.clip_contents = true
	diagnosis_tutorial_popup.add_theme_stylebox_override("panel", _make_center_hud_panel_style(Color(0.015, 0.060, 0.085, 0.96), GAME_UI_ACCENT, 8))
	add_child(diagnosis_tutorial_popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagnosis_tutorial_popup.add_child(box)

	diagnosis_tutorial_title = Label.new()
	diagnosis_tutorial_title.text = "操作与诊断教学"
	diagnosis_tutorial_title.custom_minimum_size = Vector2(0, 34)
	diagnosis_tutorial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnosis_tutorial_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_hud_label_style(diagnosis_tutorial_title, GAME_UI_ACCENT, 25, 2)
	box.add_child(diagnosis_tutorial_title)

	diagnosis_tutorial_label = Label.new()
	diagnosis_tutorial_label.text = "第一关基础操作：\n1. 点塔位打开圆形菜单。\n2. 选模块建塔；再点已建塔位升级。\n3. 准备后点右侧按钮开始波次。\n\n诊断步骤：\n1. 点敌人打开诊断。\n2. 查看寄存器、波形、电流、阈值四组数据。\n3. 在数据页点“返回检测选择”继续查看。\n4. 找到异常项后选择故障类型。"
	diagnosis_tutorial_label.custom_minimum_size = Vector2(0, 260)
	diagnosis_tutorial_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagnosis_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_art_label_style(diagnosis_tutorial_label, GAME_UI_TEXT, 16, true)
	diagnosis_tutorial_label.add_theme_font_override("font", _hud_display_font(true) if _uses_ps_light_ui() else _make_ui_font_variation(0.29))
	box.add_child(diagnosis_tutorial_label)

	var ok_button := Button.new()
	ok_button.text = "开始诊断"
	ok_button.custom_minimum_size = Vector2(0, 42)
	_apply_platform_button_style(ok_button, true)
	ok_button.pressed.connect(_dismiss_diagnosis_tutorial_popup)
	box.add_child(ok_button)


func _show_diagnosis_tutorial_popup() -> void:
	if diagnosis_tutorial_popup == null:
		return
	_animate_popup_in(diagnosis_tutorial_popup)
	_close_slot_menu()
	_close_diagnostic_menu()
	queue_redraw()


func _dismiss_diagnosis_tutorial_popup() -> bool:
	if diagnosis_tutorial_popup == null:
		return false
	diagnosis_tutorial_seen = true
	_animate_popup_out(diagnosis_tutorial_popup)
	queue_redraw()
	return true


func _build_slot_menu() -> void:
	slot_menu_panel = Control.new()
	slot_menu_panel.visible = false
	slot_menu_panel.size = Vector2(300, 300)
	slot_menu_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(slot_menu_panel)

	slot_menu_backdrop = SlotMenuBackdrop.new()
	slot_menu_backdrop.size = Vector2(300, 300)
	slot_menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_menu_panel.add_child(slot_menu_backdrop)

	slot_menu_title = Label.new()
	slot_menu_title.position = Vector2(94, 115)
	slot_menu_title.size = Vector2(112, 70)
	slot_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_menu_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_menu_title.max_lines_visible = 2
	slot_menu_title.add_theme_constant_override("line_spacing", 2)
	slot_menu_title.text = "塔位"
	_apply_hud_label_style(slot_menu_title, GAME_UI_ACCENT, 18, 2)
	slot_menu_panel.add_child(slot_menu_title)

	var ring_positions := {
		"i2c": Vector2(106, 18),
		"filter": Vector2(194, 106),
		"peak": Vector2(106, 194),
		"power": Vector2(18, 106)
	}

	for tower_id in ["i2c", "filter", "peak", "power"]:
		var item := VBoxContainer.new()
		item.position = ring_positions[tower_id]
		item.size = Vector2(88, 88)
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_menu_panel.add_child(item)

		var button := Button.new()
		button.custom_minimum_size = Vector2(70, 70)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_slot_menu_tower_pressed.bind(tower_id))
		item.add_child(button)
		if tower_defs.has(tower_id):
			var tower_def := tower_defs[tower_id] as Dictionary
			_apply_slot_menu_button_style(button, tower_def["color"], false)
		slot_menu_buttons[tower_id] = {
			"button": button,
			"item": item,
			"targetPosition": ring_positions[tower_id],
		}


func _build_diagnostic_hud_overlay() -> void:
	diagnostic_hud_overlay = PanelContainer.new()
	diagnostic_hud_overlay.visible = false
	diagnostic_hud_overlay.position = HUD_PANEL_RECT.position + Vector2(8, 8)
	diagnostic_hud_overlay.size = HUD_PANEL_RECT.size - Vector2(16, 16)
	diagnostic_hud_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	diagnostic_hud_overlay.clip_contents = true
	diagnostic_hud_overlay.add_theme_stylebox_override("panel", _make_text_plate_style(18, Color(1, 1, 1, 1.0)))
	add_child(diagnostic_hud_overlay)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	diagnostic_hud_overlay.add_child(box)

	var title := Label.new()
	title.text = "诊断数据读数"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_hud_label_style(title, GAME_UI_ACCENT, 18, 2)
	box.add_child(title)

	var divider := HSeparator.new()
	box.add_child(divider)

	diagnostic_data_label = Label.new()
	diagnostic_data_label.visible = false
	diagnostic_data_label.custom_minimum_size = Vector2(0, 560)
	diagnostic_data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostic_data_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_apply_body_art_label_style(diagnostic_data_label, Color(0.040, 0.145, 0.180, 0.99), 16, true)
	diagnostic_data_label.add_theme_font_override("font", _hud_display_font(true))
	diagnostic_data_label.add_theme_constant_override("line_spacing", 6)
	box.add_child(diagnostic_data_label)


func _build_diagnostic_menu() -> void:
	diagnostic_menu_panel = PanelContainer.new()
	diagnostic_menu_panel.visible = false
	diagnostic_menu_panel.size = Vector2(300, 392)
	diagnostic_menu_panel.clip_contents = true
	diagnostic_menu_panel.add_theme_stylebox_override("panel", _make_game_panel_style())
	add_child(diagnostic_menu_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	diagnostic_menu_panel.add_child(box)

	diagnostic_menu_title = Label.new()
	diagnostic_menu_title.text = "选择检测手段"
	diagnostic_menu_title.custom_minimum_size = Vector2(0, 42)
	diagnostic_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diagnostic_menu_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	diagnostic_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostic_menu_title.max_lines_visible = 2
	_apply_hud_label_style(diagnostic_menu_title, GAME_UI_TEXT, 18, 2)
	box.add_child(diagnostic_menu_title)

	for method_id in ["read_registers", "inspect_waveform", "inspect_current", "check_threshold"]:
		var def := diagnostic_methods[method_id] as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [str(def["label"]), str(def["hint"])]
		button.custom_minimum_size = Vector2(0, 43)
		_apply_platform_button_style(button, false)
		button.pressed.connect(_choose_diagnostic_method.bind(method_id))
		box.add_child(button)
		diagnostic_menu_buttons[method_id] = button

	diagnostic_back_button = Button.new()
	diagnostic_back_button.visible = false
	diagnostic_back_button.text = "返回检测选择"
	diagnostic_back_button.custom_minimum_size = Vector2(0, 30)
	_apply_platform_button_style(diagnostic_back_button, false)
	diagnostic_back_button.pressed.connect(_return_to_diagnostic_methods)
	box.add_child(diagnostic_back_button)

	for enemy_type in ["config", "noise", "drift_noise", "false_peak", "power_spike", "hybrid_fault"]:
		var button := Button.new()
		button.visible = false
		button.text = _enemy_codex_name(enemy_type)
		button.custom_minimum_size = Vector2(0, 30)
		_apply_platform_button_style(button, false)
		button.pressed.connect(_choose_fault_type.bind(enemy_type))
		box.add_child(button)
		diagnostic_fault_buttons[enemy_type] = button


func _build_codex_popup() -> void:
	codex_entry_cards.clear()
	codex_preview_nodes.clear()
	codex_sprite_views.clear()
	codex_popup = PanelContainer.new()
	codex_popup.visible = false
	codex_popup.position = Vector2(204, 86)
	codex_popup.size = Vector2(720, 548)
	codex_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	codex_popup.clip_contents = true
	var popup_style := _make_hud_texture_style("dialog", 24, 34, Color(1, 1, 1, 0.985))
	var codex_fallback: StyleBox = _make_ps_surface_style(20, 34, false, true) if _uses_ps_light_ui() else _make_flat_panel_style(GAME_UI_PANEL, GAME_UI_BORDER, 8, 34)
	codex_popup.add_theme_stylebox_override("panel", popup_style if popup_style != null else codex_fallback)
	add_child(codex_popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	codex_popup.add_child(box)

	var title := Label.new()
	title.text = "敌人图鉴"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_hud_label_style(title, GAME_UI_ACCENT, 28, 2)
	box.add_child(title)

	codex_grid = GridContainer.new()
	codex_grid.columns = 2
	codex_grid.add_theme_constant_override("h_separation", 10)
	codex_grid.add_theme_constant_override("v_separation", 8)
	codex_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(codex_grid)
	codex_card_grid = codex_grid

	for enemy_type in ["config", "noise", "drift_noise", "false_peak", "power_spike", "hybrid_fault"]:
		codex_grid.add_child(_make_codex_entry_card(enemy_type))

	var close_button := Button.new()
	close_button.text = "关闭图鉴"
	close_button.custom_minimum_size = Vector2(0, 38)
	_apply_platform_button_style(close_button, true)
	close_button.pressed.connect(_hide_codex_popup)
	box.add_child(close_button)


func _make_codex_entry_card(enemy_type: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(318, 114)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _make_text_plate_style(8, Color(1, 1, 1, 0.98)))
	codex_entry_cards.append(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(82, 82)
	preview_frame.add_theme_stylebox_override("panel", _make_flat_panel_style(Color(0.060, 0.120, 0.140, 0.92), GAME_UI_ACCENT, 8, 4))
	row.add_child(preview_frame)

	var preview := TextureRect.new()
	preview.texture = _enemy_codex_preview_texture(enemy_type)
	preview.custom_minimum_size = Vector2(74, 74)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview)
	codex_preview_nodes.append(preview)
	codex_sprite_views[enemy_type] = preview

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 3)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = _enemy_codex_name(enemy_type)
	name_label.custom_minimum_size = Vector2(0, 22)
	_apply_hud_label_style(name_label, GAME_UI_TEXT, 16, 2)
	text_box.add_child(name_label)

	var def := enemy_defs.get(enemy_type, {}) as Dictionary
	var hint_label := Label.new()
	hint_label.text = str(def.get("codexHint", "观察运动、症状标签和诊断数据。"))
	hint_label.custom_minimum_size = Vector2(0, 54)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.max_lines_visible = 3
	_apply_hud_label_style(hint_label, GAME_UI_TEXT_SECONDARY, 12, 1)
	text_box.add_child(hint_label)

	return card


func _enemy_codex_preview_texture(enemy_type: String) -> Texture2D:
	var texture = enemy_anim_sheets.get(enemy_type, null)
	if texture == null:
		texture = enemy_anim_sheets.get("unknown_fault", null)
	if texture == null:
		return null
	var sheet := texture as Texture2D
	var frame_size := Vector2(float(sheet.get_width()) / float(ENEMY_ANIM_COLUMNS), float(sheet.get_height()) / float(ENEMY_ANIM_ROWS))
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2.ZERO, frame_size)
	return atlas


func _make_platform_panel_style(bg_color: Color = PLATFORM_SURFACE_CARD, border_color: Color = PLATFORM_BORDER, radius: int = 12) -> StyleBox:
	if _uses_ps_light_ui():
		return _make_ps_surface_style(maxi(radius, 14), 14, false, true)
	var texture_style := _make_hud_texture_style("panel", 18, 14, Color(1, 1, 1, 0.92))
	if texture_style != null:
		return texture_style
	return _make_flat_panel_style(bg_color, border_color, radius, 14)


func _make_game_panel_style(bg_color: Color = GAME_UI_PANEL, border_color: Color = GAME_UI_BORDER, radius: int = 8) -> StyleBox:
	if _uses_ps_light_ui():
		return _make_ps_surface_style(20, 18, false, true)
	var texture_style := _make_hud_texture_style("panel", 22, 18, Color(1, 1, 1, 1.0))
	if texture_style != null:
		return texture_style
	return _make_flat_panel_style(bg_color, border_color, radius, 18)


func _make_flat_panel_style(bg_color: Color, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0.000, 0.000, 0.000, 0.32)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 5)
	return style


func _make_ps_surface_style(radius: int, margin: int, focused: bool = false, elevated: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PS_UI_SURFACE
	style.border_color = PS_UI_ACCENT if focused else PS_UI_BORDER
	style.set_border_width_all(2 if focused else 1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0.055, 0.085, 0.140, 0.17 if elevated else 0.10)
	style.shadow_size = 16 if elevated else 7
	style.shadow_offset = Vector2(0, 5 if elevated else 2)
	return style


func _make_map_menu_panel_style() -> StyleBox:
	if _uses_ps_light_ui():
		return _make_ps_surface_style(20, 36, false, true)
	var texture_style := _make_hud_texture_style("dialog", 24, 36, Color(1, 1, 1, 0.98))
	if texture_style != null:
		return texture_style
	var style := _make_flat_panel_style(GAME_UI_PANEL, GAME_UI_BORDER, 8, 36)
	style.shadow_size = 18
	return style


func _make_center_hud_panel_style(bg_color: Color, border_color: Color, radius: int) -> StyleBox:
	if _uses_ps_light_ui():
		return _make_ps_surface_style(20, 34, border_color == GAME_UI_ACCENT, true)
	var texture_style := _make_hud_texture_style("panel", 22, 34, Color(1, 1, 1, 0.98))
	if texture_style != null:
		return texture_style
	return _make_flat_panel_style(bg_color, border_color, radius, 34)


func _make_hud_texture_style(texture_id: String, texture_margin: int, content_margin: int, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	if _uses_ps_light_ui():
		return null
	var texture = hud_textures.get(texture_id, null)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture as Texture2D
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.set_content_margin(SIDE_LEFT, content_margin)
	style.set_content_margin(SIDE_TOP, content_margin)
	style.set_content_margin(SIDE_RIGHT, content_margin)
	style.set_content_margin(SIDE_BOTTOM, content_margin)
	style.modulate_color = modulate
	return style


func _make_status_tray_style() -> StyleBox:
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(2)
	return style


func _make_text_plate_style(content_margin: int = 8, modulate: Color = Color.WHITE) -> StyleBox:
	if _uses_ps_light_ui():
		var ps_style := _make_ps_surface_style(16, content_margin, true, false)
		ps_style.bg_color.a *= modulate.a
		ps_style.border_color.a *= modulate.a
		return ps_style
	var texture_style := _make_hud_texture_style("text_plate", 18, content_margin, modulate)
	if texture_style != null:
		return texture_style
	var style := _make_flat_panel_style(Color(0.990, 0.998, 1.000, 0.98), Color(0.22, 0.58, 0.64, 0.16), 8, content_margin)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_text_chip_style(content_margin: int = 4, modulate: Color = Color.WHITE) -> StyleBox:
	if _uses_ps_light_ui():
		var ps_style := _make_ps_surface_style(10, content_margin, false, false)
		ps_style.bg_color.a *= modulate.a
		ps_style.border_color.a *= modulate.a
		ps_style.shadow_color.a *= modulate.a
		return ps_style
	var texture_style := _make_hud_texture_style("text_chip", 16, content_margin, modulate)
	if texture_style != null:
		return texture_style
	var style := _make_flat_panel_style(Color(0.990, 0.998, 1.000, 0.92), Color(0.22, 0.58, 0.64, 0.14), 16, content_margin)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 1)
	return style


func _make_section_card_style(content_margin: int = 8, modulate: Color = Color.WHITE) -> StyleBox:
	if _uses_ps_light_ui():
		var ps_style := _make_ps_surface_style(14, content_margin, false, false)
		ps_style.bg_color = PS_UI_SURFACE_MUTED
		ps_style.bg_color.a *= modulate.a
		return ps_style
	var texture_style := _make_hud_texture_style("section_card", 20, content_margin, modulate)
	if texture_style != null:
		return texture_style
	var style := _make_flat_panel_style(Color(0.965, 0.982, 0.992, 0.98), Color(0.55, 0.68, 0.74, 0.28), 22, content_margin)
	style.shadow_color = Color(0.06, 0.14, 0.20, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _game_canvas_rect() -> Rect2:
	return Rect2(Vector2.ZERO, DESIGN_SIZE)


func _background_draw_rect() -> Rect2:
	return _game_canvas_rect()


func _hud_background_draw_rect() -> Rect2:
	return _game_canvas_rect()


func _hud_panel_rect() -> Rect2:
	return HUD_PANEL_RECT


func _hud_shell_rect() -> Rect2:
	return HUD_SHELL_RECT


func _hud_screen_rect() -> Rect2:
	return HUD_SCREEN_RECT


func _hud_screen_corner_radius() -> int:
	return HUD_SCREEN_CORNER_RADIUS


func _hud_shell_palette() -> Dictionary:
	return {
		"frame": HUD_SHELL_FRAME_COLOR,
		"screen": HUD_SCREEN_COLOR,
		"border": HUD_SCREEN_BORDER_COLOR,
	}


func _slot_marker_center(slot_pos: Vector2) -> Vector2:
	return Vector2(roundf(slot_pos.x), roundf(slot_pos.y))


func _slot_cross_rects(slot_pos: Vector2) -> Array:
	var center := _slot_marker_center(slot_pos)
	var arm_length := 12.0
	var thickness := 2.0
	var half_length := arm_length * 0.5
	var half_thickness := thickness * 0.5
	return [
		Rect2(center - Vector2(half_length, half_thickness), Vector2(arm_length, thickness)),
		Rect2(center - Vector2(half_thickness, half_length), Vector2(thickness, arm_length))
	]


func _empty_slot_marker_style() -> Dictionary:
	return {
		"runtimeRingCount": 0,
		"crossAlpha": 0.18,
	}


func _add_hud_section_card(parent: VBoxContainer, section_id: String, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.set_meta("hud_section_id", section_id)
	card.clip_contents = true
	var continuous_group_style := StyleBoxEmpty.new()
	continuous_group_style.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", continuous_group_style)
	parent.add_child(card)
	hud_section_cards[section_id] = card
	var section := _make_hud_section(section_id, title)
	card.add_child(section)
	return section


func _make_hud_section(section_id: String, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.set_meta("hud_section_id", section_id)
	section.add_theme_constant_override("separation", 3)
	var title_plate := PanelContainer.new()
	title_plate.custom_minimum_size = Vector2(0, 26)
	title_plate.clip_contents = true
	var title_style := StyleBoxEmpty.new()
	title_style.set_content_margin(SIDE_LEFT, 10)
	title_style.set_content_margin(SIDE_TOP, 2)
	title_style.set_content_margin(SIDE_RIGHT, 10)
	title_style.set_content_margin(SIDE_BOTTOM, 2)
	title_plate.add_theme_stylebox_override("panel", title_style)
	var title_label := Label.new()
	title_label.text = title
	title_label.custom_minimum_size = Vector2(0, 18)
	title_label.max_lines_visible = 1
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if section_id == "feedback":
		title_label.custom_minimum_size = Vector2(0, 18)
		_apply_hud_label_style(title_label, GAME_UI_TEXT, 12, 2)
		hud_feedback_title_label = title_label
	else:
		_apply_hud_label_style(title_label, GAME_UI_ACCENT if section_id == "action" else GAME_UI_TEXT_SECONDARY, 12, 2)
	title_plate.add_child(title_label)
	section.add_child(title_plate)
	return section


func _hud_section_order() -> Array:
	var order := []
	var side_root := _side_hud_root()
	if side_root == null:
		return order
	for child in side_root.get_children():
		if child.has_meta("hud_section_id"):
			order.append(str(child.get_meta("hud_section_id")))
	return order


func _side_hud_root() -> Node:
	if side_hud_content_frame != null and side_hud_content_frame.get_child_count() > 0:
		return side_hud_content_frame.get_child(0)
	if side_panel != null and side_panel.get_child_count() > 0:
		var first_child := side_panel.get_child(0)
		if first_child is MarginContainer and first_child.get_child_count() > 0:
			return first_child.get_child(0)
		return first_child
	return null


func _apply_platform_button_style(button: Button, primary: bool = false, selected: bool = false) -> void:
	_apply_game_button_style(button, primary, selected)


func _apply_game_button_style(button: Button, primary: bool = false, selected: bool = false) -> void:
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var normal := _make_hud_button_style(primary, selected, Color(1, 1, 1, 1.0))
	var hover := _make_hud_button_style(primary, true, Color(1.10, 1.18, 1.16, 1.0))
	var pressed := _make_hud_button_style(primary, selected, Color(0.78, 0.88, 0.86, 1.0))
	var disabled := _make_hud_button_style(false, false, Color(1.0, 1.0, 1.0, 0.92))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	var text_color := PS_UI_TEXT if _uses_ps_light_ui() else GAME_UI_TEXT
	var focus_color := PS_UI_ACCENT.darkened(0.18) if _uses_ps_light_ui() else Color(0.040, 0.120, 0.160, 0.98)
	var disabled_color := PS_UI_TEXT_MUTED if _uses_ps_light_ui() else Color(0.42, 0.50, 0.54, 0.62)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", focus_color)
	button.add_theme_color_override("font_pressed_color", focus_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)
	button.add_theme_font_override("font", _hud_display_font(primary or selected))
	button.add_theme_font_size_override("font_size", 15 if primary else 14)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	button.add_theme_constant_override("outline_size", 0)


func _apply_hud_label_style(label: Label, color: Color, size: int, emphasis: int = 1) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := _hud_readable_font(false)
	if _uses_ps_light_ui():
		font = _hud_display_font(emphasis >= 2)
	elif emphasis >= 3:
		font = _hud_tech_font(true)
	elif emphasis >= 2:
		font = _hud_display_font(true)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", _resolved_ui_text_color(color))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size", 0)


func _apply_body_art_label_style(label: Label, color: Color, size: int, strong: bool = false) -> void:
	_apply_hud_label_style(label, color, size, 1)
	label.add_theme_font_override("font", _hud_display_font(strong) if _uses_ps_light_ui() else _hud_readable_font(false))


func _resolved_ui_text_color(color: Color) -> Color:
	if !_uses_ps_light_ui():
		return color
	if color == GAME_UI_ACCENT:
		return PS_UI_ACCENT
	if color == GAME_UI_DANGER:
		return PS_UI_DANGER
	if color == GAME_UI_TEXT_SECONDARY:
		return PS_UI_TEXT_SECONDARY
	if color == GAME_UI_TEXT_MUTED:
		return PS_UI_TEXT_MUTED
	if color == GAME_UI_TEXT:
		return PS_UI_TEXT
	return color


func _apply_watch_readout_label_style(label: Label, size: int) -> void:
	_apply_hud_label_style(label, PS_UI_TEXT if _uses_ps_light_ui() else Color(0.045, 0.105, 0.135, 0.98), size, 1)
	label.add_theme_font_override("font", _hud_display_font(false) if _uses_ps_light_ui() else _hud_readable_font(false))
	label.add_theme_constant_override("line_spacing", 1)


func _apply_level_info_label_style(label: Label, size: int) -> void:
	_apply_watch_readout_label_style(label, size)
	label.add_theme_font_override("font", _hud_display_font(true))


func _apply_status_banner_label_style(label: Label) -> void:
	_apply_hud_label_style(label, PS_UI_TEXT if _uses_ps_light_ui() else Color(0.060, 0.150, 0.175, 0.96), 21, 1)
	label.add_theme_font_override("font", _hud_display_font(true) if _uses_ps_light_ui() else _hud_body_art_font(true))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", 1)


func _make_hud_button_style(primary: bool, selected: bool, modulate: Color) -> StyleBox:
	if _uses_ps_light_ui():
		var ps_style := StyleBoxFlat.new()
		var is_hover := modulate.r > 1.0
		var is_pressed := modulate.r < 0.90
		var is_disabled := modulate.a < 0.95
		ps_style.bg_color = PS_UI_SURFACE_HOVER if is_hover else (Color("#DDE8FC") if is_pressed else (PS_UI_SURFACE_MUTED if is_disabled else PS_UI_SURFACE))
		ps_style.border_color = PS_UI_ACCENT if primary or selected or is_hover else PS_UI_BORDER
		ps_style.set_border_width_all(2 if primary or selected or is_hover else 1)
		ps_style.set_corner_radius_all(12)
		ps_style.set_content_margin_all(10)
		ps_style.shadow_color = Color(0.10, 0.30, 0.62, 0.16 if primary or selected else 0.09)
		ps_style.shadow_size = 8 if primary or selected else 4
		ps_style.shadow_offset = Vector2(0, 3 if primary or selected else 1)
		return ps_style
	var texture_key := "button_primary" if primary else "button"
	var texture_style := _make_hud_texture_style(texture_key, 18, 10, modulate)
	if texture_style != null:
		return texture_style
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.820, 0.965, 0.930, 0.96) if primary else (Color(0.850, 0.970, 0.980, 0.94) if selected else GAME_UI_PANEL_SOFT)
	normal.border_color = GAME_UI_ACCENT if primary else (GAME_UI_BORDER if selected else GAME_UI_BORDER_MUTED)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(22)
	normal.set_content_margin_all(10)
	normal.shadow_color = Color(0.060, 0.160, 0.180, 0.16)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 2)
	return normal


func _build_quiz_panel() -> void:
	quiz_panel = PanelContainer.new()
	quiz_panel.visible = false
	quiz_panel.position = Vector2(250, 135)
	quiz_panel.size = Vector2(680, 460)
	quiz_panel.clip_contents = true
	var quiz_style := _make_hud_texture_style("dialog", 24, 38, Color(1, 1, 1, 0.98))
	var quiz_fallback: StyleBox = _make_ps_surface_style(20, 38, false, true) if _uses_ps_light_ui() else _make_flat_panel_style(GAME_UI_PANEL, GAME_UI_BORDER, 8, 38)
	quiz_panel.add_theme_stylebox_override("panel", quiz_style if quiz_style != null else quiz_fallback)
	add_child(quiz_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	quiz_panel.add_child(box)

	quiz_title = Label.new()
	quiz_title.text = "波间知识校验"
	_apply_hud_label_style(quiz_title, GAME_UI_ACCENT, 26, 2)
	box.add_child(quiz_title)

	quiz_prompt = Label.new()
	quiz_prompt.text = ""
	quiz_prompt.custom_minimum_size = Vector2(0, 52)
	quiz_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quiz_prompt.max_lines_visible = 2
	_apply_body_art_label_style(quiz_prompt, GAME_UI_TEXT, 18, true)
	box.add_child(quiz_prompt)

	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 48)
		_apply_platform_button_style(button, false)
		button.add_theme_font_override("font", _hud_display_font(true) if _uses_ps_light_ui() else _hud_readable_font(true))
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(answer_quiz.bind(i))
		box.add_child(button)
		quiz_buttons.append(button)

	quiz_feedback = Label.new()
	quiz_feedback.text = ""
	quiz_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_body_art_label_style(quiz_feedback, GAME_UI_TEXT_SECONDARY, 15)
	box.add_child(quiz_feedback)


func _popup_motion_controls() -> Array:
	return [
		main_menu_panel,
		level_select_panel,
		diagnosis_tutorial_popup,
		slot_menu_panel,
		diagnostic_menu_panel,
		codex_popup,
		quiz_panel,
	]


func _popup_open_total_duration() -> float:
	return POPUP_OPEN_MATERIALIZE_DURATION + POPUP_OPEN_SETTLE_DURATION


func _popup_close_duration() -> float:
	return POPUP_CLOSE_MATERIALIZE_DURATION


func _popup_motion_profile() -> Dictionary:
	return {
		"name": "liquid_expand",
		"startScale": POPUP_START_SCALE,
		"overshootScale": POPUP_OVERSHOOT_SCALE,
		"closeScale": POPUP_CLOSE_SCALE,
		"openDuration": _popup_open_total_duration(),
		"closeDuration": _popup_close_duration(),
	}


func _slot_menu_item_origin() -> Vector2:
	var panel_size := slot_menu_panel.size if slot_menu_panel != null else Vector2(300, 300)
	return panel_size * 0.5 - Vector2(44, 44)


func _slot_menu_motion_profile() -> Dictionary:
	return {
		"name": "radial_emit",
		"origin": _slot_menu_item_origin(),
		"itemDuration": SLOT_MENU_RADIAL_ITEM_DURATION,
		"stagger": SLOT_MENU_RADIAL_STAGGER,
		"openDuration": SLOT_MENU_RADIAL_ITEM_DURATION + SLOT_MENU_RADIAL_STAGGER * 3.0,
		"closeDuration": SLOT_MENU_RADIAL_CLOSE_DURATION,
		"startScale": SLOT_MENU_RADIAL_START_SCALE,
	}


func _stop_slot_menu_motion() -> void:
	if slot_menu_motion_tween != null:
		slot_menu_motion_tween.kill()
		slot_menu_motion_tween = null


func _animate_slot_menu_in() -> void:
	if slot_menu_panel == null:
		return
	_stop_slot_menu_motion()
	var origin := _slot_menu_item_origin()
	var tower_ids := ["i2c", "filter", "peak", "power"]
	for tower_id in tower_ids:
		var entry := slot_menu_buttons.get(tower_id, {}) as Dictionary
		var item := entry.get("item") as Control
		var button := entry.get("button") as Button
		if item == null:
			continue
		item.position = origin
		item.pivot_offset = item.size * 0.5
		item.scale = SLOT_MENU_RADIAL_START_SCALE
		item.modulate = SLOT_MENU_RADIAL_START_TINT
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot_menu_backdrop != null:
		slot_menu_backdrop.pivot_offset = slot_menu_backdrop.size * 0.5
		slot_menu_backdrop.scale = Vector2(0.82, 0.82)
		slot_menu_backdrop.modulate = Color(0.84, 1.0, 1.04, 0.28)
	if slot_menu_title != null:
		slot_menu_title.modulate = Color(1, 1, 1, 0.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	slot_menu_motion_tween = tween
	for index in range(tower_ids.size()):
		var entry := slot_menu_buttons.get(tower_ids[index], {}) as Dictionary
		var item := entry.get("item") as Control
		if item == null:
			continue
		var target := entry.get("targetPosition", item.position) as Vector2
		var delay := float(index) * SLOT_MENU_RADIAL_STAGGER
		tween.tween_property(item, "position", target, SLOT_MENU_RADIAL_ITEM_DURATION).set_delay(delay).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(item, "scale", Vector2.ONE, SLOT_MENU_RADIAL_ITEM_DURATION * 0.88).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(item, "modulate", Color.WHITE, SLOT_MENU_RADIAL_ITEM_DURATION * 0.72).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if slot_menu_backdrop != null:
		tween.tween_property(slot_menu_backdrop, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot_menu_backdrop, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if slot_menu_title != null:
		tween.tween_property(slot_menu_title, "modulate", Color.WHITE, 0.14).set_delay(0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_slot_menu_motion_in.bind(tween))


func _finish_slot_menu_motion_in(tween: Tween) -> void:
	if slot_menu_motion_tween != tween:
		return
	slot_menu_motion_tween = null
	for tower_id in ["i2c", "filter", "peak", "power"]:
		var entry := slot_menu_buttons.get(tower_id, {}) as Dictionary
		var item := entry.get("item") as Control
		var button := entry.get("button") as Button
		if item != null:
			item.position = entry.get("targetPosition", item.position) as Vector2
			item.scale = Vector2.ONE
			item.modulate = Color.WHITE
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_STOP
	if slot_menu_backdrop != null:
		slot_menu_backdrop.scale = Vector2.ONE
		slot_menu_backdrop.modulate = Color.WHITE
	if slot_menu_title != null:
		slot_menu_title.modulate = Color.WHITE


func _animate_slot_menu_out() -> void:
	if slot_menu_panel == null or !slot_menu_panel.visible:
		return
	_stop_slot_menu_motion()
	var origin := _slot_menu_item_origin()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	slot_menu_motion_tween = tween
	for tower_id in ["i2c", "filter", "peak", "power"]:
		var entry := slot_menu_buttons.get(tower_id, {}) as Dictionary
		var item := entry.get("item") as Control
		var button := entry.get("button") as Button
		if item == null:
			continue
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tween.tween_property(item, "position", origin, SLOT_MENU_RADIAL_CLOSE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(item, "scale", SLOT_MENU_RADIAL_START_SCALE, SLOT_MENU_RADIAL_CLOSE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(item, "modulate", SLOT_MENU_RADIAL_START_TINT, SLOT_MENU_RADIAL_CLOSE_DURATION * 0.82).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if slot_menu_backdrop != null:
		tween.tween_property(slot_menu_backdrop, "scale", Vector2(0.84, 0.84), SLOT_MENU_RADIAL_CLOSE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tween.tween_property(slot_menu_backdrop, "modulate", Color(0.84, 1.0, 1.04, 0.0), SLOT_MENU_RADIAL_CLOSE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if slot_menu_title != null:
		tween.tween_property(slot_menu_title, "modulate", Color(1, 1, 1, 0.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish_slot_menu_motion_out.bind(tween))


func _finish_slot_menu_motion_out(tween: Tween) -> void:
	if slot_menu_motion_tween != tween:
		return
	slot_menu_motion_tween = null


func _stop_popup_motion(popup: Control) -> void:
	if popup == null:
		return
	var popup_id := popup.get_instance_id()
	var active_tween = popup_motion_tweens.get(popup_id)
	if active_tween is Tween:
		(active_tween as Tween).kill()
	popup_motion_tweens.erase(popup_id)


func _animate_popup_in(popup: Control) -> void:
	if popup == null:
		return
	_stop_popup_motion(popup)
	popup.visible = true
	popup.pivot_offset = popup.size * 0.5
	popup.scale = POPUP_START_SCALE
	popup.modulate = POPUP_START_TINT
	var popup_id := popup.get_instance_id()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	popup_motion_tweens[popup_id] = tween
	tween.tween_property(popup, "scale", POPUP_OVERSHOOT_SCALE, POPUP_OPEN_MATERIALIZE_DURATION).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate", POPUP_OVERSHOOT_TINT, POPUP_OPEN_MATERIALIZE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2.ONE, POPUP_OPEN_SETTLE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate", Color.WHITE, POPUP_OPEN_SETTLE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_popup_motion_in.bind(popup, popup_id, tween))


func _finish_popup_motion_in(popup: Control, popup_id: int, tween: Tween) -> void:
	if popup_motion_tweens.get(popup_id) != tween:
		return
	popup_motion_tweens.erase(popup_id)
	if !is_instance_valid(popup):
		return
	popup.scale = Vector2.ONE
	popup.modulate = Color.WHITE


func _animate_popup_out(popup: Control) -> void:
	if popup == null:
		return
	_stop_popup_motion(popup)
	if !popup.visible:
		popup.scale = Vector2.ONE
		popup.modulate = Color.WHITE
		return
	popup.pivot_offset = popup.size * 0.5
	var popup_id := popup.get_instance_id()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	popup_motion_tweens[popup_id] = tween
	tween.tween_property(popup, "scale", POPUP_CLOSE_SCALE, POPUP_CLOSE_MATERIALIZE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(popup, "modulate", POPUP_CLOSE_TINT, POPUP_CLOSE_MATERIALIZE_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish_popup_motion_out.bind(popup, popup_id, tween))


func _finish_popup_motion_out(popup: Control, popup_id: int, tween: Tween) -> void:
	if popup_motion_tweens.get(popup_id) != tween:
		return
	popup_motion_tweens.erase(popup_id)
	if !is_instance_valid(popup):
		return
	popup.visible = false
	popup.scale = Vector2.ONE
	popup.modulate = Color.WHITE
	if popup == slot_menu_panel:
		slot_menu_closing = false


func _on_session_initialized(session: Dictionary) -> void:
	var config: Dictionary = session.get("config", {})
	max_leaks = maxi(1, int(config.get("max_leaks", MAX_LEAKS)))
	var knowledge: Dictionary = session.get("knowledge", {})
	var loaded_questions = knowledge.get("questions", [])
	if typeof(loaded_questions) == TYPE_ARRAY and !loaded_questions.is_empty():
		questions = loaded_questions
	var data: Dictionary = session.get("data", {})
	var injected_waves = data.get("waves", [])
	if typeof(injected_waves) == TYPE_ARRAY and !injected_waves.is_empty():
		waves = injected_waves
	runtime.log_info("Ch11 band defense initialized.")
	_report_progress("场景已就绪")
	_update_ui()


func _on_custom_command(type: String, _payload: Dictionary) -> void:
	if type == "DGB_GODOT_RECORDING_DEMO":
		_start_recording_demo()


func show_main_menu() -> void:
	state = "main_menu"
	run_started = false
	completed = false
	current_level = 1
	current_wave = 0
	energy = 90
	selected_tower_id = "i2c"
	selected_slot_index = -1
	enemies.clear()
	spawn_queue.clear()
	feedbacks.clear()
	attack_effects.clear()
	_clear_enemy_hit_feedback()
	diagnosed_enemy_types.clear()
	_close_slot_menu()
	_close_diagnostic_menu()
	_hide_codex_popup()
	if diagnosis_tutorial_popup != null:
		_animate_popup_out(diagnosis_tutorial_popup)
	if quiz_panel != null:
		_animate_popup_out(quiz_panel)
	if main_menu_panel != null:
		_animate_popup_in(main_menu_panel)
	if level_select_panel != null:
		_animate_popup_out(level_select_panel)
	if side_panel != null:
		side_panel.visible = false
	if result_label != null:
		result_label.text = ""
		result_label.visible = false
	if diagnostic_label != null:
		diagnostic_label.text = "选择入口后开始调试数据链路防线。"
	if start_button != null:
		start_button.text = "从总菜单开始"
	status_label.text = "互动练习 / Alpha：选择闯关或选关"
	_apply_level_layout(current_level)
	_update_ui()


func show_level_select() -> void:
	state = "level_select"
	_close_slot_menu()
	_close_diagnostic_menu()
	_hide_codex_popup()
	if diagnosis_tutorial_popup != null:
		_animate_popup_out(diagnosis_tutorial_popup)
	if main_menu_panel != null:
		_animate_popup_out(main_menu_panel)
	if level_select_panel != null:
		_animate_popup_in(level_select_panel)
	if side_panel != null:
		side_panel.visible = false
	status_label.text = "选择要直接测试的关卡。"
	if diagnostic_label != null:
		diagnostic_label.text = "选关会保留本关地图和波次；第 2/3 关默认开放全部塔。"
	_update_ui()


func select_level(level_number: int) -> void:
	_prepare_level_intro(level_number)


func _prepare_level_intro(level_number: int) -> void:
	state = "intro"
	run_started = false
	completed = false
	current_level = clampi(level_number, 1, _max_level_number())
	if side_panel != null:
		side_panel.visible = true
	current_wave = 0
	trusted_data = 0
	leaks = 0
	link_stability = 100
	correct_count = 0
	wrong_count = 0
	band_score = 0
	question_index = 0
	selected_tower_id = "i2c"
	selected_slot_index = -1
	enemies.clear()
	spawn_queue.clear()
	feedbacks.clear()
	attack_effects.clear()
	_clear_enemy_hit_feedback()
	current_wave_stats.clear()
	diagnosed_enemy_types.clear()
	_apply_level_layout(current_level)
	for i in range(tower_slots.size()):
		tower_slots[i]["tower"] = null
	if current_level == 1:
		energy = 90
		unlocked = {"i2c": true, "filter": true, "peak": false, "power": false}
	else:
		energy = 160
		unlocked = {"i2c": true, "filter": true, "peak": true, "power": true}
	_reset_level_stats(current_level)
	_close_slot_menu()
	_close_diagnostic_menu()
	_hide_codex_popup()
	if diagnosis_tutorial_popup != null:
		_animate_popup_out(diagnosis_tutorial_popup)
	if quiz_panel != null:
		_animate_popup_out(quiz_panel)
	if main_menu_panel != null:
		_animate_popup_out(main_menu_panel)
	if level_select_panel != null:
		_animate_popup_out(level_select_panel)
	if result_label != null:
		result_label.text = ""
		result_label.visible = false
	if diagnostic_label != null:
		diagnostic_label.text = "关卡准备：链路模块待部署。"
	status_label.text = LevelLayouts.intro_text_for_level(current_level)
	if start_button != null:
		start_button.text = "开始第 %d 关" % current_level
		start_button.disabled = false
	_update_ui()
	_report_progress("第 %d 关准备" % current_level)


func start_game() -> void:
	if state == "result":
		_reset()
	_close_slot_menu()
	_close_diagnostic_menu()
	_hide_codex_popup()
	if main_menu_panel != null:
		_animate_popup_out(main_menu_panel)
	if level_select_panel != null:
		_animate_popup_out(level_select_panel)
	if side_panel != null:
		side_panel.visible = true
	if !run_started:
		if runtime != null:
			runtime.begin_attempt()
		var level_to_start := 1 if state == "main_menu" or state == "level_select" else current_level
		run_started = true
		completed = false
		started_at = Time.get_ticks_msec()
		current_level = level_to_start
		current_wave = 0
		waves_cleared = 0
		cleared_wave_keys.clear()
		trusted_data = 0
		leaks = 0
		link_stability = 100
		correct_count = 0
		wrong_count = 0
		band_score = 0
		question_index = 0
		diagnosed_enemy_types.clear()
		_apply_level_layout(current_level)
		_reset_level_stats(current_level)
	var has_prebuilt_tower := false
	for slot in tower_slots:
		if (slot as Dictionary)["tower"] != null:
			has_prebuilt_tower = true
			break
	state = "wave_running"
	leaks = 0
	link_stability = 100
	if !has_prebuilt_tower:
		energy = 90 if current_level == 1 else maxi(energy, 130)
		selected_tower_id = "i2c"
		for i in range(tower_slots.size()):
			tower_slots[i]["tower"] = null
		if current_level == 1:
			unlocked = {"i2c": true, "filter": true, "peak": false, "power": false}
		else:
			unlocked = {"i2c": true, "filter": true, "peak": true, "power": true}
	enemies.clear()
	feedbacks.clear()
	attack_effects.clear()
	_clear_enemy_hit_feedback()
	_start_next_wave()


func _slot_at_position(point: Vector2) -> int:
	for i in range(tower_slots.size()):
		var slot := tower_slots[i] as Dictionary
		if point.distance_to(slot["pos"] as Vector2) <= 48.0:
			return i
	return -1


func _open_slot_menu(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= tower_slots.size():
		return
	slot_menu_closing = false
	selected_slot_index = slot_index
	var slot := tower_slots[slot_index] as Dictionary
	var pos := slot["pos"] as Vector2
	var panel_size := Vector2(300, 300)
	var desired := pos - panel_size * 0.5
	var view_size := get_viewport_rect().size
	desired.x = clampf(desired.x, 16.0, maxf(16.0, view_size.x - panel_size.x - 16.0))
	desired.y = clampf(desired.y, 84.0, maxf(84.0, view_size.y - panel_size.y - 16.0))
	slot_menu_panel.position = desired
	slot_menu_panel.size = panel_size
	if slot_menu_backdrop != null:
		slot_menu_backdrop.size = panel_size
		slot_menu_backdrop.queue_redraw()
	_animate_popup_in(slot_menu_panel)
	_update_slot_menu()
	_animate_slot_menu_in()
	_refresh_tutorial()
	queue_redraw()


func _close_slot_menu() -> void:
	selected_slot_index = -1
	if slot_menu_panel != null and slot_menu_panel.visible and !slot_menu_closing:
		slot_menu_closing = true
		_animate_slot_menu_out()
		_animate_popup_out(slot_menu_panel)
	_refresh_tutorial()
	queue_redraw()


func _update_slot_menu() -> void:
	if slot_menu_panel == null or !slot_menu_panel.visible:
		return
	if selected_slot_index < 0 or selected_slot_index >= tower_slots.size():
		_close_slot_menu()
		return
	var slot := tower_slots[selected_slot_index] as Dictionary
	var occupied := slot["tower"] != null
	slot_menu_title.text = "塔位 %d\n%s" % [selected_slot_index + 1, "升级" if occupied else "建造"]
	for tower_id in slot_menu_buttons.keys():
		var entry := slot_menu_buttons[tower_id] as Dictionary
		var button := entry["button"] as Button
		var def := tower_defs[tower_id] as Dictionary
		var is_unlocked := bool(unlocked.get(tower_id, false))
		var cost := int(def["cost"])
		var label_text := "%s\n%d" % [str(def["label"]), cost]
		button.disabled = false
		if !is_unlocked:
			label_text = "%s\n未解锁" % str(def["label"])
			button.disabled = true
		elif !occupied:
			button.disabled = energy < cost
			if energy < cost:
				label_text = "%s\n能量不足" % str(def["label"])
		else:
			var tower := slot["tower"] as Dictionary
			if str(tower["id"]) != tower_id:
				label_text = "%s\n已占用" % str(def["label"])
				button.disabled = true
			elif int(tower.get("level", 1)) >= 3:
				label_text = "%s\n已满级" % str(def["label"])
				button.disabled = true
			else:
				var upgrade_cost := _tower_upgrade_cost(def, int(tower.get("level", 1)))
				label_text = "%s\n升级 %d" % [str(def["label"]), upgrade_cost]
				button.disabled = energy < upgrade_cost
				if energy < upgrade_cost:
					label_text = "%s\n能量不足" % str(def["label"])
		button.text = label_text
		_apply_slot_menu_button_style(button, def["color"], button.disabled)


func _apply_slot_menu_button_style(button: Button, base_color: Color, disabled: bool) -> void:
	var fill := Color(0.965, 0.988, 0.995, 0.97)
	var accent := Color(base_color.r, base_color.g, base_color.b, 0.78)
	var text_color := Color(0.055, 0.105, 0.12)
	if disabled:
		fill = Color(0.90, 0.925, 0.935, 0.92)
		accent = Color(0.52, 0.59, 0.61, 0.48)
		text_color = Color(0.36, 0.43, 0.45)
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.border_blend = true
	normal.set_corner_radius_all(35)
	normal.set_content_margin_all(5.0)
	normal.shadow_color = Color(0.02, 0.08, 0.10, 0.15)
	normal.shadow_size = 9
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.925, 0.985, 0.995, 0.99) if not disabled else fill
	hover.border_color = Color(base_color.r, base_color.g, base_color.b, 0.96) if not disabled else accent
	hover.shadow_size = 11
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.86, 0.95, 0.965, 0.98) if not disabled else fill
	pressed.shadow_size = 5
	pressed.shadow_offset = Vector2(0, 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_font_override("font", _hud_display_font(false))
	button.add_theme_font_size_override("font_size", 14)
	button.set_meta("slot_glass_style", true)
	button.set_meta("slot_accent_color", base_color)


func _on_slot_menu_tower_pressed(tower_id: String) -> void:
	if selected_slot_index < 0:
		return
	build_tower(selected_slot_index, tower_id)
	_close_slot_menu()


func build_tower(slot_index: int, tower_id: String) -> void:
	if state != "intro" and state != "wave_running":
		return
	if slot_index < 0 or slot_index >= tower_slots.size():
		return
	if !tower_defs.has(tower_id) or !unlocked.get(tower_id, false):
		_add_feedback("未解锁", tower_slots[slot_index]["pos"], Color(0.95, 0.28, 0.28))
		return
	var def := tower_defs[tower_id] as Dictionary
	var slot := tower_slots[slot_index] as Dictionary
	if slot["tower"] == null:
		var cost := int(def["cost"])
		if energy < cost:
			_add_feedback("能量不足", slot["pos"], Color(0.95, 0.28, 0.28))
			return
		energy -= cost
		slot["tower"] = {"id": tower_id, "level": 1, "cooldown": 0.0, "attackAnim": 0.0}
		_add_feedback(str(def["label"]), slot["pos"], def["color"])
	else:
		var tower := slot["tower"] as Dictionary
		if str(tower["id"]) != tower_id:
			_add_feedback("塔位已占", slot["pos"], Color(0.95, 0.28, 0.28))
			return
		if int(tower["level"]) >= 3:
			_add_feedback("已满级", slot["pos"], Color(0.95, 0.80, 0.32))
			return
		var next_level := int(tower["level"]) + 1
		var upgrade_cost := _tower_upgrade_cost(def, int(tower["level"]))
		if energy < upgrade_cost:
			_add_feedback("升级能量不足", slot["pos"], Color(0.95, 0.28, 0.28))
			return
		energy -= upgrade_cost
		tower["level"] = next_level
		tower["cooldown"] = 0.0
		_add_feedback("升级", slot["pos"], Color(0.95, 0.80, 0.32))
	_update_ui()
	_report_progress("建塔更新")


func _tower_upgrade_cost(def: Dictionary, current_level: int) -> int:
	return int(def["cost"]) + 20 * maxi(1, current_level)


func _tower_upgrade_description(tower_id: String, current_level: int) -> String:
	if !tower_defs.has(tower_id):
		return ""
	if current_level <= 1:
		match tower_id:
			"i2c":
				return "Lv2 解锁：WHO_AM_I 与寄存器校准"
			"filter":
				return "Lv2 解锁：滑动平均抑制毛刺"
			"peak":
				return "Lv2 解锁：最小步间隔捕获"
			"power":
				return "Lv2 解锁：WOM 唤醒 + STOP 门控"
			_:
				return "Lv2 解锁：模块专项模式"
	if current_level == 2:
		match tower_id:
			"i2c":
				return "Lv3 增强：上拉/ACK/总线时序复核"
			"filter":
				return "Lv3 增强：窗口与延迟平衡"
			"peak":
				return "Lv3 增强：合加速度 + 阈值联调"
			"power":
				return "Lv3 增强：低功耗状态机"
			_:
				return "Lv3 增强：伤害和效果提升"
	return "已满级"


func _active_enemy_count(threat_tag: String) -> int:
	var count := 0
	for enemy in enemies:
		var e := enemy as Dictionary
		if bool(e.get("reached", false)) or float(e.get("hp", 0.0)) <= 0.0:
			continue
		if str(e.get("threatTag", "")) == threat_tag:
			count += 1
	return count


func _tower_module_strength(tower_id: String) -> float:
	var strength := 0.0
	for slot in tower_slots:
		var tower = (slot as Dictionary).get("tower", null)
		if tower == null:
			continue
		var tower_data := tower as Dictionary
		if str(tower_data.get("id", "")) != tower_id:
			continue
		strength += float(tower_data.get("level", 1))
	return strength


func _band_link_metrics() -> Dictionary:
	var config_faults := _active_enemy_count("config")
	var noise_faults := _active_enemy_count("noise")
	var peak_faults := _active_enemy_count("false_peak")
	var power_faults := _active_enemy_count("power")
	var i2c_strength := _tower_module_strength("i2c")
	var filter_strength := _tower_module_strength("filter")
	var peak_strength := _tower_module_strength("peak")
	var power_strength := _tower_module_strength("power")
	var ack_rate := clampf(98.0 - 7.5 * float(config_faults) - 2.0 * float(leaks) + 2.2 * i2c_strength, 55.0, 99.5)
	var noise_rms := clampf(0.06 + 0.045 * float(noise_faults) + 0.012 * float(config_faults) - 0.012 * filter_strength, 0.02, 0.36)
	var step_error_rate := clampf(1.5 + 5.0 * float(peak_faults) + 1.5 * float(noise_faults) - 1.2 * peak_strength, 0.0, 24.0)
	var average_current := clampf(7.8 + 3.8 * float(power_faults) + 0.7 * float(current_wave) - 0.9 * power_strength, 3.8, 28.0)
	var wake_latency := clampf(28.0 + 9.0 * float(power_faults) + 2.0 * float(leaks) - 2.6 * power_strength, 8.0, 90.0)
	return {
		"ackRate": snappedf(ack_rate, 0.1),
		"noiseRms": snappedf(noise_rms, 0.01),
		"stepErrorRate": snappedf(step_error_rate, 0.1),
		"averageCurrent": snappedf(average_current, 0.1),
		"wakeLatency": snappedf(wake_latency, 0.1)
	}


func _band_metrics_text() -> String:
	var metrics := _band_link_metrics()
	return "链路指标\nI2C ACK率：%.1f%%\n噪声RMS：%.2f g\n误计步率：%.1f%%\n平均电流：%.1f mA\n唤醒延迟：%.1f ms" % [
		float(metrics.get("ackRate", 0.0)),
		float(metrics.get("noiseRms", 0.0)),
		float(metrics.get("stepErrorRate", 0.0)),
		float(metrics.get("averageCurrent", 0.0)),
		float(metrics.get("wakeLatency", 0.0))
	]


func _band_metrics_compact_text() -> String:
	var metrics := _band_link_metrics()
	return "应答 %.1f%%  噪声 %.2fg\n误步 %.1f%%  电流 %.1fmA\n唤醒 %.1fms  数据 %d" % [
		float(metrics.get("ackRate", 0.0)),
		float(metrics.get("noiseRms", 0.0)),
		float(metrics.get("stepErrorRate", 0.0)),
		float(metrics.get("averageCurrent", 0.0)),
		float(metrics.get("wakeLatency", 0.0)),
		trusted_data
	]


func _band_status_readout_text() -> String:
	var metrics := _band_link_metrics()
	return "应答 %.0f%% · 电流 %.1fmA" % [
		float(metrics.get("ackRate", 0.0)),
		float(metrics.get("averageCurrent", 0.0))
	]


func _band_model_nodes() -> Array:
	return band_model_nodes.duplicate(true)


func _band_model_overlay_draws_text() -> bool:
	return DRAW_BAND_MODEL_NODE_TEXT


func _empty_tower_slot_draws_text() -> bool:
	return DRAW_EMPTY_TOWER_SLOT_TEXT


func _band_model_hud_title() -> String:
	return "手环链路仪表盘"


func _tower_module_label(tower_id: String) -> String:
	if tower_defs.has(tower_id):
		var label := str((tower_defs[tower_id] as Dictionary).get("label", tower_id))
		if label == "I2C":
			return "I2C 模块"
		return "%s模块" % label
	return "%s 模块" % tower_id


func _band_model_stage_name(level_number: int, wave_number: int) -> String:
	if level_number <= 1:
		match wave_number:
			1:
				return "采集建链阶段"
			2:
				return "MCU 算法阶段"
			3:
				return "显示与功耗阶段"
	if level_number == 2:
		match wave_number:
			1:
				return "夜跑采样阶段"
			2:
				return "步态算法阶段"
			3:
				return "续航管理阶段"
	if level_number >= 3:
		match wave_number:
			1:
				return "多源接入阶段"
			2:
				return "模块联调阶段"
			3:
				return "整机验收阶段"
	return "手环链路阶段"


func _band_model_wave_title(level_number: int, wave_number: int, brief: String = "") -> String:
	var stage := _band_model_stage_name(level_number, wave_number)
	var body := brief.strip_edges()
	if body == "":
		body = "异常信号进入手环数据链路"
	return "%s：%s" % [stage, body]


func _attack_feedback_text(_tower_id: String, attack: Dictionary, _target: Dictionary) -> String:
	if bool(attack.get("matched", false)):
		return "应对！"
	return "错配！"


func _build_codex_text() -> String:
	var order := ["config", "noise", "drift_noise", "false_peak", "power_spike", "hybrid_fault"]
	var lines := ["敌人图鉴"]
	for enemy_type in order:
		if !enemy_defs.has(enemy_type):
			continue
		var def := enemy_defs[enemy_type] as Dictionary
		lines.append("- %s: %s" % [
			str(def.get("codexName", enemy_type)),
			str(def.get("codexHint", "观察它的运动和症状变化。"))
		])
	return "\n".join(lines)


func _enemy_codex_name(enemy_type: String) -> String:
	if !enemy_defs.has(enemy_type):
		return enemy_type
	return str((enemy_defs[enemy_type] as Dictionary).get("codexName", enemy_type))


func _enemy_diagnosis_profile(enemy_type: String) -> Dictionary:
	match enemy_type:
		"config":
			return {
				"symptom": "WHO_AM_I 读数异常",
				"short": "WHO_AM_I 异常",
				"methodId": "read_registers",
				"method": "读寄存器",
				"finding": "地址、WHO_AM_I 或量程配置不一致。"
			}
		"noise":
			return {
				"symptom": "波形毛刺增多",
				"short": "毛刺增多",
				"methodId": "inspect_waveform",
				"method": "看波形窗口",
				"finding": "原始加速度散点抖动，需要滤波抑噪。"
			}
		"drift_noise":
			return {
				"symptom": "基线缓慢漂移",
				"short": "基线漂移",
				"methodId": "inspect_waveform",
				"method": "看波形窗口",
				"finding": "低频偏移叠加抖动，后段可能诱发假峰值。"
			}
		"false_peak":
			return {
				"symptom": "步数突然连跳",
				"short": "步数连跳",
				"methodId": "check_threshold",
				"method": "检查阈值/最小步间隔",
				"finding": "最小步间隔过短或阈值偏低，疑似假峰值。"
			}
		"power_spike":
			return {
				"symptom": "静止时电流偏高",
				"short": "静止电流高",
				"methodId": "inspect_current",
				"method": "查看电流曲线",
				"finding": "静止电流仍有唤醒脉冲，采样或显示未进入低功耗。"
			}
		"hybrid_fault":
			return {
				"symptom": "多模块症状叠加",
				"short": "综合症状",
				"methodId": "inspect_waveform",
				"method": "看波形窗口",
				"finding": "配置、噪声、峰值和功耗会随进度切换，需要复查。"
			}
	return {
		"symptom": "未知链路异常",
		"short": "未知症状",
		"methodId": "inspect_waveform",
		"method": "观察波形和日志",
		"finding": "需要继续采集数据。"
	}


func _assign_enemy_diagnostic_fields(enemy: Dictionary, enemy_type: String) -> void:
	var profile := _enemy_diagnosis_profile(enemy_type)
	enemy["diagnosed"] = bool(diagnosed_enemy_types.get(enemy_type, false))
	enemy["symptom"] = str(profile.get("symptom", "未知链路异常"))
	enemy["symptomShort"] = str(profile.get("short", enemy["symptom"]))
	enemy["diagnosticMethodId"] = str(profile.get("methodId", "inspect_waveform"))
	enemy["diagnosticMethod"] = str(profile.get("method", "观察波形和日志"))
	enemy["diagnosticFinding"] = str(profile.get("finding", "需要继续采集数据。"))


func _enemy_display_text(enemy: Dictionary) -> String:
	if bool(enemy.get("diagnosed", false)):
		return _enemy_codex_name(str(enemy.get("type", "unknown")))
	return str(enemy.get("symptom", "未知链路异常"))


func _enemy_display_marker(enemy: Dictionary) -> String:
	if bool(enemy.get("diagnosed", false)):
		return _enemy_visual_marker(str(enemy.get("type", "unknown")))
	return "症"


func _enemy_should_draw_fault_tag(_enemy: Dictionary) -> bool:
	return false


func _enemy_should_draw_symptom_label(enemy: Dictionary, label_context: Array) -> bool:
	if !_enemy_should_draw_fault_tag(enemy):
		return false
	if bool(enemy.get("reached", false)):
		return false
	if bool(enemy.get("diagnosed", false)):
		return true
	if pending_diagnostic_enemy != null and pending_diagnostic_enemy == enemy:
		return true
	if slot_menu_panel != null and slot_menu_panel.visible:
		return false
	var pos := enemy.get("pos", Vector2.ZERO) as Vector2
	var radius_sq := ENEMY_SYMPTOM_LABEL_CLUSTER_RADIUS * ENEMY_SYMPTOM_LABEL_CLUSTER_RADIUS
	for raw_enemy in label_context:
		var other := raw_enemy as Dictionary
		if other == enemy:
			break
		if bool(other.get("reached", false)) or bool(other.get("diagnosed", false)):
			continue
		var other_pos := other.get("pos", Vector2.ZERO) as Vector2
		if pos.distance_squared_to(other_pos) <= radius_sq:
			return false
	return true


func _enemy_at_position(position: Vector2):
	var best = null
	var best_distance := DIAGNOSIS_CLICK_RADIUS
	for enemy in enemies:
		var e := enemy as Dictionary
		if bool(e.get("reached", false)) or float(e.get("hp", 0.0)) <= 0.0:
			continue
		var distance := position.distance_to(e.get("pos", Vector2.ZERO) as Vector2)
		if distance <= best_distance:
			best = e
			best_distance = distance
	return best


func _diagnose_enemy_at(position: Vector2) -> bool:
	var enemy = _enemy_at_position(position)
	if enemy == null:
		return false
	var target := enemy as Dictionary
	if bool(target.get("diagnosed", false)) or bool(diagnosed_enemy_types.get(str(target.get("type", "unknown")), false)):
		return _diagnose_enemy(target)
	_open_diagnostic_menu(target)
	return true


func _diagnose_enemy(enemy: Dictionary) -> bool:
	return _complete_enemy_diagnosis(enemy, true)


func _diagnose_enemy_with_method(enemy: Dictionary, method_id: String) -> bool:
	var enemy_type := str(enemy.get("type", "unknown"))
	if bool(enemy.get("diagnosed", false)) or bool(diagnosed_enemy_types.get(enemy_type, false)):
		enemy["diagnosed"] = true
		_show_enemy_diagnosis(enemy, false)
		_update_ui()
		queue_redraw()
		return true
	var expected := str(enemy.get("diagnosticMethodId", ""))
	if method_id != expected:
		var miss_cost := mini(DIAGNOSIS_MISS_COST, energy)
		energy -= miss_cost
		var method_label := _diagnostic_method_label(method_id)
		var text := "误诊：%s\n该检测不能解释当前症状，换一种检测手段。" % method_label
		if diagnostic_label != null:
			diagnostic_label.text = text
		_add_feedback("误诊 -%d 能量" % miss_cost, enemy.get("pos", Vector2.ZERO) as Vector2, Color(1.0, 0.70, 0.22))
		_update_ui()
		queue_redraw()
		return false
	return _complete_enemy_diagnosis(enemy, true)


func _complete_enemy_diagnosis(enemy: Dictionary, spend_energy: bool) -> bool:
	var enemy_type := str(enemy.get("type", "unknown"))
	if bool(diagnosed_enemy_types.get(enemy_type, false)):
		enemy["diagnosed"] = true
		_show_enemy_diagnosis(enemy, false)
		_update_ui()
		queue_redraw()
		return true
	if bool(enemy.get("diagnosed", false)):
		_show_enemy_diagnosis(enemy, false)
		return true
	if spend_energy and energy < DIAGNOSIS_COST:
		_add_feedback("诊断能量不足", enemy.get("pos", Vector2.ZERO) as Vector2, Color(1.0, 0.70, 0.22))
		return false
	if spend_energy:
		energy -= DIAGNOSIS_COST
	_mark_enemy_type_diagnosed(enemy_type)
	_show_enemy_diagnosis(enemy, spend_energy)
	_update_ui()
	queue_redraw()
	return true


func _choose_diagnostic_method(method_id: String) -> bool:
	if pending_diagnostic_enemy == null:
		return false
	var enemy := pending_diagnostic_enemy as Dictionary
	pending_diagnostic_method = method_id
	var report := _diagnostic_report_for_method(enemy, method_id)
	if diagnostic_data_label != null:
		diagnostic_data_label.text = report
	if diagnostic_label != null:
		diagnostic_label.text = report + "\n根据异常项选择故障类型。"
	_set_diagnostic_menu_stage("fault")
	queue_redraw()
	return true


func _choose_fault_type(enemy_type: String) -> bool:
	if pending_diagnostic_enemy == null:
		return false
	var enemy := pending_diagnostic_enemy as Dictionary
	var actual_type := str(enemy.get("type", "unknown"))
	var expected_method := str(enemy.get("diagnosticMethodId", ""))
	var method_is_supported := pending_diagnostic_method == expected_method
	if enemy_type == actual_type and method_is_supported:
		var ok := _complete_enemy_diagnosis(enemy, true)
		if ok:
			_close_diagnostic_menu()
		return ok
	var miss_cost := mini(DIAGNOSIS_MISS_COST, energy)
	energy -= miss_cost
	_add_feedback("判断错误 -%d 能量" % miss_cost, enemy.get("pos", Vector2.ZERO) as Vector2, Color(1.0, 0.70, 0.22))
	if diagnostic_label != null:
		diagnostic_label.text = "判断错误：当前数据不能支持该故障结论。\n重新选择检测手段，再根据异常项判断。"
	pending_diagnostic_method = ""
	_set_diagnostic_menu_stage("method")
	_update_ui()
	queue_redraw()
	return false


func _return_to_diagnostic_methods() -> bool:
	if pending_diagnostic_enemy == null:
		return false
	pending_diagnostic_method = ""
	_set_diagnostic_menu_stage("method")
	if diagnostic_label != null:
		var enemy := pending_diagnostic_enemy as Dictionary
		diagnostic_label.text = "待诊断：%s\n可以继续查看寄存器、波形、电流或阈值数据。" % str(enemy.get("symptom", "未知链路异常"))
	queue_redraw()
	return true


func _diagnostic_method_label(method_id: String) -> String:
	if diagnostic_methods.has(method_id):
		return str((diagnostic_methods[method_id] as Dictionary).get("label", method_id))
	return method_id


func _diagnostic_report_for_method(enemy: Dictionary, method_id: String) -> String:
	return "%s\n%s" % [_enemy_health_readout(enemy), _diagnostic_measurement_report(enemy, method_id)]


func _diagnostic_measurement_report(enemy: Dictionary, method_id: String) -> String:
	var enemy_type := str(enemy.get("type", "unknown"))
	match method_id:
		"read_registers":
			if enemy_type == "config":
				return "检测数据：读寄存器\nI2C 地址：0x68 正常\nWHO_AM_I：0x00 异常\n量程配置：±16g，与预设 ±4g 不一致\n采样率寄存器：100Hz 正常\n异常项：WHO_AM_I / 量程配置"
			return "检测数据：读寄存器\nI2C 地址：0x68 正常\nWHO_AM_I：0x71 正常\n量程配置：±4g 正常\n采样率寄存器：100Hz 正常\n异常项：无寄存器异常"
		"inspect_waveform":
			match enemy_type:
				"noise":
					return "检测数据：看波形窗口\n噪声 RMS：0.34g 异常\n毛刺计数：18 次/10s 异常\n基线漂移：0.02g 正常\n峰值密度：0.18 次/s\n异常项：毛刺与高频噪声"
				"drift_noise":
					return "检测数据：看波形窗口\n噪声 RMS：0.18g 偏高\n毛刺计数：4 次/10s\n基线漂移：+0.21g 异常\n峰值密度：0.21 次/s\n异常项：低频漂移"
				"hybrid_fault":
					return "检测数据：看波形窗口\n噪声 RMS：0.24g 异常\n毛刺计数：9 次/10s 偏高\n基线漂移：+0.12g 间歇异常\n峰值密度：0.44 次/s 偏高\n异常项：多模块症状叠加"
			return "检测数据：看波形窗口\n噪声 RMS：0.07g 正常\n毛刺计数：1 次/10s 正常\n基线漂移：+0.01g 正常\n峰值密度：0.16 次/s 正常\n异常项：无波形异常"
		"inspect_current":
			if enemy_type == "power_spike":
				return "检测数据：查看电流曲线\n静止电流：18.5mA 异常\n唤醒尖峰：9 次/10s\n平均电流：8.5mA 偏高\n低功耗窗口：未稳定进入\n异常项：静止电流与唤醒尖峰"
			return "检测数据：查看电流曲线\n静止电流：1.2mA 正常\n唤醒尖峰：1 次/10s 正常\n平均电流：2.4mA 正常\n低功耗窗口：稳定进入\n异常项：无电流异常"
		"check_threshold":
			if enemy_type == "false_peak":
				return "检测数据：检查阈值/最小步间隔\n峰值阈值：0.45g 偏低\n最小步间隔：120ms 异常\n最近间隔：90 / 110 / 160ms\n去抖窗口：40ms 偏短\n异常项：最小步间隔 / 峰值阈值"
			return "检测数据：检查阈值/最小步间隔\n峰值阈值：1.20g 正常\n最小步间隔：280ms 正常\n最近间隔：420 / 510 / 480ms\n去抖窗口：90ms 正常\n异常项：无阈值异常"
	return "检测数据：%s\nI2C 地址：0x68\n噪声 RMS：0.08g\n静止电流：1.2mA\n最小步间隔：280ms\n异常项：检测手段未定义" % _diagnostic_method_label(method_id)


func _set_diagnostic_menu_stage(stage: String) -> void:
	var choosing_fault := stage == "fault"
	for method_id in diagnostic_menu_buttons.keys():
		var button := diagnostic_menu_buttons[method_id] as Button
		button.visible = !choosing_fault
	for enemy_type in diagnostic_fault_buttons.keys():
		var button := diagnostic_fault_buttons[enemy_type] as Button
		button.visible = choosing_fault
	if diagnostic_hud_overlay != null:
		diagnostic_hud_overlay.visible = choosing_fault and pending_diagnostic_method != ""
	if diagnostic_data_label != null:
		diagnostic_data_label.visible = choosing_fault and pending_diagnostic_method != ""
	if diagnostic_back_button != null:
		diagnostic_back_button.visible = choosing_fault
	if diagnostic_menu_title != null:
		if choosing_fault:
			diagnostic_menu_title.text = "查看数据并判断故障"
		elif pending_diagnostic_enemy != null:
			var enemy := pending_diagnostic_enemy as Dictionary
			diagnostic_menu_title.text = "症状：%s\n选择检测手段" % str(enemy.get("symptomShort", "未知症状"))
		else:
			diagnostic_menu_title.text = "选择检测手段"


func _open_diagnostic_menu(enemy: Dictionary) -> void:
	pending_diagnostic_enemy = enemy
	pending_diagnostic_method = ""
	_close_slot_menu()
	if diagnostic_menu_panel == null:
		return
	var pos := enemy.get("pos", Vector2.ZERO) as Vector2
	var panel_size := Vector2(300, 392)
	var desired := pos + Vector2(44, -118)
	var view_size := get_viewport_rect().size
	desired.x = clampf(desired.x, 16.0, maxf(16.0, view_size.x - panel_size.x - 16.0))
	desired.y = clampf(desired.y, 84.0, maxf(84.0, view_size.y - panel_size.y - 16.0))
	diagnostic_menu_panel.position = desired
	diagnostic_menu_panel.size = panel_size
	_animate_popup_in(diagnostic_menu_panel)
	_set_diagnostic_menu_stage("method")
	if diagnostic_label != null:
		diagnostic_label.text = "待诊断：%s\n先选择检测手段，再决定部署处理模块。" % str(enemy.get("symptom", "未知链路异常"))
	queue_redraw()


func _close_diagnostic_menu() -> void:
	pending_diagnostic_enemy = null
	pending_diagnostic_method = ""
	if diagnostic_menu_panel != null:
		_animate_popup_out(diagnostic_menu_panel)
	_set_diagnostic_menu_stage("method")
	queue_redraw()


func _mark_enemy_type_diagnosed(enemy_type: String) -> void:
	diagnosed_enemy_types[enemy_type] = true
	for raw_enemy in enemies:
		var enemy := raw_enemy as Dictionary
		if str(enemy.get("type", "")) == enemy_type:
			enemy["diagnosed"] = true


func _show_enemy_diagnosis(enemy: Dictionary, charged: bool) -> void:
	var enemy_type := str(enemy.get("type", "unknown"))
	var method := str(enemy.get("diagnosticMethod", "观察波形和日志"))
	var finding := str(enemy.get("diagnosticFinding", "需要继续采集数据。"))
	var fault := _enemy_codex_name(enemy_type)
	var cost_text := "消耗 %d 能量" % DIAGNOSIS_COST if charged else "已诊断"
	var text := "诊断：%s\n方法：%s\n结论：%s\n%s" % [str(enemy.get("symptom", "")), method, fault, finding]
	if diagnostic_label != null:
		diagnostic_label.text = text
	_add_feedback("%s：%s" % [cost_text, fault], enemy.get("pos", Vector2.ZERO) as Vector2, Color(0.62, 0.92, 1.0))


func _enemy_visual_marker(enemy_type: String) -> String:
	match enemy_type:
		"config":
			return "配"
		"noise":
			return "噪"
		"drift_noise":
			return "漂"
		"false_peak":
			return "峰"
		"power_spike":
			return "电"
		"hybrid_fault":
			return "混"
		_:
			return "?"


func _tower_level_badge(level: int) -> String:
	if level <= 1:
		return "Lv1 基础"
	if level == 2:
		return "Lv2 特效"
	return "Lv3 强化"


func _has_any_tower() -> bool:
	for slot in tower_slots:
		if (slot as Dictionary).get("tower", null) != null:
			return true
	return false


func _tutorial_text() -> String:
	if state == "main_menu":
		return "选择入口或关卡。"
	if state == "level_select":
		return "选择要测试的关卡。"
	if state == "quiz":
		return "引导4：读题，判断模块。"
	if state == "result":
		return "完成：回看诊断和错配。"
	if selected_slot_index >= 0 and slot_menu_panel != null and slot_menu_panel.visible:
		var slot := tower_slots[selected_slot_index] as Dictionary
		if slot.get("tower", null) == null:
			return "引导2：圆形菜单看费用。"
		return "引导2：Lv2 知识点，Lv3 指标增强。"
	if !_has_any_tower():
		return "引导1：点击塔位建塔。"
	if state == "intro":
		return "引导3：点击开始并观察。"
	if state == "wave_running":
		return "引导3：点敌人诊断症状。"
	return "引导：看症状与诊断。"


func _refresh_tutorial() -> void:
	if tutorial_label != null:
		tutorial_label.text = _tutorial_text()


func _toggle_codex() -> void:
	if codex_popup != null and codex_popup.visible:
		_hide_codex_popup()
	else:
		_show_codex_popup()


func _show_codex_popup() -> bool:
	if codex_popup == null:
		return false
	_close_slot_menu()
	_close_diagnostic_menu()
	if codex_label != null:
		codex_label.visible = false
	_animate_popup_in(codex_popup)
	codex_popup.move_to_front()
	if codex_button != null:
		codex_button.text = "关闭图鉴"
	queue_redraw()
	return true


func _hide_codex_popup() -> bool:
	if codex_popup == null:
		return false
	_animate_popup_out(codex_popup)
	if codex_label != null:
		codex_label.visible = false
	if codex_button != null:
		codex_button.text = "敌人图鉴"
	queue_redraw()
	return true


func _close_codex_popup() -> bool:
	return _hide_codex_popup()


func _codex_entry_count() -> int:
	return codex_entry_cards.size()


func _codex_texture_count() -> int:
	var count := 0
	for node in codex_preview_nodes:
		var preview := node as TextureRect
		if preview != null and preview.texture != null:
			count += 1
	return count


func answer_quiz(choice_index: int) -> void:
	if state != "quiz" or active_question.is_empty() or quiz_answer_locked:
		return
	quiz_answer_locked = true
	for button in quiz_buttons:
		button.disabled = true
	var correct := choice_index == int(active_question.get("answerIndex", -1))
	var unlock_tag := str(active_question.get("unlockTag", ""))
	if correct:
		correct_count += 1
		energy += 60
		quiz_feedback.text = "回答正确：+60 能量。\n" + str(active_question.get("explanation", ""))
		_unlock_from_tag(unlock_tag)
	else:
		wrong_count += 1
		energy += 15
		link_stability = maxi(0, link_stability - 8)
		quiz_feedback.text = "回答错误：+15 能量。\n" + str(active_question.get("explanation", ""))
	_update_ui()
	await get_tree().create_timer(1.15).timeout
	if state != "quiz":
		return
	_animate_popup_out(quiz_panel)
	_close_slot_menu()
	if current_wave >= _current_level_wave_count():
		_complete_current_level()
	else:
		_start_next_wave()


func finish_game(shutdown: bool) -> void:
	if completed:
		return
	state = "result"
	completed = true
	_animate_popup_out(quiz_panel)
	_close_slot_menu()
	start_button.text = "重新开始"
	start_button.disabled = false
	band_score = _calculate_score(shutdown)
	var host_score := clampi(roundi(float(band_score) / 100.0), 0, 100)
	var title := "防线守住" if !shutdown else "链路失真"
	result_label.visible = true
	result_label.text = "%s\n手环分：%d\n完成关卡：%d / %d\n可信数据：%d\n正确/错误：%d/%d" % [
		title,
		band_score,
		current_level,
		_max_level_number(),
		trusted_data,
		correct_count,
		wrong_count
	]
	if last_level_summary != "":
		result_label.text += "\n" + last_level_summary
	var elapsed := Time.get_ticks_msec() - started_at
	if runtime:
		runtime.complete(host_score, -1, elapsed, {
			"bandScore": band_score,
			"level": current_level,
			"wavesCleared": _waves_cleared_count(shutdown),
			"leaks": leaks,
			"correct": correct_count,
			"wrong": wrong_count,
			"linkStability": link_stability,
			"shutdown": 1 if shutdown else 0
		})
	_update_ui()


func _on_tower_button_pressed(tower_id: String) -> void:
	if state != "intro" and state != "wave_running":
		return
	if !tower_defs.has(tower_id) or !unlocked.get(tower_id, false):
		return
	selected_tower_id = tower_id
	_add_feedback("选择：" + str((tower_defs[tower_id] as Dictionary)["label"]), Vector2(760, 160), Color(0.70, 0.90, 1.0))
	_update_ui()


func _start_next_wave() -> void:
	if current_wave >= _current_level_wave_count():
		finish_game(false)
		return
	current_wave += 1
	state = "wave_running"
	spawn_queue = _build_spawn_queue(current_wave)
	_reset_wave_stats(current_wave)
	spawn_interval = WaveLevelDirector.wave_spawn_interval(waves, current_level, current_wave)
	spawn_elapsed = spawn_interval
	var brief := WaveLevelDirector.wave_brief(waves, current_level, current_wave)
	var pressure_label := WaveLevelDirector.wave_pressure_label(waves, current_level, current_wave)
	status_label.text = "第 %d 关 / 第 %d 波：%s" % [
		current_level,
		current_wave,
		_band_model_stage_name(current_level, current_wave)
	]
	if pressure_label != "":
		status_label.text += "｜%s" % pressure_label
	start_button.disabled = true
	_report_progress("第 %d 关第 %d 波开始" % [current_level, current_wave])
	_update_ui()
	if current_level == 1 and current_wave == 1 and !diagnosis_tutorial_seen:
		_show_diagnosis_tutorial_popup()


func _build_spawn_queue(wave_number: int) -> Array:
	return WaveLevelDirector.build_spawn_queue(waves, current_level, wave_number)


func _reset_wave_stats(wave_number: int) -> void:
	var focus_type := WaveLevelDirector.wave_focus_type(waves, current_level, wave_number)
	var brief := WaveLevelDirector.wave_brief(waves, current_level, wave_number)
	current_wave_stats = {
		"level": current_level,
		"wave": wave_number,
		"focusType": focus_type,
		"matched_hits": {},
		"mismatched_hits": {},
		"kills": {},
		"leaks": {}
	}
	last_wave_summary = ""
	if diagnostic_label != null:
		var stage := _band_model_stage_name(current_level, wave_number)
		if brief == "":
			diagnostic_label.text = "%s进行中\n链路监测：运行" % stage
		else:
			diagnostic_label.text = "%s\n症状：%s\n链路监测：运行" % [stage, brief]


func _record_wave_count(bucket: String, enemy_type: String) -> void:
	if current_wave_stats.is_empty() or enemy_type == "":
		return
	var counts: Dictionary = current_wave_stats.get(bucket, {})
	counts[enemy_type] = int(counts.get(enemy_type, 0)) + 1
	current_wave_stats[bucket] = counts
	if !current_level_stats.is_empty():
		var level_counts: Dictionary = current_level_stats.get(bucket, {})
		level_counts[enemy_type] = int(level_counts.get(enemy_type, 0)) + 1
		current_level_stats[bucket] = level_counts


func _show_wave_diagnostics() -> void:
	if current_wave_stats.is_empty():
		return
	last_wave_summary = WaveDiagnostics.build_wave_summary(current_wave_stats, enemy_defs)
	if diagnostic_label != null:
		diagnostic_label.text = last_wave_summary
	_report_progress("波后诊断")


func _reset_level_stats(level_number: int) -> void:
	current_level_stats = {
		"level": level_number,
		"matched_hits": {},
		"mismatched_hits": {},
		"kills": {},
		"leaks": {}
	}
	last_level_summary = ""


func _current_level_wave_count() -> int:
	var count := WaveLevelDirector.wave_count_for_level(waves, current_level)
	if count <= 0:
		return TOTAL_WAVES
	return count


func _leak_warning_threshold() -> int:
	if max_leaks <= 1:
		return 1
	return clampi(floori(float(max_leaks) * 0.625), 1, max_leaks - 1)


func _mark_current_wave_cleared() -> void:
	var key := "%d-%d" % [current_level, current_wave]
	if cleared_wave_keys.has(key):
		return
	cleared_wave_keys[key] = true
	waves_cleared += 1


func _waves_cleared_count(_shutdown: bool) -> int:
	return waves_cleared


func _max_level_number() -> int:
	var max_level := 1
	for raw_wave in waves:
		if typeof(raw_wave) != TYPE_DICTIONARY:
			continue
		max_level = maxi(max_level, int((raw_wave as Dictionary).get("level", 1)))
	return max_level


func _complete_current_level() -> void:
	last_level_summary = WaveDiagnostics.build_level_summary(current_level_stats, enemy_defs)
	if current_level >= _max_level_number():
		finish_game(false)
		return
	if diagnostic_label != null:
		diagnostic_label.text = last_level_summary
	current_level += 1
	current_wave = 0
	state = "intro"
	enemies.clear()
	spawn_queue.clear()
	feedbacks.clear()
	attack_effects.clear()
	_clear_enemy_hit_feedback()
	_close_slot_menu()
	_apply_level_layout(current_level)
	unlocked = {"i2c": true, "filter": true, "peak": true, "power": true}
	energy = maxi(energy, 130)
	leaks = 0
	link_stability = 100
	selected_tower_id = "i2c"
	_reset_level_stats(current_level)
	status_label.text = LevelLayouts.intro_text_for_level(current_level)
	start_button.text = "开始第 %d 关" % current_level
	start_button.disabled = false
	_report_progress("第 %d 关准备" % current_level)
	_update_ui()


func _update_spawning(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_elapsed += delta
	if spawn_elapsed >= spawn_interval:
		spawn_elapsed = 0.0
		var spawn_entry = spawn_queue.pop_front()
		_spawn_enemy(spawn_entry)


func _spawn_enemy(spawn_entry) -> void:
	var spawn_data := {}
	var enemy_type := "noise"
	if typeof(spawn_entry) == TYPE_DICTIONARY:
		spawn_data = (spawn_entry as Dictionary).duplicate(true)
		enemy_type = str(spawn_data.get("type", "noise"))
		if spawn_data.has("switches"):
			enemy_type = WaveLevelDirector.type_for_progress({
				"type": enemy_type,
				"progress": 0.0,
				"switches": spawn_data.get("switches", [])
			}, 1.0)
	else:
		enemy_type = str(spawn_entry)
	if !enemy_defs.has(enemy_type):
		enemy_type = "noise"
	var def := enemy_defs[enemy_type] as Dictionary
	var hp_multiplier := float(spawn_data.get("hpMultiplier", 1.0))
	var reward_multiplier := float(spawn_data.get("rewardMultiplier", 1.0))
	var speed_multiplier := float(spawn_data.get("speedMultiplier", 1.0))
	var enemy := {
		"type": enemy_type,
		"spawnType": str(spawn_data.get("type", enemy_type)),
		"label": str(def["label"]),
		"threatTag": str(def["threatTag"]),
		"hp": float(def["hp"]) * hp_multiplier,
		"maxHp": float(def["hp"]) * hp_multiplier,
		"speed": float(def["speed"]) * speed_multiplier,
		"speedMultiplier": speed_multiplier,
		"reward": roundi(float(def["reward"]) * reward_multiplier),
		"progress": 0.0,
		"pos": path_points[0],
		"switches": spawn_data.get("switches", []),
		"symptomPhase": float(enemies.size()) * 0.73,
		"hitPulse": 0.0,
		"hitReactionTtl": 0.0,
		"hitReactionDuration": HitFeedbackFx.IMPACT_DURATION,
		"hitDirection": Vector2.RIGHT,
		"switchPulse": 0.0,
		"lastMatched": false,
		"reached": false
	}
	_assign_enemy_diagnostic_fields(enemy, enemy_type)
	enemies.append(enemy)


func _update_enemies(delta: float) -> void:
	var path_length := _path_length()
	for enemy in enemies:
		var e := enemy as Dictionary
		var movement_speed := float(e["speed"])
		var stun_timer := float(e.get("stunTimer", 0.0))
		var slow_timer := float(e.get("slowTimer", 0.0))
		if stun_timer > 0.0:
			e["stunTimer"] = maxf(0.0, stun_timer - delta)
			movement_speed = 0.0
		elif slow_timer > 0.0:
			e["slowTimer"] = maxf(0.0, slow_timer - delta)
			movement_speed *= float(e.get("slowMultiplier", 1.0))
		e["progress"] = float(e["progress"]) + movement_speed * delta
		_apply_enemy_switch(e, path_length)
		e["pos"] = _point_at_distance(float(e["progress"]))
		e["hitPulse"] = maxf(0.0, float(e.get("hitPulse", 0.0)) - delta)
		e["hitReactionTtl"] = maxf(0.0, float(e.get("hitReactionTtl", 0.0)) - delta)
		e["switchPulse"] = maxf(0.0, float(e.get("switchPulse", 0.0)) - delta)
		if float(e["progress"]) >= path_length and !bool(e["reached"]):
			e["reached"] = true
			_on_enemy_leaked(e)


func _apply_enemy_switch(enemy: Dictionary, path_length: float) -> void:
	var next_type := WaveLevelDirector.type_for_progress(enemy, path_length)
	if next_type == str(enemy.get("type", "")) or !enemy_defs.has(next_type):
		return
	var def := enemy_defs[next_type] as Dictionary
	enemy["type"] = next_type
	enemy["label"] = str(def["label"])
	enemy["threatTag"] = str(def["threatTag"])
	enemy["speed"] = float(def["speed"]) * float(enemy.get("speedMultiplier", 1.0))
	_assign_enemy_diagnostic_fields(enemy, next_type)
	enemy["switchPulse"] = 0.45
	enemy["hitPulse"] = 0.36
	_add_feedback("异常切换：" + str(def["label"]), enemy["pos"], Color(1.0, 0.88, 0.28))


func _update_towers(delta: float) -> void:
	for i in range(tower_slots.size()):
		var slot := tower_slots[i] as Dictionary
		if slot["tower"] == null:
			continue
		var tower := slot["tower"] as Dictionary
		tower["attackAnim"] = maxf(0.0, float(tower.get("attackAnim", 0.0)) - delta)
		tower["cooldown"] = maxf(0.0, float(tower.get("cooldown", 0.0)) - delta)
		if float(tower["cooldown"]) > 0.0:
			continue
		var tower_id := str(tower["id"])
		var def := tower_defs[tower_id] as Dictionary
		var target = _find_target(slot["pos"], float(def["range"]))
		if target == null:
			continue
		_fire_tower(slot, tower, def, target)


func _find_target(origin: Vector2, attack_range: float):
	var best = null
	var best_progress := -1.0
	for enemy in enemies:
		var e := enemy as Dictionary
		if bool(e.get("reached", false)):
			continue
		if float(e["hp"]) <= 0.0:
			continue
		if origin.distance_to(e["pos"]) <= attack_range and float(e["progress"]) > best_progress:
			best = e
			best_progress = float(e["progress"])
	return best


func _resolve_tower_attack(tower_id: String, level: int, target: Dictionary) -> Dictionary:
	if !tower_defs.has(tower_id):
		return {
			"damage": 0.0,
			"matched": false,
			"concept": "未知模块",
			"color": Color(0.95, 0.25, 0.25)
		}
	var def := tower_defs[tower_id] as Dictionary
	var base_damage := float(def["damage"]) * (1.0 + 0.35 * float(level - 1))
	var counter_tags := def["counterTags"] as Array
	var matched := counter_tags.has(str(target["threatTag"]))
	var diagnosis_ready := bool(target.get("diagnosed", true))
	var multiplier := 1.8 if matched else 0.25
	var damage := base_damage * multiplier
	var concept := "匹配" if matched else "错配"
	var color := Color(0.25, 0.95, 0.55) if matched else Color(0.95, 0.25, 0.25)
	if !diagnosis_ready:
		damage *= PROBE_DAMAGE_MULTIPLIER
		concept = "未诊断试探"
		color = Color(0.95, 0.72, 0.22)
		return {
			"damage": damage,
			"matched": matched,
			"concept": concept,
			"color": color,
			"needsDiagnosis": true
		}
	if matched and level >= 2:
		match str(def.get("attackStyle", "")):
			"calibrate":
				if bool(target.get("calibrated", false)):
					damage *= 1.35
					concept = "I2C 校准复核"
				else:
					target["calibrated"] = true
					concept = "I2C 校准标记"
			"smooth":
				target["slowTimer"] = maxf(float(target.get("slowTimer", 0.0)), 1.35 + 0.20 * float(level - 2))
				target["slowMultiplier"] = 0.50 if level >= 3 else 0.62
				concept = "滤波抑噪"
			"threshold_burst":
				damage *= 1.35
				target["captureTag"] = "threshold"
				concept = "峰值捕获"
			"power_gate":
				target["stunTimer"] = maxf(float(target.get("stunTimer", 0.0)), 0.55 + 0.12 * float(level - 1))
				var refund: int = 4 + 2 * max(0, level - 1)
				energy += refund
				concept = "低功耗拦截"
	return {
		"damage": damage,
		"matched": matched,
		"concept": concept,
		"color": color,
		"needsDiagnosis": false
	}


func _fire_tower(slot: Dictionary, tower: Dictionary, def: Dictionary, target: Dictionary) -> void:
	var level := int(tower.get("level", 1))
	var tower_id := str(tower.get("id", ""))
	var attack := _resolve_tower_attack(tower_id, level, target)
	var matched := bool(attack.get("matched", false))
	var damage := float(attack.get("damage", 0.0))
	target["hp"] = float(target["hp"]) - damage
	var hit_direction := ((target["pos"] as Vector2) - (slot["pos"] as Vector2)).normalized()
	if hit_direction.is_zero_approx():
		hit_direction = Vector2.RIGHT
	target["hitReactionTtl"] = HitFeedbackFx.IMPACT_DURATION
	target["hitReactionDuration"] = HitFeedbackFx.IMPACT_DURATION
	target["hitDirection"] = hit_direction
	target["lastMatched"] = matched
	_record_wave_count("matched_hits" if matched else "mismatched_hits", str(target["type"]))
	tower["cooldown"] = float(def["fireInterval"]) * (0.82 if level > 1 else 1.0)
	tower["attackAnim"] = TOWER_ATTACK_DURATION
	_add_attack_effect(slot["pos"] as Vector2, target["pos"] as Vector2, tower_id, matched, str(def.get("attackStyle", "")))
	_add_enemy_hit_effect(target, tower_id, matched, damage, hit_direction)
	var hit_text := _attack_feedback_text(tower_id, attack, target)
	var hit_color := attack.get("color", Color(0.95, 0.25, 0.25)) as Color
	_add_feedback(hit_text, target["pos"], hit_color)


func _cleanup_dead_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i] as Dictionary
		if float(enemy["hp"]) <= 0.0:
			_add_death_echo(enemy)
			energy += int(enemy["reward"])
			trusted_data += 1
			_record_wave_count("kills", str(enemy["type"]))
			_add_feedback("+%d 数据" % int(enemy["reward"]), enemy["pos"], Color(0.65, 0.95, 1.0))
			enemies.remove_at(i)
		elif bool(enemy.get("reached", false)):
			enemies.remove_at(i)
	_update_ui()


func _add_enemy_hit_effect(target: Dictionary, tower_id: String, matched: bool, damage: float, direction: Vector2) -> void:
	hit_effect_serial += 1
	var event := HitFeedbackFx.make_impact_event(
		target.get("pos", Vector2.ZERO) as Vector2,
		direction,
		tower_id,
		matched,
		damage,
		float(target.get("hp", 0.0)) <= 0.0,
		hit_effect_serial
	)
	event["serial"] = hit_effect_serial
	hit_effects.append(event)
	HitFeedbackFx.enforce_caps(hit_effects, death_echoes)


func _add_death_echo(enemy: Dictionary) -> void:
	hit_effect_serial += 1
	death_echoes.append({
		"enemy": enemy.duplicate(true),
		"position": enemy.get("pos", Vector2.ZERO),
		"ttl": HitFeedbackFx.DEATH_DURATION,
		"duration": HitFeedbackFx.DEATH_DURATION,
		"serial": hit_effect_serial,
	})
	HitFeedbackFx.enforce_caps(hit_effects, death_echoes)


func _update_enemy_hit_feedback(delta: float) -> void:
	for index in range(hit_effects.size() - 1, -1, -1):
		var event := hit_effects[index] as Dictionary
		event["ttl"] = float(event.get("ttl", 0.0)) - delta
		if float(event["ttl"]) <= 0.0:
			hit_effects.remove_at(index)
	for index in range(death_echoes.size() - 1, -1, -1):
		var echo := death_echoes[index] as Dictionary
		echo["ttl"] = float(echo.get("ttl", 0.0)) - delta
		if float(echo["ttl"]) <= 0.0:
			death_echoes.remove_at(index)


func _clear_enemy_hit_feedback() -> void:
	hit_effects.clear()
	death_echoes.clear()
	hovered_enemy = null
	hover_health_alpha = 0.0
	hover_health_active = false
	hover_pointer_known = false


func _find_hovered_enemy(mouse_position: Vector2):
	var best = null
	var best_distance := 36.0
	var best_progress := -INF
	for enemy_value in enemies:
		var enemy := enemy_value as Dictionary
		if bool(enemy.get("reached", false)) or float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var distance := mouse_position.distance_to(enemy.get("pos", Vector2.ZERO) as Vector2)
		var progress := float(enemy.get("progress", 0.0))
		if distance < best_distance - 0.01 or (is_equal_approx(distance, best_distance) and progress > best_progress):
			best = enemy
			best_distance = distance
			best_progress = progress
	return best


func _refresh_hover_target() -> void:
	if state != "wave_running" or !hover_pointer_known:
		hover_health_active = false
		return
	var candidate = _find_hovered_enemy(hover_pointer_position)
	if candidate == null:
		hover_health_active = false
		return
	hovered_enemy = candidate
	hover_health_active = true


func _update_hover_health(delta: float) -> void:
	_refresh_hover_target()
	var target_alpha := 1.0 if hover_health_active else 0.0
	var fade_duration := 0.08 if hover_health_active else 0.12
	hover_health_alpha = move_toward(hover_health_alpha, target_alpha, delta / fade_duration)
	if hover_health_alpha <= 0.001 and !hover_health_active:
		hover_health_alpha = 0.0
		hovered_enemy = null


func _enemy_health_readout(enemy: Dictionary) -> String:
	var current_hp := maxi(0, roundi(float(enemy.get("hp", 0.0))))
	var maximum_hp := maxi(1, roundi(float(enemy.get("maxHp", 1.0))))
	var percent := clampi(roundi(float(current_hp) / float(maximum_hp) * 100.0), 0, 100)
	return "生命 %d / %d · %d%%" % [current_hp, maximum_hp, percent]


func _hover_health_chip_rect(enemy: Dictionary) -> Rect2:
	var font := _hud_display_font(true)
	var font_size := 15
	var text_size := font.get_string_size(_enemy_health_readout(enemy), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var chip_size := Vector2(maxf(146.0, text_size.x + 34.0), 34.0)
	var enemy_position := enemy.get("pos", Vector2.ZERO) as Vector2
	var desired := enemy_position + Vector2(-chip_size.x * 0.5, -73.0)
	var safe_left := MAP_RECT.position.x + 8.0
	var safe_top := MAP_RECT.position.y + 8.0
	var safe_right := minf(MAP_RECT.end.x - 8.0, HUD_PANEL_RECT.position.x - 12.0)
	var safe_bottom := MAP_RECT.end.y - 8.0
	desired.x = clampf(desired.x, safe_left, maxf(safe_left, safe_right - chip_size.x))
	desired.y = clampf(desired.y, safe_top, maxf(safe_top, safe_bottom - chip_size.y))
	return Rect2(desired, chip_size)


func _draw_hover_health_chip() -> void:
	if hovered_enemy == null or hover_health_alpha <= 0.001:
		return
	var enemy := hovered_enemy as Dictionary
	var chip_rect := _hover_health_chip_rect(enemy)
	var alpha := clampf(hover_health_alpha, 0.0, 1.0)
	var style := _make_text_chip_style(8, Color(1.0, 1.0, 1.0, alpha))
	draw_style_box(style, chip_rect)
	var state_name := HitFeedbackFx.health_state(float(enemy.get("hp", 0.0)), float(enemy.get("maxHp", 1.0)))
	var state_color := Color(0.18, 0.72, 0.58, alpha)
	if state_name == "damaged":
		state_color = Color(0.96, 0.66, 0.15, alpha)
	elif state_name == "critical":
		state_color = Color(0.94, 0.31, 0.18, alpha)
	draw_circle(chip_rect.position + Vector2(16.0, 17.0), 3.5, state_color)
	var text_color := Color(GAME_UI_TEXT.r, GAME_UI_TEXT.g, GAME_UI_TEXT.b, alpha)
	draw_string(_hud_display_font(true), chip_rect.position + Vector2(27.0, 23.0), _enemy_health_readout(enemy), HORIZONTAL_ALIGNMENT_LEFT, chip_rect.size.x - 34.0, 15, text_color)


func _on_enemy_leaked(enemy: Dictionary) -> void:
	leaks += 1
	link_stability = maxi(0, link_stability - 12)
	_record_wave_count("leaks", str(enemy["type"]))
	_add_feedback("漏防", enemy["pos"], Color(1.0, 0.28, 0.28))
	_report_progress("异常信号漏防")
	if leaks >= max_leaks:
		finish_game(true)


func _check_wave_end() -> void:
	if state != "wave_running":
		return
	if spawn_queue.is_empty() and enemies.is_empty():
		_mark_current_wave_cleared()
		_show_wave_diagnostics()
		_show_quiz()


func _show_quiz() -> void:
	if questions.is_empty():
		if current_wave >= _current_level_wave_count():
			_complete_current_level()
		else:
			_start_next_wave()
		return
	state = "quiz"
	_close_slot_menu()
	quiz_answer_locked = false
	active_question = _select_next_question()
	quiz_title.text = "波间知识校验：%s" % str(active_question.get("knowledgePoint", "第 11 章"))
	quiz_prompt.text = str(active_question.get("prompt", ""))
	quiz_feedback.text = ""
	var choices: Array = active_question.get("choices", [])
	for i in range(quiz_buttons.size()):
		var button := quiz_buttons[i] as Button
		button.disabled = false
		button.text = "%s. %s" % [char(65 + i), str(choices[i]) if i < choices.size() else ""]
	_animate_popup_in(quiz_panel)
	status_label.text = "答题给资源，首次答对模块题会解锁对应塔。"
	_update_ui()


func _select_next_question() -> Dictionary:
	for offset in range(questions.size()):
		var index := (question_index + offset) % questions.size()
		var candidate := questions[index] as Dictionary
		if _question_level(candidate) != current_level:
			continue
		if _question_unlocks_locked_tower(candidate):
			question_index = index + 1
			return candidate
	for offset in range(questions.size()):
		var index := (question_index + offset) % questions.size()
		var candidate := questions[index] as Dictionary
		if _question_level(candidate) == current_level:
			question_index = index + 1
			return candidate
	var fallback := questions[question_index % questions.size()] as Dictionary
	question_index += 1
	return fallback


func _question_level(question: Dictionary) -> int:
	return int(question.get("level", 1))


func _question_unlocks_locked_tower(question: Dictionary) -> bool:
	var unlock_map := {
		"i2c": "i2c",
		"filter": "filter",
		"step": "peak",
		"peak": "peak",
		"power": "power"
	}
	var tag := str(question.get("unlockTag", ""))
	if !unlock_map.has(tag):
		return false
	var tower_id := str(unlock_map[tag])
	return !bool(unlocked.get(tower_id, false))


func _unlock_from_tag(tag: String) -> void:
	var unlock_map := {
		"filter": "filter",
		"peak": "peak",
		"power": "power"
	}
	if unlock_map.has(tag):
		var tower_id := str(unlock_map[tag])
		if !bool(unlocked.get(tower_id, false)):
			unlocked[tower_id] = true
			quiz_feedback.text += "\n解锁：" + str(tower_defs[tower_id]["name"])
	elif tag == "i2c":
		energy += 20
		quiz_feedback.text += "\nI2C 模块巩固：额外 +20 能量。"


func _update_feedback(delta: float) -> void:
	for i in range(feedbacks.size() - 1, -1, -1):
		var feedback := feedbacks[i] as Dictionary
		feedback["ttl"] = float(feedback["ttl"]) - delta
		feedback["pos"] = (feedback["pos"] as Vector2) + Vector2(0, -22 * delta)
		if float(feedback["ttl"]) <= 0.0:
			feedbacks.remove_at(i)


func _update_attack_effects(delta: float) -> void:
	for i in range(attack_effects.size() - 1, -1, -1):
		var effect := attack_effects[i] as Dictionary
		effect["ttl"] = float(effect["ttl"]) - delta
		if float(effect["ttl"]) <= 0.0:
			attack_effects.remove_at(i)


func _add_feedback(text: String, pos: Vector2, color: Color) -> void:
	var ttl := 1.35 if text.length() > 24 else 0.9
	feedbacks.append({"text": text, "pos": pos, "ttl": ttl, "color": color})


func _add_attack_effect(from_pos: Vector2, to_pos: Vector2, tower_id: String, matched: bool, attack_style: String) -> void:
	attack_effects.append({
		"from": from_pos,
		"to": to_pos,
		"towerId": tower_id,
		"ttl": ATTACK_EFFECT_DURATION,
		"duration": ATTACK_EFFECT_DURATION,
		"matched": matched,
		"showRange": matched or attack_style in ["smooth", "threshold_burst", "power_gate"]
	})


func _calculate_score(shutdown: bool) -> int:
	var score := 3000
	score += current_wave * 1200
	score += correct_count * 500
	score += trusted_data * 80
	score += link_stability * 20
	score -= leaks * 600
	score -= wrong_count * 300
	if shutdown:
		score = mini(score, 3000)
	return clampi(score, 0, 10000)


func _update_ui() -> void:
	if hud_label == null:
		return
	hud_label.text = "关卡 %d · 波次 %d/%d · 能量 %d\n%s" % [
		current_level,
		current_wave,
		_current_level_wave_count(),
		energy,
		_band_status_readout_text()
	]
	for tower_id in tower_buttons.keys():
		var button := tower_buttons[tower_id] as Button
		var def := tower_defs[tower_id] as Dictionary
		var is_unlocked := bool(unlocked.get(tower_id, false))
		var is_selected: bool = selected_tower_id == tower_id and is_unlocked and (state == "intro" or state == "wave_running")
		_apply_platform_button_style(button, false, is_selected)
		button.text = "%s · %d" % [str(def["label"]), int(def["cost"])]
		if is_selected:
			button.text = "● " + button.text
		button.disabled = !is_unlocked or state == "quiz" or state == "result" or state == "main_menu" or state == "level_select"
		if !is_unlocked:
			button.text = "锁定 · " + str(def["label"])
	if start_button:
		start_button.disabled = state == "wave_running" or state == "quiz" or state == "main_menu" or state == "level_select"
	_refresh_tutorial()
	_update_slot_menu()
	if hud_metrics_strip != null:
		hud_metrics_strip.queue_redraw()


func _report_progress(hint: String) -> void:
	if runtime == null:
		return
	var progress := 0.0
	var max_level := _max_level_number()
	var wave_count := _current_level_wave_count()
	if max_level > 0 and wave_count > 0:
		var level_progress := float(maxi(current_level - 1, 0)) / float(max_level)
		var wave_progress := float(maxi(current_wave - 1, 0)) / float(wave_count * max_level)
		progress = clampf(level_progress + wave_progress, 0.0, 1.0)
	if state == "wave_running" and max_level > 0 and wave_count > 0:
		var running_level_progress := float(maxi(current_level - 1, 0)) / float(max_level)
		var running_wave_progress := (float(current_wave - 1) + 0.5) / float(wave_count * max_level)
		progress = clampf(running_level_progress + running_wave_progress, 0.0, 1.0)
	runtime.report_progress(progress, hint, {
		"level": current_level,
		"wave": current_wave,
		"leaks": leaks,
		"stable": link_stability,
		"correct": correct_count,
		"wrong": wrong_count
	})


func _reset() -> void:
	state = "main_menu"
	run_started = false
	completed = false
	current_level = 1
	current_wave = 0
	waves_cleared = 0
	cleared_wave_keys.clear()
	energy = 90
	trusted_data = 0
	leaks = 0
	link_stability = 100
	correct_count = 0
	wrong_count = 0
	band_score = 0
	question_index = 0
	selected_tower_id = "i2c"
	selected_slot_index = -1
	enemies.clear()
	spawn_queue.clear()
	feedbacks.clear()
	attack_effects.clear()
	_clear_enemy_hit_feedback()
	current_wave_stats.clear()
	current_level_stats.clear()
	diagnosed_enemy_types.clear()
	last_wave_summary = ""
	last_level_summary = ""
	quiz_answer_locked = false
	_apply_level_layout(current_level)
	unlocked = {"i2c": true, "filter": true, "peak": false, "power": false}
	_animate_popup_out(quiz_panel)
	_close_slot_menu()
	_close_diagnostic_menu()
	_hide_codex_popup()
	result_label.text = ""
	result_label.visible = false
	if codex_label != null:
		codex_label.visible = false
	if codex_button != null:
		codex_button.text = "敌人图鉴"
	if diagnostic_label != null:
		diagnostic_label.text = "选择入口后开始调试数据链路防线。"
	status_label.text = "互动练习 / Alpha：选择闯关或选关"
	start_button.text = "从总菜单开始"
	start_button.disabled = true
	if main_menu_panel != null:
		_animate_popup_in(main_menu_panel)
	if level_select_panel != null:
		_animate_popup_out(level_select_panel)
	if side_panel != null:
		side_panel.visible = false
	_update_ui()
	_report_progress("已重置")


func _on_pause_requested() -> void:
	get_tree().paused = true


func _on_resume_requested() -> void:
	get_tree().paused = false


func _path_length() -> float:
	var total := 0.0
	for i in range(path_points.size() - 1):
		total += path_points[i].distance_to(path_points[i + 1])
	return total


func _point_at_distance(distance: float) -> Vector2:
	var remaining := distance
	for i in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var segment: float = a.distance_to(b)
		if remaining <= segment:
			return a.lerp(b, remaining / segment)
		remaining -= segment
	return path_points[path_points.size() - 1]


func _default_path_layer_style() -> Dictionary:
	return {
		"visible": false,
		"color": Color(0.18, 0.96, 1.0, 0.95),
		"width": 11.0,
		"coreCount": 3,
		"coreWidth": 2.4,
		"coreSpacing": 4.5,
		"connectorGlowWidth": 4.2,
		"cornerRadius": 26.0,
		"cornerSamples": 6,
		"glowWidth": 18.0,
		"glowAlpha": 0.22,
		"arrowSpacing": 92.0,
		"startPort": Vector2(76, 350),
		"endPort": Vector2(878, 350)
	}


func _path_layer_style() -> Dictionary:
	if path_layer_settings.is_empty():
		return _default_path_layer_style()
	return path_layer_settings.duplicate(true)


func _draw_path_layer() -> void:
	var style := _path_layer_style()
	if !bool(style.get("visible", true)) or path_points.size() < 2:
		return
	var color := style.get("color", Color(0.18, 0.96, 1.0, 0.95)) as Color
	var width := float(style.get("width", 11.0))
	var core_count := maxi(1, int(style.get("coreCount", 3)))
	var core_width := float(style.get("coreWidth", 2.4))
	var core_spacing := float(style.get("coreSpacing", 4.5))
	var glow_width := float(style.get("glowWidth", width + 7.0))
	var glow_alpha := float(style.get("glowAlpha", 0.34))
	var points := PackedVector2Array()
	for raw_point in path_points:
		points.append(raw_point as Vector2)
	draw_polyline(points, Color(color.r, color.g, color.b, glow_alpha * 0.24), glow_width + 7.0, true)
	draw_polyline(points, Color(color.r, color.g, color.b, glow_alpha), glow_width, true)
	draw_polyline(points, Color(0.035, 0.22, 0.24, 0.50), width + 3.0, true)
	for core_index in range(core_count):
		var offset := (float(core_index) - float(core_count - 1) * 0.5) * core_spacing
		var core_points := RouteGeometry.offset_route(points, offset)
		draw_polyline(core_points, Color(color.r, color.g, color.b, glow_alpha * 0.82), core_width + 5.0, true)
		draw_polyline(core_points, Color(color.r, color.g, color.b, color.a), core_width, true)
		draw_polyline(core_points, Color(0.93, 1.0, 1.0, 0.74), maxf(0.85, core_width * 0.36), true)
	_draw_path_connectors(style, color, core_count, core_width, core_spacing)
	_draw_path_layer_arrows(color, width, float(style.get("arrowSpacing", 84.0)))


func _draw_path_connectors(style: Dictionary, color: Color, core_count: int, core_width: float, core_spacing: float) -> void:
	if path_points.size() < 2:
		return
	var start_port := style.get("startPort", path_points[0]) as Vector2
	var end_port := style.get("endPort", path_points[path_points.size() - 1]) as Vector2
	var connector_glow_width := float(style.get("connectorGlowWidth", core_width + 2.0))
	_draw_path_connector(start_port, path_points[0] as Vector2, color, core_count, core_width, core_spacing, connector_glow_width)
	_draw_path_connector(end_port, path_points[path_points.size() - 1] as Vector2, color, core_count, core_width, core_spacing, connector_glow_width)


func _draw_path_connector(port_center: Vector2, route_endpoint: Vector2, color: Color, core_count: int, core_width: float, core_spacing: float, connector_glow_width: float) -> void:
	var direction := route_endpoint - port_center
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var normal := Vector2(-direction.y, direction.x)
	var body_start := port_center - direction * 1.5
	var body_end := route_endpoint + direction * 5.0
	var body := PackedVector2Array([
		body_start + normal * 11.0,
		body_end - direction * 2.0 + normal * 8.5,
		body_end + normal * 6.0,
		body_end - normal * 6.0,
		body_end - direction * 2.0 - normal * 8.5,
		body_start - normal * 11.0,
	])
	var shadow := PackedVector2Array()
	for point in body:
		shadow.append(point + Vector2(0, 2.0))
	draw_colored_polygon(shadow, Color(0.015, 0.025, 0.03, 0.48))
	draw_colored_polygon(body, Color(0.075, 0.105, 0.12, 0.96))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.70, 0.77, 0.78, 0.88), 1.25, true)
	draw_line(body_start + normal * 9.0, body_start - normal * 9.0, Color(0.24, 0.30, 0.31, 0.96), 2.5, true)
	draw_line(body_end - direction * 2.5 + normal * 7.0, body_end - direction * 2.5 - normal * 7.0, Color(0.54, 0.62, 0.63, 0.92), 1.6, true)
	for core_index in range(core_count):
		var offset := (float(core_index) - float(core_count - 1) * 0.5) * core_spacing
		var core_start := port_center + direction * 1.0 + normal * offset
		var core_end := route_endpoint + direction * 4.0 + normal * offset
		draw_line(core_start, core_end, Color(0.66, 0.72, 0.72, 0.94), core_width + 1.6, true)
		draw_line(core_start, core_end, Color(color.r, color.g, color.b, 0.18), connector_glow_width, true)
		draw_line(core_start, core_end, color, core_width, true)
		draw_line(core_start, core_end, Color(0.95, 1.0, 1.0, 0.82), maxf(0.8, core_width * 0.34), true)


func _draw_path_layer_arrows(color: Color, width: float, spacing: float) -> void:
	if spacing <= 0.0:
		return
	var traveled := spacing * 0.45
	for i in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.001:
			continue
		var direction := (b - a).normalized()
		var distance := spacing - fmod(traveled, spacing)
		while distance < segment:
			_draw_path_layer_chevron(a + direction * distance, direction, color, width)
			distance += spacing
		traveled += segment


func _draw_path_layer_chevron(center: Vector2, direction: Vector2, color: Color, width: float) -> void:
	var normal := Vector2(-direction.y, direction.x)
	var tip := center + direction * 10.0
	var left := center - direction * 9.0 + normal * 6.0
	var right := center - direction * 9.0 - normal * 6.0
	var arrow_color := Color(0.93, 1.0, 1.0, minf(0.92, color.a))
	var arrow_width := maxf(2.0, width * 0.32)
	draw_line(left, tip, arrow_color, arrow_width)
	draw_line(right, tip, arrow_color, arrow_width)


func _draw_map() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	draw_rect(viewport_rect, PLATFORM_SURFACE_BASE, true)
	if background_map != null:
		draw_texture_rect(background_map, _background_draw_rect(), false)
	_draw_hud_shell()
	_draw_band_model_overlay()


func _draw_hud_shell() -> void:
	draw_rect(_hud_shell_rect(), HUD_SHELL_FRAME_COLOR, true)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = HUD_SCREEN_COLOR
	screen_style.border_color = HUD_SCREEN_BORDER_COLOR
	screen_style.set_border_width_all(2)
	screen_style.set_corner_radius_all(_hud_screen_corner_radius())
	draw_style_box(screen_style, _hud_screen_rect())

	var inner_rect := _hud_screen_rect().grow(-5.0)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.020, 0.052, 0.068, 0.96)
	inner_style.border_color = Color(0.12, 0.25, 0.30, 0.72)
	inner_style.set_border_width_all(1)
	inner_style.set_corner_radius_all(_hud_screen_corner_radius() - 5)
	draw_style_box(inner_style, inner_rect)


func _draw_band_model_overlay() -> void:
	for raw_node in band_model_nodes:
		var node := raw_node as Dictionary
		var pos := node.get("pos", Vector2.ZERO) as Vector2
		draw_circle(pos, 4.0, Color(0.22, 0.95, 0.82, 0.52))
		if DRAW_BAND_MODEL_NODE_TEXT:
			draw_string(_draw_font(), pos + Vector2(8, -6), str(node.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, 120, 12, Color(0.08, 0.22, 0.24, 0.70))
			draw_string(_draw_font(), pos + Vector2(8, 9), str(node.get("hint", "")), HORIZONTAL_ALIGNMENT_LEFT, 136, 10, Color(0.12, 0.35, 0.36, 0.48))


func _draw_menu_backdrop() -> void:
	if state != "main_menu" and state != "level_select":
		return
	var content_rect := _game_canvas_rect()
	draw_rect(content_rect, Color(0.00, 0.05, 0.07, 0.24), true)


func _draw_tower_slots() -> void:
	var empty_style := _empty_slot_marker_style()
	var cross_alpha := float(empty_style.get("crossAlpha", 0.18))
	for i in range(tower_slots.size()):
		var slot := tower_slots[i] as Dictionary
		var pos := slot["pos"] as Vector2
		var marker_center := _slot_marker_center(pos)
		if i == selected_slot_index:
			draw_circle(marker_center, 48, Color(0.95, 0.78, 0.25, 0.13))
			draw_arc(marker_center, 43, 0, TAU, 40, Color(0.95, 0.78, 0.25, 0.72), 3.0)
		elif slot["tower"] == null:
			for cross_rect in _slot_cross_rects(marker_center):
				draw_rect(cross_rect as Rect2, Color(0.12, 0.64, 0.92, cross_alpha), true)
			if DRAW_EMPTY_TOWER_SLOT_TEXT:
				draw_string(_draw_font(), marker_center + Vector2(-32, 58), "建塔", HORIZONTAL_ALIGNMENT_CENTER, 64, 13, Color(0.32, 0.45, 0.52, 0.56))
		if slot["tower"] != null:
			var tower := slot["tower"] as Dictionary
			var def := tower_defs[str(tower["id"])] as Dictionary
			var level := int(tower.get("level", 1))
			var range_color := def["color"] as Color
			var range_alpha := 0.22 if i == selected_slot_index else 0.09
			draw_arc(marker_center, float(def.get("range", 120.0)), 0, TAU, 96, Color(range_color.r, range_color.g, range_color.b, range_alpha), 2.0)
			draw_circle(marker_center, 36, Color(1.0, 1.0, 1.0, 0.72))
			_draw_hardware_tower_sprite(marker_center, tower, Vector2(82, 82), Color(1, 1, 1, 0.98))
			var label_rect := Rect2(marker_center + Vector2(-36, -48), Vector2(54, 18))
			draw_rect(label_rect, Color(0.02, 0.06, 0.08, 0.76), true)
			draw_rect(Rect2(label_rect.position, Vector2(3, label_rect.size.y)), range_color, true)
			draw_string(_draw_font(), label_rect.position + Vector2(7, 14), str(def["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 1.0, 0.95))
			var badge_rect := Rect2(marker_center + Vector2(-34, 44), Vector2(68, 19))
			draw_rect(badge_rect, Color(1.0, 1.0, 1.0, 0.86), true)
			draw_rect(Rect2(badge_rect.position, Vector2(badge_rect.size.x, 2)), range_color, true)
			draw_string(_draw_font(), badge_rect.position + Vector2(5, 14), _tower_level_badge(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.12, 0.19, 0.24))


func _draw_slot_menu_guides() -> void:
	return


func _draw_enemies() -> void:
	var time := float(Time.get_ticks_msec()) / 1000.0
	for enemy in enemies:
		var e := enemy as Dictionary
		if bool(e.get("reached", false)):
			continue
		var def := enemy_defs[str(e["type"])] as Dictionary
		var pos := e["pos"] as Vector2
		var diagnosed := bool(e.get("diagnosed", false))
		var visual_pos := SymptomFx.visual_pos(e, pos, time) if diagnosed else pos + Vector2(0.0, sin(time * 5.5 + float(e.get("symptomPhase", 0.0))) * 2.0)
		var display_color: Color = def["color"] if diagnosed else Color(0.70, 0.86, 0.92)
		if diagnosed:
			SymptomFx.draw_symptom(self, e, visual_pos, time)
		else:
			_draw_unknown_fault_aura(visual_pos, time + float(e.get("symptomPhase", 0.0)))
		var reaction := HitFeedbackFx.reaction_transform(e)
		var reaction_offset := reaction.get("offset", Vector2.ZERO) as Vector2
		var reaction_angle := float(reaction.get("angle", 0.0))
		var reaction_scale := float(reaction.get("scale", 1.0))
		_draw_enemy_shadow(visual_pos, reaction_offset, reaction_scale)
		draw_set_transform(visual_pos + reaction_offset, reaction_angle, Vector2(reaction_scale, reaction_scale))
		_draw_enemy_animation(e, Vector2.ZERO, Vector2(66, 74), time, _enemy_body_modulate(e, time))
		draw_circle(Vector2(-18, -17), 6, display_color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _enemy_should_draw_fault_tag(e):
			var marker_rect := Rect2(visual_pos + Vector2(-16, -60), Vector2(32, 19))
			draw_rect(marker_rect, Color(0.02, 0.06, 0.08, 0.78), true)
			draw_rect(Rect2(marker_rect.position, Vector2(marker_rect.size.x, 2)), display_color, true)
			draw_string(_draw_font(), marker_rect.position + Vector2(9, 15), _enemy_display_marker(e), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0, 0.96))
		if _enemy_should_draw_symptom_label(e, enemies):
			var symptom_text := str(e.get("symptomShort", _enemy_display_text(e))) if !diagnosed else _enemy_display_text(e)
			var label_rect := Rect2(visual_pos + Vector2(-46, 28), Vector2(92, 18))
			draw_rect(label_rect, Color(0.02, 0.06, 0.08, 0.74), true)
			draw_string(_draw_font(), label_rect.position + Vector2(5, 13), symptom_text, HORIZONTAL_ALIGNMENT_LEFT, 84, 11, Color(0.92, 0.98, 1.0, 0.96))
		var switch_pulse := float(e.get("switchPulse", 0.0))
		if switch_pulse > 0.0:
			draw_arc(visual_pos, 42.0 + 18.0 * switch_pulse, 0, TAU, 48, Color(1.0, 0.88, 0.28, switch_pulse * 1.7), 3.0)


func _draw_enemy_animation(enemy: Dictionary, center: Vector2, size: Vector2, time: float, modulate: Color = Color.WHITE) -> void:
	var enemy_type := _enemy_visual_texture_key(enemy)
	var texture = enemy_anim_sheets.get(enemy_type, null)
	if texture == null:
		if enemy_type == "unknown_fault":
			_draw_unknown_fault_sprite(center, size, time)
			return
		_draw_sheet_sprite(center, enemy_sprite_cells.get(enemy_type, Vector2(0, 0)), size, Color(modulate.r, modulate.g, modulate.b, modulate.a * 0.95))
		return
	var sheet := texture as Texture2D
	var phase := float(enemy.get("symptomPhase", 0.0))
	var frame_index := int(floor((time + phase) * ENEMY_ANIM_FPS)) % ENEMY_ANIM_FRAMES
	var frame_col := frame_index % ENEMY_ANIM_COLUMNS
	var frame_row := floori(float(frame_index) / float(ENEMY_ANIM_COLUMNS))
	var frame_size := Vector2(float(sheet.get_width()) / float(ENEMY_ANIM_COLUMNS), float(sheet.get_height()) / float(ENEMY_ANIM_ROWS))
	var source_rect := Rect2(Vector2(frame_col * frame_size.x, frame_row * frame_size.y), frame_size)
	var target_rect := Rect2(center - size * 0.5, size)
	draw_texture_rect_region(sheet, target_rect, source_rect, Color(modulate.r, modulate.g, modulate.b, modulate.a * 0.95))


func _draw_enemy_shadow(center: Vector2, reaction_offset: Vector2, reaction_scale: float) -> void:
	var profile := HitFeedbackFx.shadow_profile(reaction_scale)
	var alpha := float(profile.get("alpha", 0.0))
	if alpha <= 0.0:
		return
	var shadow_center := center + Vector2(0.0, float(profile.get("offsetY", 18.0))) + reaction_offset * 0.15
	draw_set_transform(shadow_center, 0.0, Vector2(1.0, float(profile.get("scaleY", 0.36))))
	draw_circle(Vector2.ZERO, float(profile.get("radius", 17.0)), Color(0.01, 0.04, 0.055, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _enemy_body_modulate(enemy: Dictionary, time: float) -> Color:
	match HitFeedbackFx.health_state(float(enemy.get("hp", 0.0)), float(enemy.get("maxHp", 1.0))):
		"damaged":
			var flicker := 0.92 + 0.08 * sin(time * 11.0 + float(enemy.get("symptomPhase", 0.0)))
			return Color(flicker, flicker, flicker * 0.98, 1.0)
		"critical":
			var warning := 0.86 + 0.10 * sin(time * 15.0 + float(enemy.get("symptomPhase", 0.0)))
			return Color(1.0, warning, 0.62 + warning * 0.16, 1.0)
		_:
			return Color.WHITE


func _enemy_visual_texture_key(enemy: Dictionary) -> String:
	if !bool(enemy.get("diagnosed", false)):
		return "unknown_fault"
	return str(enemy.get("type", "noise"))


func _draw_unknown_fault_aura(center: Vector2, time: float) -> void:
	var alpha := 0.20 + 0.08 * sin(time * 6.0)
	draw_arc(center, 31.0, 0, TAU, 48, Color(0.70, 0.86, 0.92, alpha), 2.0)
	draw_arc(center, 39.0, 0.4, TAU + 0.4, 48, Color(0.95, 0.76, 0.26, alpha * 0.72), 1.4)


func _draw_unknown_fault_sprite(center: Vector2, size: Vector2, time: float) -> void:
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect.grow(-10), Color(0.12, 0.20, 0.23, 0.82), true)
	draw_arc(center, size.x * 0.30, 0, TAU, 40, Color(0.70, 0.86, 0.92, 0.70), 3.0)
	draw_string(_draw_font(), center + Vector2(-8, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95, 0.98, 1.0, 0.95))


func _load_hardware_tower_textures() -> void:
	hardware_tower_textures.clear()
	for tower_id in hardware_tower_texture_paths.keys():
		var texture := _load_png_texture(str(hardware_tower_texture_paths[tower_id]))
		if texture != null:
			hardware_tower_textures[tower_id] = texture
	hardware_tower_static_textures.clear()
	for tower_id in hardware_tower_static_texture_paths.keys():
		var texture := _load_png_texture(str(hardware_tower_static_texture_paths[tower_id]))
		if texture != null:
			hardware_tower_static_textures[tower_id] = texture
	attack_effect_textures.clear()
	for tower_id in attack_effect_texture_paths.keys():
		var effect_paths := attack_effect_texture_paths[tower_id] as Dictionary
		attack_effect_textures[tower_id] = {}
		for effect_name in effect_paths.keys():
			var texture := _load_png_texture(str(effect_paths[effect_name]))
			if texture != null:
				(attack_effect_textures[tower_id] as Dictionary)[effect_name] = texture


func _load_hud_textures() -> void:
	hud_textures.clear()
	for texture_id in hud_texture_paths.keys():
		var texture := _load_png_texture(str(hud_texture_paths[texture_id]))
		if texture != null:
			hud_textures[texture_id] = texture


func _load_png_texture(path: String) -> Texture2D:
	var texture: Texture2D = null
	var image_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if FileAccess.file_exists(image_path):
		var image := Image.new()
		if image.load(image_path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		if ResourceLoader.exists(path):
			texture = ResourceLoader.load(path) as Texture2D
	return texture


func _draw_hardware_tower_sprite(center: Vector2, tower: Dictionary, size: Vector2, modulate: Color) -> void:
	var tower_id := str(tower.get("id", ""))
	var texture = hardware_tower_textures.get(tower_id, null)
	if texture == null:
		var static_texture = hardware_tower_static_textures.get(tower_id, null)
		if static_texture != null:
			draw_texture_rect(static_texture as Texture2D, Rect2(center - size * 0.5, size), false, modulate)
		else:
			_draw_sheet_sprite(center, tower_sprite_cells.get(tower_id, Vector2(0, 1)), size, modulate)
		return
	var sheet := texture as Texture2D
	var attack_left := float(tower.get("attackAnim", 0.0))
	var row := 1 if attack_left > 0.0 else 0
	var frame_index := 0
	if row == 1:
		var attack_elapsed := clampf(TOWER_ATTACK_DURATION - attack_left, 0.0, TOWER_ATTACK_DURATION)
		frame_index = clampi(floori(attack_elapsed * TOWER_ATTACK_FPS), 0, TOWER_ANIM_COLUMNS - 1)
	else:
		var time := float(Time.get_ticks_msec()) / 1000.0
		frame_index = int(floor(time * TOWER_IDLE_FPS)) % TOWER_ANIM_COLUMNS
	var frame_size := Vector2(float(sheet.get_width()) / float(TOWER_ANIM_COLUMNS), float(sheet.get_height()) / float(TOWER_ANIM_ROWS))
	var source_rect := Rect2(Vector2(float(frame_index) * frame_size.x, float(row) * frame_size.y), frame_size)
	var target_rect := Rect2(center - size * 0.5, size)
	draw_texture_rect_region(sheet, target_rect, source_rect, modulate)


func _draw_sheet_sprite(center: Vector2, cell: Vector2, size: Vector2, modulate: Color) -> void:
	if sprite_sheet == null:
		_draw_fallback_module_sprite(center, size, modulate)
		return
	var cell_size := Vector2(float(sprite_sheet.get_width()) / 4.0, float(sprite_sheet.get_height()) / 2.0)
	var source_rect := Rect2(Vector2(cell.x * cell_size.x, cell.y * cell_size.y), cell_size)
	var target_rect := Rect2(center - size * 0.5, size)
	draw_texture_rect_region(sprite_sheet, target_rect, source_rect, modulate)


func _draw_fallback_module_sprite(center: Vector2, size: Vector2, modulate: Color) -> void:
	var radius := minf(size.x, size.y) * 0.34
	draw_circle(center, radius, Color(0.10, 0.52, 0.62, 0.92) * modulate)
	draw_arc(center, radius * 1.18, -PI * 0.85, PI * 0.85, 24, Color(0.70, 1.00, 0.90, 0.86) * modulate, 3.0, true)
	var chip_rect := Rect2(center - Vector2(radius * 0.48, radius * 0.34), Vector2(radius * 0.96, radius * 0.68))
	draw_rect(chip_rect, Color(0.03, 0.13, 0.16, 0.94) * modulate, true, 4.0)
	draw_rect(chip_rect, Color(0.80, 1.00, 0.90, 0.82) * modulate, false, 2.0)


func _draw_death_echoes() -> void:
	var time := float(Time.get_ticks_msec()) / 1000.0
	for echo_value in death_echoes:
		var echo := echo_value as Dictionary
		var duration := maxf(float(echo.get("duration", HitFeedbackFx.DEATH_DURATION)), 0.001)
		var ttl := clampf(float(echo.get("ttl", 0.0)), 0.0, duration)
		var progress := clampf(1.0 - ttl / duration, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(0.42, 1.0, progress)
		var enemy := echo.get("enemy", {}) as Dictionary
		var position := echo.get("position", Vector2.ZERO) as Vector2
		var scale := Vector2(1.0 - progress * 0.10, 1.0 - progress * 0.34)
		var sink := Vector2(0.0, progress * 11.0)
		draw_set_transform(position + sink, sin(progress * PI) * 0.025, scale)
		_draw_enemy_animation(enemy, Vector2.ZERO, Vector2(66, 74), time, Color(0.62, 0.72, 0.73, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _draw_enemy_hit_effects() -> void:
	for event_value in hit_effects:
		var event := event_value as Dictionary
		HitFeedbackFx.draw_impact_foreground(self, event)


func _draw_enemy_hit_backplates() -> void:
	for event_value in hit_effects:
		var event := event_value as Dictionary
		var tower_id := str(event.get("towerId", ""))
		var textures = attack_effect_textures.get(tower_id, null)
		if textures == null:
			continue
		HitFeedbackFx.draw_impact_backplate(self, event, textures as Dictionary, ATTACK_EFFECT_FRAMES)


func _draw_attack_effects() -> void:
	for effect in attack_effects:
		var e := effect as Dictionary
		var tower_id := str(e.get("towerId", ""))
		var textures = attack_effect_textures.get(tower_id, null)
		if textures == null:
			continue
		var duration := maxf(0.01, float(e.get("duration", ATTACK_EFFECT_DURATION)))
		var ttl := clampf(float(e.get("ttl", 0.0)), 0.0, duration)
		var elapsed := duration - ttl
		var frame_index := clampi(floori(elapsed * ATTACK_EFFECT_FPS), 0, ATTACK_EFFECT_FRAMES - 1)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var fade := clampf(ttl / duration, 0.0, 1.0)
		var matched := bool(e.get("matched", false))
		var alpha := 0.95 if matched else 0.58
		var from_pos := e.get("from", Vector2.ZERO) as Vector2
		var to_pos := e.get("to", Vector2.ZERO) as Vector2
		_draw_attack_beam(textures as Dictionary, from_pos, to_pos, frame_index, fade * alpha)
		if bool(e.get("showRange", false)):
			_draw_attack_range(textures as Dictionary, to_pos, frame_index, progress, fade * alpha)


func _draw_attack_beam(textures: Dictionary, from_pos: Vector2, to_pos: Vector2, frame_index: int, alpha: float) -> void:
	var texture = textures.get("beam", null)
	if texture == null:
		return
	var sheet := texture as Texture2D
	var direction := to_pos - from_pos
	var length := maxf(24.0, direction.length())
	var source_rect := Rect2(Vector2(float(frame_index) * ATTACK_BEAM_FRAME_SIZE.x, 0), ATTACK_BEAM_FRAME_SIZE)
	var target_rect := Rect2(Vector2(0, -ATTACK_BEAM_FRAME_SIZE.y * 0.25), Vector2(length, ATTACK_BEAM_FRAME_SIZE.y * 0.5))
	draw_set_transform(from_pos, direction.angle(), Vector2.ONE)
	draw_texture_rect_region(sheet, target_rect, source_rect, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_attack_range(textures: Dictionary, center: Vector2, frame_index: int, progress: float, alpha: float) -> void:
	var texture = textures.get("range", null)
	if texture == null:
		return
	var sheet := texture as Texture2D
	var source_rect := Rect2(Vector2(float(frame_index) * ATTACK_RANGE_FRAME_SIZE.x, 0), ATTACK_RANGE_FRAME_SIZE)
	var range_size := 108.0 + 74.0 * progress
	var target_rect := Rect2(center - Vector2(range_size, range_size) * 0.5, Vector2(range_size, range_size))
	draw_texture_rect_region(sheet, target_rect, source_rect, Color(1, 1, 1, alpha))


func _draw_feedback() -> void:
	for feedback in feedbacks:
		var f := feedback as Dictionary
		var font := _hit_feedback_font()
		var font_size := _hit_feedback_font_size()
		var text := str(f["text"])
		var pos := f["pos"] as Vector2
		draw_string(font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, 136, font_size, Color(0.02, 0.06, 0.08, 0.42))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 136, font_size, f["color"])
