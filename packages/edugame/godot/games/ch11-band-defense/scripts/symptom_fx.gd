extends RefCounted

const HIT_PULSE_DURATION := 0.32


static func visual_pos(enemy: Dictionary, base_pos: Vector2, time: float) -> Vector2:
	var phase := float(enemy.get("symptomPhase", 0.0))
	var threat := str(enemy.get("threatTag", ""))
	if threat == "noise":
		return base_pos + Vector2(sin(time * 17.0 + phase) * 4.0, cos(time * 23.0 + phase) * 3.0)
	if threat == "false_peak":
		return base_pos + Vector2(0.0, sin(time * 9.0 + phase) * 2.0)
	if threat == "power":
		return base_pos + Vector2(sin(time * 6.0 + phase) * 1.5, 0.0)
	return base_pos


static func draw_symptom(canvas: CanvasItem, enemy: Dictionary, pos: Vector2, time: float) -> void:
	var threat := str(enemy.get("threatTag", ""))
	var phase := float(enemy.get("symptomPhase", 0.0))
	if threat == "noise":
		_draw_jitter(canvas, pos, time, phase)
	elif threat == "false_peak":
		_draw_ghost_peak(canvas, pos, time, phase)
	elif threat == "config":
		_draw_calibration_frame(canvas, pos, time, phase)
	elif threat == "power":
		_draw_flash_pulse(canvas, pos, time, phase)


static func draw_hit_pulse(canvas: CanvasItem, enemy: Dictionary, pos: Vector2) -> void:
	var hit_pulse := float(enemy.get("hitPulse", 0.0))
	if hit_pulse <= 0.0:
		return
	var matched := bool(enemy.get("lastMatched", false))
	var pulse_color := Color(0.25, 0.95, 0.55, hit_pulse * 2.4) if matched else Color(0.95, 0.25, 0.25, hit_pulse * 2.4)
	var radius := 23.0 + (HIT_PULSE_DURATION - hit_pulse) * 30.0
	canvas.draw_arc(pos, radius, 0, TAU, 48, pulse_color, 3.0)


static func _draw_jitter(canvas: CanvasItem, pos: Vector2, time: float, phase: float) -> void:
	var jitter_color := Color(0.95, 0.28, 0.28, 0.55)
	for i in range(3):
		var offset := Vector2(-15 + i * 15, -23 + sin(time * 15.0 + phase + i) * 3.0)
		canvas.draw_line(pos + offset, pos + offset + Vector2(8, -5), jitter_color, 2.0)
		canvas.draw_line(pos + offset + Vector2(8, -5), pos + offset + Vector2(16, 2), jitter_color, 2.0)


static func _draw_ghost_peak(canvas: CanvasItem, pos: Vector2, time: float, phase: float) -> void:
	var ghost_alpha := 0.24 + 0.10 * sin(time * 8.0 + phase)
	canvas.draw_circle(pos + Vector2(-8, 0), 15, Color(1.0, 0.72, 0.24, ghost_alpha))
	canvas.draw_circle(pos + Vector2(8, 0), 15, Color(1.0, 0.72, 0.24, ghost_alpha))
	canvas.draw_line(pos + Vector2(0, -24), pos + Vector2(0, -11), Color(1.0, 0.82, 0.36, 0.65), 3.0)


static func _draw_calibration_frame(canvas: CanvasItem, pos: Vector2, time: float, phase: float) -> void:
	var frame_color := Color(0.25, 0.45, 1.0, 0.62)
	var wobble := sin(time * 4.0 + phase) * 2.0
	var rect := Rect2(pos + Vector2(-22, -22 + wobble), Vector2(44, 44))
	canvas.draw_rect(rect, frame_color, false, 2.0)
	canvas.draw_line(pos + Vector2(-27, 0), pos + Vector2(-18, 0), frame_color, 2.0)
	canvas.draw_line(pos + Vector2(18, 0), pos + Vector2(27, 0), frame_color, 2.0)


static func _draw_flash_pulse(canvas: CanvasItem, pos: Vector2, time: float, phase: float) -> void:
	var alpha := 0.28 + 0.32 * absf(sin(time * 10.0 + phase))
	var flash_color := Color(0.68, 0.42, 0.95, alpha)
	canvas.draw_arc(pos, 24.0, -0.8, 4.6, 32, flash_color, 3.0)
	canvas.draw_line(pos + Vector2(-4, -25), pos + Vector2(6, -12), flash_color, 3.0)
	canvas.draw_line(pos + Vector2(6, -12), pos + Vector2(-2, -13), flash_color, 3.0)
	canvas.draw_line(pos + Vector2(-2, -13), pos + Vector2(8, 0), flash_color, 3.0)
