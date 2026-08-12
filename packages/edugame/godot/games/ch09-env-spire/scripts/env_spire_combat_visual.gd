extends Control

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")
const ENEMY_ART_ROOT := "res://assets/enemy-art"
const ENEMY_ART_IDS := {
	"mq2_warmup": true,
	"bh1750_stale": true,
	"adc_spike": true,
	"lcd_blocking": true,
	"alarm_jitter": true,
	"mq2_baseline_drift": true,
	"bh1750_early_read": true,
	"hdc1080_conversion_wait": true,
	"i2c_address_collision": true,
	"uart_frame_overrun": true,
	"i2c_congestion": true,
	"multi_sensor_race": true,
	"display_bus_deadlock": true,
	"warehouse_acceptance": true
}

var visual_mode := "device"
var ui_font: Font
var snapshot: Dictionary = {}
var pulse_amount := 0.0
var pulse_color := Color("#2f7f8d")
var pulse_kind := ""
var motion_time := 0.0
var enemy_art_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func configure(mode: String, font: Font) -> void:
	visual_mode = mode
	ui_font = font if font != null else ThemeDB.fallback_font
	queue_redraw()


func set_snapshot(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	_sync_enemy_art()
	queue_redraw()


func visual_snapshot() -> Dictionary:
	return snapshot.duplicate(true)


func enemy_art_path(encounter_id: String = "") -> String:
	var resolved_id := encounter_id
	if resolved_id.is_empty():
		resolved_id = str(snapshot.get("id", snapshot.get("encounterId", "")))
	if !ENEMY_ART_IDS.has(resolved_id):
		return ""
	return "%s/%s.png" % [ENEMY_ART_ROOT, resolved_id]


func _sync_enemy_art() -> void:
	enemy_art_texture = null
	var art_path := enemy_art_path()
	if !art_path.is_empty() and ResourceLoader.exists(art_path):
		enemy_art_texture = load(art_path) as Texture2D


func surface_palette() -> Dictionary:
	return {
		"background": Color("#111821"),
		"raised": Color("#182330"),
		"label": VisualTheme.color("button_text"),
		"secondary": VisualTheme.color("button_text_muted"),
		"device": Color("#20d7ee"),
		"evidence": Color("#5bf0b4"),
		"fault": Color("#ff5f57")
	}


func fault_art_contract() -> Dictionary:
	return {
		"style": "flat_electronic_target",
		"minimumTraceWidth": 3,
		"tonalSteps": 3,
		"motifLanguage": "engineering_modules",
		"textPlateBorderWidth": 0,
		"minimumTextPadding": 6,
		"redundantTopLabels": false
	}


func localized_signal_labels() -> Dictionary:
	return {
		"sources": ["烟", "光", "温", "湿"],
		"stages": ["采", "接", "理", "出"]
	}


func content_safe_rect() -> Rect2:
	if size.y < 120.0:
		return Rect2(10, 10, maxf(0.0, size.x - 20.0), maxf(0.0, size.y - 20.0))
	return Rect2(14, 28, maxf(0.0, size.x - 28.0), maxf(0.0, size.y - 56.0))


func fault_text_layout() -> Dictionary:
	var empty_layout := {
		"heading": Rect2(),
		"intent": Rect2(),
		"condition": Rect2(),
		"state": Rect2()
	}
	var safe_rect := content_safe_rect()
	if size.y < 120.0 or safe_rect.size.x < 240.0:
		return empty_layout
	var plate_height := 24.0
	var lower_rail_clearance := 20.0
	return {
		"heading": Rect2(),
		"intent": Rect2(),
		"condition": Rect2(Vector2(safe_rect.position.x, safe_rect.end.y - plate_height - lower_rail_clearance), Vector2(96.0, plate_height)),
		"state": Rect2(Vector2(safe_rect.end.x - 112.0, safe_rect.end.y - plate_height - lower_rail_clearance), Vector2(112.0, plate_height))
	}


func pulse(kind: String, accent: Color) -> void:
	pulse_kind = kind
	pulse_color = accent
	pulse_amount = 1.0
	queue_redraw()


func get_visual_signature() -> String:
	if visual_mode != "fault":
		return "%s:%s" % [visual_mode, str(snapshot.get("encounterId", "none"))]
	return "fault:flat_electronic_target:%s:%s:%d:%s" % [
		_enemy_art_signature(),
		str(snapshot.get("tier", "ordinary")),
		int(snapshot.get("bossPhase", 0)),
		fault_condition()
	]


func _enemy_art_signature() -> String:
	var art_path := enemy_art_path()
	if !art_path.is_empty():
		return art_path.get_file().get_basename()
	return _fault_motif()


func fault_condition() -> String:
	if bool(snapshot.get("resolved", false)):
		return "restored"
	var repair_target := maxi(1, int(snapshot.get("repairTarget", 1)))
	var repair_ratio := clampf(float(snapshot.get("repairProgress", 0)) / float(repair_target), 0.0, 1.0)
	if repair_ratio >= 1.0:
		return "restored"
	if repair_ratio >= 0.67:
		return "stabilizing"
	if repair_ratio >= 0.34:
		return "isolated"
	return "unstable"


func _process(delta: float) -> void:
	motion_time += delta
	if pulse_amount > 0.0:
		pulse_amount = maxf(0.0, pulse_amount - delta * 2.8)
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	match visual_mode:
		"device":
			_draw_device()
		"evidence":
			_draw_evidence()
		"fault":
			_draw_fault()
		_:
			_draw_empty()
	if pulse_amount > 0.0:
		var pulse_rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_style_box(_outline_style(Color(pulse_color.r, pulse_color.g, pulse_color.b, pulse_amount * 0.72)), pulse_rect)
		_draw_pulse_semantics()


func _draw_pulse_semantics() -> void:
	if visual_mode != "fault":
		return
	var center := Vector2(size.x * 0.50, size.y * 0.54)
	var alpha := clampf(pulse_amount, 0.0, 1.0)
	var color := Color(pulse_color.r, pulse_color.g, pulse_color.b, alpha * 0.86)
	match pulse_kind:
		"weakness":
			var spread := 42.0 + (1.0 - alpha) * 8.0
			_draw_target_corners(Rect2(center - Vector2(spread, 30), Vector2(spread * 2.0, 60)), color, 5.0)
		"fault_suppressed":
			var seal := PackedVector2Array([
				center + Vector2(0, -28), center + Vector2(30, 0),
				center + Vector2(0, 28), center + Vector2(-30, 0)
			])
			draw_colored_polygon(seal, Color(color.r, color.g, color.b, color.a * 0.22))
			draw_polyline(PackedVector2Array([seal[0], seal[1], seal[2], seal[3], seal[0]]), color, 4.0, true)
			draw_line(center + Vector2(-12, 1), center + Vector2(-3, 10), color, 5.0)
			draw_line(center + Vector2(-3, 10), center + Vector2(15, -12), color, 5.0)
		"fault_triggered":
			for index in range(3):
				var offset := Vector2(-44.0 + float(index) * 32.0, -24.0 + float(index % 2) * 22.0)
				draw_rect(Rect2(center + offset, Vector2(24, 12)), Color(color.r, color.g, color.b, color.a * (0.48 + float(index) * 0.16)), true)
		"boss_phase":
			for index in range(3):
				var segment := Rect2(center.x - 45.0 + float(index) * 32.0, center.y - 36.0, 26.0, 7.0)
				draw_rect(segment, Color(color.r, color.g, color.b, color.a * (1.0 - float(index) * 0.2)), true)


func _draw_device() -> void:
	var frame := Rect2(8, 20, minf(size.x * 0.43, 150.0), size.y - 28)
	draw_style_box(_surface_style(Color("#071820"), Color("#20d7ee")), frame)
	var chip := frame.grow(-10)
	draw_rect(chip, Color("#091219"), true)
	draw_rect(chip, Color("#20d7ee"), false, 2.0)
	for pin_index in range(4):
		var pin_y := chip.position.y + 10.0 + float(pin_index) * maxf((chip.size.y - 20.0) / 3.0, 8.0)
		draw_line(Vector2(chip.position.x - 6, pin_y), Vector2(chip.position.x, pin_y), Color("#9cc5bd"), 2.0)
		draw_line(Vector2(chip.end.x, pin_y), Vector2(chip.end.x + 6, pin_y), Color("#9cc5bd"), 2.0)
	var processing_points := int(snapshot.get("processingPoints", 0))
	var block := int(snapshot.get("block", 0))
	_draw_label(chip.position + Vector2(8, 20), "MCU / ENV", 13, Color("#e7f4f1"))
	_draw_label(chip.position + Vector2(8, 40), "PWR %d   SHD %d" % [processing_points, block], 11, Color("#b4d8d1"))

	var raw := snapshot.get("rawData", {}) as Dictionary
	var trusted := snapshot.get("trustedData", {}) as Dictionary
	var source_names := ["smoke", "light", "temp", "humidity"]
	var source_labels := localized_signal_labels().get("sources", []) as Array
	var right_start := frame.end.x + 18.0
	var available_width := maxf(size.x - right_start - 8.0, 80.0)
	for index in range(source_names.size()):
		var column_width := available_width / float(source_names.size())
		var center := Vector2(right_start + column_width * (float(index) + 0.5), 48)
		var raw_value := int(raw.get(source_names[index], 0))
		var trusted_value := int(trusted.get(source_names[index], 0))
		var active_color := Color("#5bf0b4") if trusted_value > 0 else (Color("#ff7a62") if raw_value > 0 else Color("#789092"))
		draw_circle(center, 9.0, Color(active_color.r, active_color.g, active_color.b, 0.20))
		draw_circle(center, 5.0, active_color)
		_draw_centered_label(Vector2(center.x, 76), source_labels[index], 11, VisualTheme.color("text_secondary"))
		_draw_centered_label(Vector2(center.x, 92), "%d/%d" % [raw_value, trusted_value], 10, VisualTheme.color("text_muted"))

	var waveform := PackedVector2Array()
	var wave_left := right_start + 3.0
	var wave_right := size.x - 12.0
	var wave_y := size.y - 20.0
	var raw_total := _dictionary_total(raw)
	for sample_index in range(16):
		var progress := float(sample_index) / 15.0
		var wave_height := sin(progress * TAU * 2.0 + motion_time * 2.2) * (3.0 + minf(float(raw_total), 5.0))
		waveform.append(Vector2(lerpf(wave_left, wave_right, progress), wave_y + wave_height))
	if waveform.size() > 1:
		draw_polyline(waveform, Color("#20d7ee"), 2.0, true)


func _draw_evidence() -> void:
	var stages: Array[String] = ["collect", "interface", "process", "output"]
	var stage_labels := localized_signal_labels().get("stages", []) as Array
	var active_stage := str(snapshot.get("lastStage", ""))
	var completed_stages := snapshot.get("completedStages", {}) as Dictionary
	var line_y := size.y * 0.50
	var left := 26.0
	var right := size.x - 26.0
	for index in range(stages.size() - 1):
		var from_x := lerpf(left, right, float(index) / 3.0)
		var to_x := lerpf(left, right, float(index + 1) / 3.0)
		var line_color := Color("#5bf0b4") if bool(completed_stages.get(stages[index], false)) else Color("#445166")
		draw_line(Vector2(from_x + 9, line_y), Vector2(to_x - 9, line_y), line_color, 3.0)
	for index in range(stages.size()):
		var stage: String = stages[index]
		var center := Vector2(lerpf(left, right, float(index) / 3.0), line_y)
		var completed := bool(completed_stages.get(stage, false))
		var active: bool = stage == active_stage
		var stage_color := _stage_color(stage)
		var outer := stage_color if active or completed else Color("#536072")
		draw_circle(center, 12.0, Color(outer.r, outer.g, outer.b, 0.20))
		draw_circle(center, 8.0, outer if active or completed else Color("#202a38"))
		draw_circle(center, 8.0, outer, false, 2.0)
		_draw_centered_label(Vector2(center.x, center.y + 31), stage_labels[index], 11, VisualTheme.color("text_secondary"))

	var repair_progress := int(snapshot.get("repairProgress", 0))
	var repair_target := maxi(1, int(snapshot.get("repairTarget", 1)))
	var repair_ratio := clampf(float(repair_progress) / float(repair_target), 0.0, 1.0)
	var ring_center := Vector2(size.x - 32.0, 28.0)
	draw_arc(ring_center, 14.0, -PI * 0.5, PI * 1.5, 30, Color("#3b4657"), 3.0, true)
	draw_arc(ring_center, 14.0, -PI * 0.5, -PI * 0.5 + TAU * repair_ratio, 30, VisualTheme.color("success"), 4.0, true)
	var gate_met := bool(snapshot.get("gateMet", false))
	_draw_label(Vector2(10, size.y - 8), "GATE %s  //  REPAIR %d%%" % ["PASS" if gate_met else "OPEN", int(round(repair_ratio * 100.0))], 11, VisualTheme.color("success") if gate_met else VisualTheme.color("warning"))


func _draw_fault() -> void:
	var motif := _fault_motif()
	var accent := _fault_accent()
	var muted := accent.lerp(Color("#111820"), 0.58)
	var safe_rect := content_safe_rect()
	var text_layout := fault_text_layout()
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.30, 22), Vector2(size.x - 8, 22),
		Vector2(size.x - 8, size.y - 18), Vector2(size.x * 0.62, size.y - 18)
	]), Color(accent.r, accent.g, accent.b, 0.055))
	var condition_rect := text_layout.get("condition", Rect2()) as Rect2
	var condition_target := safe_rect.grow(-8.0)
	if enemy_art_texture != null:
		_draw_enemy_art(enemy_art_texture, safe_rect)
	else:
		var art_bottom := safe_rect.end.y
		if condition_rect.has_area():
			art_bottom = condition_rect.position.y - 7.0
		var art_height := maxf(30.0, art_bottom - safe_rect.position.y)
		var center := Vector2(size.x * 0.50, safe_rect.position.y + art_height * 0.5)
		var module_height := minf(clampf(size.y * 0.44, 54.0, 92.0), art_height)
		var module_size := Vector2(clampf(size.x * 0.46, 154.0, 214.0), module_height)
		var module_rect := Rect2(center - module_size * 0.5, module_size)
		_draw_clipped_plate(Rect2(module_rect.position + Vector2(4, 5), module_rect.size), Color("#080d13"), Color("#080d13"), 9.0)
		_draw_clipped_plate(module_rect, Color("#171f29"), muted, 9.0)
		draw_rect(Rect2(module_rect.position + Vector2(12, 8), Vector2(module_rect.size.x - 24, 5)), accent, true)
		for pin_index in range(4):
			var pin_y := module_rect.position.y + 20.0 + float(pin_index) * maxf((module_rect.size.y - 40.0) / 3.0, 10.0)
			draw_rect(Rect2(module_rect.position.x - 7, pin_y - 3, 9, 6), muted, true)
			draw_rect(Rect2(module_rect.end.x - 2, pin_y - 3, 9, 6), muted, true)
		var indicator_alpha := 0.70 + sin(motion_time * 3.0) * 0.10
		draw_rect(Rect2(module_rect.end.x - 24, module_rect.position.y + 19, 10, 6), Color(accent.r, accent.g, accent.b, indicator_alpha), true)
		_draw_fault_motif(motif, module_rect.grow(-14), accent, muted)
		condition_target = module_rect
	_draw_fault_condition(condition_target)

	var triggered := bool(snapshot.get("faultTriggered", false))
	var suppressed := bool(snapshot.get("faultSuppressed", false))
	var state_text := "TRIGGERED" if triggered else ("SUPPRESSED" if suppressed else "MONITORING")
	var state_color := Color("#ff5f57") if triggered else (Color("#5bf0b4") if suppressed else Color("#aa85ff"))
	if condition_rect.has_area():
		var condition_color := _fault_condition_color()
		_draw_text_plate(condition_rect, Color("#101821"), condition_color)
		_draw_label(condition_rect.position + Vector2(10, 16), fault_condition().to_upper(), 9, condition_color)
	var state_rect := text_layout.get("state", Rect2()) as Rect2
	if state_rect.has_area():
		_draw_text_plate(state_rect, Color("#101821"), state_color)
		_draw_centered_label(Vector2(state_rect.get_center().x, state_rect.position.y + 16), state_text, 9, state_color)


func _draw_enemy_art(texture: Texture2D, target_rect: Rect2) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or !target_rect.has_area():
		return
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	var target_ratio := target_rect.size.x / target_rect.size.y
	var source_ratio := texture_size.x / texture_size.y
	if source_ratio > target_ratio:
		var crop_width := texture_size.y * target_ratio
		source_rect.position.x = (texture_size.x - crop_width) * 0.5
		source_rect.size.x = crop_width
	else:
		var crop_height := texture_size.x / target_ratio
		source_rect.position.y = (texture_size.y - crop_height) * 0.5
		source_rect.size.y = crop_height
	draw_rect(target_rect, Color("#760e18"), true)
	draw_texture_rect_region(texture, target_rect, source_rect)
	var lower_shade := Rect2(
		Vector2(target_rect.position.x, target_rect.end.y - minf(30.0, target_rect.size.y * 0.32)),
		Vector2(target_rect.size.x, minf(30.0, target_rect.size.y * 0.32))
	)
	draw_rect(lower_shade, Color(0.04, 0.06, 0.08, 0.24), true)


func _draw_fault_motif(motif: String, rect: Rect2, accent: Color, muted: Color) -> void:
	var center := rect.get_center()
	var panel := Color("#0c131b")
	match motif:
		"thermal_ring":
			var sensor := Rect2(center - Vector2(25, 24), Vector2(50, 48))
			draw_rect(sensor, panel, true)
			draw_rect(sensor, muted, false, 3.0)
			for coil_index in range(4):
				var coil_y := sensor.position.y + 10.0 + float(coil_index) * 9.0
				var coil_start := sensor.position.x + (8.0 if coil_index % 2 == 0 else 16.0)
				var coil_end := sensor.end.x - (16.0 if coil_index % 2 == 0 else 8.0)
				draw_line(Vector2(coil_start, coil_y), Vector2(coil_end, coil_y), accent, 4.0)
			draw_rect(Rect2(sensor.position.x - 18, center.y - 5, 18, 10), muted, true)
			draw_rect(Rect2(sensor.end.x, center.y - 5, 18, 10), muted, true)
			_draw_centered_label(Vector2(center.x, sensor.end.y + 11), "MQ-2", 9, accent)
		"stale_bars":
			var slot_width := 22.0
			for slot_index in range(5):
				var slot := Rect2(center.x - 59.0 + float(slot_index) * 25.0, center.y - 18.0, slot_width, 36.0)
				draw_rect(slot, panel, true)
				draw_rect(slot.grow(-4), accent if slot_index < 2 else muted, true)
			_draw_label(Vector2(rect.position.x + 3, rect.end.y - 2), "OLD DATA", 9, accent)
		"adc_spike":
			var adc_block := Rect2(rect.position.x + 5, center.y - 22, 42, 44)
			draw_rect(adc_block, panel, true)
			draw_rect(adc_block, muted, false, 3.0)
			_draw_centered_label(Vector2(adc_block.get_center().x, adc_block.get_center().y + 4), "ADC", 9, accent)
			_draw_fault_trace(PackedVector2Array([
				Vector2(rect.position.x, center.y), Vector2(adc_block.position.x, center.y)
			]), muted)
			var graph_left := adc_block.end.x + 12.0
			draw_rect(Rect2(graph_left, center.y - 24, rect.end.x - graph_left, 48), panel, true)
			_draw_fault_trace(PackedVector2Array([
				Vector2(graph_left + 4, center.y + 13), Vector2(graph_left + 22, center.y + 11),
				Vector2(graph_left + 34, center.y - 20), Vector2(graph_left + 44, center.y + 14),
				Vector2(rect.end.x - 4, center.y + 11)
			]), accent, 4.0)
		"scan_block":
			var display := Rect2(center - Vector2(54, 25), Vector2(108, 50))
			draw_rect(display, panel, true)
			draw_rect(display, muted, false, 3.0)
			for row_index in range(4):
				var row := Rect2(display.position.x + 9, display.position.y + 8 + float(row_index) * 10.0, 66, 5)
				draw_rect(row, accent if row_index == 2 else muted, true)
			draw_rect(Rect2(display.end.x - 23, display.position.y + 8, 13, 34), accent, true)
			draw_rect(Rect2(display.end.x - 20, display.position.y + 15, 7, 20), panel, true)
		"threshold_wave":
			var comparator := PackedVector2Array([
				center + Vector2(-8, -26), center + Vector2(38, 0), center + Vector2(-8, 26)
			])
			draw_colored_polygon(comparator, panel)
			draw_polyline(PackedVector2Array([comparator[0], comparator[1], comparator[2], comparator[0]]), muted, 3.0, true)
			_draw_fault_trace(PackedVector2Array([
				Vector2(rect.position.x + 2, center.y + 12), center + Vector2(-8, 12)
			]), accent)
			_draw_fault_trace(PackedVector2Array([
				Vector2(rect.position.x + 2, center.y - 12), center + Vector2(-8, -12)
			]), Color("#ffb43e"))
			_draw_fault_trace(PackedVector2Array([center + Vector2(38, 0), Vector2(rect.end.x - 2, center.y)]), accent)
			draw_rect(Rect2(rect.end.x - 14, center.y - 8, 12, 16), accent, true)
		"bus_mesh":
			var rail_left := rect.position.x + 10.0
			var rail_right := rect.end.x - 10.0
			for rail_y in [center.y - 14.0, center.y + 14.0]:
				_draw_fault_trace(PackedVector2Array([Vector2(rail_left, rail_y), Vector2(rail_right, rail_y)]), accent)
			for device_index in range(3):
				var device_x := lerpf(rail_left + 12.0, rail_right - 12.0, float(device_index) / 2.0)
				draw_rect(Rect2(device_x - 10, center.y - 7, 20, 14), panel, true)
				draw_rect(Rect2(device_x - 10, center.y - 7, 20, 14), muted, false, 3.0)
			_draw_fault_trace(PackedVector2Array([center + Vector2(27, -24), center + Vector2(41, -10)]), Color("#ff5f57"), 5.0)
			_draw_fault_trace(PackedVector2Array([center + Vector2(41, -24), center + Vector2(27, -10)]), Color("#ff5f57"), 5.0)
		"sensor_matrix":
			var hub := Rect2(center - Vector2(18, 15), Vector2(36, 30))
			draw_rect(hub, accent, true)
			draw_rect(hub.grow(-5), panel, true)
			for node_offset in [Vector2(-52, -22), Vector2(52, -22), Vector2(-52, 22), Vector2(52, 22)]:
				var node_center: Vector2 = center + (node_offset as Vector2)
				_draw_fault_trace(PackedVector2Array([center, node_center]), muted)
				draw_rect(Rect2(node_center - Vector2(9, 7), Vector2(18, 14)), accent, true)
				draw_rect(Rect2(node_center - Vector2(5, 3), Vector2(10, 6)), panel, true)
		"trust_lattice":
			var block_width := 36.0
			for block_index in range(3):
				var block := Rect2(center.x - 58.0 + float(block_index) * 41.0, center.y - 17, block_width, 34)
				draw_rect(block, panel, true)
				draw_rect(block, accent if block_index == 2 else muted, false, 3.0)
				if block_index < 2:
					_draw_fault_trace(PackedVector2Array([Vector2(block.end.x, center.y), Vector2(block.end.x + 5, center.y)]), muted)
			draw_line(center + Vector2(28, 1), center + Vector2(36, 9), Color("#5bf0b4"), 4.0)
			draw_line(center + Vector2(36, 9), center + Vector2(50, -9), Color("#5bf0b4"), 4.0)
		"acceptance_core":
			var core := PackedVector2Array([
				center + Vector2(-24, -24), center + Vector2(24, -24),
				center + Vector2(36, 0), center + Vector2(24, 24),
				center + Vector2(-24, 24), center + Vector2(-36, 0)
			])
			draw_colored_polygon(core, panel)
			draw_polyline(PackedVector2Array([core[0], core[1], core[2], core[3], core[4], core[5], core[0]]), accent, 4.0, true)
			draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), accent, true)
			var boss_phase := clampi(int(snapshot.get("bossPhase", 0)), 0, 2)
			for phase_index in range(3):
				var phase_rect := Rect2(center.x - 49.0 + float(phase_index) * 34.0, rect.position.y + 1, 30, 7)
				draw_rect(phase_rect, accent if phase_index <= boss_phase else muted, true)
		_:
			var chip := Rect2(center - Vector2(38, 25), Vector2(76, 50))
			draw_rect(chip, panel, true)
			draw_rect(chip, muted, false, 3.0)
			_draw_centered_label(Vector2(center.x, center.y + 8), "!", 24, accent)


func _draw_fault_condition(module_rect: Rect2) -> void:
	var condition := fault_condition()
	var condition_color := _fault_condition_color()
	match condition:
		"unstable":
			var blink := 0.55 + sin(motion_time * 5.0) * 0.15
			for offset in [Vector2(-14, -7), Vector2(module_rect.size.x, 12), Vector2(18, module_rect.size.y)]:
				draw_rect(Rect2(module_rect.position + offset, Vector2(16, 7)), Color(condition_color.r, condition_color.g, condition_color.b, blink), true)
		"isolated":
			_draw_target_corners(module_rect.grow(7), condition_color, 4.0)
		"stabilizing":
			for segment_index in range(4):
				var segment_width := (module_rect.size.x - 21.0) / 4.0
				var segment := Rect2(module_rect.position.x + 4.0 + float(segment_index) * (segment_width + 3.0), module_rect.end.y + 5.0, segment_width, 5.0)
				draw_rect(segment, condition_color if segment_index < 3 else Color(condition_color.r, condition_color.g, condition_color.b, 0.25), true)
		"restored":
			draw_rect(module_rect.grow(4), Color(condition_color.r, condition_color.g, condition_color.b, 0.08), true)
			draw_rect(module_rect.grow(4), condition_color, false, 3.0)
			var seal_center := module_rect.get_center()
			draw_line(seal_center + Vector2(-12, 1), seal_center + Vector2(-3, 10), condition_color, 5.0)
			draw_line(seal_center + Vector2(-3, 10), seal_center + Vector2(16, -13), condition_color, 5.0)


func _fault_condition_color() -> Color:
	return {
		"unstable": Color("#ff5f57"),
		"isolated": Color("#ffb43e"),
		"stabilizing": Color("#20d7ee"),
		"restored": Color("#5bf0b4")
	}.get(fault_condition(), Color("#728487"))


func _draw_clipped_plate(rect: Rect2, fill: Color, edge: Color, cut: float) -> void:
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0), Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut), Vector2(rect.end.x, rect.end.y - cut),
		Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut), Vector2(rect.position.x, rect.position.y + cut)
	])
	draw_colored_polygon(points, fill)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, edge, 2.0, true)


func _draw_text_plate(rect: Rect2, fill: Color, accent: Color) -> void:
	var cut := 4.0
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0), Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut), Vector2(rect.end.x, rect.end.y - cut),
		Vector2(rect.end.x - cut, rect.end.y), Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut), Vector2(rect.position.x, rect.position.y + cut)
	])
	draw_colored_polygon(points, fill)
	draw_rect(Rect2(rect.position + Vector2(3, 5), Vector2(3, maxf(0.0, rect.size.y - 10))), accent, true)


func _draw_fault_trace(points: PackedVector2Array, color: Color, width: float = 3.0) -> void:
	if points.size() >= 2:
		draw_polyline(points, color, maxf(width, 3.0), true)


func _draw_target_corners(rect: Rect2, color: Color, width: float = 4.0) -> void:
	var length := minf(16.0, minf(rect.size.x, rect.size.y) * 0.28)
	for corner in [
		{"point": rect.position, "x": 1.0, "y": 1.0},
		{"point": Vector2(rect.end.x, rect.position.y), "x": -1.0, "y": 1.0},
		{"point": Vector2(rect.position.x, rect.end.y), "x": 1.0, "y": -1.0},
		{"point": rect.end, "x": -1.0, "y": -1.0}
	]:
		var point := corner.get("point", Vector2.ZERO) as Vector2
		draw_line(point, point + Vector2(float(corner.get("x", 1.0)) * length, 0), color, width)
		draw_line(point, point + Vector2(0, float(corner.get("y", 1.0)) * length), color, width)


func _draw_empty() -> void:
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), Color("#111821"), true)


func _fault_motif() -> String:
	var encounter_id := str(snapshot.get("id", snapshot.get("encounterId", "")))
	if encounter_id.contains("mq2") or encounter_id.contains("training"):
		return "thermal_ring"
	if encounter_id.contains("bh1750"):
		return "stale_bars"
	if encounter_id.contains("adc"):
		return "adc_spike"
	if encounter_id.contains("lcd"):
		return "scan_block"
	if encounter_id.contains("alarm"):
		return "threshold_wave"
	if encounter_id.contains("i2c"):
		return "bus_mesh"
	if encounter_id.contains("sensor_checkpoint"):
		return "sensor_matrix"
	if encounter_id.contains("trust_checkpoint"):
		return "trust_lattice"
	if encounter_id.contains("warehouse") or str(snapshot.get("tier", "")) == "boss":
		return "acceptance_core"
	return "generic_fault"


func _fault_accent() -> Color:
	match str(snapshot.get("tier", "ordinary")):
		"boss":
			return Color("#aa85ff")
		"elite":
			return Color("#ffb43e")
		"checkpoint":
			return Color("#20d7ee")
	return Color("#ff5f57")


func _stage_color(stage: String) -> Color:
	return {
		"collect": Color("#ff7064"),
		"interface": Color("#20d7ee"),
		"process": Color("#aa85ff"),
		"output": Color("#ffb43e")
	}.get(stage, Color("#728487"))


func _dictionary_total(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _draw_label(position: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ui_font if ui_font != null else ThemeDB.fallback_font
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered_label(position: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ui_font if ui_font != null else ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, position - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _surface_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _outline_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	return style
