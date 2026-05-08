extends Control

const GRAIN_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float pixel_size = 2.0;
uniform float grain_strength = 0.11;
uniform float dither_strength = 0.08;
uniform float stealth_tint_strength = 0.55;
uniform vec3 stealth_tint = vec3(0.32, 0.95, 0.48);
uniform float scanline_strength = 0.18;
uniform float vignette_strength = 0.22;
uniform float grille_strength = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 size = max(viewport_size, vec2(1.0));
	vec2 centered = SCREEN_UV * 2.0 - vec2(1.0);
	vec2 warped_uv = SCREEN_UV + centered * vec2(abs(centered.y), abs(centered.x)) * 0.015;
	vec2 clamped_uv = clamp(warped_uv, vec2(0.0), vec2(1.0));
	vec2 frag_px = clamped_uv * size;
	vec2 snapped_px = (floor(frag_px / pixel_size) + 0.5) * pixel_size;
	vec4 col = texture(screen_texture, clamped_uv);

	float grain = (hash(floor(snapped_px) + vec2(TIME * 19.0, TIME * 11.0)) - 0.5) * grain_strength;
	float dither = (hash(floor(snapped_px * 0.5) + vec2(17.0, 53.0)) - 0.5) * dither_strength;
	col.rgb = clamp(col.rgb + grain + dither, vec3(0.0), vec3(1.0));
	float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 phosphor_mono = stealth_tint * (0.32 + luminance * 1.05);
	col.rgb = mix(col.rgb, phosphor_mono, stealth_tint_strength);
	col.rgb += stealth_tint * 0.08;
	col.rgb = max(col.rgb, stealth_tint * 0.18);
	float scan_phase = 0.5 + 0.5 * cos(frag_px.y * 3.14159265);
	float scanline = 1.0 - scan_phase * scanline_strength;
	float triad = 0.94 + 0.06 * sin(frag_px.x * 2.4);
	float grille = 1.0 - (0.5 + 0.5 * sin(frag_px.x * 1.2)) * grille_strength;
	float vignette = 1.0 - smoothstep(0.28, 1.12, length(centered)) * vignette_strength;
	col.rgb *= scanline * grille * vignette;
	col.r *= triad * 0.98;
	col.g *= 1.02;
	col.b *= (2.0 - triad) * 0.96;
	col.rgb = clamp(col.rgb, vec3(0.0), vec3(1.0));
	COLOR = col;
}
"""

var _shader_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GRAIN_SHADER_CODE
	_shader_material.shader = shader
	material = _shader_material
	ColorSystem.mode_changed.connect(_update_shader_params)
	resized.connect(_update_shader_params)
	_update_shader_params()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_shader_params()


func _update_shader_params() -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter("viewport_size", get_viewport_rect().size)
	_shader_material.set_shader_parameter("stealth_tint_strength", 0.55 if not ColorSystem.in_combat else 0.0)
