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
uniform float pixel_size = 2.0;
uniform float grain_strength = 0.08;
uniform float dither_strength = 0.06;
uniform float crt_tint_strength = 0.22;
uniform vec3 crt_tint = vec3(0.32, 0.95, 0.48);
uniform float scanline_strength = 0.22;
uniform float vignette_strength = 0.24;
uniform float grille_strength = 0.1;
uniform float warp_strength = 0.02;
uniform float wash_radius_px = 320.0;
uniform float wash_softness_px = 140.0;
uniform float wash_strength = 0.18;
uniform vec3 wash_tint = vec3(0.2, 0.9, 0.42);

vec4 blur3(vec2 uv, float blur_px) {
	vec2 px = vec2(1.0) / viewport_size;
	vec2 o = px * blur_px;
	vec4 c = texture(screen_tex, uv) * 0.52;
	c += texture(screen_tex, uv + vec2(o.x, o.y)) * 0.24;
	c += texture(screen_tex, uv - vec2(o.x, o.y)) * 0.24;
	return c;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - vec2(1.0);
	vec2 warped_uv = SCREEN_UV + centered * vec2(abs(centered.y), abs(centered.x)) * warp_strength;
	vec2 clamped_uv = clamp(warped_uv, vec2(0.0), vec2(1.0));
	vec4 base = texture(screen_tex, clamped_uv);
	vec4 out_col = base;
	vec2 screen_pos = clamped_uv * viewport_size;
	if (stealth_mix > 0.001) {
		float dist_px = distance(screen_pos, light_center);
		float blur_band = smoothstep(blur_start_px, outer_radius_px, dist_px);
		float darkness_band = smoothstep(inner_radius_px, outer_radius_px, dist_px);
		float blur_amount = mix(0.0, 8.0, blur_band);
		vec4 blurred = blur3(clamped_uv, blur_amount);
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
		float wash = 1.0 - smoothstep(wash_radius_px - wash_softness_px, wash_radius_px, dist_px);
		mixed_col.rgb += wash_tint * wash * wash_strength;
		out_col = mix(base, vec4(mixed_col.rgb, 1.0), stealth_mix);
	}

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

	vec2 frag_px = clamped_uv * viewport_size;
	vec2 snapped_px = (floor(frag_px / pixel_size) + 0.5) * pixel_size;
	vec2 noise_phase = floor(snapped_px * vec2(1.0, 0.5)) + vec2(TIME * 19.0, TIME * 11.0);
	float noise = hash(noise_phase) - 0.5;
	float grain = noise * grain_strength;
	float dither = noise * dither_strength * 0.55;
	out_col.rgb = clamp(out_col.rgb + grain + dither, vec3(0.0), vec3(1.0));
	float luminance = dot(out_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 phosphor_mono = crt_tint * (0.32 + luminance * 1.05);
	out_col.rgb = mix(out_col.rgb, phosphor_mono, crt_tint_strength);
	out_col.rgb += crt_tint * 0.06;
	float scan_phase = 0.5 + 0.5 * cos(frag_px.y * 3.14159265);
	float scanline = 1.0 - scan_phase * scanline_strength;
	float triad = 0.94 + 0.06 * sin(frag_px.x * 2.4);
	float grille = 1.0 - (0.5 + 0.5 * sin(frag_px.x * 1.2)) * grille_strength;
	float crt_vignette = 1.0 - smoothstep(0.24, 1.1, length(centered)) * vignette_strength;
	out_col.rgb *= scanline * grille * crt_vignette;
	out_col.r *= triad * 0.98;
	out_col.g *= 1.03;
	out_col.b *= (2.0 - triad) * 0.95;
	out_col.rgb = clamp(out_col.rgb, vec3(0.0), vec3(1.0));

	COLOR = out_col;
}
"""

var _shader_material: ShaderMaterial
var _last_viewport_size := Vector2.ZERO
var _last_mode_in_combat := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER_CODE
	_shader_material.shader = shader
	material = _shader_material
	_apply_static_shader_params()
	_update_shader_params()
	ColorSystem.mode_changed.connect(_on_mode_changed)


func _process(delta: float) -> void:
	_update_shader_params()


func _on_mode_changed(_in_combat: bool) -> void:
	_apply_static_shader_params()
	_update_shader_params()


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
	if rect.size != _last_viewport_size:
		_last_viewport_size = rect.size
		queue_redraw()
	var reveal_data: Dictionary = _stealth_reveal_data(rect)
	var in_combat := ColorSystem.in_combat
	if in_combat != _last_mode_in_combat:
		_last_mode_in_combat = in_combat
		_apply_static_shader_params()
	_shader_material.set_shader_parameter("light_center", _signal_center(rect))
	_shader_material.set_shader_parameter("viewport_size", rect.size)
	_shader_material.set_shader_parameter("stealth_mix", 1.0 if not in_combat else 0.0)
	_shader_material.set_shader_parameter("combat_mix", 0.0 if not in_combat else 1.0)
	_shader_material.set_shader_parameter("reveal_count", reveal_data["count"])
	_shader_material.set_shader_parameter("reveal_centers", reveal_data["centers"])
	_shader_material.set_shader_parameter("reveal_radii", reveal_data["radii"])


func _apply_static_shader_params() -> void:
	if _shader_material == null:
		return
	var in_combat := ColorSystem.in_combat
	_shader_material.set_shader_parameter("inner_radius_px", 132.0)
	_shader_material.set_shader_parameter("blur_start_px", 153.0)
	_shader_material.set_shader_parameter("outer_radius_px", 382.0)
	_shader_material.set_shader_parameter("max_darkness", 0.92)
	_shader_material.set_shader_parameter("ambient_floor", 0.16)
	_shader_material.set_shader_parameter("reveal_strength", 0.82)
	_shader_material.set_shader_parameter("pixel_size", 2.0)
	_shader_material.set_shader_parameter("grain_strength", 0.05 if not in_combat else 0.035)
	_shader_material.set_shader_parameter("dither_strength", 0.025 if not in_combat else 0.015)
	_shader_material.set_shader_parameter("crt_tint_strength", 0.28 if not in_combat else 0.1)
	_shader_material.set_shader_parameter("crt_tint", Vector3(0.32, 0.95, 0.48))
	_shader_material.set_shader_parameter("scanline_strength", 0.22)
	_shader_material.set_shader_parameter("vignette_strength", 0.24)
	_shader_material.set_shader_parameter("grille_strength", 0.08)
	_shader_material.set_shader_parameter("warp_strength", 0.012)
	_shader_material.set_shader_parameter("wash_radius_px", 382.0)
	_shader_material.set_shader_parameter("wash_softness_px", 176.0)
	_shader_material.set_shader_parameter("wash_strength", 0.16 if not in_combat else 0.0)
	_shader_material.set_shader_parameter("wash_tint", Vector3(0.17, 0.78, 0.36))
