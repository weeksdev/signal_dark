shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float green_strength : hint_range(0.0, 1.0) = 0.72;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.14;
uniform float scanline_count = 240.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.18;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.018;
uniform float brightness = 1.1;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = texture(screen_texture, uv).rgb;

	float luma = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 green_crt = vec3(luma * 0.08, luma * 1.25, luma * 0.22);
	vec3 color = mix(src, green_crt, green_strength);

	float scan = sin(uv.y * scanline_count * 6.2831853);
	color *= 1.0 - scanline_strength * (0.5 + 0.5 * scan);

	float n = rand(uv * TIME * 60.0) - 0.5;
	color += n * noise_strength;

	vec2 centered = uv - 0.5;
	float vignette = 1.0 - dot(centered, centered) * vignette_strength * 2.0;
	color *= clamp(vignette, 0.0, 1.0);

	COLOR = vec4(color * brightness, 1.0);
}
