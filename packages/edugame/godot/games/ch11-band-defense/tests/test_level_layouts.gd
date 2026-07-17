extends SceneTree

var failures := 0

const TOWER_BASE_VISUAL_RADIUS := 44.0
const LEVEL_THREE_RIGHT_SLOT_MIN_PATH_DISTANCE := 60.0


func _init() -> void:
	_test_level_one_layout_preserves_current_mvp_shape()
	_test_level_two_layout_has_complex_route_and_more_slots()
	_test_level_three_layout_is_comprehensive_and_roadside()
	_test_level_intro_text_matches_progression()
	if failures > 0:
		quit(1)
	else:
		print("level layouts tests passed")
		quit(0)


func _layouts():
	var script = load("res://scripts/level_layouts.gd")
	_assert(script != null, "level_layouts.gd should load")
	return script


func _test_level_one_layout_preserves_current_mvp_shape() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	var layout: Dictionary = layouts.layout_for_level(1)
	_assert(str(layout.get("background", "")) == "res://assets/backgrounds/band-defense-map-level1-watch-debug-map-layer.png", "level 1 should use the left map hardware background as a separate layer")
	_assert(str(layout.get("hudBackground", "")) == "res://assets/backgrounds/band-defense-hud-level1-watch-debug-layer.png", "level 1 should use the right smartwatch HUD background as a separate layer")
	_assert(FileAccess.file_exists(str(layout.get("background", ""))), "level 1 left map background layer should exist on disk")
	_assert(FileAccess.file_exists(str(layout.get("hudBackground", ""))), "level 1 right HUD background layer should exist on disk")
	var path_layer := layout.get("pathLayer", {}) as Dictionary
	_assert(path_layer.get("visible", false) == true, "level 1 should declare a separately configurable path layer")
	_assert(float(path_layer.get("width", 0.0)) >= 8.0, "level 1 path layer should expose a readable route width")
	_assert((path_layer.get("startPort", Vector2.ZERO) as Vector2).distance_to(Vector2(68, 321)) <= 1.0, "level 1 route should begin at the outer end of the circled metal contacts")
	_assert((path_layer.get("endPort", Vector2.ZERO) as Vector2).distance_to(Vector2(878, 350)) <= 1.0, "level 1 route should end at the outer end of the matching right metal contacts")
	var path: Array = layout.get("path", []) as Array
	_assert(path.size() >= 11, "level 1 route should include the connected hardware port endpoints and a horizontal entrance lead")
	_assert((path[0] as Vector2).distance_to(Vector2(68, 321)) <= 1.0, "level 1 enemy route should start beyond the circled module rather than cover it")
	_assert(_min_distance_to_path(Vector2(185, 260), path) <= 6.0, "level 1 should follow the left cyan data-link bend on the clean watch-board art")
	_assert(_min_distance_to_path(Vector2(639, 385), path) <= 6.0, "level 1 should follow the central vertical cyan data-link bend on the clean watch-board art")
	_assert((path[path.size() - 1] as Vector2).distance_to(Vector2(878, 350)) <= 1.0, "level 1 enemy route should stop before covering the matching right module")
	var slots: Array = layout.get("towerSlots", []) as Array
	_assert(slots.size() == 4, "level 1 should use the four visible circular tower slots from the clean reference art")
	var expected_visual_centers := [Vector2(214, 207), Vector2(470, 207), Vector2(550, 405), Vector2(762, 257)]
	for i in range(mini(slots.size(), expected_visual_centers.size())):
		var pos: Vector2 = (slots[i] as Dictionary).get("pos", Vector2.ZERO)
		_assert(pos.distance_to(expected_visual_centers[i]) <= 3.0, "level 1 tower slot %d should align with its visual base" % [i + 1])
		_assert(_min_distance_to_path(pos, path) >= 50.0, "level 1 tower slot %d should stay clear of the route glow" % [i + 1])


func _test_level_two_layout_has_complex_route_and_more_slots() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	var level_one: Dictionary = layouts.layout_for_level(1)
	var level_two: Dictionary = layouts.layout_for_level(2)
	var level_two_path: Array = level_two.get("path", []) as Array
	var level_two_slots: Array = level_two.get("towerSlots", []) as Array
	_assert(str(level_two.get("background", "")) == "res://assets/backgrounds/band-defense-map-level2-watch-debug-map-layer.png", "level 2 should use the watch-debug hardware map layer")
	_assert(str(level_two.get("hudBackground", "")) == "res://assets/backgrounds/band-defense-hud-level1-watch-debug-layer.png", "level 2 should share the separated right smartwatch HUD layer")
	_assert(FileAccess.file_exists(str(level_two.get("background", ""))), "level 2 map background layer should exist on disk")
	_assert(FileAccess.file_exists(str(level_two.get("hudBackground", ""))), "level 2 HUD background layer should exist on disk")
	_assert(level_two_path.size() >= 8, "level 2 should keep a multi-stage route")
	var level_two_path_layer := level_two.get("pathLayer", {}) as Dictionary
	_assert((level_two_path_layer.get("startPort", Vector2.ZERO) as Vector2).distance_to(Vector2(68, 334)) <= 1.0, "level 2 should use its left metal-contact terminal")
	_assert((level_two_path_layer.get("endPort", Vector2.ZERO) as Vector2).distance_to(Vector2(880, 347)) <= 1.0, "level 2 should use its right metal-contact terminal")
	_assert((level_two_path[0] as Vector2).distance_to(Vector2(68, 334)) <= 1.0, "level 2 route should start beyond the left module")
	_assert((level_two_path[level_two_path.size() - 1] as Vector2).distance_to(Vector2(880, 347)) <= 1.0, "level 2 route should stop before covering the right module")
	_assert(level_two_slots.size() > (level_one.get("towerSlots", []) as Array).size(), "level 2 should add tower slot choices")
	var expected_visual_centers := [Vector2(214, 207), Vector2(476, 142), Vector2(332, 354), Vector2(550, 405), Vector2(762, 257), Vector2(806, 487)]
	for i in range(mini(level_two_slots.size(), expected_visual_centers.size())):
		var slot := level_two_slots[i] as Dictionary
		var pos: Vector2 = (slot as Dictionary).get("pos", Vector2.ZERO)
		var distance := _min_distance_to_path(pos, level_two_path)
		_assert(pos.distance_to(expected_visual_centers[i]) <= 3.0, "level 2 tower slot %d should align with its visual base" % [i + 1])
		_assert(distance >= 50.0, "level 2 tower slot %s should stay clear of the route glow" % pos)
		_assert(distance <= 150.0, "level 2 tower slot %s should sit within readable roadside range, but is %.1f px away" % [pos, distance])


func _test_level_three_layout_is_comprehensive_and_roadside() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	var level_three: Dictionary = layouts.layout_for_level(3)
	var path: Array = level_three.get("path", []) as Array
	var slots: Array = level_three.get("towerSlots", []) as Array
	_assert(str(level_three.get("background", "")) == "res://assets/backgrounds/band-defense-map-level3-watch-debug-map-layer.png", "level 3 should use its own watch-debug hardware map layer")
	_assert(str(level_three.get("hudBackground", "")) == "res://assets/backgrounds/band-defense-hud-level1-watch-debug-layer.png", "level 3 should share the separated right smartwatch HUD layer")
	_assert(FileAccess.file_exists(str(level_three.get("background", ""))), "level 3 map background layer should exist on disk")
	_assert(FileAccess.file_exists(str(level_three.get("hudBackground", ""))), "level 3 HUD background layer should exist on disk")
	_assert(path.size() >= 8, "level 3 should have a multi-stage route")
	var path_layer := level_three.get("pathLayer", {}) as Dictionary
	_assert((path_layer.get("startPort", Vector2.ZERO) as Vector2).distance_to(Vector2(68, 350)) <= 1.0, "level 3 should use its left metal-contact terminal")
	_assert((path_layer.get("endPort", Vector2.ZERO) as Vector2).distance_to(Vector2(880, 350)) <= 1.0, "level 3 should use its right metal-contact terminal")
	_assert((path[0] as Vector2).distance_to(Vector2(68, 350)) <= 1.0, "level 3 route should start beyond the left module")
	_assert((path[path.size() - 1] as Vector2).distance_to(Vector2(880, 350)) <= 1.0, "level 3 route should stop before covering the right module")
	_assert(slots.size() >= 6, "level 3 should keep enough roadside build choices")
	for slot in slots:
		var pos: Vector2 = (slot as Dictionary).get("pos", Vector2.ZERO)
		var distance := _min_distance_to_path(pos, path)
		_assert(distance >= 50.0, "level 3 tower slot %s should stay clear of the route glow" % pos)
		_assert(distance <= 115.0, "level 3 tower slot %s should sit within readable roadside range, but is %.1f px away" % [pos, distance])
	var expected_visual_centers := [Vector2(212, 227), Vector2(362, 398), Vector2(476, 240), Vector2(562, 432), Vector2(644, 212), Vector2(772, 288), Vector2(826, 472)]
	for i in range(mini(slots.size(), expected_visual_centers.size())):
		var pos: Vector2 = (slots[i] as Dictionary).get("pos", Vector2.ZERO)
		_assert(pos.distance_to(expected_visual_centers[i]) <= 3.0, "level 3 tower slot %d should align with its visual base" % [i + 1])
	var rightmost_slot := _rightmost_slot(slots)
	var rightmost_pos: Vector2 = rightmost_slot.get("pos", Vector2.ZERO)
	var rightmost_distance := _min_distance_to_path(rightmost_pos, path)
	_assert(rightmost_distance >= LEVEL_THREE_RIGHT_SLOT_MIN_PATH_DISTANCE, "level 3 rightmost tower slot %s should clear the visible road, but is %.1f px away" % [rightmost_pos, rightmost_distance])


func _test_level_intro_text_matches_progression() -> void:
	var layouts = _layouts()
	if layouts == null:
		return
	var has_intro_text := false
	for method in layouts.get_script_method_list():
		if str((method as Dictionary).get("name", "")) == "intro_text_for_level":
			has_intro_text = true
			break
	_assert(has_intro_text, "level_layouts.gd should expose intro_text_for_level")
	if !has_intro_text:
		return
	_assert(str(layouts.intro_text_for_level(2)).contains("夜跑"), "level 2 intro should describe the night-run anomaly")
	_assert(str(layouts.intro_text_for_level(3)).contains("综合验收"), "level 3 intro should describe the comprehensive validation")


func _min_distance_to_path(point: Vector2, path: Array) -> float:
	var best := INF
	for i in range(path.size() - 1):
		best = minf(best, _distance_to_segment(point, path[i] as Vector2, path[i + 1] as Vector2))
	return best


func _path_length(path: Array) -> float:
	var total := 0.0
	for i in range(path.size() - 1):
		total += (path[i] as Vector2).distance_to(path[i + 1] as Vector2)
	return total


func _paths_are_close(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if (a[i] as Vector2).distance_to(b[i] as Vector2) > 3.0:
			return false
	return true


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / denom, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _rightmost_slot(slots: Array) -> Dictionary:
	var best := {}
	for raw_slot in slots:
		var slot := raw_slot as Dictionary
		if best.is_empty() or ((slot.get("pos", Vector2.ZERO) as Vector2).x > (best.get("pos", Vector2.ZERO) as Vector2).x):
			best = slot
	return best


func _circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(
		clampf(center.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(center.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return center.distance_to(nearest) < radius


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
