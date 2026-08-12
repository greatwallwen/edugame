extends Control

const HARDWARE_ART_PATH := "res://assets/ui/in-run-electronic-frame-flat-slim-v5.png"
const HARDWARE_ART := preload(HARDWARE_ART_PATH)
const HARDWARE_WIDE_ART_PATH := "res://assets/ui/in-run-electronic-frame-flat-slim-wide-v5.png"
const HARDWARE_WIDE_ART := preload(HARDWARE_WIDE_ART_PATH)

var accent := Color("#4fc3ff")
var frame_id := "unit"
var profile := "hardware"
var motion_time := 0.0
var hardware_art: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_hardware_art()
	_sync_profile_visibility()
	call_deferred("_place_below_content")
	set_process(true)
	queue_redraw()


func configure(id: String, frame_accent: Color, frame_profile: String = "hardware") -> void:
	frame_id = id
	accent = frame_accent
	_sync_hardware_texture()
	set_profile(frame_profile)


func set_profile(value: String) -> void:
	profile = value if value in ["hardware", "tactical"] else "hardware"
	_sync_profile_visibility()
	queue_redraw()


func hardware_art_path() -> String:
	return HARDWARE_ART_PATH


func hardware_art_paths() -> Dictionary:
	return {
		"support": HARDWARE_ART_PATH,
		"fault": HARDWARE_WIDE_ART_PATH,
	}


static func content_safe_insets_for(id: String) -> Dictionary:
	if id == "fault":
		return {"left": 20.0, "top": 64.0, "right": 20.0, "bottom": 24.0}
	return {"left": 18.0, "top": 32.0, "right": 18.0, "bottom": 24.0}


func content_safe_insets() -> Dictionary:
	return content_safe_insets_for(frame_id)


func visual_signature() -> String:
	return "%s:%s" % ["tactical_hud" if profile == "tactical" else "flat_slim_electronic_art", frame_id]


func _process(delta: float) -> void:
	motion_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 48.0 or size.y < 48.0:
		return
	if profile == "tactical":
		_draw_tactical()
	else:
		_draw_hardware()


func _draw_hardware() -> void:
	var strong := Color(accent.r, accent.g, accent.b, 0.88)
	var soft := Color(accent.r, accent.g, accent.b, 0.34)
	var pulse := 0.72 + sin(motion_time * 2.4) * 0.12
	draw_rect(Rect2(16, 12, 18, 3), Color(strong.r, strong.g, strong.b, pulse), true)
	draw_rect(Rect2(37, 12, 7, 3), soft, true)
	draw_rect(Rect2(size.x - 21, size.y - 17, 5, 5), strong, true)


func _ensure_hardware_art() -> void:
	if hardware_art != null:
		return
	hardware_art = TextureRect.new()
	hardware_art.name = "HardwareFrameArt"
	hardware_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hardware_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hardware_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hardware_art.stretch_mode = TextureRect.STRETCH_SCALE
	hardware_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hardware_art.show_behind_parent = true
	add_child(hardware_art)
	_sync_hardware_texture()


func _sync_hardware_texture() -> void:
	if hardware_art != null:
		hardware_art.texture = HARDWARE_WIDE_ART if frame_id == "fault" else HARDWARE_ART
		if frame_id == "fault":
			hardware_art.offset_left = -40.0
			hardware_art.offset_top = -32.0
			hardware_art.offset_right = 40.0
			hardware_art.offset_bottom = 32.0
		else:
			hardware_art.offset_left = -34.0
			hardware_art.offset_top = -36.0
			hardware_art.offset_right = 34.0
			hardware_art.offset_bottom = 36.0


func _place_below_content() -> void:
	var parent := get_parent()
	if parent != null and get_index() > 0:
		parent.move_child(self, 0)


func _sync_profile_visibility() -> void:
	if hardware_art != null:
		hardware_art.visible = profile == "hardware"


func _draw_tactical() -> void:
	var strong := Color(accent.r, accent.g, accent.b, 0.82)
	var soft := Color(accent.r, accent.g, accent.b, 0.24)
	var inset := 5.0
	var bracket := 17.0
	_draw_corner(Vector2(inset, inset), Vector2(1, 1), bracket, strong)
	_draw_corner(Vector2(size.x - inset, inset), Vector2(-1, 1), bracket, strong)
	_draw_corner(Vector2(inset, size.y - inset), Vector2(1, -1), bracket, soft)
	_draw_corner(Vector2(size.x - inset, size.y - inset), Vector2(-1, -1), bracket, soft)
	draw_line(Vector2(30, inset), Vector2(size.x * 0.36, inset), soft, 1.0)
	var scan_width := maxf(30.0, size.x * 0.16)
	var scan_start := 30.0 + fmod(motion_time * 28.0, maxf(size.x - scan_width - 60.0, 1.0))
	draw_line(Vector2(scan_start, inset), Vector2(minf(scan_start + scan_width, size.x - 30.0), inset), Color(accent.r, accent.g, accent.b, 0.50), 2.0)
	for index in range(3):
		var pip_x := size.x - 30.0 - float(index) * 8.0
		draw_rect(Rect2(pip_x, 9, 4, 2), strong if index == 0 else soft, true)


func _draw_corner(origin: Vector2, direction: Vector2, length: float, color: Color) -> void:
	draw_line(origin, origin + Vector2(direction.x * length, 0), color, 2.0)
	draw_line(origin, origin + Vector2(0, direction.y * length), color, 2.0)
