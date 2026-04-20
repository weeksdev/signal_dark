extends Control

const OVERLAY_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 light_center = vec2(800.0, 450.0);
uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform float inner_radius_px = 110.0;
uniform float outer_radius_px = 250.0;
uniform float max_darkness = 0.72;
uniform float ambient_floor = 0.24;
uniform float stealth_mix = 1.0;

vec4 blur5(vec2 uv, float blur_px) {
	vec2 px = vec2(1.0) / viewport_size;
	vec2 o = px * blur_px;
	vec4 c = texture(screen_tex, uv) * 0.36;
	c += texture(screen_tex, uv + vec2( o.x, 0.0)) * 0.16;
	c += texture(screen_tex, uv + vec2(-o.x, 0.0)) * 0.16;
	c += texture(screen_tex, uv + vec2(0.0,  o.y)) * 0.16;
	c += texture(screen_tex, uv + vec2(0.0, -o.y)) * 0.16;
	return c;
}

void fragment() {
	vec4 base = texture(screen_tex, SCREEN_UV);
	vec2 screen_pos = SCREEN_UV * viewport_size;
	float dist_px = distance(screen_pos, light_center);
	float falloff = smoothstep(inner_radius_px, outer_radius_px, dist_px);

	float blur_amount = mix(0.0, 10.0, falloff);
	vec4 blurred = blur5(SCREEN_UV, blur_amount);
	vec4 mixed_col = mix(base, blurred, falloff);

	float darkness = mix(0.0, max_darkness, falloff);
	float visibility = max(ambient_floor, 1.0 - darkness);
	mixed_col.rgb *= visibility;

	COLOR = mix(base, vec4(mixed_col.rgb, 1.0), stealth_mix);
}
"""

var _shader_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER_CODE
	_shader_material.shader = shader
	material = _shader_material
	ColorSystem.mode_changed.connect(_on_mode_changed)


func _process(_delta: float) -> void:
	_update_shader_params()
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_shader_params()
	queue_redraw()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color.WHITE, true)


func _signal_center(rect: Rect2) -> Vector2:
	var ship := get_tree().get_first_node_in_group("player_ship")
	var camera := get_viewport().get_camera_2d()
	if ship == null or camera == null:
		return rect.size * 0.5
	var relative: Vector2 = ship.global_position - camera.get_screen_center_position()
	return rect.size * 0.5 + Vector2(relative.x / camera.zoom.x, relative.y / camera.zoom.y)


func _update_shader_params() -> void:
	if _shader_material == null:
		return
	var rect := get_viewport_rect()
	_shader_material.set_shader_parameter("light_center", _signal_center(rect))
	_shader_material.set_shader_parameter("viewport_size", rect.size)
	_shader_material.set_shader_parameter("stealth_mix", 1.0 if not ColorSystem.in_combat else 0.0)
	_shader_material.set_shader_parameter("inner_radius_px", 115.0)
	_shader_material.set_shader_parameter("outer_radius_px", 255.0)
	_shader_material.set_shader_parameter("max_darkness", 0.72)
	_shader_material.set_shader_parameter("ambient_floor", 0.24)
