extends TextureRect

const FLOOR_DURATION := 0.32
const SETTLE_DURATION := 0.10
const ENERGY_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float charge_progress : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_height : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec2 source_pixel_size = vec2(0.0006, 0.0011);

float cyan_signal(vec2 uv) {
	vec3 pixel = texture(source_texture, uv).rgb;
	float cyan_bias = min(pixel.g, pixel.b) - pixel.r;
	float saturation = max(max(pixel.r, pixel.g), pixel.b) - min(min(pixel.r, pixel.g), pixel.b);
	return smoothstep(0.13, 0.42, cyan_bias) * smoothstep(0.14, 0.36, saturation);
}

void fragment() {
	float signal = cyan_signal(UV);
	vec2 spread = source_pixel_size * 4.0;
	float halo = max(max(cyan_signal(UV + vec2(spread.x, 0.0)), cyan_signal(UV - vec2(spread.x, 0.0))), max(cyan_signal(UV + vec2(0.0, spread.y)), cyan_signal(UV - vec2(0.0, spread.y))));
	float center_mask = smoothstep(0.32, 0.39, UV.x) * (1.0 - smoothstep(0.61, 0.68, UV.x));
	float height_from_bottom = 1.0 - UV.y;
	float charged = 1.0 - smoothstep(charge_progress - 0.012, charge_progress + 0.012, height_from_bottom);
	float pulse_band = 1.0 - smoothstep(0.0, 0.042, abs(height_from_bottom - pulse_height));
	float pulse = pulse_band * pulse_strength;
	float alpha = center_mask * ((signal * 0.52 + halo * 0.16) * charged + (signal * 0.78 + halo * 0.30) * pulse);
	vec3 energy_color = mix(vec3(0.06, 0.72, 0.82), vec3(0.72, 1.0, 0.98), pulse * 0.72);
	COLOR = vec4(energy_color, clamp(alpha, 0.0, 0.92));
}
"""

var run_node_count := 12
var charged_layer := 0
var animation_active := false
var charge_progress := 0.0
var active_tween: Tween
var shader_material: ShaderMaterial


static func layer_progress(layer_number: int, node_count: int) -> float:
	if node_count <= 0:
		return 0.0
	return clampf(float(layer_number) / float(node_count), 0.0, 1.0)


func configure(source_texture: Texture2D, node_count: int) -> void:
	texture = source_texture
	run_node_count = maxi(node_count, 1)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = ENERGY_SHADER
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("source_texture", source_texture)
	if source_texture != null and source_texture.get_width() > 0 and source_texture.get_height() > 0:
		shader_material.set_shader_parameter("source_pixel_size", Vector2(1.0 / float(source_texture.get_width()), 1.0 / float(source_texture.get_height())))
	material = shader_material
	set_layer_immediate(0)


func set_layer_immediate(layer_number: int) -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	charged_layer = clampi(layer_number, 0, run_node_count)
	animation_active = false
	_set_charge_progress(layer_progress(charged_layer, run_node_count))
	_set_pulse_strength(0.0)


func animate_to_layer(target_layer: int, duration_scale: float = 1.0, reduced_flash: bool = false) -> void:
	var target := clampi(target_layer, 0, run_node_count)
	if target <= charged_layer:
		if target < charged_layer:
			set_layer_immediate(target)
		return
	animation_active = true
	if DisplayServer.get_name() == "headless" or duration_scale <= 0.0:
		set_layer_immediate(target)
		await get_tree().process_frame
		return
	var pulse_peak := 0.34 if reduced_flash else 1.0
	for layer_number in range(charged_layer + 1, target + 1):
		var from_progress := layer_progress(layer_number - 1, run_node_count)
		var to_progress := layer_progress(layer_number, run_node_count)
		_set_charge_progress(from_progress)
		_set_pulse_strength(pulse_peak)
		active_tween = create_tween().bind_node(self)
		active_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		active_tween.tween_method(_set_charge_progress, from_progress, to_progress, FLOOR_DURATION * duration_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await active_tween.finished
		charged_layer = layer_number
		active_tween = create_tween().bind_node(self)
		active_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		active_tween.tween_method(_set_pulse_strength, pulse_peak, 0.0, SETTLE_DURATION * duration_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await active_tween.finished
	animation_active = false


func snapshot() -> Dictionary:
	return {
		"active": animation_active,
		"chargedLayer": charged_layer,
		"progress": charge_progress,
		"pulseStrength": float(shader_material.get_shader_parameter("pulse_strength")) if shader_material != null else 0.0
	}


func _set_charge_progress(value: float) -> void:
	charge_progress = clampf(value, 0.0, 1.0)
	if shader_material != null:
		shader_material.set_shader_parameter("charge_progress", charge_progress)
		shader_material.set_shader_parameter("pulse_height", charge_progress)


func _set_pulse_strength(value: float) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("pulse_strength", clampf(value, 0.0, 1.0))
