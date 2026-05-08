shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.015, 0.05, 0.03, 1.0);
uniform vec4 base_color : source_color = vec4(0.16, 0.85, 0.48, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.75, 1.0, 0.86, 1.0);
uniform float alpha_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float panel_mix = smoothstep(0.0, 0.22, 1.0 - luma);
	float highlight_mix = smoothstep(0.12, 0.45, luma);
	vec3 mapped = mix(shadow_color.rgb, base_color.rgb, panel_mix);
	mapped = mix(mapped, highlight_color.rgb, highlight_mix * 0.7);
	COLOR = vec4(mapped, tex.a * alpha_strength * COLOR.a);
}
