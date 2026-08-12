extends TextureRect

const BACKDROP_TEXTURE = preload("res://assets/ui/ambient-lab-backdrop-v1.png")


func _init() -> void:
	name = "EnvSpireBackdrop"
	texture = BACKDROP_TEXTURE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modulate = Color(0.96, 0.98, 1.0, 0.94)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_side_veil("AmbientLeftColorVeil", 0.0, 0.18)
	_add_side_veil("AmbientRightColorVeil", 0.82, 1.0)


func _add_side_veil(veil_name: String, left_anchor: float, right_anchor: float) -> void:
	var veil := ColorRect.new()
	veil.name = veil_name
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.anchor_left = left_anchor
	veil.anchor_right = right_anchor
	veil.offset_left = 0.0
	veil.offset_top = 0.0
	veil.offset_right = 0.0
	veil.offset_bottom = 0.0
	veil.color = Color(0.96, 0.98, 1.0, 0.18)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)


func visual_signature() -> String:
	return "ambient_lab:quiet_center:perimeter_sensors"
