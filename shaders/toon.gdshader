shader_type spatial;
/* Fragment-only cel look — NO custom light().
   Godot 4.5–4.7 Forward+ had regressions where NORMAL/VIEW inside light()
   failed to compile (magenta/pink materials). This path stays safe. */
render_mode unshaded, cull_back, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.35, 0.28, 0.55, 1.0);
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shade_softness : hint_range(0.001, 0.5) = 0.04;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.85;
uniform float highlight_softness : hint_range(0.001, 0.5) = 0.05;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_mix : hint_range(0.0, 1.0) = 0.25;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.45;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.55;
uniform vec4 rim_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
/** Fake key-light direction in view/world-ish space for band shading. */
uniform vec3 light_dir = vec3(0.35, 0.85, 0.35);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(light_dir);
	float ndotl = clamp(dot(n, l), 0.0, 1.0);

	float shade = smoothstep(
		shade_threshold - shade_softness,
		shade_threshold + shade_softness,
		ndotl
	);
	vec3 lit = mix(albedo.rgb * shade_color.rgb, albedo.rgb, shade);

	float hi = smoothstep(
		highlight_threshold - highlight_softness,
		highlight_threshold + highlight_softness,
		ndotl
	);
	lit = mix(lit, mix(lit, highlight_color.rgb, highlight_mix), hi);

	float ndotv = clamp(dot(n, VIEW), 0.0, 1.0);
	float rim = smoothstep(rim_threshold, 1.0, 1.0 - ndotv) * rim_amount;
	lit += rim_color.rgb * rim;

	ALBEDO = lit;
	ALPHA = albedo.a;
	EMISSION = emission_color.rgb * emission_strength + lit * 0.08;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
