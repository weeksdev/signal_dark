extends Control

const OVERLAY_SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 light_center = vec2(800.0, 450.0);
uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform float inner_radius_px = 96.0;
uniform float blur_start_px = 120.0;
uniform float outer_radius_px = 285.0;
uniform float max_darkness = 0.84;
uniform float ambient_floor = 0.19;
uniform float stealth_mix = 1.0;
uniform int reveal_count = 0;
uniform vec2 reveal_centers[4];
uniform float reveal_radii[4];
uniform float reveal_strength = 0.22;

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
	float blur_band = smoothstep(blur_start_px, outer_radius_px, dist_px);
	float darkness_band = smoothstep(inner_radius_px, outer_radius_px, dist_px);

	float blur_amount = mix(0.0, 10.5, blur_band);
	vec4 blurred = blur5(SCREEN_UV, blur_amount);
	vec4 mixed_col = mix(base, blurred, blur_band);

	float darkness = mix(0.0, max_darkness, darkness_band);
	float visibility = max(ambient_floor, 1.0 - darkness);
	float reveal_visibility = 0.0;
	float reveal_clarity = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= reveal_count) {
			break;
		}
		float reveal_dist = distance(screen_pos, reveal_centers[i]);
		float reveal_outer = 1.0 - smoothstep(reveal_radii[i] * 0.36, reveal_radii[i], reveal_dist);
		float reveal_inner = 1.0 - smoothstep(0.0, reveal_radii[i] * 0.46, reveal_dist);
		reveal_visibility = max(reveal_visibility, reveal_outer);
		reveal_clarity = max(reveal_clarity, reveal_inner * 0.72 + reveal_outer * 0.12);
	}
	mixed_col.rgb *= visibility;
	mixed_col.rgb *= 1.0 + reveal_visibility * reveal_strength;
	mixed_col = mix(mixed_col, base, reveal_clarity);

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
	return _screen_from_world(ship.global_position, rect)


func _screen_from_world(world_pos: Vector2, rect: Rect2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return rect.size * 0.5
	var relative: Vector2 = world_pos - camera.get_screen_center_position()
	return rect.size * 0.5 + Vector2(relative.x / camera.zoom.x, relative.y / camera.zoom.y)


func _wisp_reveal_data(rect: Rect2) -> Dictionary:
	var centers: Array = [
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0)
	]
	var radii: Array = [0.0, 0.0, 0.0, 0.0]
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null:
			continue
		if not enemy.scene_file_path.ends_with("Wisp.tscn"):
			continue
		if count >= 4:
			break
		var center: Vector2 = _screen_from_world(enemy.global_position, rect)
		if not Rect2(Vector2.ZERO, rect.size).grow(96.0).has_point(center):
			continue
		centers[count] = center
		radii[count] = 110.0
		count += 1
	return {
		"count": count,
		"centers": centers,
		"radii": radii
	}


func _update_shader_params() -> void:
	if _shader_material == null:
		return
	var rect := get_viewport_rect()
	var reveal_data: Dictionary = _wisp_reveal_data(rect)
	_shader_material.set_shader_parameter("light_center", _signal_center(rect))
	_shader_material.set_shader_parameter("viewport_size", rect.size)
	_shader_material.set_shader_parameter("stealth_mix", 1.0 if not ColorSystem.in_combat else 0.0)
	_shader_material.set_shader_parameter("inner_radius_px", 88.0)
	_shader_material.set_shader_parameter("blur_start_px", 102.0)
	_shader_material.set_shader_parameter("outer_radius_px", 255.0)
	_shader_material.set_shader_parameter("max_darkness", 0.92)
	_shader_material.set_shader_parameter("ambient_floor", 0.16)
	_shader_material.set_shader_parameter("reveal_count", reveal_data["count"])
	_shader_material.set_shader_parameter("reveal_centers", reveal_data["centers"])
	_shader_material.set_shader_parameter("reveal_radii", reveal_data["radii"])
	_shader_material.set_shader_parameter("reveal_strength", 0.7)
