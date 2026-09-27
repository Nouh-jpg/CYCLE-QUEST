extends CharacterBody3D

const LANE_WIDTH := 3.0
const BASE_FORWARD_SPEED := 15.0
const BOOST_SPEED := 25.0
const LANE_SWITCH_SPEED := 12.0
const JUMP_FORCE := 8.0
const GRAVITY := 20.0
const SPEED_LINE_THRESHOLD := 20.0
const VISUAL_SCALE := 1.65

var target_lane := 0 # -1 Left, 0 Center, 1 Right
var is_jumping := false
var is_sliding := false
var score := 0
var current_speed := BASE_FORWARD_SPEED
var _visuals_applied := false
var _was_on_floor := true
var _prev_lane := 0
var _squash_tween: Tween

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var visual_root: Node3D
var speed_particles: GPUParticles3D
var dust_particles: GPUParticles3D
var sparkle_particles: GPUParticles3D

func _ready() -> void:
	_apply_character_visuals()
	_setup_particles()

func _apply_character_visuals() -> void:
	if _visuals_applied:
		return
	_visuals_applied = true

	# Hide stock capsule — detailed mesh hierarchy is the silhouette now.
	if mesh_instance:
		mesh_instance.visible = false

	visual_root = Node3D.new()
	visual_root.name = "Visual"
	visual_root.scale = Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
	add_child(visual_root)

	var is_maya := GameManager.selected_character == "Maya"
	var skin: Color = StyleKit.PALETTE["maya_skin"] if is_maya else StyleKit.PALETTE["jax_skin"]
	var hair: Color = StyleKit.PALETTE["maya_hair"] if is_maya else StyleKit.PALETTE["jax_hair"]
	var hair_dark: Color = StyleKit.PALETTE["maya_hair_dark"] if is_maya else StyleKit.PALETTE["jax_hair_dark"]
	var bike: Color = StyleKit.PALETTE["maya_bike"] if is_maya else StyleKit.PALETTE["jax_bike"]
	var bike_accent: Color = StyleKit.PALETTE["maya_bike_accent"] if is_maya else StyleKit.PALETTE["jax_bike_accent"]
	var iris: Color = StyleKit.PALETTE["eye_iris_maya"] if is_maya else StyleKit.PALETTE["eye_iris_jax"]

	if is_maya:
		_build_maya(visual_root, skin, hair, hair_dark, bike, bike_accent, iris)
	else:
		_build_jax(visual_root, skin, hair, hair_dark, bike, bike_accent, iris)

func _build_maya(root: Node3D, skin: Color, hair: Color, hair_dark: Color, bike: Color, bike_accent: Color, iris: Color) -> void:
	var hair_hi: Color = StyleKit.PALETTE["maya_hair_accent"]
	var outfit: Color = StyleKit.PALETTE["maya_outfit"]
	var skirt_col: Color = StyleKit.PALETTE["maya_skirt"]
	var black := Color(0.08, 0.06, 0.1)

	# --- Head ---
	_add_mesh(root, _sphere(0.38), Vector3(0, 1.55, -0.02), skin, {
		"outline_width": 0.04, "emission_strength": 0.28, "emission_color": skin, "base_glow": 0.18
	})
	# Face plate (-Z forward) for cheek / eye read from 3/4
	_add_mesh(root, _box(Vector3(0.52, 0.42, 0.1)), Vector3(0, 1.48, -0.32), skin, {
		"outline_width": 0.025, "emission_strength": 0.45, "emission_color": skin, "base_glow": 0.15
	})
	# Soft cheek blush
	_add_mesh(root, _sphere(0.07), Vector3(-0.22, 1.38, -0.34), Color(1.0, 0.55, 0.6), {
		"outline_width": 0.0, "emission_strength": 0.35, "emission_color": Color(1.0, 0.55, 0.6)
	})
	_add_mesh(root, _sphere(0.07), Vector3(0.22, 1.38, -0.34), Color(1.0, 0.55, 0.6), {
		"outline_width": 0.0, "emission_strength": 0.35, "emission_color": Color(1.0, 0.55, 0.6)
	})
	# Small mouth
	_add_mesh(root, _box(Vector3(0.1, 0.035, 0.04)), Vector3(0, 1.28, -0.36), Color(0.85, 0.25, 0.35), {
		"outline_width": 0.0, "emission_strength": 0.25, "emission_color": Color(0.85, 0.25, 0.35)
	})

	# Oversized anime eyes facing -Z
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.16, 1.5, -0.36)
		root.add_child(eye)
		_add_mesh(eye, _sphere(0.14), Vector3.ZERO, StyleKit.PALETTE["eye_white"], {
			"outline_width": 0.018, "emission_strength": 0.5, "emission_color": Color(1, 1, 1)
		}).scale = Vector3(0.85, 1.15, 0.7)
		_add_mesh(eye, _sphere(0.085), Vector3(0, -0.01, -0.07), iris, {
			"outline_width": 0.0, "emission_strength": 0.7, "emission_color": iris
		})
		_add_mesh(eye, _sphere(0.04), Vector3(0, -0.015, -0.11), StyleKit.PALETTE["eye_pupil"], {
			"outline_width": 0.0
		})
		# Eye highlight
		_add_mesh(eye, _sphere(0.028), Vector3(side * -0.03, 0.035, -0.1), Color(1, 1, 1), {
			"outline_width": 0.0, "emission_strength": 1.2, "emission_color": Color(1, 1, 1)
		})

	# --- Hair (main feature): huge crimson volume ---
	# Crown / top dome
	_add_mesh(root, _sphere(0.46), Vector3(0, 1.78, 0.02), hair, {
		"outline_width": 0.055, "rim_amount": 0.6, "emission_strength": 0.95, "emission_color": hair, "base_glow": 0.3
	})
	# Forehead bangs (front fringe, readable from 3/4)
	_add_mesh(root, _sphere(0.18), Vector3(-0.12, 1.72, -0.28), hair, {
		"outline_width": 0.03, "emission_strength": 0.9, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.18), Vector3(0.12, 1.72, -0.28), hair, {
		"outline_width": 0.03, "emission_strength": 0.9, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.14), Vector3(0, 1.62, -0.34), hair_hi, {
		"outline_width": 0.02, "emission_strength": 1.0, "emission_color": hair_hi
	})
	# Side bangs / cheek curtain
	_add_mesh(root, _sphere(0.2), Vector3(-0.4, 1.5, -0.05), hair, {
		"outline_width": 0.03, "emission_strength": 0.85, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.2), Vector3(0.4, 1.5, -0.05), hair, {
		"outline_width": 0.03, "emission_strength": 0.85, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.16), Vector3(-0.42, 1.28, 0.0), hair_dark, {
		"outline_width": 0.025, "emission_strength": 0.7, "emission_color": hair_dark
	})
	_add_mesh(root, _sphere(0.16), Vector3(0.42, 1.28, 0.0), hair_dark, {
		"outline_width": 0.025, "emission_strength": 0.7, "emission_color": hair_dark
	})

	# Massive rear hair volume (chase cam sits on +Z looking -Z)
	_add_mesh(root, _sphere(0.58), Vector3(0, 1.55, 0.42), hair, {
		"outline_width": 0.06, "emission_strength": 1.15, "emission_color": hair, "base_glow": 0.35
	})
	_add_mesh(root, _sphere(0.42), Vector3(0, 1.25, 0.55), hair_dark, {
		"outline_width": 0.05, "emission_strength": 0.95, "emission_color": hair_dark, "base_glow": 0.25
	})
	_add_mesh(root, _box(Vector3(0.7, 0.85, 0.35)), Vector3(0, 1.2, 0.5), hair, {
		"outline_width": 0.045, "emission_strength": 1.0, "emission_color": hair
	})
	# Long flowing back ribbons / twin tails
	for side in [-1.0, 1.0]:
		_add_mesh(root, _sphere(0.22), Vector3(side * 0.32, 1.15, 0.62), hair, {
			"outline_width": 0.035, "emission_strength": 1.05, "emission_color": hair
		})
		_add_mesh(root, _capsule(0.12, 0.7), Vector3(side * 0.38, 0.75, 0.58), hair, {
			"outline_width": 0.03, "emission_strength": 0.95, "emission_color": hair
		}).rotation_degrees = Vector3(18.0, 0.0, side * -12.0)
		_add_mesh(root, _capsule(0.1, 0.55), Vector3(side * 0.45, 0.4, 0.52), hair_dark, {
			"outline_width": 0.025, "emission_strength": 0.85, "emission_color": hair_dark
		}).rotation_degrees = Vector3(22.0, 0.0, side * -18.0)
		# Tip sparkle accent
		_add_mesh(root, _sphere(0.1), Vector3(side * 0.5, 0.18, 0.48), hair_hi, {
			"outline_width": 0.02, "emission_strength": 1.2, "emission_color": hair_hi
		})
	# Extra mid-back cascade for silhouette thickness
	_add_mesh(root, _capsule(0.18, 0.9), Vector3(0, 0.85, 0.65), hair, {
		"outline_width": 0.04, "emission_strength": 1.0, "emission_color": hair
	}).rotation_degrees = Vector3(25.0, 0.0, 0.0)
	_add_mesh(root, _sphere(0.2), Vector3(0, 0.45, 0.72), hair_dark, {
		"outline_width": 0.03, "emission_strength": 0.9, "emission_color": hair_dark
	})

	# --- Body: jacket torso + skirt flare ---
	_add_mesh(root, _box(Vector3(0.55, 0.55, 0.32)), Vector3(0, 1.05, 0.02), outfit, {
		"outline_width": 0.04, "emission_strength": 0.2, "emission_color": outfit, "base_glow": 0.12
	})
	# Chest accent stripe (pink)
	_add_mesh(root, _box(Vector3(0.2, 0.45, 0.34)), Vector3(0, 1.05, -0.01), skirt_col, {
		"outline_width": 0.02, "emission_strength": 0.55, "emission_color": skirt_col
	})
	# Collar
	_add_mesh(root, _box(Vector3(0.5, 0.1, 0.28)), Vector3(0, 1.32, 0.0), black, {
		"outline_width": 0.02, "emission_strength": 0.15, "emission_color": black
	})
	# Skirt flare (reads as anime girl from behind)
	_add_mesh(root, _box(Vector3(0.72, 0.28, 0.42)), Vector3(0, 0.72, 0.05), skirt_col, {
		"outline_width": 0.04, "emission_strength": 0.5, "emission_color": skirt_col, "base_glow": 0.15
	})
	_add_mesh(root, _box(Vector3(0.85, 0.12, 0.5)), Vector3(0, 0.58, 0.08), hair, {
		"outline_width": 0.03, "emission_strength": 0.7, "emission_color": hair
	})

	# Arms (slightly forward for riding pose)
	for side in [-1.0, 1.0]:
		_add_mesh(root, _capsule(0.09, 0.45), Vector3(side * 0.42, 1.05, -0.12), outfit, {
			"outline_width": 0.025, "emission_strength": 0.18, "emission_color": outfit
		}).rotation_degrees = Vector3(55.0, 0.0, side * 25.0)
		_add_mesh(root, _sphere(0.09), Vector3(side * 0.48, 0.85, -0.28), skin, {
			"outline_width": 0.02, "emission_strength": 0.25, "emission_color": skin
		})

	# Legs / boots on bike
	for side in [-1.0, 1.0]:
		_add_mesh(root, _capsule(0.1, 0.4), Vector3(side * 0.16, 0.42, 0.05), black, {
			"outline_width": 0.025, "emission_strength": 0.15, "emission_color": black
		}).rotation_degrees = Vector3(70.0, 0.0, side * 8.0)
		_add_mesh(root, _box(Vector3(0.16, 0.12, 0.28)), Vector3(side * 0.18, 0.22, -0.12), black, {
			"outline_width": 0.02, "emission_strength": 0.2, "emission_color": black
		})

	_build_bike(root, bike, bike_accent, true)

func _build_jax(root: Node3D, skin: Color, hair: Color, hair_dark: Color, bike: Color, bike_accent: Color, iris: Color) -> void:
	# Simpler but still readable boy silhouette — not broken.
	_add_mesh(root, _capsule(0.38, 1.15), Vector3(0, 0.95, 0), skin, {
		"outline_width": 0.04, "emission_strength": 0.3, "emission_color": skin, "base_glow": 0.2
	})
	_add_mesh(root, _box(Vector3(0.5, 0.4, 0.1)), Vector3(0, 1.35, -0.28), skin, {
		"outline_width": 0.025, "emission_strength": 0.4, "emission_color": skin
	})
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.18, 1.35, -0.34)
		root.add_child(eye)
		_add_mesh(eye, _sphere(0.12), Vector3.ZERO, StyleKit.PALETTE["eye_white"], {
			"outline_width": 0.015, "emission_strength": 0.4, "emission_color": Color(1, 1, 1)
		})
		_add_mesh(eye, _sphere(0.07), Vector3(0, -0.01, -0.07), iris, {
			"outline_width": 0.0, "emission_strength": 0.55, "emission_color": iris
		})
		_add_mesh(eye, _sphere(0.035), Vector3(0, -0.012, -0.1), StyleKit.PALETTE["eye_pupil"], {
			"outline_width": 0.0
		})
	# Cyan hair mass + spikes
	_add_mesh(root, _sphere(0.42), Vector3(0, 1.55, 0.05), hair, {
		"outline_width": 0.045, "emission_strength": 0.7, "emission_color": hair, "base_glow": 0.2
	})
	_add_mesh(root, _sphere(0.48), Vector3(0, 1.4, 0.38), hair, {
		"outline_width": 0.05, "emission_strength": 0.85, "emission_color": hair
	})
	_add_mesh(root, _box(Vector3(0.22, 0.42, 0.2)), Vector3(-0.2, 1.82, 0.05), hair, {
		"outline_width": 0.02, "emission_strength": 0.6, "emission_color": hair
	})
	_add_mesh(root, _box(Vector3(0.22, 0.48, 0.2)), Vector3(0.18, 1.88, 0.1), hair_dark, {
		"outline_width": 0.02, "emission_strength": 0.6, "emission_color": hair_dark
	})
	_add_mesh(root, _box(Vector3(0.35, 0.55, 0.25)), Vector3(0, 1.55, 0.5), hair, {
		"outline_width": 0.03, "emission_strength": 0.8, "emission_color": hair
	})
	# Jacket torso hint
	_add_mesh(root, _box(Vector3(0.55, 0.5, 0.3)), Vector3(0, 0.95, 0.02), Color(0.1, 0.25, 0.4), {
		"outline_width": 0.035, "emission_strength": 0.25, "emission_color": Color(0.1, 0.35, 0.55)
	})
	_build_bike(root, bike, bike_accent, false)

func _build_bike(root: Node3D, bike: Color, bike_accent: Color, is_maya: bool) -> void:
	var bike_root := Node3D.new()
	bike_root.name = "Bike"
	bike_root.position = Vector3(0, 0.1, 0.12)
	root.add_child(bike_root)
	# Sleek chunky scooter body
	_add_mesh(bike_root, _box(Vector3(0.9, 0.38, 1.65)), Vector3(0, 0.36, 0), bike, {
		"outline_width": 0.045, "rim_amount": 0.5, "emission_strength": 0.65, "emission_color": bike, "base_glow": 0.22
	})
	# Front fairing / nose
	_add_mesh(bike_root, _box(Vector3(0.95, 0.28, 0.55)), Vector3(0, 0.55, -0.45), bike_accent, {
		"outline_width": 0.035, "emission_strength": 0.9, "emission_color": bike_accent
	})
	# Handlebar
	_add_mesh(bike_root, _box(Vector3(0.85, 0.08, 0.08)), Vector3(0, 0.78, -0.35), Color(0.1, 0.08, 0.12), {
		"outline_width": 0.02, "emission_strength": 0.15, "emission_color": Color(0.2, 0.15, 0.25)
	})
	# Rear fender / seat
	_add_mesh(bike_root, _box(Vector3(0.78, 0.26, 0.5)), Vector3(0, 0.48, 0.58), bike_accent, {
		"outline_width": 0.03, "emission_strength": 0.95, "emission_color": bike_accent
	})
	# Side panels
	for side in [-1.0, 1.0]:
		var panel_col := Color(0.08, 0.06, 0.1) if is_maya else Color(0.05, 0.2, 0.3)
		_add_mesh(bike_root, _box(Vector3(0.08, 0.28, 1.1)), Vector3(side * 0.48, 0.38, 0.05), panel_col, {
			"outline_width": 0.02, "emission_strength": 0.2, "emission_color": panel_col
		})
	# Wheels
	for wz in [-0.58, 0.62]:
		_add_mesh(bike_root, _cylinder(0.38, 0.16), Vector3(0, 0.34, wz), Color(0.1, 0.08, 0.14), {
			"outline_width": 0.028, "emission_strength": 0.2, "emission_color": Color(0.35, 0.2, 0.4)
		}).rotation_degrees.z = 90.0
		# Hub glow
		_add_mesh(bike_root, _cylinder(0.14, 0.18), Vector3(0, 0.34, wz), bike_accent, {
			"outline_width": 0.0, "emission_strength": 1.1, "emission_color": bike_accent
		}).rotation_degrees.z = 90.0
	# Neon underglow strip
	var neon: Color = StyleKit.PALETTE["neon"] if not is_maya else Color(1.0, 0.35, 0.55)
	_add_mesh(bike_root, _box(Vector3(0.2, 0.08, 1.3)), Vector3(0, 0.18, 0), neon, {
		"outline_width": 0.0, "emission_strength": 2.4, "emission_color": neon, "rim_amount": 0.0
	})

func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, opts: Dictionary = {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	StyleKit.apply_to_mesh(mi, color, opts)
	return mi

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m

func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 8
	return m

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	return m

func _setup_particles() -> void:
	speed_particles = _make_particle_node("SpeedLines", Color(0.7, 0.95, 1.0, 0.7), 24, 0.35)
	speed_particles.position = Vector3(0, 0.8, 1.2)
	speed_particles.emitting = false
	# Stretch along Z for speed lines
	var speed_mat := ParticleProcessMaterial.new()
	speed_mat.direction = Vector3(0, 0, 1)
	speed_mat.spread = 12.0
	speed_mat.initial_velocity_min = 4.0
	speed_mat.initial_velocity_max = 10.0
	speed_mat.gravity = Vector3.ZERO
	speed_mat.scale_min = 0.05
	speed_mat.scale_max = 0.12
	speed_mat.color = Color(0.75, 0.95, 1.0, 0.65)
	speed_particles.process_material = speed_mat
	var speed_mesh := BoxMesh.new()
	speed_mesh.size = Vector3(0.04, 0.04, 0.6)
	speed_particles.draw_pass_1 = speed_mesh

	dust_particles = _make_particle_node("LaneDust", Color(0.85, 0.7, 1.0, 0.8), 18, 0.4)
	dust_particles.position = Vector3(0, 0.1, 0.3)
	dust_particles.emitting = false
	dust_particles.one_shot = true
	dust_particles.explosiveness = 0.9
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0, 1, 0.3)
	dust_mat.spread = 60.0
	dust_mat.initial_velocity_min = 1.5
	dust_mat.initial_velocity_max = 3.5
	dust_mat.gravity = Vector3(0, -4, 0)
	dust_mat.scale_min = 0.08
	dust_mat.scale_max = 0.22
	dust_mat.color = Color(0.9, 0.75, 1.0, 0.75)
	dust_particles.process_material = dust_mat
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.12
	dust_mesh.height = 0.24
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 4
	dust_particles.draw_pass_1 = dust_mesh

	sparkle_particles = _make_particle_node("CoinSparkle", Color(1.0, 0.95, 0.3, 1.0), 28, 0.45)
	sparkle_particles.position = Vector3(0, 1.0, 0)
	sparkle_particles.emitting = false
	sparkle_particles.one_shot = true
	sparkle_particles.explosiveness = 1.0
	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.direction = Vector3(0, 1, 0)
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 2.0
	spark_mat.initial_velocity_max = 5.5
	spark_mat.gravity = Vector3(0, -6, 0)
	spark_mat.scale_min = 0.06
	spark_mat.scale_max = 0.16
	spark_mat.color = Color(1.0, 0.92, 0.25, 1.0)
	sparkle_particles.process_material = spark_mat
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.08
	spark_mesh.height = 0.16
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	sparkle_particles.draw_pass_1 = spark_mesh

func _make_particle_node(p_name: String, _color: Color, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = p_name
	p.amount = amount
	p.lifetime = lifetime
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 10))
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return

	# Forward movement (world -Z)
	velocity.z = -current_speed

	# Lane switching
	var target_x := target_lane * LANE_WIDTH
	velocity.x = (target_x - global_position.x) * LANE_SWITCH_SPEED

	# Gravity / jump
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= GRAVITY * delta
	else:
		is_jumping = false
		if velocity.y < 0.0:
			velocity.y = 0.0

	# Land squash
	if on_floor and not _was_on_floor:
		_play_squash(Vector3(1.25, 0.7, 1.25), 0.12)
	_was_on_floor = on_floor

	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and is_on_floor() and not is_sliding:
		velocity.y = JUMP_FORCE
		is_jumping = true
		_play_squash(Vector3(0.85, 1.25, 0.85), 0.1)

	var lane_changed := false
	if Input.is_action_just_pressed("ui_left"):
		target_lane = max(-1, target_lane - 1)
		lane_changed = true
	elif Input.is_action_just_pressed("ui_right"):
		target_lane = min(1, target_lane + 1)
		lane_changed = true

	if lane_changed and target_lane != _prev_lane:
		_burst_dust()
		_prev_lane = target_lane

	if Input.is_action_just_pressed("ui_down") and is_on_floor() and not is_sliding:
		_start_slide()

	move_and_slide()

	# Speed-line wind trail at high speed
	if speed_particles:
		speed_particles.emitting = current_speed >= SPEED_LINE_THRESHOLD

func _play_squash(scale_to: Vector3, duration: float) -> void:
	if visual_root == null:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	var base := Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual_root, "scale", scale_to * VISUAL_SCALE, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(visual_root, "scale", base, duration * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _burst_dust() -> void:
	if dust_particles == null:
		return
	dust_particles.restart()
	dust_particles.emitting = true

func _burst_sparkle() -> void:
	if sparkle_particles == null:
		return
	sparkle_particles.restart()
	sparkle_particles.emitting = true

func _start_slide() -> void:
	is_sliding = true
	if collision_shape:
		collision_shape.scale.y = 0.5
		collision_shape.position.y = -0.25
	if visual_root:
		visual_root.scale = Vector3(1.15, 0.55, 1.15) * VISUAL_SCALE
	elif mesh_instance:
		mesh_instance.scale.y = 0.5
	await get_tree().create_timer(0.8).timeout
	if collision_shape:
		collision_shape.scale.y = 1.0
		collision_shape.position.y = 0.0
	if visual_root:
		visual_root.scale = Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
	elif mesh_instance:
		mesh_instance.scale.y = 1.0
	is_sliding = false

func collect_coin() -> void:
	if GameManager.is_game_over:
		return
	score += 1
	_burst_sparkle()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_score"):
		ui.update_score(score)

func apply_boost() -> void:
	if GameManager.is_game_over:
		return
	current_speed = BOOST_SPEED
	_play_squash(Vector3(0.7, 1.4, 0.7), 0.18)
	_burst_dust()
	await get_tree().create_timer(3.0).timeout
	if not GameManager.is_game_over:
		current_speed = BASE_FORWARD_SPEED
