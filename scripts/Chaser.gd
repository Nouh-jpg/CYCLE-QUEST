extends CharacterBody3D

## The chase camera sits ~8.5 m behind the rider (Player._setup_camera).
## The chaser is hidden and far behind that lens until an obstacle hit.
## A boost does not merely open the gap: it ends the chase and the pursuer leaves.
## Another hit can bring them back. A single stumble cannot close the lead.
const START_GAP := 4.35
const CATCH_GAP := 1.55
const WARN_GAP := 4.35
## Seconds of engaged riding to ease from START_GAP down toward PRESS_GAP.
const CLOSE_SECONDS := 36.0
const PRESS_GAP := 3.05
const PURSUIT_ACCEL := 6.0
## How fast the chaser gains while the rider is slowed. Capped so the
## appearance-on-hit lunge stays short of CATCH_GAP.
const HIT_SQUEEZE_CAP := 0.62
const HIT_SQUEEZE_PER_DEFICIT := 0.08
const SIDE_FAR := 2.2
const SIDE_NEAR := 1.15
## Parked far behind and beside the chase camera. The lens is at ~8.5 m.
const DORMANT_GAP := 48.0
const DORMANT_X := 26.0
## Meters kept between the camera and the chaser's nearest (+Z) point.
const CAMERA_CLEARANCE := 3.45
const BACK_EXTENT := 0.62
const BODY_SIZE := Vector3(0.95, 1.10, 0.90)

var player: Node3D
var _run_time := 0.0
var _visual: Node3D
var _anim_t := 0.0
var _danger := 0.0 ## 0..1 for UI vignette
## Tracks cruise speed, never the boost surge, so the gap can open.
var _pursuit := 15.0
## False while the pursuer is off the road. A hit sets it; a boost clears it.
var engaged := false

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	_apply_toon_look()
	_park_offstage()

func _set_drawn(draw: bool) -> void:
	visible = draw
	if _visual:
		_visual.visible = draw
	var placeholder := get_node_or_null("Mesh")
	if placeholder:
		placeholder.visible = false

func _park_offstage() -> void:
	_set_drawn(false)
	_danger = 0.0
	if player == null or not is_instance_valid(player):
		return
	global_position = Vector3(
		player.global_position.x + DORMANT_X,
		player.global_position.y,
		player.global_position.z + DORMANT_GAP
	)
	velocity = Vector3.ZERO

## Obstacle hit while the pursuer is away. An in-progress chase is not reset.
func engage() -> void:
	if engaged or GameManager.is_game_over:
		return
	engaged = true
	_run_time = 0.0
	_set_drawn(true)
	if player and "cruise_speed" in player:
		_pursuit = float(player.cruise_speed)
	_snap_to_gap(START_GAP)

## Boost escape. The chaser leaves the screen; it does not sit a little farther back.
func disengage() -> void:
	if not engaged or GameManager.is_game_over:
		return
	engaged = false
	_park_offstage()
	var ui := get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("set_danger_level"):
		ui.set_danger_level(0.0)
	if ui and ui.has_method("popup_points"):
		ui.popup_points("AWAY!", Color(0.45, 1.0, 0.95))
	var ga := get_node_or_null("/root/GameAudio")
	if ga and ga.has_method("set_danger_energy"):
		ga.set_danger_energy(0.0)

func _snap_to_gap(gap: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	global_position = Vector3(
		player.global_position.x + SIDE_FAR,
		player.global_position.y,
		player.global_position.z + gap
	)

func _apply_toon_look() -> void:
	var old := get_node_or_null("Mesh")
	if old:
		old.visible = false

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	body.name = "Body"
	var box := BoxMesh.new()
	box.size = BODY_SIZE
	body.mesh = box
	body.position = Vector3(0, BODY_SIZE.y * 0.5, 0)
	_visual.add_child(body)
	StyleKit.apply_to_mesh(body, StyleKit.PALETTE["chaser"], {
		"outline_width": 0.028,
		"rim_amount": 0.6,
		"rim_color": StyleKit.PALETTE["chaser_accent"],
		"emission_strength": 0.35,
		"emission_color": StyleKit.PALETTE["chaser"],
		"shade_color": Color(0.25, 0.05, 0.4),
		"base_glow": 0.05,
	})

	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.12, 0.28, 0.12)
		horn.mesh = hm
		horn.position = Vector3(side * 0.28, BODY_SIZE.y + 0.06, 0.02)
		horn.rotation_degrees.z = side * -22.0
		_visual.add_child(horn)
		StyleKit.apply_to_mesh(horn, StyleKit.PALETTE["chaser_accent"], {
			"outline_width": 0.015, "emission_strength": 0.45, "emission_color": StyleKit.PALETTE["chaser_accent"]
		})

	# +Z faces the chase camera. The old eyes sat on -Z, away from the lens.
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		em.radial_segments = 10
		em.rings = 6
		eye.mesh = em
		eye.position = Vector3(side * 0.2, BODY_SIZE.y * 0.62, BODY_SIZE.z * 0.5 + 0.02)
		eye.name = "Eye%d" % (side + 2)
		_visual.add_child(eye)
		StyleKit.apply_to_mesh(eye, Color(1.0, 0.25, 0.45), {
			"outline_width": 0.0, "emission_strength": 0.95, "emission_color": Color(1.0, 0.15, 0.4), "rim_amount": 0.0
		})

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return

	var boosting := false
	if "is_boosting" in player:
		boosting = bool(player.is_boosting)
	# A pickup ends the chase outright. Do this before any pursuit step so the
	# body cannot spend a frame creeping back into the lens.
	if not engaged or boosting:
		if engaged and boosting:
			disengage()
		else:
			_park_offstage()
		return

	_run_time += delta
	_anim_t += delta

	var player_speed := 15.0
	var cruise := 15.0
	if "current_speed" in player:
		player_speed = float(player.current_speed)
	if "cruise_speed" in player:
		cruise = float(player.cruise_speed)

	# Recomputed every frame from the live speed. Do not remember a
	# boost-relative chase speed or the chaser lunges the moment the surge ends.
	_pursuit = move_toward(_pursuit, cruise, PURSUIT_ACCEL * delta)
	# Player physics runs first, so this body's gap is already inflated by one
	# step of rider speed. Subtract that step or a boost looks like a safe lead
	# and the chaser copies it instead of falling back.
	var gap := global_position.z - player.global_position.z
	var rider := player as CharacterBody3D
	if rider:
		gap += rider.velocity.z * delta
	var healthy_t := clampf(_run_time / CLOSE_SECONDS, 0.0, 1.0)
	var desired := lerpf(START_GAP, PRESS_GAP, healthy_t)
	var chase := player_speed
	var deficit := maxf(0.0, cruise - player_speed)
	var squeeze := minf(HIT_SQUEEZE_CAP, deficit * HIT_SQUEEZE_PER_DEFICIT)
	if deficit > 2.0:
		var extra := minf(0.08, maxf(0.0, (gap - desired) * 0.05))
		chase = player_speed + squeeze + extra
	else:
		var gap_err := gap - desired
		var rel := clampf(gap_err * 1.15, -1.4, 1.8)
		chase = _pursuit + rel
		if player_speed < cruise - 0.4:
			chase = minf(chase, player_speed + squeeze + 0.35)
	velocity.z = -chase
	var side := lerpf(SIDE_FAR, SIDE_NEAR, _danger)
	var desired_x := player.global_position.x + side
	velocity.x = (desired_x - global_position.x) * 3.2
	velocity.y = 0.0
	global_position.y = player.global_position.y
	move_and_slide()
	_keep_in_frame()

	gap = global_position.z - player.global_position.z
	_danger = clampf(1.0 - (gap - CATCH_GAP) / (WARN_GAP - CATCH_GAP), 0.0, 1.0)
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("set_danger_level"):
		ui.set_danger_level(_danger)
	var ga := get_node_or_null("/root/GameAudio")
	if ga and ga.has_method("set_danger_energy"):
		ga.set_danger_energy(_danger)

	if gap <= CATCH_GAP:
		_catch_player()

func _keep_in_frame() -> void:
	# +Z points at the chase camera. Clamp so the mesh cannot reach the lens.
	if player == null:
		return
	var cam_z := player.global_position.z + 8.5
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam_z = cam.global_position.z
	var max_z := cam_z - CAMERA_CLEARANCE - BACK_EXTENT
	if global_position.z > max_z:
		global_position.z = max_z

func _process(_delta: float) -> void:
	if _visual == null:
		return
	if not engaged:
		_set_drawn(false)
		return
	# Small bob only. The old 6% danger pulse sat on a body already
	# large enough to cover the rider.
	_visual.position.y = sin(_anim_t * 3.2) * 0.06
	_visual.rotation_degrees.z = sin(_anim_t * 2.4) * 4.0
	_visual.rotation_degrees.y = sin(_anim_t * 1.6) * 3.0
	var loom := lerpf(1.0, 1.1, _danger)
	var pulse := 1.0 + sin(_anim_t * 8.0) * 0.03
	var s := loom * pulse
	_visual.scale = Vector3(s, s, s)

func _catch_player() -> void:
	if GameManager.is_game_over:
		return
	if player and player.has_method("on_crash"):
		player.on_crash()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()
