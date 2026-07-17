extends RefCounted


static func build_smooth_route(raw_points: Array, corner_radius: float, corner_samples: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	if raw_points.is_empty():
		return result
	if raw_points.size() < 3 or corner_radius <= 0.0 or corner_samples < 1:
		for raw_point in raw_points:
			_append_unique(result, raw_point as Vector2)
		return result

	_append_unique(result, raw_points[0] as Vector2)
	for i in range(1, raw_points.size() - 1):
		var previous := raw_points[i - 1] as Vector2
		var corner := raw_points[i] as Vector2
		var following := raw_points[i + 1] as Vector2
		var incoming := corner - previous
		var outgoing := following - corner
		if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
			_append_unique(result, corner)
			continue
		var incoming_direction := incoming.normalized()
		var outgoing_direction := outgoing.normalized()
		if incoming_direction.dot(outgoing_direction) >= 0.998:
			_append_unique(result, corner)
			continue
		var cut_distance := minf(corner_radius, minf(incoming.length() * 0.36, outgoing.length() * 0.36))
		var curve_start := corner - incoming_direction * cut_distance
		var curve_end := corner + outgoing_direction * cut_distance
		_append_unique(result, curve_start)
		for sample in range(1, corner_samples + 1):
			var t := float(sample) / float(corner_samples)
			var inverse := 1.0 - t
			var point := curve_start * inverse * inverse + corner * 2.0 * inverse * t + curve_end * t * t
			_append_unique(result, point)
	_append_unique(result, raw_points[raw_points.size() - 1] as Vector2)
	return result


static func offset_route(route: PackedVector2Array, offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if route.is_empty():
		return result
	if is_zero_approx(offset) or route.size() == 1:
		return route.duplicate()
	for i in range(route.size()):
		var tangent := Vector2.RIGHT
		if i == 0:
			tangent = route[1] - route[0]
		elif i == route.size() - 1:
			tangent = route[i] - route[i - 1]
		else:
			tangent = route[i + 1] - route[i - 1]
		if tangent.length_squared() <= 0.001:
			result.append(route[i])
			continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		result.append(route[i] + normal * offset)
	return result


static func _append_unique(points: PackedVector2Array, point: Vector2) -> void:
	if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.01:
		points.append(point)
