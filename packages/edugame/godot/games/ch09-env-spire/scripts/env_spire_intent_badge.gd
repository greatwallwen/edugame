extends Button

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const BADGE_SIZE := Vector2(154, 42)
const NEGATIVE_LABELS := {
	"uncalibrated": "未校准读数",
	"uncalibrated_reading": "未校准读数",
	"stale_data": "旧数据",
	"abnormal_reading": "异常读数",
	"blocking_delay": "阻塞延时",
	"false_alarm": "误报警",
	"i2c_nack": "I2C NACK",
	"address_conflict": "地址冲突",
	"unverified_config": "未验证配置"
}

var intent_data: Dictionary = {}
var intent_summary: Dictionary = {}
var badge_font: Font


func _init() -> void:
	name = "EnemyIntent"
	custom_minimum_size = BADGE_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	clip_text = true
	_apply_styles(Color("#ff665f"))


func configure_intent(intent: Dictionary, font: Font) -> void:
	intent_data = intent.duplicate(true)
	intent_summary = summary_for_intent(intent_data)
	badge_font = font if font != null else ThemeDB.fallback_font
	tooltip_text = str(intent_summary.get("tooltip", ""))
	_apply_styles(intent_summary.get("accent", Color("#ffb43e")) as Color)
	queue_redraw()


func summary_for_intent(intent: Dictionary) -> Dictionary:
	var intent_type := str(intent.get("type", "warning"))
	var full_text := str(intent.get("text", "系统状态变化"))
	match intent_type:
		"damage":
			var amount := maxi(0, int(intent.get("amount", 0)))
			return {
				"icon": "damage",
				"label": "稳定度",
				"value": "-%d" % amount,
				"accent": Color("#ff665f"),
				"tooltip": full_text
			}
		"negative":
			var card_id := str(intent.get("card", ""))
			return {
				"icon": "negative",
				"label": str(NEGATIVE_LABELS.get(card_id, _concise_action(full_text))),
				"value": "+1",
				"accent": Color("#a98cff"),
				"tooltip": full_text
			}
		_:
			return {
				"icon": "warning",
				"label": _concise_action(full_text),
				"value": "",
				"accent": Color("#ffb43e"),
				"tooltip": full_text
			}


func visual_contract() -> Dictionary:
	return {
		"size": BADGE_SIZE,
		"iconSize": 24,
		"maxLines": 1,
		"placement": "enemy_art_top_center"
	}


func _concise_action(full_text: String) -> String:
	var concise := full_text.strip_edges()
	for prefix in ["加入", "执行"]:
		if concise.begins_with(prefix):
			concise = concise.trim_prefix(prefix).strip_edges()
	if concise.contains("："):
		concise = concise.get_slice("：", 0).strip_edges()
	if concise.is_empty():
		return "系统动作"
	return concise.left(8)


func _apply_styles(accent: Color) -> void:
	var styles := VisualTheme.button_styles(accent)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := (styles.get(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.set_corner_radius_all(3)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.border_width_left = 3
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		add_theme_stylebox_override(state, style)


func _draw() -> void:
	if intent_summary.is_empty():
		return
	var accent := intent_summary.get("accent", Color("#ffb43e")) as Color
	var icon_rect := Rect2(9, 9, 24, 24)
	_draw_icon(str(intent_summary.get("icon", "warning")), icon_rect, accent)
	var font := badge_font if badge_font != null else ThemeDB.fallback_font
	var label := str(intent_summary.get("label", "系统动作"))
	var value := str(intent_summary.get("value", ""))
	draw_string(font, Vector2(40, 27), label, HORIZONTAL_ALIGNMENT_LEFT, 76, 13, Color("#f4f8fb"))
	if !value.is_empty():
		var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(size.x - 10.0 - value_width, 29), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)


func _draw_icon(kind: String, rect: Rect2, accent: Color) -> void:
	draw_circle(rect.get_center(), 12.0, Color(accent.r, accent.g, accent.b, 0.16))
	match kind:
		"damage":
			var bolt := PackedVector2Array([
				rect.position + Vector2(13, 2), rect.position + Vector2(6, 14),
				rect.position + Vector2(12, 14), rect.position + Vector2(9, 23),
				rect.position + Vector2(19, 10), rect.position + Vector2(13, 10)
			])
			draw_colored_polygon(bolt, accent)
		"negative":
			draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(13, 17)), Color("#101821"), true)
			draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(13, 17)), accent, false, 2.0)
			draw_line(rect.position + Vector2(16, 16), rect.position + Vector2(22, 16), accent, 2.0)
			draw_line(rect.position + Vector2(19, 13), rect.position + Vector2(19, 19), accent, 2.0)
		_:
			var triangle := PackedVector2Array([
				rect.position + Vector2(12, 2), rect.position + Vector2(23, 21), rect.position + Vector2(1, 21)
			])
			draw_colored_polygon(triangle, Color(accent.r, accent.g, accent.b, 0.26))
			draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), accent, 2.0, true)
			draw_line(rect.position + Vector2(12, 8), rect.position + Vector2(12, 15), accent, 2.0)
			draw_circle(rect.position + Vector2(12, 18), 1.4, accent)
