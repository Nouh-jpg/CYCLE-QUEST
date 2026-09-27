extends Node3D
## Electric horizon bands + bold cloud puffs — arcade cabinet sky.

@export var cloud_count := 10
var _clouds: Array[Node3D] = []
var _bands: Array[MeshInstance3D] = []
var player: Node3D
var _anim_t := 0.0

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	_build_horizon_bands()
	for i in cloud_count:
		_clouds.append(_make_cloud(
			Vector3(randf_range(-32, 32), randf_range(12, 24), -i * 22.0 - randf_range(0, 12)),
			randf_range(2.8, 5.5)
		))

func _build_horizon_bands() -> void:
	# Saturated electric stripes — no muddy midtones
	var specs := [
		{"y": 7.5, "h": 3.8, "col": Color(0.25, 0.55, 1.0), "z": -180.0},
		{"y": 4.2, "h": 2.8, "col": Color(0.45, 0.85, 1.0), "z": -175.0},
		{"y": 1.6, "h": 2.2, "col": Color(1.0, 0.45, 0.85), "z": -170.0},  # magenta band
		{"y": -0.4, "h": 2.0, "col": Color(1.0, 0.75, 0.15), "z": -166.0},  # gold strip
		{"y": -2.2, "h": 3.2, "col": Color(0.15, 0.85, 0.35), "z": -162.0},
	]
	for s in specs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(220.0, float(s["h"]), 0.4)
		mi.mesh = bm
		mi.position = Vector3(0, float(s["y"]), float(s["z"]))
		add_child(mi)
		var col: Color = s["col"]
		StyleKit.apply_to_mesh(mi, col, {
			"outline_width": 0.0,
			"emission_strength": 0.75,
			"emission_color": col,
			"base_glow": 0.35,
		})
		_bands.append(mi)

func _process(delta: float) -> void:
	_anim_t += delta
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return
	for i in _bands.size():
		var b := _bands[i]
		b.global_position.x = player.global_position.x
		b.global_position.z = player.global_position.z - 160.0
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
			"emission_strength": 0.45,
			"emission_color": col,
			"base_glow": 0.25,
		})
	return root
