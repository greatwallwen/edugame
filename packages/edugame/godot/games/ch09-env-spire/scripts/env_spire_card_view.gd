extends Button

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const DISPLAY_FONT = preload("res://assets/fonts/DingTalkJinBuTi.ttf")
const DETAIL_FONT = preload("res://assets/fonts/NotoSansSC-VF.ttf")

const ART_PATHS := {
	"mq2_sample": "res://assets/card-art/prototypes/mq2_sample-v4.png",
	"bh1750_read": "res://assets/card-art/prototypes/bh1750_read-v4.png",
	"hdc1080_read": "res://assets/card-art/prototypes/hdc1080_read-v4.png",
	"environment_baseline": "res://assets/card-art/prototypes/environment_baseline-v4.png",
	"adc_continuous_sample": "res://assets/card-art/prototypes/adc_continuous_sample-v4.png",
	"adc_convert": "res://assets/card-art/prototypes/adc_convert-v4.png",
	"i2c_transaction": "res://assets/card-art/prototypes/i2c_transaction-v4.png",
	"unit_convert": "res://assets/card-art/prototypes/unit_convert-v4.png",
	"sliding_average": "res://assets/card-art/prototypes/sliding_average-v4.png",
	"threshold_judgement": "res://assets/card-art/prototypes/threshold_judgement-v4.png",
	"outlier_reject": "res://assets/card-art/prototypes/outlier_reject-v4.png",
	"address_shift": "res://assets/card-art/prototypes/address_shift-v4.png",
	"i2c_register_read": "res://assets/card-art/prototypes/i2c_register_read-v4.png",
	"time_slice": "res://assets/card-art/prototypes/time_slice-v4.png",
	"state_machine": "res://assets/card-art/prototypes/state_machine-v4.png",
	"nonblocking_delay": "res://assets/card-art/prototypes/nonblocking_delay-v4.png",
	"data_cache": "res://assets/card-art/prototypes/data_cache-v4.png",
	"bus_reset": "res://assets/card-art/prototypes/bus_reset-v4.png",
	"timeout_retry": "res://assets/card-art/prototypes/timeout_retry-v4.png",
	"uart_log": "res://assets/card-art/prototypes/uart_log-v4.png",
	"lcd_display": "res://assets/card-art/prototypes/lcd_display-v4.png",
	"led_alarm": "res://assets/card-art/prototypes/led_alarm-v4.png",
	"serial_curve": "res://assets/card-art/prototypes/serial_curve-v4.png",
	"acceptance_report": "res://assets/card-art/prototypes/acceptance_report-v4.png",
	"calibration_curve": "res://assets/card-art/prototypes/calibration_curve-v4.png",
	"i2c_address_table": "res://assets/card-art/prototypes/i2c_address_table-v4.png",
	"scheduler_template": "res://assets/card-art/prototypes/scheduler_template-v4.png",
	"display_buffer": "res://assets/card-art/prototypes/display_buffer-v4.png",
	"polling_scan": "res://assets/card-art/prototypes/polling_scan-v4.png",
	"logic_probe": "res://assets/card-art/prototypes/logic_probe-v4.png",
	"task_yield": "res://assets/card-art/prototypes/task_yield-v4.png",
	"median_filter": "res://assets/card-art/prototypes/median_filter-v4.png",
	"dma_queue": "res://assets/card-art/prototypes/dma_queue-v4.png",
	"trusted_snapshot": "res://assets/card-art/prototypes/trusted_snapshot-v4.png",
	"interrupt_trace": "res://assets/card-art/prototypes/interrupt_trace-v4.png",
	"multi_source_dashboard": "res://assets/card-art/prototypes/multi_source_dashboard-v4.png",
	"diagnostic_manual": "res://assets/card-art/prototypes/diagnostic_manual-v4.png",
	"abnormal_reading": "res://assets/card-art/prototypes/abnormal_reading-v4.png",
	"stale_data": "res://assets/card-art/prototypes/stale_data-v4.png",
	"blocking_delay": "res://assets/card-art/prototypes/blocking_delay-v4.png",
	"i2c_nack": "res://assets/card-art/prototypes/i2c_nack-v4.png",
	"address_conflict": "res://assets/card-art/prototypes/address_conflict-v4.png",
	"uncalibrated": "res://assets/card-art/prototypes/uncalibrated-v4.png",
	"uncalibrated_reading": "res://assets/card-art/prototypes/uncalibrated-v4.png",
	"false_alarm": "res://assets/card-art/prototypes/false_alarm-v4.png",
	"unverified_config": "res://assets/card-art/prototypes/unverified_config-v4.png"
}

const TYPE_COLORS := {
	"collect": Color("#d95f4f"),
	"interface": Color("#2bb8c3"),
	"process": Color("#8260d1"),
	"defense": Color("#58a86e"),
	"output": Color("#dc9223"),
	"power": Color("#c8a53b"),
	"negative": Color("#a74450")
}

const TYPE_DARK_COLORS := {
	"collect": Color("#973e35"),
	"interface": Color("#167d86"),
	"process": Color("#593f9e"),
	"defense": Color("#337449"),
	"output": Color("#966017"),
	"power": Color("#846b1f"),
	"negative": Color("#6f2831")
}

const TYPE_NAMES := {
	"collect": "采集",
	"interface": "接口",
	"process": "处理",
	"defense": "防护",
	"output": "输出",
	"power": "能力",
	"negative": "故障"
}

const TYPE_GLYPHS := {
	"collect": "◎",
	"interface": "▦",
	"process": "∿",
	"defense": "◇",
	"output": "◉",
	"power": "▤",
	"negative": "!"
}

const STAGE_NAMES := {
	"collect": "采集阶段",
	"interface": "接口阶段",
	"process": "处理阶段",
	"output": "输出阶段"
}

const RARITY_NAMES := {
	"starter": "基础",
	"common": "普通",
	"uncommon": "进阶",
	"rare": "稀有",
	"negative": "负面"
}

const RARITY_COLORS := {
	"starter": Color("#9aa7a2"),
	"common": Color("#d2d7d3"),
	"uncommon": Color("#72b8c0"),
	"rare": Color("#f0c95d"),
	"negative": Color("#d05a68")
}

var card_data: Dictionary = {}
var display_mode := "hand"
var unavailable_reason := ""
var support_text := ""

var cost_orb: PanelContainer
var cost_label: Label
var title_label: Label
var art_rect: TextureRect
var art_fallback: ColorRect
var art_fallback_glyph: Label
var type_strip: Label
var effect_label: Label
var footer_label: Label
var rarity_mark: ColorRect
var unavailable_overlay: ColorRect
var unavailable_label: Label


func _init() -> void:
	clip_contents = false
	clip_text = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_nodes()
	_apply_card_fonts()
	_hide_native_text()


func configure_card(
	card: Dictionary,
	mode: String = "hand",
	cost_value: Variant = null,
	reason: String = "",
	card_support_text: String = ""
) -> void:
	card_data = card.duplicate(true)
	display_mode = mode if mode in ["hand", "compact", "choice"] else "hand"
	unavailable_reason = reason
	support_text = card_support_text
	var card_type := _card_type(card_data)
	var accent: Color = TYPE_COLORS.get(card_type, Color("#697b80"))
	var accent_dark: Color = TYPE_DARK_COLORS.get(card_type, accent.darkened(0.28))
	_apply_size()
	_apply_frame_styles(accent)
	_layout_nodes()

	var negative := _is_negative(card_data)
	var resolved_cost: Variant = cost_value
	if resolved_cost == null:
		resolved_cost = "!" if negative else int(card_data.get("cost", 0))
	cost_label.text = str(resolved_cost)
	title_label.text = str(card_data.get("name", "卡牌")) + ("+" if bool(card_data.get("upgraded", false)) else "")
	var effect_text := str(
		card_data.get("upgradedEffectText", card_data.get("effectText", ""))
		if bool(card_data.get("upgraded", false))
		else card_data.get("effectText", "")
	)
	if negative and effect_text.is_empty():
		effect_text = _negative_effect_text(card_data)
	effect_label.text = effect_text
	var stage := str(card_data.get("stage", card_type))
	if card_type in ["defense", "power", "negative"]:
		stage = card_type
	var stage_name: String = str({
		"defense": "任意阶段",
		"power": "持续生效",
		"negative": "抽取触发"
	}.get(stage, STAGE_NAMES.get(stage, "任意阶段")))
	type_strip.text = "%s  %s       %s" % [
		TYPE_GLYPHS.get(card_type, "•"),
		TYPE_NAMES.get(card_type, card_type),
		stage_name
	]
	var rarity := "negative" if negative else str(card_data.get("rarity", "common"))
	footer_label.text = "%s%s" % [
		RARITY_NAMES.get(rarity, rarity),
		(" · " + support_text) if !support_text.is_empty() else ""
	]
	rarity_mark.color = RARITY_COLORS.get(rarity, Color("#9aa7a2"))
	art_fallback.color = accent_dark
	art_fallback_glyph.text = str(TYPE_GLYPHS.get(card_type, "•"))

	var texture := _load_card_texture(str(card_data.get("id", "")))
	art_rect.texture = texture
	art_rect.visible = texture != null
	art_fallback.visible = texture == null
	tooltip_text = str(card_data.get("knowledgePoint", ""))
	if !unavailable_reason.is_empty():
		tooltip_text += ("\n" if !tooltip_text.is_empty() else "") + "不可用：" + unavailable_reason
	unavailable_label.text = unavailable_reason
	unavailable_overlay.visible = !unavailable_reason.is_empty()
	disabled = !unavailable_reason.is_empty()
	text = _semantic_text(resolved_cost, card_type, effect_text)


func _get_minimum_size() -> Vector2:
	return custom_minimum_size


func _build_nodes() -> void:
	title_label = Label.new()
	title_label.name = "CardTitle"
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", Color("#f4f8fb"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	art_fallback = ColorRect.new()
	art_fallback.name = "CardArtFallback"
	art_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_fallback)
	art_fallback_glyph = Label.new()
	art_fallback_glyph.name = "CardArtFallbackGlyph"
	art_fallback_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_fallback_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_fallback_glyph.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	art_fallback_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_fallback.add_child(art_fallback_glyph)

	art_rect = TextureRect.new()
	art_rect.name = "CardArt"
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_rect)

	type_strip = Label.new()
	type_strip.name = "CardTypeStrip"
	type_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_strip.add_theme_color_override("font_color", Color("#fffaf0"))
	type_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(type_strip)

	effect_label = Label.new()
	effect_label.name = "CardEffect"
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", Color("#25312e"))
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect_label)

	footer_label = Label.new()
	footer_label.name = "CardFooter"
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer_label.clip_text = true
	footer_label.add_theme_color_override("font_color", Color("#52635f"))
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_label)

	rarity_mark = ColorRect.new()
	rarity_mark.name = "CardRarityMark"
	rarity_mark.rotation = PI / 4.0
	rarity_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rarity_mark)

	cost_orb = PanelContainer.new()
	cost_orb.name = "CardCostOrb"
	cost_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_orb.z_index = 4
	add_child(cost_orb)
	cost_label = Label.new()
	cost_label.name = "CardCost"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color("#18211f"))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_orb.add_child(cost_label)

	unavailable_overlay = ColorRect.new()
	unavailable_overlay.name = "CardUnavailableOverlay"
	unavailable_overlay.color = Color(0.08, 0.10, 0.10, 0.76)
	unavailable_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unavailable_overlay.z_index = 2
	unavailable_overlay.visible = false
	add_child(unavailable_overlay)
	unavailable_label = Label.new()
	unavailable_label.name = "CardUnavailableReason"
	unavailable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unavailable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unavailable_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unavailable_label.add_theme_color_override("font_color", Color("#fff7e3"))
	unavailable_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unavailable_overlay.add_child(unavailable_label)


func _apply_card_fonts() -> void:
	var art_body := VisualTheme.font_for_role(DISPLAY_FONT, "body")
	var art_strong := VisualTheme.font_for_role(DISPLAY_FONT, "strong")
	var art_display := VisualTheme.font_for_role(DISPLAY_FONT, "display")
	var detail := VisualTheme.font_for_role(DETAIL_FONT, "body")
	for label in [title_label, cost_label]:
		label.add_theme_font_override("font", art_strong)
	for label in [type_strip, footer_label]:
		label.add_theme_font_override("font", art_body)
	art_fallback_glyph.add_theme_font_override("font", art_display)
	effect_label.add_theme_font_override("font", detail)
	unavailable_label.add_theme_font_override("font", detail)


func _apply_size() -> void:
	custom_minimum_size = {
		"hand": Vector2(130, 186),
		"compact": Vector2(166, 240),
		"choice": Vector2(212, 306)
	}.get(display_mode, Vector2(130, 186))


func _layout_nodes() -> void:
	var card_size := custom_minimum_size
	var choice_mode := display_mode == "choice"
	var compact_mode := display_mode == "compact"
	var header_height := 40.0 if choice_mode else (32.0 if compact_mode else 26.0)
	var strip_height := 25.0 if choice_mode else (21.0 if compact_mode else 18.0)
	var art_height := (card_size.x - 4.0) * 0.75
	var footer_height := 20.0 if choice_mode else (16.0 if compact_mode else 12.0)
	var cost_size := 50.0 if choice_mode else (42.0 if compact_mode else 36.0)
	var cost_title_gap := 2.0
	var rules_top := header_height + art_height + strip_height

	title_label.position = Vector2(cost_size * 0.62, 0.0)
	title_label.size = Vector2(card_size.x - cost_size * 0.82, header_height)
	art_fallback.position = Vector2(2.0, header_height)
	art_fallback.size = Vector2(card_size.x - 4.0, art_height)
	art_fallback_glyph.position = Vector2.ZERO
	art_fallback_glyph.size = art_fallback.size
	art_rect.position = art_fallback.position
	art_rect.size = art_fallback.size
	type_strip.position = Vector2(2.0, header_height + art_height)
	type_strip.size = Vector2(card_size.x - 4.0, strip_height)
	effect_label.position = Vector2(8.0, rules_top + 2.0)
	effect_label.size = Vector2(card_size.x - 16.0, card_size.y - rules_top - footer_height - 4.0)
	footer_label.position = Vector2(8.0, card_size.y - footer_height - 2.0)
	footer_label.size = Vector2(card_size.x - 16.0, footer_height)
	rarity_mark.position = Vector2(card_size.x - (18.0 if choice_mode else (16.0 if compact_mode else 14.0)), 10.0)
	rarity_mark.size = Vector2(9.0, 9.0) if choice_mode else (Vector2(8.0, 8.0) if compact_mode else Vector2(7.0, 7.0))
	cost_orb.position = Vector2(title_label.position.x - cost_size - cost_title_gap, 4.0)
	cost_orb.size = Vector2(cost_size, cost_size)
	unavailable_overlay.position = Vector2.ZERO
	unavailable_overlay.size = card_size
	unavailable_label.position = Vector2(12.0, rules_top - 10.0)
	unavailable_label.size = Vector2(card_size.x - 24.0, card_size.y - rules_top + 4.0)

	title_label.add_theme_font_size_override("font_size", 18 if choice_mode else (14 if compact_mode else 12))
	type_strip.add_theme_font_size_override("font_size", 12 if choice_mode else (10 if compact_mode else 8))
	effect_label.add_theme_font_size_override("font_size", 15 if choice_mode else (11 if compact_mode else 10))
	footer_label.add_theme_font_size_override("font_size", 10 if choice_mode else 8)
	cost_label.add_theme_font_size_override("font_size", 22 if choice_mode else (18 if compact_mode else 16))
	art_fallback_glyph.add_theme_font_size_override("font_size", 64 if choice_mode else (50 if compact_mode else 42))
	unavailable_label.add_theme_font_size_override("font_size", 14 if choice_mode else (11 if compact_mode else 10))


func _apply_frame_styles(accent: Color) -> void:
	var normal := _frame_style(Color("#151b1b"), accent, 2, 10)
	var hover := _frame_style(Color("#1c2524"), accent.lightened(0.12), 3, 16)
	var pressed := _frame_style(Color("#101716"), accent.darkened(0.08), 3, 8)
	var disabled_style := _frame_style(Color("#202625"), accent.lerp(Color("#7d8884"), 0.48), 2, 5)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)

	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = TYPE_DARK_COLORS.get(_card_type(card_data), accent.darkened(0.28))
	strip_style.content_margin_left = 8.0
	strip_style.content_margin_right = 8.0
	type_strip.add_theme_stylebox_override("normal", strip_style)

	var effect_style := StyleBoxFlat.new()
	effect_style.bg_color = Color("#f3efe4")
	effect_style.content_margin_left = 5.0
	effect_style.content_margin_right = 5.0
	effect_label.add_theme_stylebox_override("normal", effect_style)

	var orb_style := StyleBoxFlat.new()
	orb_style.bg_color = Color("#f8f3df")
	orb_style.border_color = accent
	orb_style.set_border_width_all(3)
	orb_style.corner_radius_top_left = 30
	orb_style.corner_radius_top_right = 30
	orb_style.corner_radius_bottom_left = 30
	orb_style.corner_radius_bottom_right = 30
	orb_style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	orb_style.shadow_size = 5
	orb_style.shadow_offset = Vector2(0, 3)
	cost_orb.add_theme_stylebox_override("panel", orb_style)


func _frame_style(surface: Color, accent: Color, border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = surface
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 5)
	return style


func _hide_native_text() -> void:
	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_disabled_color"
	]:
		add_theme_color_override(color_name, Color.TRANSPARENT)


func _load_card_texture(card_id: String) -> Texture2D:
	var path := str(ART_PATHS.get(card_id, ""))
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func has_card_art(card_id: String) -> bool:
	var path := str(ART_PATHS.get(card_id, ""))
	return !path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(ProjectSettings.globalize_path(path)))


func _card_type(card: Dictionary) -> String:
	if _is_negative(card):
		return "negative"
	return str(card.get("type", "process"))


func _is_negative(card: Dictionary) -> bool:
	return bool(card.get("negative", false)) or str(card.get("type", "")) == "negative" or card.has("drawEffect")


func _negative_effect_text(card: Dictionary) -> String:
	var effect := card.get("drawEffect", {}) as Dictionary
	var effect_type := str(effect.get("type", "影响"))
	var amount := int(effect.get("amount", 0))
	if effect_type == "damage":
		return "抽到时：稳定度 -%d。" % amount
	if effect_type == "energy":
		return "抽到时：处理点 %d。" % amount
	return "抽到时：%s %d。" % [effect_type, amount]


func _semantic_text(cost_value: Variant, card_type: String, effect_text: String) -> String:
	return "[%s] %s · %s\n%s%s%s" % [
		str(cost_value),
		str(card_data.get("name", "卡牌")),
		card_type,
		effect_text,
		("\n" + support_text) if !support_text.is_empty() else "",
		("\n不可用：" + unavailable_reason) if !unavailable_reason.is_empty() else ""
	]
