extends CharacterBody3D

const BASE_CHASE_SPEED := 14.0
const SPEED_INCREMENT := 0.08

var current_speed := BASE_CHASE_SPEED
var player: Node3D

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	_apply_toon_look()

func _apply_toon_look() -> void:
	# Rebuild chaser as a menacing anime blob with neon eyes
	var old := get_node_or_null("Mesh")
	if old:
		old.visible = false

	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 2.3, 2.0)
	body.mesh = box
	body.position = Vector3(0, 1.15, 0)
	visual.add_child(body)
	StyleKit.apply_to_mesh(body, StyleKit.PALETTE["chaser"], {
		"outline_width": 0.05,
		"rim_amount": 0.6,
		"rim_color": StyleKit.PALETTE["chaser_accent"],
		"emission_strength": 0.35,
		"emission_color": StyleKit.PALETTE["chaser"],
		"shade_color": Color(0.25, 0.05, 0.4),
	})

	# Horns / spikes
	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.25, 0.7, 0.25)
		horn.mesh = hm
		horn.position = Vector3(side * 0.7, 2.4, -0.2)
		horn.rotation_degrees.z = side * -25.0
		visual.add_child(horn)
		StyleKit.apply_to_mesh(horn, StyleKit.PALETTE["chaser_accent"], {
			"outline_width": 0.03, "emission_strength": 0.8, "emission_color": StyleKit.PALETTE["chaser_accent"]
		})

	# Glowing eyes
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.22
		em.height = 0.44
		em.radial_segments = 10
		em.rings = 6
		eye.mesh = em
		eye.position = Vector3(side * 0.45, 1.5, -1.05)
		visual.add_child(eye)
		StyleKit.apply_to_mesh(eye, Color(1.0, 0.3, 0.5), {
			"outline_width": 0.0, "emission_strength": 2.5, "emission_color": Color(1.0, 0.2, 0.45), "rim_amount": 0.0
		})

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return

	current_speed += SPEED_INCREMENT * delta
	velocity.z = -current_speed
	velocity.x = (player.global_position.x - global_position.x) * 2.5
	velocity.y = 0.0
	global_position.y = player.global_position.y
	move_and_slide()

	var gap := global_position.z - player.global_position.z
	if gap <= 1.5:
		_catch_player()

func _catch_player() -> void:
	if GameManager.is_game_over:
		return
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()
