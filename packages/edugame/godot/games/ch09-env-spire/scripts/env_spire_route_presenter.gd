extends RefCounted

const VisualTheme = preload("res://scripts/env_spire_visual_theme.gd")

const NODE_SIZE := 56.0
const NODE_ROW_HEIGHT := 58.0
const CONNECTOR_HEIGHT := 14.0
const DETAIL_WIDTH := 176.0


static func node_state(layer_number: int, current_layer: int) -> String:
	if layer_number <= current_layer:
		return "completed"
	if layer_number == current_layer + 1:
		return "available"
	return "future"


static func progress_sequence(target_layer: int, run_node_count: int) -> Array[int]:
	var sequence: Array[int] = []
	for layer_number in range(1, clampi(target_layer, 0, run_node_count) + 1):
		sequence.append(layer_number)
	return sequence


static func marker_spec(
	layer_number: int,
	state: String,
	node_type: String,
	details_revealed: bool,
	node_label: String,
	type_label: String
) -> Dictionary:
	var background := Color("#dbe7eb")
	var accent := Color("#8ea5af")
	var text_color := VisualTheme.color("text_muted")
	var detail_color := VisualTheme.color("text_muted")
	if state == "completed":
		background = Color("#d5efed")
		accent = VisualTheme.category_color("interface")
		text_color = Color("#123b43")
		detail_color = VisualTheme.color("text_secondary")
	elif details_revealed and node_type == "boss":
		background = Color("#3c315a")
		accent = VisualTheme.category_color("process")
		text_color = Color.WHITE
		detail_color = VisualTheme.color("text_primary")
	elif state == "available":
		background = VisualTheme.color("button_surface")
		accent = VisualTheme.category_color("collect")
		text_color = VisualTheme.color("button_text")
		detail_color = VisualTheme.color("text_primary")
	var state_text: String = str({
		"completed": "已完成",
		"available": "当前目标",
		"future": "待侦察"
	}.get(state, "待侦察"))
	var detail_text := "内容未揭示"
	if details_revealed:
		detail_text = "%s\n%s" % [node_label, type_label]
	return {
		"nodeText": "%02d" % layer_number,
		"stateText": state_text,
		"detailText": detail_text,
		"background": background,
		"accent": accent,
		"textColor": text_color,
		"detailColor": detail_color,
		"enabled": state == "available"
	}


static func render_route(
	owner: Node,
	map_route: VBoxContainer,
	layers: Array,
	run_node_count: int,
	current_layer: int,
	revealed_nodes: Array[int],
	on_select: Callable
) -> void:
	for child in map_route.get_children():
		map_route.remove_child(child)
		child.queue_free()
	for layer_number in range(run_node_count, 0, -1):
		var layer_data := (layers[layer_number - 1] as Dictionary) if layer_number - 1 < layers.size() else {}
		var layer_choices: Array = layer_data.get("choices", [])
		var marker_node := layer_choices[0] as Dictionary if !layer_choices.is_empty() else {}
		var marker_type := str(marker_node.get("type", ""))
		var state := node_state(layer_number, current_layer)
		var details_revealed := state != "future" or revealed_nodes.has(layer_number)
		var type_label := str(owner.call("_node_type_name", marker_type))
		var spec := marker_spec(layer_number, state, marker_type, details_revealed, str(marker_node.get("label", "调试节点")), type_label)
		var step := _build_step(owner, layer_number, marker_type, state, spec, on_select)
		map_route.add_child(step)


static func set_input_enabled(map_route: VBoxContainer, enabled: bool) -> void:
	if map_route == null:
		return
	for step in map_route.get_children():
		var marker := (step as Control).find_child("MapNodeButton", true, false) as Button
		if marker != null:
			marker.disabled = !enabled or str((step as Control).get_meta("route_state", "future")) != "available"


static func play_progress_animation(
	owner: Node,
	map_route: VBoxContainer,
	target_layer: int,
	run_node_count: int,
	duration_scale: float = 1.0
) -> void:
	var sequence := progress_sequence(target_layer, run_node_count)
	if owner == null or map_route == null or sequence.is_empty():
		return
	if DisplayServer.get_name() == "headless" or duration_scale <= 0.0:
		await owner.get_tree().process_frame
		return
	for layer_number in sequence:
		var step := map_route.get_node_or_null("MapStep%02d" % layer_number) as Control
		if step == null:
			continue
		var marker := step.find_child("MapNodeButton", true, false) as Control
		if marker == null:
			continue
		if layer_number > 1:
			var connector := step.find_child("MapConnector", true, false) as ColorRect
			if connector != null:
				var connector_tween := owner.create_tween().bind_node(connector)
				connector_tween.tween_property(connector, "modulate", Color("#dfffff"), 0.045 * duration_scale)
				connector_tween.tween_property(connector, "modulate", Color.WHITE, 0.055 * duration_scale)
				await connector_tween.finished
		marker.pivot_offset = marker.size * 0.5
		var pulse := owner.create_tween().bind_node(marker)
		pulse.set_parallel(true)
		pulse.tween_property(marker, "scale", Vector2(1.16, 1.16), 0.075 * duration_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(marker, "modulate", Color("#e8ffff"), 0.075 * duration_scale)
		await pulse.finished
		var settle := owner.create_tween().bind_node(marker)
		settle.set_parallel(true)
		settle.tween_property(marker, "scale", Vector2.ONE, 0.09 * duration_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle.tween_property(marker, "modulate", Color.WHITE, 0.09 * duration_scale)
		await settle.finished


static func _build_step(
	owner: Node,
	layer_number: int,
	node_type: String,
	state: String,
	spec: Dictionary,
	on_select: Callable
) -> VBoxContainer:
	var step := VBoxContainer.new()
	step.name = "MapStep%02d" % layer_number
	step.add_theme_constant_override("separation", 0)
	step.set_meta("route_state", state)
	step.set_meta("layer_number", layer_number)
	var station_row := HBoxContainer.new()
	station_row.name = "MapStationRow"
	station_row.custom_minimum_size = Vector2(0, NODE_ROW_HEIGHT)
	station_row.alignment = BoxContainer.ALIGNMENT_CENTER
	station_row.add_theme_constant_override("separation", 12)
	step.add_child(station_row)
	var detail := _build_detail(owner, spec, layer_number % 2 == 0)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	if layer_number % 2 == 0:
		station_row.add_child(detail)
	else:
		station_row.add_child(spacer)
	var marker := Button.new()
	marker.name = "MapNodeButton"
	marker.text = str(spec.get("nodeText", ""))
	marker.tooltip_text = "%s：%s" % [str(spec.get("stateText", "")), str(spec.get("detailText", ""))]
	marker.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	marker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.focus_mode = Control.FOCUS_ALL
	var accent := spec.get("accent", VisualTheme.color("line")) as Color
	var background := spec.get("background", VisualTheme.color("surface")) as Color
	var text_color := spec.get("textColor", VisualTheme.color("text_secondary")) as Color
	var normal := _node_style(background, accent, 2)
	var hover := _node_style(background.lightened(0.08), accent.lightened(0.10), 3)
	var pressed := _node_style(background.darkened(0.08), accent, 4)
	var disabled := _node_style(background, Color(accent.r, accent.g, accent.b, 0.54), 2)
	for style_name in ["normal", "focus", "hover", "pressed", "disabled"]:
		var style := normal
		if style_name in ["focus", "hover"]:
			style = hover
		elif style_name == "pressed":
			style = pressed
		elif style_name == "disabled":
			style = disabled
		marker.add_theme_stylebox_override(style_name, style)
	marker.add_theme_color_override("font_color", text_color)
	marker.add_theme_color_override("font_hover_color", text_color)
	marker.add_theme_color_override("font_pressed_color", text_color)
	marker.add_theme_color_override("font_disabled_color", text_color)
	marker.add_theme_font_size_override("font_size", 17)
	if owner.get("ui_font_strong") != null:
		marker.add_theme_font_override("font", owner.get("ui_font_strong") as Font)
	marker.disabled = !bool(spec.get("enabled", false))
	if !marker.disabled:
		marker.pressed.connect(on_select)
	station_row.add_child(marker)
	if layer_number % 2 == 0:
		station_row.add_child(spacer)
	else:
		station_row.add_child(detail)
	var connector_center := CenterContainer.new()
	connector_center.custom_minimum_size = Vector2(0, CONNECTOR_HEIGHT)
	connector_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var connector := ColorRect.new()
	connector.name = "MapConnector"
	connector.custom_minimum_size = Vector2(4, CONNECTOR_HEIGHT)
	connector.color = accent if state != "future" else Color("#8fa7b1")
	connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	connector_center.add_child(connector)
	step.add_child(connector_center)
	connector.visible = layer_number > 1
	if node_type == "boss":
		marker.add_theme_font_size_override("font_size", 19)
	return step


static func _build_detail(owner: Node, spec: Dictionary, align_right: bool) -> VBoxContainer:
	var detail := VBoxContainer.new()
	detail.name = "MapNodeDetail"
	detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	detail.add_theme_constant_override("separation", 2)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state_label := Label.new()
	state_label.name = "MapStateLabel"
	state_label.text = str(spec.get("stateText", ""))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", spec.get("accent", VisualTheme.color("line")) as Color)
	if owner.get("ui_font_strong") != null:
		state_label.add_theme_font_override("font", owner.get("ui_font_strong") as Font)
	detail.add_child(state_label)
	var node_label := Label.new()
	node_label.name = "MapNodeLabel"
	node_label.text = str(spec.get("detailText", ""))
	node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	node_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_label.max_lines_visible = 2
	node_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node_label.add_theme_font_size_override("font_size", 13)
	node_label.add_theme_color_override("font_color", spec.get("detailColor", VisualTheme.color("text_secondary")) as Color)
	node_label.add_theme_color_override("font_shadow_color", Color("#f5fafae0"))
	node_label.add_theme_constant_override("shadow_offset_x", 1)
	node_label.add_theme_constant_override("shadow_offset_y", 1)
	if owner.get("ui_font") != null:
		node_label.add_theme_font_override("font", owner.get("ui_font") as Font)
	detail.add_child(node_label)
	return detail


static func _node_style(background: Color, accent: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
