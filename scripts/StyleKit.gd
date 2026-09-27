class_name StyleKit
extends RefCounted
## Builds reusable stylized materials + inverted-hull outline.
## Uses StandardMaterial3D (never pink) instead of a custom light() toon shader.
## Godot 4.5–4.7 Forward+ has had regressions where NORMAL/VIEW in light()
## fail to compile → magenta/pink materials. Playability first.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## Vibrant anime palette (no muddy greys/browns).
const PALETTE := {
	"maya_skin": Color(1.0, 0.78, 0.72),
	"maya_hair": Color(0.95, 0.35, 0.95),
	"maya_hair_dark": Color(0.65, 0.15, 0.85),
	"maya_bike": Color(1.0, 0.35, 0.75),
	"maya_bike_accent": Color(0.7, 0.2, 1.0),
	"jax_skin": Color(0.92, 0.75, 0.62),
	"jax_hair": Color(0.25, 0.85, 1.0),
	"jax_hair_dark": Color(0.15, 0.45, 0.95),
	"jax_bike": Color(0.2, 0.75, 1.0),
	"jax_bike_accent": Color(0.15, 1.0, 0.85),
	"eye_white": Color(1.0, 1.0, 1.0),
	"eye_iris_maya": Color(0.55, 0.2, 0.95),
	"eye_iris_jax": Color(0.15, 0.55, 1.0),
	"eye_pupil": Color(0.05, 0.05, 0.12),
	"chaser": Color(0.55, 0.1, 0.85),
	"chaser_accent": Color(1.0, 0.2, 0.7),
	"road": Color(0.35, 0.25, 0.65),
	"road_stripe": Color(1.0, 0.95, 0.35),
	"road_edge": Color(0.15, 0.95, 0.85),
	"obstacle": Color(1.0, 0.25, 0.35),
	"obstacle_accent": Color(1.0, 0.55, 0.15),
	"coin": Color(1.0, 0.9, 0.2),
	"boost": Color(0.2, 1.0, 0.55),
	"mushroom_cap": Color(1.0, 0.3, 0.55),
	"mushroom_stem": Color(1.0, 0.95, 0.85),
	"block": Color(0.35, 0.85, 1.0),
	"neon": Color(0.4, 1.0, 0.3),
	"outline": Color(0.08, 0.04, 0.16, 1.0),
}

static func make_outline(width: float = 0.035, color: Color = PALETTE["outline"]) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", width)
	return mat

## Build a vivid, always-valid material. opts keys (all optional):
## outline_width, outline_color, emission_strength, emission_color,
## metallic, roughness, base_glow, shade_color (ignored — kept for API compat),
## rim_amount / highlight_* (ignored — kept for API compat).
static func make_toon(
	albedo: Color,
	opts: Dictionary = {}
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = float(opts.get("roughness", 0.72))
	mat.metallic = float(opts.get("metallic", 0.0))
	# Mild base glow so meshes pop against the sky and never read as void/black.
	var base_glow := float(opts.get("base_glow", 0.14))
	var em_str := float(opts.get("emission_strength", 0.0))
	var em_col: Color = opts.get("emission_color", albedo)
	if em_str > 0.0:
		mat.emission_enabled = true
		mat.emission = em_col
		mat.emission_energy_multiplier = em_str + base_glow * 0.35
	elif base_glow > 0.0:
		mat.emission_enabled = true
		mat.emission = albedo
		mat.emission_energy_multiplier = base_glow
	var outline_w: float = float(opts.get("outline_width", 0.035))
	if outline_w > 0.0:
		mat.next_pass = make_outline(outline_w, opts.get("outline_color", PALETTE["outline"]))
	return mat

static func apply_to_mesh(mesh_instance: MeshInstance3D, albedo: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var mat := make_toon(albedo, opts)
	mesh_instance.material_override = mat
	return mat
