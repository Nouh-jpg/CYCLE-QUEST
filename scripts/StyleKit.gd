extends Node
## Builds reusable stylized materials + inverted-hull outline.
## Autoload singleton so StyleKit resolves on Godot 4.7
## even when global class cache fails for RefCounted scripts.
## Uses StandardMaterial3D (never pink) instead of a custom light() toon shader.
## Godot 4.5–4.7 Forward+ has had regressions where NORMAL/VIEW in light()
## fail to compile → magenta/pink materials. Playability first.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## Arcade-cabinet loud palette — max saturation, no muddy greys.
const PALETTE := {
	"maya_skin": Color(1.0, 0.84, 0.76),
	"maya_hair": Color(1.0, 0.05, 0.22),  # electric crimson
	"maya_hair_dark": Color(0.75, 0.0, 0.12),
	"maya_hair_accent": Color(1.0, 0.4, 0.55),
	"maya_outfit": Color(0.1, 0.05, 0.18),
	"maya_skirt": Color(1.0, 0.2, 0.55),
	"maya_bike": Color(1.0, 0.05, 0.18),
	"maya_bike_accent": Color(1.0, 0.9, 0.05),
	"jax_skin": Color(0.95, 0.78, 0.64),
	"jax_hair": Color(0.05, 0.9, 1.0),
	"jax_hair_dark": Color(0.0, 0.35, 1.0),
	"jax_bike": Color(0.05, 0.5, 1.0),
	"jax_bike_accent": Color(0.1, 1.0, 0.7),
	"eye_white": Color(1.0, 1.0, 1.0),
	"eye_iris_maya": Color(1.0, 0.15, 0.35),
	"eye_iris_jax": Color(0.05, 0.55, 1.0),
	"eye_pupil": Color(0.05, 0.05, 0.12),
	"chaser": Color(0.65, 0.05, 1.0),
	"chaser_accent": Color(1.0, 0.15, 0.75),
	"road": Color(0.18, 0.12, 0.28),
	"road_stripe": Color(1.0, 0.95, 0.05),
	"road_lane": Color(1.0, 1.0, 1.0),
	"road_edge": Color(0.05, 1.0, 0.9),
	"roadside": Color(0.15, 0.85, 0.25),
	"roadside_alt": Color(0.55, 0.2, 0.95),
	"tree_trunk": Color(0.55, 0.28, 0.08),
	"tree_leaf": Color(0.1, 0.9, 0.2),
	"palm_leaf": Color(0.15, 1.0, 0.35),
	"pillar": Color(0.9, 0.9, 1.0),
	"obstacle": Color(1.0, 0.12, 0.18),
	"obstacle_accent": Color(1.0, 0.55, 0.0),
	"coin": Color(1.0, 0.92, 0.05),
	"boost": Color(0.05, 1.0, 0.45),
	"mushroom_cap": Color(1.0, 0.2, 0.5),
	"mushroom_stem": Color(1.0, 0.96, 0.88),
	"block": Color(0.15, 0.75, 1.0),
	"neon": Color(0.35, 1.0, 0.2),
	"outline": Color(0.04, 0.01, 0.1, 1.0),
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
	mat.roughness = float(opts.get("roughness", 0.68))
	mat.metallic = float(opts.get("metallic", 0.0))
	# Tiny default fill so unlit meshes stay readable without washing the scene.
	var base_glow := float(opts.get("base_glow", 0.02))
	var em_str := float(opts.get("emission_strength", 0.0))
	var em_col: Color = opts.get("emission_color", albedo)
	if em_str > 0.0:
		mat.emission_enabled = true
		mat.emission = em_col
		mat.emission_energy_multiplier = em_str + base_glow * 0.15
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
