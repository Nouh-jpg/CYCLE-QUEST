extends CharacterBody3D

const LANE_WIDTH := 3.0
const BASE_FORWARD_SPEED := 15.0
const MAX_FORWARD_SPEED := 28.0
const SPEED_RAMP_PER_SEC := 0.32
const SPEED_PER_SCORE := 0.028
const BOOST_ADD := 8.0
const BOOST_DURATION := 2.6
const LANE_SWITCH_SPEED := 20.0
const JUMP_FORCE := 9.5
const GRAVITY := 24.0
const SPEED_LINE_THRESHOLD := 17.0
const VISUAL_SCALE := 0.9
const IDLE_BOB_AMP := 0.075
const IDLE_BOB_SPEED := 11.0
const LEAN_MAX_DEG := 28.0
const LEAN_LERP := 16.0
const WHEEL_RADIUS := 0.38
const COYOTE_TIME := 0.08
const JUMP_BUFFER := 0.08
const BASE_FOV := 72.0
const MAX_FOV := 84.0
const COIN_BASE_POINTS := 10
const NEAR_MISS_POINTS := 25
const BOOST_POINTS := 50
const COMBO_GAP := 1.35

var target_lane := 0 # -1 Left, 0 Center, 1 Right
var is_jumping := false
var is_sliding := false
var score := 0
var current_speed := BASE_FORWARD_SPEED
var distance_traveled := 0.0
var combo := 0
var _visuals_applied := false
var _was_on_floor := true
var _prev_lane := 0
var _squash_tween: Tween
var _anim_time := 0.0
var _lean_z := 0.0
var _jump_stretch := 0.0
var _run_time := 0.0
var _boost_timer := 0.0
var _coyote := 0.0
var _jump_buf := 0.0
var _combo_timer := 0.0
var _shake_amp := 0.0
var _cam_base_pos := Vector3(0.0, 4.5, 8.5)
var _start_z := 0.0
var _near_miss_cd := 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Camera3D

var visual_root: Node3D
var bike_root: Node3D
var wheel_nodes: Array[Node3D] = []
var speed_particles: GPUParticles3D
var dust_particles: GPUParticles3D
var sparkle_particles: GPUParticles3D

func _ready() -> void:
	_start_z = global_position.z
	_apply_character_visuals()
	_setup_particles()
	_setup_camera()

func _setup_camera() -> void:
	# Classic Genesis runner framing: centered behind, pulled back/up, wide FOV.
	if camera == null:
		return
	_cam_base_pos = Vector3(0.0, 4.5, 8.5)
	camera.position = _cam_base_pos
	camera.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	camera.fov = BASE_FOV
	camera.current = true

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
	# Simplified silhouette for readable Genesis-scale runner (bold, fewer parts).
	var hair_hi: Color = StyleKit.PALETTE["maya_hair_accent"]
	var outfit: Color = StyleKit.PALETTE["maya_outfit"]
	var skirt_col: Color = StyleKit.PALETTE["maya_skirt"]
	var black := Color(0.08, 0.06, 0.1)

	# Head
	_add_mesh(root, _sphere(0.36), Vector3(0, 1.52, -0.02), skin, {
		"outline_width": 0.045, "emission_strength": 0.08, "emission_color": skin, "base_glow": 0.02
	})
	_add_mesh(root, _box(Vector3(0.48, 0.38, 0.1)), Vector3(0, 1.45, -0.3), skin, {
		"outline_width": 0.03, "emission_strength": 0.12, "emission_color": skin, "base_glow": 0.02
	})
	# Eyes
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.15, 1.48, -0.34)
		root.add_child(eye)
		_add_mesh(eye, _sphere(0.13), Vector3.ZERO, StyleKit.PALETTE["eye_white"], {
			"outline_width": 0.02, "emission_strength": 0.2, "emission_color": Color(1, 1, 1)
		}).scale = Vector3(0.85, 1.15, 0.7)
		_add_mesh(eye, _sphere(0.08), Vector3(0, -0.01, -0.07), iris, {
			"outline_width": 0.0, "emission_strength": 0.3, "emission_color": iris
		})
		_add_mesh(eye, _sphere(0.035), Vector3(0, -0.012, -0.1), StyleKit.PALETTE["eye_pupil"], {
			"outline_width": 0.0
		})

	# Crimson hair mass — chunky silhouette, not micro-detail
	_add_mesh(root, _sphere(0.44), Vector3(0, 1.72, 0.02), hair, {
		"outline_width": 0.06, "emission_strength": 0.55, "emission_color": hair, "base_glow": 0.1
	})
	_add_mesh(root, _sphere(0.16), Vector3(-0.14, 1.68, -0.26), hair, {
		"outline_width": 0.03, "emission_strength": 0.35, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.16), Vector3(0.14, 1.68, -0.26), hair, {
		"outline_width": 0.03, "emission_strength": 0.35, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.18), Vector3(-0.38, 1.45, 0.0), hair, {
		"outline_width": 0.03, "emission_strength": 0.32, "emission_color": hair
	})
	_add_mesh(root, _sphere(0.18), Vector3(0.38, 1.45, 0.0), hair, {
		"outline_width": 0.03, "emission_strength": 0.32, "emission_color": hair
	})
	# Rear volume + twin tails
	_add_mesh(root, _sphere(0.52), Vector3(0, 1.48, 0.4), hair, {
		"outline_width": 0.06, "emission_strength": 0.6, "emission_color": hair, "base_glow": 0.12
	})
	_add_mesh(root, _sphere(0.36), Vector3(0, 1.15, 0.52), hair_dark, {
		"outline_width": 0.045, "emission_strength": 0.35, "emission_color": hair_dark
	})
	for side in [-1.0, 1.0]:
		_add_mesh(root, _capsule(0.11, 0.65), Vector3(side * 0.36, 0.7, 0.55), hair, {
			"outline_width": 0.03, "emission_strength": 0.38, "emission_color": hair
		}).rotation_degrees = Vector3(18.0, 0.0, side * -14.0)
		_add_mesh(root, _sphere(0.1), Vector3(side * 0.48, 0.22, 0.48), hair_hi, {
			"outline_width": 0.02, "emission_strength": 0.45, "emission_color": hair_hi
		})

	# Body
	_add_mesh(root, _box(Vector3(0.52, 0.5, 0.3)), Vector3(0, 1.02, 0.02), outfit, {
		"outline_width": 0.04, "emission_strength": 0.06, "emission_color": outfit, "base_glow": 0.02
	})
	_add_mesh(root, _box(Vector3(0.18, 0.42, 0.32)), Vector3(0, 1.02, -0.01), skirt_col, {
		"outline_width": 0.02, "emission_strength": 0.2, "emission_color": skirt_col
	})
	_add_mesh(root, _box(Vector3(0.68, 0.26, 0.4)), Vector3(0, 0.7, 0.05), skirt_col, {
		"outline_width": 0.04, "emission_strength": 0.18, "emission_color": skirt_col, "base_glow": 0.03
	})
	for side in [-1.0, 1.0]:
		_add_mesh(root, _capsule(0.085, 0.4), Vector3(side * 0.4, 1.02, -0.1), outfit, {
			"outline_width": 0.025, "emission_strength": 0.06, "emission_color": outfit
		}).rotation_degrees = Vector3(55.0, 0.0, side * 25.0)
		_add_mesh(root, _capsule(0.09, 0.36), Vector3(side * 0.15, 0.4, 0.05), black, {
			"outline_width": 0.025, "emission_strength": 0.05, "emission_color": black
		}).rotation_degrees = Vector3(70.0, 0.0, side * 8.0)

	_build_bike(root, bike, bike_accent, true)

func _build_jax(root: Node3D, skin: Color, hair: Color, hair_dark: Color, bike: Color, bike_accent: Color, iris: Color) -> void:
	_add_mesh(root, _capsule(0.36, 1.1), Vector3(0, 0.92, 0), skin, {
		"outline_width": 0.04, "emission_strength": 0.1, "emission_color": skin, "base_glow": 0.02
	})
	_add_mesh(root, _box(Vector3(0.48, 0.38, 0.1)), Vector3(0, 1.32, -0.28), skin, {
		"outline_width": 0.025, "emission_strength": 0.12, "emission_color": skin
	})
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.17, 1.32, -0.32)
		root.add_child(eye)
		_add_mesh(eye, _sphere(0.11), Vector3.ZERO, StyleKit.PALETTE["eye_white"], {
			"outline_width": 0.015, "emission_strength": 0.18, "emission_color": Color(1, 1, 1)
		})
		_add_mesh(eye, _sphere(0.065), Vector3(0, -0.01, -0.07), iris, {
			"outline_width": 0.0, "emission_strength": 0.25, "emission_color": iris
		})
	_add_mesh(root, _sphere(0.4), Vector3(0, 1.52, 0.05), hair, {
		"outline_width": 0.05, "emission_strength": 0.35, "emission_color": hair, "base_glow": 0.06
	})
	_add_mesh(root, _sphere(0.44), Vector3(0, 1.35, 0.36), hair, {
		"outline_width": 0.05, "emission_strength": 0.38, "emission_color": hair
	})
	_add_mesh(root, _box(Vector3(0.2, 0.4, 0.18)), Vector3(-0.18, 1.78, 0.05), hair, {
		"outline_width": 0.02, "emission_strength": 0.25, "emission_color": hair
	})
	_add_mesh(root, _box(Vector3(0.2, 0.46, 0.18)), Vector3(0.16, 1.84, 0.08), hair_dark, {
		"outline_width": 0.02, "emission_strength": 0.25, "emission_color": hair_dark
	})
	_add_mesh(root, _box(Vector3(0.52, 0.48, 0.28)), Vector3(0, 0.92, 0.02), Color(0.1, 0.25, 0.4), {
		"outline_width": 0.035, "emission_strength": 0.1, "emission_color": Color(0.1, 0.35, 0.55)
	})
	_build_bike(root, bike, bike_accent, false)

func _build_bike(root: Node3D, bike: Color, bike_accent: Color, is_maya: bool) -> void:
	bike_root = Node3D.new()
	bike_root.name = "Bike"
	bike_root.position = Vector3(0, 0.1, 0.12)
	root.add_child(bike_root)
	_add_mesh(bike_root, _box(Vector3(0.85, 0.36, 1.55)), Vector3(0, 0.34, 0), bike, {
		"outline_width": 0.05, "emission_strength": 0.25, "emission_color": bike, "base_glow": 0.04
	})
	_add_mesh(bike_root, _box(Vector3(0.9, 0.26, 0.5)), Vector3(0, 0.52, -0.42), bike_accent, {
		"outline_width": 0.035, "emission_strength": 0.35, "emission_color": bike_accent
	})
	_add_mesh(bike_root, _box(Vector3(0.8, 0.08, 0.08)), Vector3(0, 0.74, -0.32), Color(0.1, 0.08, 0.12), {
		"outline_width": 0.02, "emission_strength": 0.05, "emission_color": Color(0.2, 0.15, 0.25)
	})
	_add_mesh(bike_root, _box(Vector3(0.72, 0.24, 0.46)), Vector3(0, 0.46, 0.55), bike_accent, {
		"outline_width": 0.03, "emission_strength": 0.35, "emission_color": bike_accent
	})
	for side in [-1.0, 1.0]:
		var panel_col := Color(0.08, 0.06, 0.1) if is_maya else Color(0.05, 0.2, 0.3)
		_add_mesh(bike_root, _box(Vector3(0.08, 0.26, 1.0)), Vector3(side * 0.46, 0.36, 0.05), panel_col, {
			"outline_width": 0.02, "emission_strength": 0.08, "emission_color": panel_col
		})
	# Wheels as spin hubs (rotate local X while rolling along -Z)
	wheel_nodes.clear()
	for wz in [-0.55, 0.58]:
		var hub := Node3D.new()
		hub.name = "Wheel"
		hub.position = Vector3(0, 0.32, wz)
		bike_root.add_child(hub)
		_add_mesh(hub, _cylinder(WHEEL_RADIUS, 0.15), Vector3.ZERO, Color(0.12, 0.1, 0.16), {
			"outline_width": 0.03, "emission_strength": 0.08, "emission_color": Color(0.35, 0.2, 0.4)
		}).rotation_degrees.z = 90.0
		_add_mesh(hub, _cylinder(0.13, 0.17), Vector3.ZERO, bike_accent, {
			"outline_width": 0.0, "emission_strength": 0.35, "emission_color": bike_accent
		}).rotation_degrees.z = 90.0
		# Spoke mark so spin reads
		_add_mesh(hub, _box(Vector3(0.04, WHEEL_RADIUS * 1.6, 0.04)), Vector3.ZERO, Color(0.85, 0.85, 0.9), {
			"outline_width": 0.0, "emission_strength": 0.12, "emission_color": Color(0.85, 0.85, 0.9)
		})
		wheel_nodes.append(hub)
	var neon: Color = StyleKit.PALETTE["neon"] if not is_maya else Color(1.0, 0.35, 0.55)
	_add_mesh(bike_root, _box(Vector3(0.18, 0.07, 1.2)), Vector3(0, 0.16, 0), neon, {
		"outline_width": 0.0, "emission_strength": 0.65, "emission_color": neon, "rim_amount": 0.0
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
	m.radial_segments = 10
	m.rings = 6
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
	m.radial_segments = 10
	return m

func _setup_particles() -> void:
	speed_particles = _make_particle_node("SpeedLines", Color(0.7, 0.95, 1.0, 0.7), 36, 0.32)
	speed_particles.position = Vector3(0, 0.8, 1.2)
	speed_particles.emitting = false
	var speed_mat := ParticleProcessMaterial.new()
	speed_mat.direction = Vector3(0, 0, 1)
	speed_mat.spread = 12.0
	speed_mat.initial_velocity_min = 6.0
	speed_mat.initial_velocity_max = 14.0
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

	_run_time += delta
	_near_miss_cd = maxf(0.0, _near_miss_cd - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0 and combo > 0:
		combo = 0
		_notify_combo()

	# Speed ramp: smooth rise with time + score, boost spikes on top, hard cap
	var ramp := BASE_FORWARD_SPEED + _run_time * SPEED_RAMP_PER_SEC + float(score) * SPEED_PER_SCORE
	ramp = minf(ramp, MAX_FORWARD_SPEED)
	if _boost_timer > 0.0:
		_boost_timer -= delta
		current_speed = minf(ramp + BOOST_ADD, MAX_FORWARD_SPEED + 2.0)
	else:
		current_speed = ramp

	# Forward movement (world -Z)
	velocity.z = -current_speed
	distance_traveled = maxf(distance_traveled, _start_z - global_position.z)

	# Snappy lane switching
	var target_x := target_lane * LANE_WIDTH
	velocity.x = (target_x - global_position.x) * LANE_SWITCH_SPEED

	# Gravity / jump with coyote + buffer
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		is_jumping = false
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		_jump_buf = JUMP_BUFFER
	else:
		_jump_buf = maxf(0.0, _jump_buf - delta)

	if _jump_buf > 0.0 and _coyote > 0.0 and not is_sliding:
		velocity.y = JUMP_FORCE
		is_jumping = true
		_jump_buf = 0.0
		_coyote = 0.0
		_jump_stretch = 1.0
		_play_squash(Vector3(0.78, 1.35, 0.78), 0.08)

	# Land squash
	if on_floor and not _was_on_floor:
		_jump_stretch = 0.0
		_play_squash(Vector3(1.3, 0.65, 1.3), 0.1)
	_was_on_floor = on_floor

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

	_update_speed_feel(delta)

	if speed_particles:
		speed_particles.emitting = current_speed >= SPEED_LINE_THRESHOLD

func _update_speed_feel(delta: float) -> void:
	if camera == null:
		return
	# FOV punch scales with speed; shake decays
	var t := clampf((current_speed - BASE_FORWARD_SPEED) / (MAX_FORWARD_SPEED - BASE_FORWARD_SPEED), 0.0, 1.0)
	var want_fov := lerpf(BASE_FOV, MAX_FOV, t)
	if _boost_timer > 0.0:
		want_fov += 3.0
	camera.fov = lerpf(camera.fov, want_fov, clampf(8.0 * delta, 0.0, 1.0))
	_shake_amp = maxf(0.0, _shake_amp - delta * 9.0)
	var shake := Vector3.ZERO
	if _shake_amp > 0.01:
		shake = Vector3(
			randf_range(-1, 1) * _shake_amp,
			randf_range(-1, 1) * _shake_amp * 0.6,
			0.0
		)
	camera.position = _cam_base_pos + shake
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_speed"):
		ui.update_speed(current_speed, MAX_FORWARD_SPEED)

func _process(delta: float) -> void:
	if visual_root == null or GameManager.is_game_over:
		return
	_anim_time += delta
	_update_ride_anim(delta)

func _update_ride_anim(delta: float) -> void:
	# Target lean toward destination lane
	var target_x := float(target_lane) * LANE_WIDTH
	var dx := target_x - global_position.x
	var lean_target := clampf(-dx * 7.5, -LEAN_MAX_DEG, LEAN_MAX_DEG)
	if is_sliding:
		lean_target *= 0.35
	_lean_z = lerpf(_lean_z, lean_target, clampf(LEAN_LERP * delta, 0.0, 1.0))

	# Idle bob + slight pitch (suppressed in air / slide) — stronger for readable motion
	var bob := 0.0
	var pitch := 0.0
	if is_on_floor() and not is_sliding:
		bob = sin(_anim_time * IDLE_BOB_SPEED) * IDLE_BOB_AMP
		pitch = sin(_anim_time * IDLE_BOB_SPEED) * 5.5
	elif is_jumping or not is_on_floor():
		pitch = -10.0
		_jump_stretch = maxf(0.0, _jump_stretch - delta * 2.5)

	visual_root.position.y = bob
	visual_root.rotation_degrees = Vector3(pitch, 0.0, _lean_z)

	# Wheel spin ∝ speed (rad/s = v / r); local X while tire faces sideways
	var spin_rad := (current_speed / WHEEL_RADIUS) * delta * 1.15
	for w in wheel_nodes:
		if is_instance_valid(w):
			w.rotate_x(spin_rad)

func _play_squash(scale_to: Vector3, duration: float) -> void:
	if visual_root == null:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	var base := Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual_root, "scale", scale_to * VISUAL_SCALE, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(visual_root, "scale", base, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

func add_shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp, amount)

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
	combo += 1
	_combo_timer = COMBO_GAP
	var mult := mini(combo, 8)
	var pts := COIN_BASE_POINTS * mult
	score += pts
	_burst_sparkle()
	_notify_score()
	_notify_combo()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("popup_points"):
		var label := "+%d" % pts
		if combo >= 2:
			label = "+%d  x%d" % [pts, mult]
		ui.popup_points(label, Color(1.0, 0.92, 0.2))

func register_near_miss() -> void:
	if GameManager.is_game_over or _near_miss_cd > 0.0:
		return
	_near_miss_cd = 0.45
	score += NEAR_MISS_POINTS
	add_shake(0.22)
	_notify_score()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("popup_points"):
		ui.popup_points("CLOSE! +%d" % NEAR_MISS_POINTS, Color(1.0, 0.45, 0.85))
	if ui and ui.has_method("flash_near_miss"):
		ui.flash_near_miss()

func on_crash() -> void:
	add_shake(0.55)
	combo = 0
	_combo_timer = 0.0

func apply_boost() -> void:
	if GameManager.is_game_over:
		return
	_boost_timer = BOOST_DURATION
	score += BOOST_POINTS
	combo = max(combo, 1)
	_combo_timer = COMBO_GAP
	add_shake(0.18)
	_play_squash(Vector3(0.7, 1.4, 0.7), 0.15)
	_burst_dust()
	_notify_score()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("popup_points"):
		ui.popup_points("BOOST! +%d" % BOOST_POINTS, Color(0.35, 1.0, 0.55))

func _notify_score() -> void:
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_score"):
		ui.update_score(score)

func _notify_combo() -> void:
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_combo"):
		ui.update_combo(combo)
