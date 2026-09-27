extends CharacterBody3D

## Starts behind; desired gap shrinks with time/speed for visible closing tension.
const START_GAP := 18.0
const MIN_GAP := 2.8
const CATCH_GAP := 1.55
const WARN_GAP := 7.5
## Closing rate: seconds to approach min gap under steady play.
const CLOSE_PER_SEC := 0.22
const CLOSE_PER_SPEED := 0.35

var player: Node3D
var _run_time := 0.0
var _visual: Node3D
var _anim_t := 0.0
var _danger := 0.0 ## 0..1 for UI vignette

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	_apply_toon_look()

func _apply_toon_look() -> void:
	var old := get_node_or_null("Mesh")
	if old:
		old.visible = false

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.3, 2.0)
	body.mesh = box
	body.position = Vector3(0, 1.15, 0)
	_visual.add_child(body)
	StyleKit.apply_to_mesh(body, StyleKit.PALETTE["chaser"], {
		"outline_width": 0.055,
		"rim_amount": 0.6,
		"rim_color": StyleKit.PALETTE["chaser_accent"],
		"emission_strength": 0.7,
		"emission_color": StyleKit.PALETTE["chaser"],
		"shade_color": Color(0.25, 0.05, 0.4),
		"base_glow": 0.2,
	})

	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.25, 0.7, 0.25)
		horn.mesh = hm
		horn.position = Vector3(side * 0.7, 2.4, -0.2)
		horn.rotation_degrees.z = side * -25.0
		_visual.add_child(horn)
		StyleKit.apply_to_mesh(horn, StyleKit.PALETTE["chaser_accent"], {
			"outline_width": 0.03, "emission_strength": 1.2, "emission_color": StyleKit.PALETTE["chaser_accent"]
		})

	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.22
		em.height = 0.44
		em.radial_segments = 10
		em.rings = 6
		eye.mesh = em
		eye.position = Vector3(side * 0.45, 1.5, -1.05)
		eye.name = "Eye%d" % (side + 2)
		_visual.add_child(eye)
		StyleKit.apply_to_mesh(eye, Color(1.0, 0.25, 0.45), {
			"outline_width": 0.0, "emission_strength": 3.2, "emission_color": Color(1.0, 0.15, 0.4), "rim_amount": 0.0
		})

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return

	_run_time += delta
	_anim_t += delta

	var player_speed := 15.0
	if "current_speed" in player:
		player_speed = float(player.current_speed)

	# Desired gap shrinks with time and player speed — visibly closes in
	var speed_factor := clampf((player_speed - 15.0) / 13.0, 0.0, 1.0)
	var desired_gap := START_GAP - _run_time * CLOSE_PER_SEC - speed_factor * CLOSE_PER_SPEED * 8.0
	desired_gap = maxf(MIN_GAP, desired_gap)

	var gap := global_position.z - player.global_position.z
	# Chase velocity: match player + close/open toward desired gap
	var gap_err := gap - desired_gap
	var chase_speed := player_speed + gap_err * 1.8
	velocity.z = -chase_speed
	velocity.x = (player.global_position.x - global_position.x) * 2.8
	velocity.y = 0.0
	global_position.y = player.global_position.y
	move_and_slide()

	gap = global_position.z - player.global_position.z
	_danger = clampf(1.0 - (gap - CATCH_GAP) / (WARN_GAP - CATCH_GAP), 0.0, 1.0)
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("set_danger_level"):
		ui.set_danger_level(_danger)

	if gap <= CATCH_GAP:
		_catch_player()

func _process(_delta: float) -> void:
	if _visual == null:
		return
	# Idle menace: bob, sway, eye pulse
	_visual.position.y = sin(_anim_t * 3.2) * 0.18
	_visual.rotation_degrees.z = sin(_anim_t * 2.4) * 6.0
	_visual.rotation_degrees.y = sin(_anim_t * 1.6) * 4.0
	var pulse := 1.0 + sin(_anim_t * 8.0) * 0.06 * (0.5 + _danger)
	_visual.scale = Vector3(pulse, pulse, pulse)

func _catch_player() -> void:
	if GameManager.is_game_over:
		return
	if player and player.has_method("on_crash"):
		player.on_crash()
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()
