shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

/** Inverted-hull outline: expands along normals, draws backfaces only. */
uniform vec4 outline_color : source_color = vec4(0.08, 0.04, 0.16, 1.0);
/** World-ish expand amount (scaled by mesh size; keep small for mobile). */
uniform float outline_width : hint_range(0.0, 0.25) = 0.035;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
