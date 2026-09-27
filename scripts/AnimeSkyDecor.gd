extends Node3D
## Large fluffy anime cloud puffs (primitive spheres) that follow the player lightly.

@export var cloud_count := 10
var _clouds: Array[Node3D] = []
var player: Node3D

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	for i in cloud_count:
		_clouds.append(_make_cloud(
			Vector3(randf_range(-28, 28), randf_range(10, 22), -i * 18.0 - randf_range(0, 10)),
			randf_range(2.5, 5.0)
		))

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return
	# Recycle clouds ahead of the runner
	for c in _clouds:
		if c.global_position.z > player.global_position.z + 30.0:
			c.global_position.z = player.global_position.z - randf_range(60.0, 140.0)
			c.global_position.x = randf_range(-30, 30)
			c.global_position.y = randf_range(10, 22)

func _make_cloud(pos: Vector3, scale_base: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var puff_count := 4 + randi() % 3
	for i in puff_count:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := scale_base * randf_range(0.45, 1.0)
		sm.radius = r
		sm.height = r * 1.6
		sm.radial_segments = 10
		sm.rings = 6
		mi.mesh = sm
		mi.position = Vector3(randf_range(-scale_base, scale_base), randf_range(-0.4, 0.6), randf_range(-scale_base * 0.4, scale_base * 0.4))
		mi.scale = Vector3(1.0, 0.65, 1.0)
		root.add_child(mi)
		var col := Color(1.0, 0.92, 1.0) if randf() < 0.5 else Color(0.85, 0.9, 1.0)
		StyleKit.apply_to_mesh(mi, col, {
			"outline_width": 0.06,
			"rim_amount": 0.35,
			"shade_color": Color(0.75, 0.7, 0.95),
			"shade_threshold": 0.55,
			"emission_strength": 0.15,
			"emission_color": col,
		})
	return root
