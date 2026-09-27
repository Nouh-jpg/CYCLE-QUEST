extends Area3D

const LANE_WIDTH := 3.0
const NEAR_MISS_LATERAL := 4.2
## Crawl gap under the gate. Slide hurtbox top stays near world y=0.8;
## a standing or jumping rider still intersects the panel.
const BEAM_BOTTOM := 1.10
const BEAM_TOP := 4.60

## "low" = jump barrier. "overhead" = full-width cyan gate, slide required.
var kind := "low"
var _passed := false
var _near_miss_sent := false
var _anim_t := 0.0
var _base_y := 0.0
var player: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	if kind == "overhead":
		_build_overhead()
	else:
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
		"emission_strength": 0.3,
		"emission_color": StyleKit.PALETTE["obstacle"],
		"shade_color": Color(0.45, 0.05, 0.15),
		"base_glow": 0.04,
	})
	# Warning stripe accent — danger orange
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.05, 0.22, 1.05)
	stripe.mesh = sm
	stripe.position = Vector3(0, 0.35, 0)
	add_child(stripe)
	StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["obstacle_accent"], {
		"outline_width": 0.0, "emission_strength": 0.5, "emission_color": StyleKit.PALETTE["obstacle_accent"], "rim_amount": 0.0
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
		"outline_width": 0.0, "emission_strength": 0.7, "emission_color": Color(1.0, 0.9, 0.2)
	})

func _build_overhead() -> void:
	# Stable gate: no bob, or the crawl gap would change height mid-approach.
	var beam_size := Vector3(9.6, BEAM_TOP - BEAM_BOTTOM, 1.0)
	var beam_center := Vector3(0.0, (BEAM_BOTTOM + BEAM_TOP) * 0.5, 0.0)
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		var beam := BoxMesh.new()
		beam.size = beam_size
		mesh_node.mesh = beam
		mesh_node.position = beam_center
		StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["block"], {
			"outline_width": 0.04,
			"emission_strength": 0.55,
			"emission_color": StyleKit.PALETTE["block"],
			"shade_color": Color(0.02, 0.15, 0.35),
			"base_glow": 0.06,
		})
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		var shape := BoxShape3D.new()
		shape.size = beam_size
		col.shape = shape
		col.position = beam_center
	# Yellow lip marks the duck line. It stays inside the beam volume.
	var lip := MeshInstance3D.new()
	var lip_mesh := BoxMesh.new()
	lip_mesh.size = Vector3(9.6, 0.16, 0.92)
	lip.mesh = lip_mesh
	lip.position = Vector3(0.0, BEAM_BOTTOM + 0.1, 0.0)
	lip.name = "Lip"
	add_child(lip)
	StyleKit.apply_to_mesh(lip, StyleKit.PALETTE["obstacle_accent"], {
		"outline_width": 0.0, "emission_strength": 0.7, "emission_color": Color(1.0, 0.85, 0.15)
	})
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.34, BEAM_BOTTOM, 0.34)
		post.mesh = pm
		post.position = Vector3(side * 4.62, pm.size.y * 0.5, 0.0)
		add_child(post)
		StyleKit.apply_to_mesh(post, StyleKit.PALETTE["block"], {
			"outline_width": 0.03, "emission_strength": 0.35, "emission_color": StyleKit.PALETTE["block"]
		})

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	_anim_t += delta
	if kind == "overhead":
		var lip := get_node_or_null("Lip") as MeshInstance3D
		if lip:
			var s := 1.0 + sin(_anim_t * 8.0) * 0.04
			lip.scale = Vector3(1.0, s, 1.0)
		_try_near_miss()
		return
	# Warning wobble + pulse so obstacles read as living hazards
	rotation_degrees.y = sin(_anim_t * 6.0) * 8.0
	position.y = _base_y + sin(_anim_t * 4.5) * 0.06
	var beacon := get_node_or_null("Beacon") as MeshInstance3D
	if beacon:
		var s := 1.0 + sin(_anim_t * 10.0) * 0.18
		beacon.scale = Vector3(s, s, s)

	_try_near_miss()

func _try_near_miss() -> void:
	# The gate spans every lane, so sliding under it is not a near miss.
	if kind == "overhead":
		_passed = true
		return
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
