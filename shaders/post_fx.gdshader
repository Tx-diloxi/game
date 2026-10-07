shader_type canvas_item;

// Vignette, grain de film et voile rouge de blessure (superposé à l'image).
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 0.3) = 0.06;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
// Voile de couleur (Sang de zombie)
uniform vec3 tint : source_color = vec3(0.2, 0.45, 1.0);
uniform float tint_amt : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.3;
	float dist = length(uv);
	float vig = smoothstep(0.35, 0.95, dist);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	float dmg = damage * smoothstep(0.15, 0.8, dist) * pulse;
	float n = rand(UV * 731.0 + fract(TIME * 7.13));
	vec3 col = mix(vec3(0.0), vec3(0.45, 0.0, 0.0), clamp(dmg * 2.0, 0.0, 1.0));
	float a = clamp(vig * vignette + dmg * 0.9, 0.0, 0.97);
	// grain : alterne léger éclaircissement/assombrissement
	col = mix(col, vec3(n), grain * (1.0 - a));
	a = max(a, grain * 0.6);
	col = mix(col, flash_color, flash);
	a = mix(a, 1.0, flash);
	if (tint_amt > 0.001) {
		col = mix(col, tint, 0.85);
		a = max(a, tint_amt);
	}
	COLOR = vec4(col, a);
}
