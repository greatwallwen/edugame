extends RefCounted

const IMPACT_DURATION := 0.26
const DEATH_DURATION := 0.26
const MAX_IMPACTS := 24
const MAX_DEATHS := 12


static func reaction_profile(matched: bool) -> Dictionary:
	return {
		"recoilPx": 4.0 if matched else 1.35,
		"tiltRad": deg_to_rad(3.0 if matched else 0.8),
		"compression": 0.94 if matched else 0.985,
		"particleCount": 0,
	}


static func impact_visual_profile(matched: bool) -> Dictionary:
	if matched:
		return {
			"minBloomSize": 34.0,
			"maxBloomSize": 52.0,
			"maxAlpha": 0.62,
			"contactOffset": 12.0,
			"aspect": 0.62,
		}
	return {
		"minBloomSize": 24.0,
		"maxBloomSize": 34.0,
		"maxAlpha": 0.28,
		"contactOffset": 12.0,
		"aspect": 0.62,
	}


static func shadow_profile(reaction_scale: float) -> Dictionary:
	var lift := clampf((1.0 - reaction_scale) / 0.06, 0.0, 1.0)
	if lift <= 0.01:
		return {
			"alpha": 0.0,
			"offsetY": 0.0,
			"radius": 0.0,
			"scaleY": 0.0,
		}
	return {
		"alpha": 0.08 + lift * 0.02,
		"offsetY": 16.0 + lift * 2.0,
		"radius": 15.0 + lift * 2.0,
		"scaleY": 0.40 - lift * 0.05,
	}


static func health_state(hp: float, max_hp: float) -> String:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if ratio < 0.25:
		return "critical"
	if ratio <= 0.60:
		return "damaged"
	return "stable"


static func signature_profile(tower_id: String) -> Dictionary:
	match tower_id:
		"i2c":
			return {"kind": "scan_bracket", "color": Color(0.20, 0.88, 1.0), "bloomScale": 0.92}
		"filter":
			return {"kind": "noise_damping", "color": Color(0.20, 0.94, 0.72), "bloomScale": 1.02}
		"peak":
			return {"kind": "threshold_flash", "color": Color(1.0, 0.68, 0.18), "bloomScale": 0.88}
		"power":
			return {"kind": "power_clamp", "color": Color(0.68, 0.48, 1.0), "bloomScale": 0.98}
		_:
			return {"kind": "scan_bracket", "color": Color(0.36, 0.90, 0.94), "bloomScale": 0.92}


static func impact_color(tower_id: String, matched: bool) -> Color:
	if !matched:
		return Color(1.0, 0.25, 0.08)
	return signature_profile(tower_id).get("color", Color(0.36, 0.90, 0.94)) as Color


static func make_impact_event(
	position: Vector2,
	direction: Vector2,
	tower_id: String,
	matched: bool,
	damage: float,
	lethal: bool,
	seed: int
) -> Dictionary:
	var normalized_direction := direction.normalized()
	if normalized_direction.is_zero_approx():
		normalized_direction = Vector2.RIGHT
	return {
		"position": position,
		"direction": normalized_direction,
		"towerId": tower_id,
		"matched": matched,
		"damage": damage,
		"lethal": lethal,
		"seed": seed,
		"ttl": IMPACT_DURATION,
		"duration": IMPACT_DURATION,
		"particles": [],
	}


static func reaction_transform(enemy: Dictionary) -> Dictionary:
	var duration := maxf(float(enemy.get("hitReactionDuration", IMPACT_DURATION)), 0.001)
	var ttl := clampf(float(enemy.get("hitReactionTtl", 0.0)), 0.0, duration)
	if ttl <= 0.0:
		return {"offset": Vector2.ZERO, "angle": 0.0, "scale": 1.0}
	var progress := clampf(1.0 - ttl / duration, 0.0, 1.0)
	var profile := reaction_profile(bool(enemy.get("lastMatched", false)))
	var direction := enemy.get("hitDirection", Vector2.RIGHT) as Vector2
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var kick := sin(progress * PI) * pow(1.0 - progress, 0.35)
	var settle := sin(progress * PI * 2.0) * (1.0 - progress)
	var recoil := -direction * float(profile.get("recoilPx", 0.0)) * kick
	var tilt_sign := 1.0 if direction.x + direction.y >= 0.0 else -1.0
	var angle := float(profile.get("tiltRad", 0.0)) * settle * tilt_sign
	var compression := float(profile.get("compression", 1.0))
	var scale := lerpf(1.0, compression, kick)
	return {"offset": recoil, "angle": angle, "scale": scale}


static func enforce_caps(events: Array, death_echoes: Array) -> void:
	while events.size() > MAX_IMPACTS:
		events.remove_at(_weakest_event_index(events))
	while death_echoes.size() > MAX_DEATHS:
		death_echoes.pop_front()


static func draw_impact(canvas: CanvasItem, event: Dictionary, textures: Dictionary, frame_count: int = 8) -> void:
	draw_impact_backplate(canvas, event, textures, frame_count)
	draw_impact_foreground(canvas, event)


static func draw_impact_backplate(canvas: CanvasItem, event: Dictionary, textures: Dictionary, frame_count: int = 8) -> void:
	var context := _impact_context(event)
	var matched := bool(context.get("matched", false))
	var tower_id := str(context.get("towerId", ""))
	var direction := context.get("direction", Vector2.RIGHT) as Vector2
	var profile := impact_visual_profile(matched)
	var contact := context.get("position", Vector2.ZERO) as Vector2
	contact -= direction * float(profile.get("contactOffset", 12.0))
	var alpha := float(context.get("envelope", 0.0)) * float(profile.get("maxAlpha", 0.0))
	_draw_bitmap_bloom(
		canvas,
		textures,
		contact,
		direction,
		tower_id,
		matched,
		float(context.get("progress", 0.0)),
		alpha,
		frame_count,
		profile
	)


static func draw_impact_foreground(canvas: CanvasItem, event: Dictionary) -> void:
	var context := _impact_context(event)
	var matched := bool(context.get("matched", false))
	var tower_id := str(context.get("towerId", ""))
	var direction := context.get("direction", Vector2.RIGHT) as Vector2
	var profile := impact_visual_profile(matched)
	var contact := context.get("position", Vector2.ZERO) as Vector2
	contact -= direction * float(profile.get("contactOffset", 12.0))
	var progress := float(context.get("progress", 0.0))
	var alpha := float(context.get("envelope", 0.0)) * (0.90 if matched else 0.38)
	var color := impact_color(tower_id, matched)
	if matched:
		_draw_signature(canvas, tower_id, contact, direction, progress, alpha, color)
	else:
		_draw_mismatch_scatter(canvas, contact, direction, progress, alpha, color)


static func _impact_context(event: Dictionary) -> Dictionary:
	var duration := maxf(float(event.get("duration", IMPACT_DURATION)), 0.001)
	var ttl := clampf(float(event.get("ttl", 0.0)), 0.0, duration)
	var progress := clampf((duration - ttl) / duration, 0.0, 1.0)
	var direction := event.get("direction", Vector2.RIGHT) as Vector2
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var peak_in := clampf(progress / 0.17, 0.0, 1.0)
	var tail_out := 1.0 - smoothstep(0.62, 1.0, progress)
	return {
		"progress": progress,
		"envelope": peak_in * tail_out,
		"matched": bool(event.get("matched", false)),
		"towerId": str(event.get("towerId", "")),
		"position": event.get("position", Vector2.ZERO) as Vector2,
		"direction": direction,
	}


static func _draw_bitmap_bloom(
	canvas: CanvasItem,
	textures: Dictionary,
	position: Vector2,
	direction: Vector2,
	tower_id: String,
	matched: bool,
	progress: float,
	alpha: float,
	frame_count: int,
	profile: Dictionary
) -> void:
	var texture = textures.get("range", null)
	if texture == null:
		return
	var sheet := texture as Texture2D
	var safe_frame_count := maxi(frame_count, 1)
	var frame_index := clampi(floori(progress * float(safe_frame_count)), 0, safe_frame_count - 1)
	var frame_size := Vector2(float(sheet.get_width()) / float(safe_frame_count), float(sheet.get_height()))
	var source_rect := Rect2(Vector2(float(frame_index) * frame_size.x, 0.0), frame_size)
	var signature := signature_profile(tower_id)
	var base_size := lerpf(float(profile.get("minBloomSize", 28.0)), float(profile.get("maxBloomSize", 48.0)), sin(progress * PI))
	base_size *= float(signature.get("bloomScale", 1.0))
	var target_size := Vector2(base_size, base_size * float(profile.get("aspect", 0.62)))
	var tower_color := impact_color(tower_id, true)
	var modulate := Color(
		lerpf(1.0, tower_color.r, 0.42),
		lerpf(1.0, tower_color.g, 0.42),
		lerpf(1.0, tower_color.b, 0.42),
		alpha
	)
	if !matched:
		modulate = Color(1.0, 0.48, 0.30, alpha)
	canvas.draw_set_transform(position, direction.angle(), Vector2.ONE)
	canvas.draw_texture_rect_region(sheet, Rect2(-target_size * 0.5, target_size), source_rect, modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_signature(canvas: CanvasItem, tower_id: String, center: Vector2, direction: Vector2, progress: float, alpha: float, color: Color) -> void:
	match str(signature_profile(tower_id).get("kind", "")):
		"scan_bracket":
			_draw_scan_brackets(canvas, center, direction, progress, alpha, color)
		"noise_damping":
			_draw_noise_damping(canvas, center, progress, alpha, color)
		"threshold_flash":
			_draw_threshold_flash(canvas, center, progress, alpha, color)
		"power_clamp":
			_draw_power_clamp(canvas, center, direction, progress, alpha, color)


static func _draw_scan_brackets(canvas: CanvasItem, center: Vector2, direction: Vector2, progress: float, alpha: float, color: Color) -> void:
	var tangent := direction.orthogonal()
	var half_gap := lerpf(24.0, 11.0, minf(progress / 0.72, 1.0))
	var arm := 8.0
	for side in [-1.0, 1.0]:
		var anchor: Vector2 = center + tangent * half_gap * float(side)
		var edge: Vector2 = anchor - tangent * arm * float(side)
		canvas.draw_line(anchor - direction * arm, anchor + direction * arm, Color(color.r, color.g, color.b, alpha * 0.88), 1.8, true)
		canvas.draw_line(anchor - direction * arm, edge - direction * arm, Color(color.r, color.g, color.b, alpha * 0.88), 1.8, true)
		canvas.draw_line(anchor + direction * arm, edge + direction * arm, Color(color.r, color.g, color.b, alpha * 0.88), 1.8, true)


static func _draw_noise_damping(canvas: CanvasItem, center: Vector2, progress: float, alpha: float, color: Color) -> void:
	var radius := lerpf(23.0, 9.0, minf(progress / 0.76, 1.0))
	canvas.draw_arc(center, radius, 0.22, PI * 1.18, 22, Color(color.r, color.g, color.b, alpha * 0.76), 1.8, true)
	canvas.draw_arc(center, radius - 4.0, PI + 0.22, TAU + PI * 0.18, 18, Color(color.r, color.g, color.b, alpha * 0.44), 1.4, true)


static func _draw_threshold_flash(canvas: CanvasItem, center: Vector2, progress: float, alpha: float, color: Color) -> void:
	var flare_alpha := alpha * (1.0 - smoothstep(0.34, 0.84, progress))
	canvas.draw_circle(center, lerpf(5.8, 2.4, progress), Color(1.0, 0.96, 0.78, flare_alpha))
	canvas.draw_arc(center, lerpf(8.0, 18.0, progress), 0.0, TAU, 28, Color(color.r, color.g, color.b, flare_alpha * 0.74), 2.0, true)


static func _draw_power_clamp(canvas: CanvasItem, center: Vector2, direction: Vector2, progress: float, alpha: float, color: Color) -> void:
	var angle := direction.angle()
	var radius := lerpf(22.0, 10.0, minf(progress / 0.72, 1.0))
	canvas.draw_arc(center, radius, angle + 0.34, angle + 1.46, 14, Color(color.r, color.g, color.b, alpha * 0.84), 2.0, true)
	canvas.draw_arc(center, radius, angle + PI + 0.34, angle + PI + 1.46, 14, Color(color.r, color.g, color.b, alpha * 0.84), 2.0, true)
	if progress > 0.34 and progress < 0.62:
		canvas.draw_circle(center, 4.0, Color(0.02, 0.08, 0.07, alpha * 0.94))


static func _draw_mismatch_scatter(canvas: CanvasItem, center: Vector2, direction: Vector2, progress: float, alpha: float, color: Color) -> void:
	var tangent := direction.orthogonal()
	for side in [-1.0, 1.0]:
		var start: Vector2 = center + tangent * float(side) * 3.0
		var end: Vector2 = start - direction * lerpf(8.0, 15.0, progress) + tangent * float(side) * 5.0
		canvas.draw_line(start, end, Color(color.r, color.g, color.b, alpha * 0.56), 1.2, true)


static func _weakest_event_index(events: Array) -> int:
	for index in range(events.size()):
		if !bool((events[index] as Dictionary).get("matched", false)):
			return index
	return 0
