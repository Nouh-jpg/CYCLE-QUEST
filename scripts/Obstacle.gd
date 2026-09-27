extends Area3D

const LANE_WIDTH := 3.0
const NEAR_MISS_LATERAL := 4.2

var _passed := false
var _near_miss_sent := false
var _anim_t := 0.0
var _base_y := 0.0
var player: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_apply_toon_look()
	player = get_tree().root.find_child("Player", true, false)
	add_to_group("obstacles")

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["obstacle"], {
		"outline_width": 0.05,
		"rim_amount": 0.4,
		"emission_strength": 0.55,
		"emission_color": StyleKit.PALETTE["obstacle"],
		"shade_color": Color(0.45, 0.05, 0.15),
		"base_glow": 0.15,
	})
	# Warning stripe accent — danger orange
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.05, 0.22, 1.05)
	stripe.mesh = sm
	stripe.position = Vector3(0, 0.35, 0)
	add_child(stripe)
	StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["obstacle_accent"], {
		"outline_width": 0.0, "emission_strength": 1.4, "emission_color": StyleKit.PALETTE["obstacle_accent"], "rim_amount": 0.0
	})
	# Top warning beacon
	var beacon := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.35, 0.35)
	beacon.mesh = bm
	beacon.position = Vector3(0, 0.85, 0)
	beacon.rotation_degrees = Vector3(45, 45, 0)
	beacon.name = "Beacon"
	add_child(beacon)
	StyleKit.apply_to_mesh(beacon, StyleKit.PALETTE["obstacle_accent"], {
		"outline_width": 0.0, "emission_strength": 2.0, "emission_color": Color(1.0, 0.9, 0.2)
	})

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	_anim_t += delta
	# Warning wobble + pulse so obstacles read as living hazards
	rotation_degrees.y = sin(_anim_t * 6.0) * 8.0
	position.y = _base_y + sin(_anim_t * 4.5) * 0.06
	var beacon := get_node_or_null("Beacon") as MeshInstance3D
	if beacon:
		var s := 1.0 + sin(_anim_t * 10.0) * 0.18
		beacon.scale = Vector3(s, s, s)

	_try_near_miss()

func _try_near_miss() -> void:
	if _near_miss_sent or _passed:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return
	# Player travels -Z; once obstacle is behind player, evaluate near-miss
	if global_position.z > player.global_position.z + 0.4:
		_passed = true
		var dx := absf(global_position.x - player.global_position.x)
		var obs_lane := int(round(global_position.x / LANE_WIDTH))
		var pl_lane := 0
		if "target_lane" in player:
			pl_lane = int(player.target_lane)
		# Adjacent lane close pass, or same-lane barely cleared laterally while switching
		var adjacent: bool = abs(obs_lane - pl_lane) == 1 and dx < NEAR_MISS_LATERAL
		var skim: bool = abs(obs_lane - pl_lane) == 0 and dx > 1.1 and dx < 2.4
		if adjacent or skim:
			_near_miss_sent = true
			if player.has_method("register_near_miss"):
				player.register_near_miss()

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("on_crash"):
			body.on_crash()
		var ui = get_tree().root.find_child("UI", true, false)
		if ui and ui.has_method("show_game_over"):
			ui.show_game_over()
