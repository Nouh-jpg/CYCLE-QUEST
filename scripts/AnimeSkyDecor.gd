extends Node3D
## Electric horizon bands + bold cloud puffs — arcade cabinet sky.

@export var cloud_count := 10
var _clouds: Array[Node3D] = []
var _skyline: Node3D
var player: Node3D
var _anim_t := 0.0

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	_build_skyline()
	for i in cloud_count:
		_clouds.append(_make_cloud(
			Vector3(randf_range(-32, 32), randf_range(12, 24), -i * 22.0 - randf_range(0, 12)),
			randf_range(2.8, 5.5)
		))

func _build_skyline() -> void:
	# Layered geometric silhouettes give the road an actual destination and depth.
	_skyline = Node3D.new()
	_skyline.name = "DistantSkyline"
	add_child(_skyline)
	var x := -96.0
	var index := 0
	while x < 96.0:
		var width := randf_range(4.5, 8.5)
		var height := randf_range(9.0, 25.0)
		var depth := randf_range(3.0, 6.0)
		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(width, height, depth)
		body.mesh = body_mesh
		body.position = Vector3(x + width * 0.5, height * 0.5 - 0.8, randf_range(-3.0, 3.0))
		_skyline.add_child(body)
		var wall_color: Color = [Color(0.23, 0.28, 0.48), Color(0.27, 0.22, 0.42), Color(0.16, 0.28, 0.40)][index % 3]
		StyleKit.apply_to_mesh(body, wall_color, {"outline_width": 0.0, "base_glow": 0.01})
		if index % 3 == 1:
			var crown := MeshInstance3D.new()
			var crown_mesh := BoxMesh.new()
			crown_mesh.size = Vector3(width * 0.52, randf_range(2.0, 5.0), depth * 0.58)
			crown.mesh = crown_mesh
			crown.position = Vector3(body.position.x, height + crown_mesh.size.y * 0.5 - 0.8, body.position.z)
			_skyline.add_child(crown)
			StyleKit.apply_to_mesh(crown, Color(0.31, 0.34, 0.56), {"outline_width": 0.0, "base_glow": 0.01})
		if index % 2 == 0:
			var sign := MeshInstance3D.new()
			var sign_mesh := BoxMesh.new()
			sign_mesh.size = Vector3(0.1, minf(height * 0.58, 8.0), 0.11)
			sign.mesh = sign_mesh
			sign.position = Vector3(body.position.x - width * 0.36, height * 0.55, body.position.z + depth * 0.52)
			_skyline.add_child(sign)
			var sign_color := Color(0.15, 0.62, 0.88) if index % 4 == 0 else Color(0.88, 0.26, 0.57)
			StyleKit.apply_to_mesh(sign, sign_color, {"outline_width": 0.0, "emission_strength": 0.35, "emission_color": sign_color})
		x += width + randf_range(0.8, 2.0)
		index += 1

func _process(delta: float) -> void:
	_anim_t += delta
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return
	if _skyline:
		_skyline.global_position.x = player.global_position.x
		_skyline.global_position.z = player.global_position.z - 155.0
	for c in _clouds:
		c.rotate_y(delta * 0.15)
		if c.global_position.z > player.global_position.z + 30.0:
			c.global_position.z = player.global_position.z - randf_range(70.0, 150.0)
			c.global_position.x = randf_range(-34, 34)
			c.global_position.y = randf_range(12, 24)

func _make_cloud(pos: Vector3, scale_base: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var puff_count := 3 + randi() % 2
	for i in puff_count:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := scale_base * randf_range(0.5, 1.0)
		sm.radius = r
		sm.height = r * 1.5
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.position = Vector3(randf_range(-scale_base, scale_base), randf_range(-0.3, 0.5), randf_range(-scale_base * 0.3, scale_base * 0.3))
		mi.scale = Vector3(1.0, 0.6, 1.0)
		root.add_child(mi)
		var col := Color(1.0, 1.0, 1.0) if randf() < 0.5 else Color(0.75, 0.9, 1.0)
		if randf() < 0.25:
			col = Color(1.0, 0.75, 0.95)  # pink-tinted puff
		StyleKit.apply_to_mesh(mi, col, {
			"outline_width": 0.05,
			"emission_strength": 0.12,
			"emission_color": col,
			"base_glow": 0.04,
		})
	return root
