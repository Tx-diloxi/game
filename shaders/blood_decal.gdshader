shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Flaque / éclaboussure de sang : bruit seuillé avec atténuation radiale.
uniform sampler2D noise_tex : repeat_enable;
uniform vec4 blood_color : source_color = vec4(0.22, 0.01, 0.01, 0.95);
uniform float spread : hint_range(0.0, 1.0) = 1.0;
uniform vec2 noise_offset = vec2(0.0);

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p) * 2.0;
	float n = texture(noise_tex, UV * 0.8 + noise_offset).r;
	float shape = n + (1.0 - d) * 0.9 - 0.75;
	float edge = smoothstep(0.0, 0.06, shape - (1.0 - spread) * 0.6);
	if (edge < 0.01) {
		discard;
	}
	ALBEDO = blood_color.rgb * (0.7 + n * 0.4);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = edge * blood_color.a;
}
