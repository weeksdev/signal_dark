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
uniform float combat_mix = 0.0;
uniform int reveal_count = 0;
	uniform vec2 reveal_centers[16];
	uniform float reveal_radii[16];
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
		for (int i = 0; i < 16; i++) {
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

	vec4 stealth_col = vec4(mixed_col.rgb, 1.0);
	vec4 out_col = mix(base, stealth_col, stealth_mix);

	vec2 centered = SCREEN_UV * 2.0 - vec2(1.0);
	float edge = smoothstep(0.28, 1.12, length(centered));
	float scan = sin(screen_pos.y * 1.7 + TIME * 18.0) * 0.5 + 0.5;
	float breach = sin(TIME * 5.4) * 0.5 + 0.5;
		vec3 combat_tint = vec3(0.01, 0.025, 0.06) * edge * 0.22;
		vec3 red_edge = vec3(0.28, 0.015, 0.005) * edge * breach * 0.15;
		vec3 red_lift = vec3(0.08, 0.012, 0.004) * (1.0 - edge) * breach * 0.04;
		vec3 combat_rgb = base.rgb * 0.68 + combat_tint + red_edge + red_lift;
		combat_rgb *= 1.0 - edge * 0.46;
		combat_rgb += scan * vec3(0.018, 0.004, 0.001) * combat_mix;
	out_col.rgb = mix(out_col.rgb, combat_rgb, combat_mix);

	COLOR = out_col;
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


func _stealth_reveal_data(rect: Rect2) -> Dictionary:
	var centers: Array = [
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0),
		Vector2(-10000.0, -10000.0)
	]
	var radii: Array = [
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
	]
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null:
			continue
		if count >= 16:
			break
		var center: Vector2 = _screen_from_world(enemy.global_position, rect)
		if not Rect2(Vector2.ZERO, rect.size).grow(96.0).has_point(center):
			continue
		var reveal_level := 0.0
		if enemy.has_method("stealth_reveal_level"):
			reveal_level = float(enemy.stealth_reveal_level())
		if enemy.scene_file_path.ends_with("Wisp.tscn"):
			reveal_level = maxf(reveal_level, 0.34)
		if reveal_level <= 0.05:
			continue
		centers[count] = center
		radii[count] = lerpf(52.0, 118.0, clampf(reveal_level, 0.0, 1.0))
		count += 1
	for node in get_tree().get_nodes_in_group("arcade_objective"):
		if node == null:
			continue
		if count >= 16:
			break
		if node.completed:
			continue
		var objective_center: Vector2 = _screen_from_world(node.global_position, rect)
		if not Rect2(Vector2.ZERO, rect.size).grow(120.0).has_point(objective_center):
			continue
		centers[count] = objective_center
		radii[count] = 150.0
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
	var reveal_data: Dictionary = _stealth_reveal_data(rect)
	_shader_material.set_shader_parameter("light_center", _signal_center(rect))
	_shader_material.set_shader_parameter("viewport_size", rect.size)
	_shader_material.set_shader_parameter("stealth_mix", 1.0 if not ColorSystem.in_combat else 0.0)
	_shader_material.set_shader_parameter("combat_mix", 0.0 if not ColorSystem.in_combat else 1.0)
	_shader_material.set_shader_parameter("inner_radius_px", 88.0)
	_shader_material.set_shader_parameter("blur_start_px", 102.0)
	_shader_material.set_shader_parameter("outer_radius_px", 255.0)
	_shader_material.set_shader_parameter("max_darkness", 0.92)
	_shader_material.set_shader_parameter("ambient_floor", 0.16)
	_shader_material.set_shader_parameter("reveal_count", reveal_data["count"])
	_shader_material.set_shader_parameter("reveal_centers", reveal_data["centers"])
	_shader_material.set_shader_parameter("reveal_radii", reveal_data["radii"])
	_shader_material.set_shader_parameter("reveal_strength", 0.82)
