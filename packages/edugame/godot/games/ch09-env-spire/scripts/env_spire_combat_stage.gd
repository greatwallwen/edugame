extends Control

var motion_time := 0.0

const STAGE_COLORS := {
	"device": Color("#20d7ee"),
	"evidence": Color("#5bf0b4"),
	"fault": Color("#ff5f57")
}


func _ready() -> void:
	name = "CombatStageVisual"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func visual_signature() -> String:
	return "signal_stage:triad_confrontation"


func stage_palette() -> Dictionary:
	return STAGE_COLORS.duplicate()


func _process(delta: float) -> void:
	motion_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 100.0 or size.y < 100.0:
		return
	var stage_bottom := minf(size.y * 0.58, 390.0)
	var center := Vector2(size.x * 0.56, stage_bottom * 0.46)
	var device := STAGE_COLORS.device as Color
	var evidence := STAGE_COLORS.evidence as Color
	var fault := STAGE_COLORS.fault as Color
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 0), Vector2(size.x * 0.34, 0), center, Vector2(0, stage_bottom)
	]), Color(device.r, device.g, device.b, 0.055))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.25, 0), Vector2(size.x * 0.61, 0), center + Vector2(54, 0), center
	]), Color(evidence.r, evidence.g, evidence.b, 0.045))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.52, 0), Vector2(size.x, 0), Vector2(size.x, stage_bottom), center + Vector2(54, 0)
	]), Color(fault.r, fault.g, fault.b, 0.060))
	var signal_y := stage_bottom * 0.52
	draw_line(Vector2(30, signal_y), Vector2(size.x - 30, signal_y), Color("#34485c80"), 1.0)
	_draw_signal_segment(Vector2(36, signal_y), Vector2(size.x * 0.31, signal_y), device)
	_draw_signal_segment(Vector2(size.x * 0.34, signal_y), Vector2(size.x * 0.57, signal_y), evidence)
	_draw_signal_segment(Vector2(size.x * 0.60, signal_y), Vector2(size.x - 36, signal_y), fault)
	for index in range(9):
		var x := 28.0 + float(index) * (size.x - 56.0) / 8.0
		draw_line(Vector2(x, stage_bottom - 16), Vector2(x, stage_bottom - (28.0 if index % 2 == 0 else 22.0)), Color("#65819b24"), 1.0)


func _draw_signal_segment(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, Color(color.r, color.g, color.b, 0.18), 3.0)
	var travel := fmod(motion_time * 0.22, 1.0)
	var head := from.lerp(to, travel)
	var tail := from.lerp(to, maxf(0.0, travel - 0.16))
	draw_line(tail, head, Color(color.r, color.g, color.b, 0.74), 3.0)
