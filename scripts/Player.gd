extends CharacterBody3D

const LANE_WIDTH := 3.0
const BASE_FORWARD_SPEED := 15.0
const BOOST_SPEED := 25.0
const LANE_SWITCH_SPEED := 12.0
const JUMP_FORCE := 8.0
const GRAVITY := 20.0
const SPEED_LINE_THRESHOLD := 20.0

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

	# Build anime rider + bike under Visual; hide greybox only after meshes exist.
	if mesh_instance:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(1.0, 0.45, 0.85)
		fallback.emission_enabled = true
		fallback.emission = Color(1.0, 0.45, 0.85)
		fallback.emission_energy_multiplier = 0.25
		mesh_instance.material_override = fallback

	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)

	var is_maya := GameManager.selected_character == "Maya"
	var skin: Color = StyleKit.PALETTE["maya_skin"] if is_maya else StyleKit.PALETTE["jax_skin"]
	var hair: Color = StyleKit.PALETTE["maya_hair"] if is_maya else StyleKit.PALETTE["jax_hair"]
	var hair_dark: Color = StyleKit.PALETTE["maya_hair_dark"] if is_maya else StyleKit.PALETTE["jax_hair_dark"]
	var bike: Color = StyleKit.PALETTE["maya_bike"] if is_maya else StyleKit.PALETTE["jax_bike"]
	var bike_accent: Color = StyleKit.PALETTE["maya_bike_accent"] if is_maya else StyleKit.PALETTE["jax_bike_accent"]
	var iris: Color = StyleKit.PALETTE["eye_iris_maya"] if is_maya else StyleKit.PALETTE["eye_iris_jax"]

	# Body
	_add_mesh(visual_root, _capsule(0.38, 1.15), Vector3(0, 0.95, 0), skin, {"outline_width": 0.04})

	# Oversized anime eyes (white + iris + pupil)
	for side in [-1, 1]:
		var eye_anchor := Node3D.new()
		eye_anchor.position = Vector3(side * 0.22, 1.35, -0.32)
		visual_root.add_child(eye_anchor)
		_add_mesh(eye_anchor, _sphere(0.16), Vector3.ZERO, StyleKit.PALETTE["eye_white"], {
			"outline_width": 0.02, "rim_amount": 0.15, "shade_threshold": 0.6
		})
		_add_mesh(eye_anchor, _sphere(0.095), Vector3(0, -0.01, -0.08), iris, {
			"outline_width": 0.0, "emission_strength": 0.35, "emission_color": iris
		})
		_add_mesh(eye_anchor, _sphere(0.045), Vector3(0, -0.015, -0.12), StyleKit.PALETTE["eye_pupil"], {
			"outline_width": 0.0, "rim_amount": 0.0
		})

	# Vibrant hair clumps
	_add_mesh(visual_root, _sphere(0.42), Vector3(0, 1.55, 0.05), hair, {
		"outline_width": 0.045, "rim_amount": 0.55, "emission_strength": 0.15, "emission_color": hair
	})
	_add_mesh(visual_root, _sphere(0.22), Vector3(-0.28, 1.5, 0.1), hair_dark, {"outline_width": 0.03})
	_add_mesh(visual_root, _sphere(0.22), Vector3(0.28, 1.5, 0.1), hair_dark, {"outline_width": 0.03})
	_add_mesh(visual_root, _sphere(0.18), Vector3(0, 1.7, -0.05), hair, {
		"outline_width": 0.025, "emission_strength": 0.2, "emission_color": hair
	})
	if is_maya:
		# Side bangs / twin poofs
		_add_mesh(visual_root, _sphere(0.16), Vector3(-0.35, 1.25, 0.05), hair, {"outline_width": 0.025})
		_add_mesh(visual_root, _sphere(0.16), Vector3(0.35, 1.25, 0.05), hair, {"outline_width": 0.025})
	else:
		# Spiky cyan tufts
		_add_mesh(visual_root, _box(Vector3(0.18, 0.35, 0.18)), Vector3(-0.2, 1.75, 0), hair, {"outline_width": 0.02})
		_add_mesh(visual_root, _box(Vector3(0.18, 0.4, 0.18)), Vector3(0.15, 1.8, 0.05), hair_dark, {"outline_width": 0.02})

	# Chunky colorful bike
	var bike_root := Node3D.new()
	bike_root.name = "Bike"
	bike_root.position = Vector3(0, 0.15, 0.15)
	visual_root.add_child(bike_root)
	_add_mesh(bike_root, _box(Vector3(0.7, 0.35, 1.4)), Vector3(0, 0.35, 0), bike, {
		"outline_width": 0.04, "rim_amount": 0.5, "emission_strength": 0.25, "emission_color": bike
	})
	_add_mesh(bike_root, _box(Vector3(0.85, 0.2, 0.55)), Vector3(0, 0.55, -0.35), bike_accent, {
		"outline_width": 0.03, "emission_strength": 0.4, "emission_color": bike_accent
	})
	# Wheels
	for wz in [-0.5, 0.55]:
		_add_mesh(bike_root, _cylinder(0.32, 0.14), Vector3(0, 0.32, wz), Color(0.12, 0.1, 0.2), {
			"outline_width": 0.025, "shade_color": Color(0.05, 0.05, 0.1)
		}).rotation_degrees.z = 90.0
	# Neon accent strip
	_add_mesh(bike_root, _box(Vector3(0.15, 0.08, 1.1)), Vector3(0, 0.2, 0), StyleKit.PALETTE["neon"], {
		"outline_width": 0.0, "emission_strength": 1.8, "emission_color": StyleKit.PALETTE["neon"], "rim_amount": 0.0
	})

	if mesh_instance:
		mesh_instance.visible = false

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
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual_root, "scale", scale_to, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(visual_root, "scale", Vector3.ONE, duration * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

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
		visual_root.scale = Vector3(1.15, 0.55, 1.15)
	elif mesh_instance:
		mesh_instance.scale.y = 0.5
	await get_tree().create_timer(0.8).timeout
	if collision_shape:
		collision_shape.scale.y = 1.0
		collision_shape.position.y = 0.0
	if visual_root:
		visual_root.scale = Vector3.ONE
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
