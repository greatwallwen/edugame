extends SceneTree

var failures := 0


func _init() -> void:
	_test_rounded_route_preserves_ports_and_adds_curve_samples()
	_test_all_level_routes_leave_and_enter_ports_horizontally()
	_test_multicore_offsets_stay_parallel_to_the_center_route()
	_test_level_styles_define_selected_multicore_connector_contract()
	if failures > 0:
		quit(1)
	else:
		print("route geometry tests passed")
		quit(0)


func _geometry():
	var script = load("res://scripts/route_geometry.gd")
	_assert(script != null, "route_geometry.gd should load")
	return script


func _layouts():
	var script = load("res://scripts/level_layouts.gd")
	_assert(script != null, "level_layouts.gd should load")
	return script


func _test_rounded_route_preserves_ports_and_adds_curve_samples() -> void:
	var geometry = _geometry()
	if geometry == null:
		return
	var controls := [
		Vector2(88, 332),
		Vector2(190, 332),
		Vector2(262, 278),
		Vector2(262, 420),
	]
	var route: PackedVector2Array = geometry.build_smooth_route(controls, 24.0, 6)
	_assert(route.size() > controls.size(), "rounded route should add curve samples")
	_assert(route[0].is_equal_approx(controls[0]), "rounded route should preserve the visible entrance endpoint")
	_assert(route[route.size() - 1].is_equal_approx(controls[controls.size() - 1]), "rounded route should preserve the visible exit endpoint")
	for i in range(route.size() - 1):
		_assert(route[i].distance_to(route[i + 1]) > 0.01, "rounded route should not contain duplicate samples")


func _test_all_level_routes_leave_and_enter_ports_horizontally() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	for level_number in range(1, 4):
		var layout: Dictionary = layouts.layout_for_level(level_number)
		var controls := layout.get("path", []) as Array
		_assert(controls.size() >= 4, "level %d should expose enough route controls" % level_number)
		if controls.size() < 4:
			continue
		var start: Vector2 = controls[0]
		var after_start: Vector2 = controls[1]
		var approach_end: Vector2 = controls[controls.size() - 3]
		var before_end: Vector2 = controls[controls.size() - 2]
		var finish: Vector2 = controls[controls.size() - 1]
		_assert(absf(start.y - after_start.y) <= 0.01 and after_start.x > start.x, "level %d route should leave the left interface horizontally" % level_number)
		_assert(absf(before_end.y - finish.y) <= 0.01 and finish.x > before_end.x, "level %d route should enter the right interface horizontally" % level_number)
		_assert(before_end.x >= approach_end.x, "level %d route should not reverse immediately before the right interface" % level_number)


func _test_multicore_offsets_stay_parallel_to_the_center_route() -> void:
	var geometry = _geometry()
	if geometry == null:
		return
	var center := PackedVector2Array([Vector2(88, 350), Vector2(140, 350), Vector2(180, 390)])
	var upper: PackedVector2Array = geometry.offset_route(center, -4.5)
	var lower: PackedVector2Array = geometry.offset_route(center, 4.5)
	_assert(upper.size() == center.size(), "upper core should retain every route sample")
	_assert(lower.size() == center.size(), "lower core should retain every route sample")
	_assert(absf(upper[0].distance_to(lower[0]) - 9.0) <= 0.05, "outer cores should keep the configured 9 px separation")
	_assert(absf(upper[1].distance_to(center[1]) - 4.5) <= 0.05, "upper core should remain 4.5 px from center")
	_assert(absf(lower[1].distance_to(center[1]) - 4.5) <= 0.05, "lower core should remain 4.5 px from center")


func _test_level_styles_define_selected_multicore_connector_contract() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	for level_number in range(1, 4):
		var layout: Dictionary = layouts.layout_for_level(level_number)
		var style := layout.get("pathLayer", {}) as Dictionary
		var controls := layout.get("path", []) as Array
		var start_port := style.get("startPort", Vector2.ZERO) as Vector2
		var end_port := style.get("endPort", Vector2.ZERO) as Vector2
		_assert(int(style.get("coreCount", 0)) == 3, "level %d should render three luminous route cores" % level_number)
		_assert(float(style.get("coreSpacing", 0.0)) >= 4.0, "level %d should keep the three cores visually separate" % level_number)
		_assert(float(style.get("connectorGlowWidth", 99.0)) <= float(style.get("coreWidth", 0.0)) + 3.0, "level %d connector glow should stay narrow enough to preserve three distinct cores" % level_number)
		_assert(float(style.get("cornerRadius", 0.0)) >= 20.0, "level %d should round route corners" % level_number)
		_assert(int(style.get("cornerSamples", 0)) >= 5, "level %d should sample rounded corners smoothly" % level_number)
		_assert(start_port.distance_to(controls[0] as Vector2) <= 0.01, "level %d enemy route should begin at the left metal interface center" % level_number)
		_assert(end_port.distance_to(controls[controls.size() - 1] as Vector2) <= 0.01, "level %d enemy route should end at the right metal interface center" % level_number)
		_assert(absf(start_port.y - (controls[0] as Vector2).y) <= 0.01, "level %d left clamp should be centered on the hardware slot" % level_number)
		_assert(absf(end_port.y - (controls[controls.size() - 1] as Vector2).y) <= 0.01, "level %d right clamp should be centered on the hardware slot" % level_number)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
