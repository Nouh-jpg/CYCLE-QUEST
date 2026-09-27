shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

/** Flat albedo / base color. */
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/** Shadow-band tint (multiply into lit albedo in shade regions). */
uniform vec4 shade_color : source_color = vec4(0.35, 0.28, 0.55, 1.0);
/** Where the light→shade hard edge sits (N·L). */
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.45;
/** Softness of the cel band edge. */
uniform float shade_softness : hint_range(0.001, 0.5) = 0.04;
/** Second highlight band strength (0 = single band). */
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.85;
uniform float highlight_softness : hint_range(0.001, 0.5) = 0.05;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_mix : hint_range(0.0, 1.0) = 0.25;
/** Fresnel-style rim light. */
uniform float rim_amount : hint_range(0.0, 1.0) = 0.45;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.55;
uniform vec4 rim_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
/** Optional self-glow (coins, boosts, neon). */
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	ALBEDO = albedo.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = albedo.a;
	EMISSION = emission_color.rgb * emission_strength;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);

	// Primary cel shade band
	float shade = smoothstep(
		shade_threshold - shade_softness,
		shade_threshold + shade_softness,
		ndotl
	);
	vec3 lit = mix(albedo.rgb * shade_color.rgb, albedo.rgb, shade);

	// Optional bright highlight band
	float hi = smoothstep(
		highlight_threshold - highlight_softness,
		highlight_threshold + highlight_softness,
		ndotl
	);
	lit = mix(lit, mix(lit, highlight_color.rgb, highlight_mix), hi);

	// Rim (view-dependent)
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = (1.0 - ndotv);
	rim = smoothstep(rim_threshold, 1.0, rim) * rim_amount;
	lit += rim_color.rgb * rim;

	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR * 0.55;
	SPECULAR_LIGHT += vec3(0.0);
}
