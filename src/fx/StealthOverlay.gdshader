shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 light_center = vec2(0.5, 0.5);
uniform float inner_radius_px = 120.0;
uniform float outer_radius_px = 280.0;
uniform float max_darkness = 0.82;
uniform vec2 viewport_size = vec2(1600.0, 900.0);
uniform bool stealth_mode = true;

vec4 blurred_screen(vec2 uv, float blur_px) {
	vec2 px = vec2(1.0) / viewport_size;
	vec2 blur = px * blur_px;
	vec4 col = texture(screen_texture, uv) * 0.28;
	col += texture(screen_texture, uv + vec2( blur.x, 0.0)) * 0.12;
	col += texture(screen_texture, uv + vec2(-blur.x, 0.0)) * 0.12;
	col += texture(screen_texture, uv + vec2(0.0,  blur.y)) * 0.12;
	col += texture(screen_texture, uv + vec2(0.0, -blur.y)) * 0.12;
	col += texture(screen_texture, uv + blur) * 0.09;
	col += texture(screen_texture, uv - blur) * 0.09;
	col += texture(screen_texture, uv + vec2( blur.x, -blur.y)) * 0.09;
	col += texture(screen_texture, uv + vec2(-blur.x,  blur.y)) * 0.09;
	return col;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	if (!stealth_mode) {
		COLOR = base;
		return;
	}

	vec2 screen_pos = SCREEN_UV * viewport_size;
	float dist = distance(screen_pos, light_center);
	float t = smoothstep(inner_radius_px, outer_radius_px, dist);

	float blur_px = mix(0.0, 7.0, t);
	vec4 blurred = blurred_screen(SCREEN_UV, blur_px);
	vec4 mixed = mix(base, blurred, t);

	float darkness = mix(0.0, max_darkness, t);
	vec3 lit_tint = mix(vec3(1.0), vec3(0.94, 0.98, 0.95), t * 0.2);
	mixed.rgb *= lit_tint;
	mixed.rgb *= (1.0 - darkness);

	COLOR = vec4(mixed.rgb, 1.0);
}
