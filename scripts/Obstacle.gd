extends Area3D

const LANE_WIDTH := 3.0
const NEAR_MISS_LATERAL := 4.2
## Two thin rails, not a wall. The slide duck tops out near world y=1.05
## and the crouched card is shorter than that. The lower rail sits above
## that crouch with a visible gap; standing clips it. The upper rail is
## what a jump hits, so the opening between them is air, not a solid slab.
const BAR_BOTTOM := 1.40
const BAR_THICK := 0.36
const UPPER_BOTTOM := 2.18
const UPPER_THICK := 0.40
const BAR_WIDTH := 9.6
const BAR_DEPTH := 0.40

## "low" = red jump block. "overhead" = magenta hanging gate, slide required.
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
	var gate_color := Color(0.95, 0.12, 0.82)
	var lower_size := Vector3(BAR_WIDTH, BAR_THICK, BAR_DEPTH)
	var lower_center := Vector3(0.0, BAR_BOTTOM + BAR_THICK * 0.5, 0.0)
	var upper_size := Vector3(BAR_WIDTH, UPPER_THICK, BAR_DEPTH)
	var upper_center := Vector3(0.0, UPPER_BOTTOM + UPPER_THICK * 0.5, 0.0)
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		var beam := BoxMesh.new()
		beam.size = lower_size
		mesh_node.mesh = beam
		mesh_node.position = lower_center
		StyleKit.apply_to_mesh(mesh_node, gate_color, {
			"outline_width": 0.035,
			"emission_strength": 0.5,
			"emission_color": gate_color,
			"shade_color": Color(0.25, 0.02, 0.2),
			"base_glow": 0.05,
		})
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		var shape := BoxShape3D.new()
		shape.size = lower_size
		col.shape = shape
		col.position = lower_center
	_add_rail("UpperRail", upper_size, upper_center, gate_color)
	# Yellow/black lip on the limbo bar, hanging in the open gap so the duck reads.
	var lip_h := 0.12
	var stripe_w := BAR_WIDTH / 8.0
	for i in 8:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(stripe_w, lip_h, BAR_DEPTH + 0.06)
		stripe.mesh = sm
		stripe.position = Vector3(-BAR_WIDTH * 0.5 + stripe_w * (float(i) + 0.5), BAR_BOTTOM - lip_h * 0.35, 0.04)
		stripe.name = "LipStripe%d" % i
		add_child(stripe)
		var yellow := i % 2 == 0
		var lip_color := Color(1.0, 0.92, 0.08) if yellow else Color(0.08, 0.06, 0.1)
		StyleKit.apply_to_mesh(stripe, lip_color, {
			"outline_width": 0.0,
			"emission_strength": 0.85 if yellow else 0.05,
			"emission_color": lip_color,
		})
	# Chevrons sit in the crawl gap, under the bar, facing the chase camera (+Z).
	var cues := Node3D.new()
	cues.name = "DuckCues"
	cues.position = Vector3(0.0, BAR_BOTTOM - 0.42, BAR_DEPTH * 0.5 + 0.08)
	add_child(cues)
	for lane_x in [-3.0, 0.0, 3.0]:
		_add_down_chevron(cues, lane_x)
	# Slim posts only as tall as the upper rail. They frame the opening; they are not a wall.
	var post_h := UPPER_BOTTOM + UPPER_THICK
	var post_index := 0
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "GatePost%d" % post_index
		post_index += 1
		var pm := BoxMesh.new()
		pm.size = Vector3(0.18, post_h, 0.18)
		post.mesh = pm
		post.position = Vector3(side * 4.85, pm.size.y * 0.5, 0.0)
		add_child(post)
		StyleKit.apply_to_mesh(post, Color(0.55, 0.05, 0.48), {
			"outline_width": 0.02, "emission_strength": 0.25, "emission_color": gate_color
		})

func _add_rail(rail_name: String, size: Vector3, center: Vector3, gate_color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = rail_name + "Mesh"
	var beam := BoxMesh.new()
	beam.size = size
	mesh_node.mesh = beam
	mesh_node.position = center
	add_child(mesh_node)
	StyleKit.apply_to_mesh(mesh_node, gate_color, {
		"outline_width": 0.03,
		"emission_strength": 0.4,
		"emission_color": gate_color,
		"shade_color": Color(0.22, 0.02, 0.18),
	})
	var col := CollisionShape3D.new()
	col.name = rail_name
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center
	add_child(col)

func _add_down_chevron(parent: Node3D, x: float) -> void:
	for sign in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.78, 0.14, 0.12)
		arm.mesh = mesh
		arm.position = Vector3(x + sign * 0.26, 0.2, 0.0)
		arm.rotation_degrees.z = sign * -52.0
		parent.add_child(arm)
		var cue := Color(1.0, 0.95, 0.15)
		StyleKit.apply_to_mesh(arm, cue, {
			"outline_width": 0.0, "emission_strength": 0.9, "emission_color": cue
		})

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	_anim_t += delta
	if kind == "overhead":
		var cues := get_node_or_null("DuckCues") as Node3D
		if cues:
			cues.position.z = BAR_DEPTH * 0.5 + 0.08 + sin(_anim_t * 6.0) * 0.04
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
		# A hit stumbles the rider. Only the chaser closing the gap ends the run.
		if body.has_method("on_obstacle_hit"):
			body.on_obstacle_hit()
