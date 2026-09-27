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
const SLIDE_DURATION := 0.7
const SLIDE_COOLDOWN := 0.28
## Short capsule kept on the same foot line as the standing hurtbox.
## World top stays under the cyan gate (Obstacle beam bottom 1.10).
const SLIDE_CAPSULE_HEIGHT := 0.68
const SLIDE_CAPSULE_RADIUS := 0.28
const BASE_FOV := 72.0
const MAX_FOV := 84.0
const COIN_BASE_POINTS := 10
const NEAR_MISS_POINTS := 25
const BOOST_POINTS := 50
const COMBO_GAP := 1.35
const SPRITE_TARGET_HEIGHT := 3.0
const MAYA_SPRITE_PATH := "res://assets/characters/maya_rider_rear.png"
const JAX_SPRITE_PATH := "res://assets/characters/jax_rider_rear.png"
# Wheel centers as fractions of the rear card (x from the left, y from the top).
const MAYA_REAR_WHEEL := Vector2(0.39, 0.86)
const MAYA_FRONT_WHEEL := Vector2(0.79, 0.66)
const JAX_REAR_WHEEL := Vector2(0.21, 0.84)
const JAX_FRONT_WHEEL := Vector2(0.87, 0.80)

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
var _slide_left := 0.0
var _slide_cd := 0.0
var _stand_height := 1.6
var _stand_radius := 0.45
var _stand_shape_y := 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Camera3D

var visual_root: Node3D
var bike_root: Node3D
var wheel_nodes: Array[Node3D] = []
var speed_particles: GPUParticles3D
var dust_particles: GPUParticles3D
var sparkle_particles: GPUParticles3D
var _rider_cards: Array[MeshInstance3D] = []

func _ready() -> void:
	_start_z = global_position.z
	_apply_character_visuals()
	_setup_particles()
	_setup_camera()
	_cache_stand_hurtbox()

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

	# Hide stock capsule — drawn sprite billboards are the silhouette now.
	if mesh_instance:
		mesh_instance.visible = false

	visual_root = Node3D.new()
	visual_root.name = "Visual"
	visual_root.scale = Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
	add_child(visual_root)

	bike_root = null
	wheel_nodes.clear()
	_rider_cards.clear()

	var is_maya := GameManager.selected_character == "Maya"
	if is_maya:
		_build_maya(visual_root)
	else:
		_build_jax(visual_root)

func _build_maya(root: Node3D) -> void:
	var spr := _make_rider_sprite(MAYA_SPRITE_PATH)
	if spr:
		root.add_child(spr)
		_build_rider_wheels(root, spr, MAYA_REAR_WHEEL, MAYA_FRONT_WHEEL, StyleKit.PALETTE["maya_bike_accent"])
	else:
		_build_maya_fallback(root)

func _build_jax(root: Node3D) -> void:
	var spr := _make_rider_sprite(JAX_SPRITE_PATH)
	if spr:
		root.add_child(spr)
		_build_rider_wheels(root, spr, JAX_REAR_WHEEL, JAX_FRONT_WHEEL, StyleKit.PALETTE["jax_bike_accent"])
	else:
		# Layer bike + rider if composite missing
		var bike_spr := _make_rider_sprite("res://assets/characters/bike_red.png", 1.6)
		var rider_spr := _make_rider_sprite("res://assets/characters/jax_rider.png", 1.9)
		if bike_spr:
			bike_spr.position.y = 0.55
			bike_spr.position.z = 0.02
			root.add_child(bike_spr)
		if rider_spr:
			rider_spr.position.y = 1.05
			rider_spr.position.z = -0.02
			root.add_child(rider_spr)
		if bike_spr == null and rider_spr == null:
			_build_jax_fallback(root)

func _load_rider_texture(path: String) -> Texture2D:
	# Decode the PNG bytes ourselves. ResourceLoader would return the imported
	# CompressedTexture2D, and a stale Windows .ctex / VRAM mip chain can
	# streak that into a one-pixel stick. No mipmaps are generated here.
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var img := Image.new()
		var err := img.load_png_from_buffer(bytes)
		if err == OK and img.get_width() >= 2 and img.get_height() >= 2:
			# Corrected rear PNGs are valid RGBA, but the studio plate is fully
			# opaque gray. Punch that out and crop so the 3 m card is the rider.
			img = _strip_studio_plate(img)
			if img.has_mipmaps():
				img.clear_mipmaps()
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null and imported.get_width() >= 2 and imported.get_height() >= 2:
			return imported
	push_warning("Missing rider texture: %s" % path)
	return null

func _is_studio_plate_byte(r: int, g: int, b: int, a: int) -> bool:
	if a < 250:
		return false
	var mx := maxi(r, maxi(g, b))
	var mn := mini(r, mini(g, b))
	return mx >= 176 and (mx - mn) <= 36

func _seed_plate(data: PackedByteArray, seen: PackedByteArray, qx: PackedInt32Array, qy: PackedInt32Array, cursor: Array, w: int, x: int, y: int) -> void:
	var idx := y * w + x
	if seen[idx] != 0:
		return
	var i := idx * 4
	if not _is_studio_plate_byte(int(data[i]), int(data[i + 1]), int(data[i + 2]), int(data[i + 3])):
		return
	seen[idx] = 1
	var n: int = int(cursor[0])
	qx[n] = x
	qy[n] = y
	cursor[0] = n + 1

func _strip_studio_plate(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var corner := img.get_pixel(0, 0)
	if corner.a < 0.98:
		return img
	if not _is_studio_plate_byte(int(corner.r * 255.0), int(corner.g * 255.0), int(corner.b * 255.0), int(corner.a * 255.0)):
		return img
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var qx := PackedInt32Array()
	var qy := PackedInt32Array()
	qx.resize(w * h)
	qy.resize(w * h)
	var cursor := [0]
	for x in w:
		_seed_plate(data, seen, qx, qy, cursor, w, x, 0)
		_seed_plate(data, seen, qx, qy, cursor, w, x, h - 1)
	for y in h:
		_seed_plate(data, seen, qx, qy, cursor, w, 0, y)
		_seed_plate(data, seen, qx, qy, cursor, w, w - 1, y)
	var qh := 0
	var qt: int = int(cursor[0])
	while qh < qt:
		var x: int = qx[qh]
		var y: int = qy[qh]
		qh += 1
		var i := (y * w + x) * 4
		data[i + 3] = 0
		if x > 0:
			_seed_plate(data, seen, qx, qy, cursor, w, x - 1, y)
		if x + 1 < w:
			_seed_plate(data, seen, qx, qy, cursor, w, x + 1, y)
		if y > 0:
			_seed_plate(data, seen, qx, qy, cursor, w, x, y - 1)
		if y + 1 < h:
			_seed_plate(data, seen, qx, qy, cursor, w, x, y + 1)
		qt = int(cursor[0])
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.set_data(w, h, false, Image.FORMAT_RGBA8, data)
	var used := out.get_used_rect()
	if used.size.x >= 2 and used.size.y >= 2 and (used.size.x < w or used.size.y < h):
		out = out.get_region(used)
	return out

func _make_rider_sprite(path: String, target_height: float = SPRITE_TARGET_HEIGHT) -> MeshInstance3D:
	var tex := _load_rider_texture(path)
	if tex == null:
		return null
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var quad := QuadMesh.new()
	# Front of the card is +Z. _face_riders_to_camera points that axis at the camera.
	quad.orientation = QuadMesh.FACE_Z
	quad.size = Vector2(target_height * aspect, target_height)
	var mi := MeshInstance3D.new()
	mi.name = "RiderSprite"
	mi.mesh = quad
	mi.position = Vector3(0.0, target_height * 0.5, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	# LINEAR is the base mip only. Do not use LINEAR_WITH_MIPMAPS: the PNG
	# dimensions are not multiples of 4, and a mip sample streaks on D3D12.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.texture_repeat = false
	mat.render_priority = 1
	mi.material_override = mat
	_rider_cards.append(mi)
	return mi

func _face_riders_to_camera() -> void:
	# Runs from _physics_process and _process. The _process call is last,
	# after visual_root lean/pitch, so the rendered frame cannot stay edge-on.
	# Camera3D is a child of this body, behind on local +Z. look_at(..., UP, true)
	# aims QuadMesh +Z at that camera and keeps world up (zero roll).
	if camera == null or _rider_cards.is_empty():
		return
	var cam_pos := camera.global_position
	for card in _rider_cards:
		if not is_instance_valid(card) or not card.is_inside_tree():
			continue
		if card.global_position.is_equal_approx(cam_pos):
			continue
		card.look_at(cam_pos, Vector3.UP, true)

func _build_rider_wheels(root: Node3D, card: MeshInstance3D, rear_uv: Vector2, front_uv: Vector2, accent: Color) -> void:
	var quad := card.mesh as QuadMesh
	if quad == null:
		return
	var size := quad.size
	# Rear ring is closer to the chase camera; the front ring is smaller and higher on the bike.
	# Parent is visual_root (not the card) so bob/lean still move the wheels while look_at owns the card.
	_add_spin_wheel(root, _wheel_spot(size, rear_uv, 0.1), size.y * 0.14, accent)
	_add_spin_wheel(root, _wheel_spot(size, front_uv, 0.05), size.y * 0.09, accent)

func _wheel_spot(card_size: Vector2, uv: Vector2, z_bias: float) -> Vector3:
	# Card bottom sits at y=0. uv.y is measured from the top of the drawing.
	return Vector3((uv.x - 0.5) * card_size.x, (1.0 - uv.y) * card_size.y, z_bias)

func _add_spin_wheel(parent: Node3D, pos: Vector3, radius: float, accent: Color) -> void:
	var hub := Node3D.new()
	hub.name = "Wheel"
	hub.position = pos
	# Identity orientation: local Z points at the chase camera. _update_ride_anim
	# spins with rotate_z so the ring turns in view instead of edge-on.
	parent.add_child(hub)

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.62
	torus.outer_radius = radius
	torus.rings = 8
	torus.ring_segments = 24
	ring.mesh = torus
	# TorusMesh lies in XZ (axis Y). Pitch it into the XY plane so it faces the camera.
	ring.rotation_degrees.x = 90.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.add_child(ring)
	StyleKit.apply_to_mesh(ring, Color(0.08, 0.08, 0.1), {
		"outline_width": 0.012,
		"emission_strength": 0.15,
		"emission_color": Color(0.45, 0.45, 0.5),
	})

	# Three narrow crossed spokes read as a spinning wheel instead of a single wobbling paddle.
	for spoke_index in range(3):
		var spoke := MeshInstance3D.new()
		spoke.name = "Spoke%d" % spoke_index
		var bar := BoxMesh.new()
		bar.size = Vector3(radius * 0.075, radius * 1.62, radius * 0.10)
		spoke.mesh = bar
		spoke.position = Vector3(0.0, 0.0, radius * 0.08)
		spoke.rotation_degrees.z = float(spoke_index) * 60.0
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hub.add_child(spoke)
		StyleKit.apply_to_mesh(spoke, Color(0.55, 0.61, 0.72), {
			"outline_width": 0.0,
			"emission_strength": 0.16,
			"emission_color": accent,
		})
	var axle := MeshInstance3D.new()
	axle.name = "Axle"
	var axle_mesh := CylinderMesh.new()
	axle_mesh.top_radius = radius * 0.12
	axle_mesh.bottom_radius = radius * 0.12
	axle_mesh.height = radius * 0.16
	axle_mesh.radial_segments = 12
	axle.mesh = axle_mesh
	axle.rotation_degrees.x = 90.0
	axle.position.z = radius * 0.1
	hub.add_child(axle)
	StyleKit.apply_to_mesh(axle, accent, {"outline_width": 0.0, "emission_strength": 0.25})

	wheel_nodes.append(hub)

func _build_maya_fallback(root: Node3D) -> void:
	var skin: Color = StyleKit.PALETTE["maya_skin"]
	var hair: Color = StyleKit.PALETTE["maya_hair"]
	_add_mesh(root, _capsule(0.28, 1.2), Vector3(0, 0.9, 0), skin, {
		"outline_width": 0.04, "emission_strength": 0.1, "emission_color": skin
	})
	_add_mesh(root, _sphere(0.32), Vector3(0, 1.55, 0), hair, {
		"outline_width": 0.05, "emission_strength": 0.4, "emission_color": hair
	})

func _build_jax_fallback(root: Node3D) -> void:
	var skin: Color = StyleKit.PALETTE["jax_skin"]
	var hair: Color = StyleKit.PALETTE["jax_hair"]
	_add_mesh(root, _capsule(0.3, 1.15), Vector3(0, 0.9, 0), skin, {
		"outline_width": 0.04, "emission_strength": 0.1, "emission_color": skin
	})
	_add_mesh(root, _sphere(0.34), Vector3(0, 1.5, 0), hair, {
		"outline_width": 0.05, "emission_strength": 0.35, "emission_color": hair
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
		_face_riders_to_camera()
		return

	_run_time += delta
	_near_miss_cd = maxf(0.0, _near_miss_cd - delta)
	_slide_cd = maxf(0.0, _slide_cd - delta)
	if is_sliding:
		_slide_left -= delta
		if _slide_left <= 0.0:
			_end_slide()
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
		_sfx("jump")

	# Land squash
	if on_floor and not _was_on_floor and not is_sliding:
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
		_sfx("lane")
		_prev_lane = target_lane

	# Keyboard (S / Down) and the touch SLIDE button both emit ui_down.
	if Input.is_action_just_pressed("ui_down") and is_on_floor() and not is_sliding and not is_jumping and _slide_cd <= 0.0:
		_start_slide()

	move_and_slide()

	_update_speed_feel(delta)
	_face_riders_to_camera()

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
	if visual_root != null and not GameManager.is_game_over:
		_anim_time += delta
		_update_ride_anim(delta)
	# After ride lean/pitch, aim the card at the chase camera again.
	_face_riders_to_camera()

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

	if is_sliding:
		# Crouch the billboard. look_at still aims the card at the camera.
		visual_root.position.y = -0.42
		visual_root.rotation_degrees = Vector3(22.0, 0.0, _lean_z)
		visual_root.scale = Vector3(1.06, 0.42, 1.06) * VISUAL_SCALE
	else:
		visual_root.position.y = bob
		visual_root.rotation_degrees = Vector3(pitch, 0.0, _lean_z)

	# Wheel spin ∝ speed (rad/s = v / r). From the chase camera the axle is local Z,
	# so rotate_z turns the ring in view. (rotate_x is the sideways axle and
	# leaves these rear-view discs edge-on.)
	var spin_rad := (current_speed / WHEEL_RADIUS) * delta
	for w in wheel_nodes:
		if is_instance_valid(w):
			w.rotate_z(spin_rad)

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

func slide_busy() -> bool:
	return is_sliding or _slide_cd > 0.0

func _cache_stand_hurtbox() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return
	collision_shape.scale = Vector3.ONE
	var shape := collision_shape.shape.duplicate() as CapsuleShape3D
	if shape == null:
		return
	collision_shape.shape = shape
	_stand_height = shape.height
	_stand_radius = shape.radius
	_stand_shape_y = collision_shape.position.y

func _apply_hurtbox(sliding: bool) -> void:
	if collision_shape == null:
		return
	var shape := collision_shape.shape as CapsuleShape3D
	if shape == null:
		return
	# Non-uniform node scale does not reliably shrink a capsule, so the old
	# slide still overlapped every low block. Resize the shape instead.
	collision_shape.scale = Vector3.ONE
	if not sliding:
		shape.height = _stand_height
		shape.radius = _stand_radius
		collision_shape.position.y = _stand_shape_y
		return
	var stand_bottom := _stand_shape_y - _stand_height * 0.5
	var slide_height := maxf(SLIDE_CAPSULE_HEIGHT, SLIDE_CAPSULE_RADIUS * 2.0 + 0.06)
	shape.radius = SLIDE_CAPSULE_RADIUS
	shape.height = slide_height
	collision_shape.position.y = stand_bottom + slide_height * 0.5

func _start_slide() -> void:
	is_sliding = true
	_slide_left = SLIDE_DURATION
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_apply_hurtbox(true)

func _end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	_slide_cd = SLIDE_COOLDOWN
	_apply_hurtbox(false)
	if visual_root:
		visual_root.scale = Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
		visual_root.position.y = 0.0
		visual_root.rotation_degrees = Vector3.ZERO

func collect_coin() -> void:
	if GameManager.is_game_over:
		return
	combo += 1
	_combo_timer = COMBO_GAP
	var mult := mini(combo, 8)
	var pts := COIN_BASE_POINTS * mult
	score += pts
	_burst_sparkle()
	_sfx("coin")
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
	_sfx("boost")
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

func _sfx(id: String) -> void:
	var ga := get_node_or_null("/root/GameAudio")
	if ga and ga.has_method("play_sfx"):
		ga.play_sfx(id)

func _notify_score() -> void:
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_score"):
		ui.update_score(score)

func _notify_combo() -> void:
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_combo"):
		ui.update_combo(combo)
