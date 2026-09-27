extends Node3D
## Genesis / OutRun road chunk: high-contrast lanes, bold roadside props.

var _bobbers: Array[Node3D] = []
var _anim_t := 0.0
var _bob_phase := 0.0

func _ready() -> void:
	_bob_phase = randf() * TAU
	_style_road()
	_add_roadside_ground()
	_add_lane_markers()
	_add_center_dashes()
	_add_neon_edges()
	_spawn_roadside_prop()
	if randf() < 0.55:
		_spawn_roadside_prop()

func _process(delta: float) -> void:
	_anim_t += delta
	for i in _bobbers.size():
		var n := _bobbers[i]
		if not is_instance_valid(n):
			continue
		var phase := _bob_phase + float(i) * 1.7
		n.position.y = sin(_anim_t * 2.4 + phase) * 0.12
		n.rotation_degrees.y = sin(_anim_t * 1.3 + phase) * 4.0

func _style_road() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["road"], {
			"outline_width": 0.015,
			"rim_amount": 0.1,
			"base_glow": 0.08,
		})

func _add_roadside_ground() -> void:
	for side in [-1.0, 1.0]:
		var grass := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(8.0, 0.12, 20.0)
		grass.mesh = gm
		grass.position = Vector3(side * 9.0, -0.02, 0)
		add_child(grass)
		var col: Color = StyleKit.PALETTE["roadside"] if side < 0.0 else StyleKit.PALETTE["roadside_alt"]
		StyleKit.apply_to_mesh(grass, col, {
			"outline_width": 0.0, "base_glow": 0.22, "emission_strength": 0.25, "emission_color": col
		})

func _add_lane_markers() -> void:
	for x in [-1.5, 1.5]:
		var stripe := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.14, 0.05, 20.0)
		stripe.mesh = m
		stripe.position = Vector3(x, 0.14, 0)
		add_child(stripe)
		StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["road_lane"], {
			"outline_width": 0.0,
			"emission_strength": 0.75,
			"emission_color": StyleKit.PALETTE["road_lane"],
			"base_glow": 0.2,
		})

func _add_center_dashes() -> void:
	for i in range(-4, 5):
		var dash := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.4, 0.06, 1.4)
		dash.mesh = m
		dash.position = Vector3(0, 0.15, float(i) * 2.2)
		add_child(dash)
		StyleKit.apply_to_mesh(dash, StyleKit.PALETTE["road_stripe"], {
			"outline_width": 0.0,
			"emission_strength": 1.3,
			"emission_color": StyleKit.PALETTE["road_stripe"],
			"base_glow": 0.25,
		})

func _add_neon_edges() -> void:
	for x in [-5.05, 5.05]:
		var edge := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.32, 0.45, 20.0)
		edge.mesh = m
		edge.position = Vector3(x, 0.24, 0)
		add_child(edge)
		StyleKit.apply_to_mesh(edge, StyleKit.PALETTE["road_edge"], {
			"outline_width": 0.02,
			"emission_strength": 1.9,
			"emission_color": StyleKit.PALETTE["road_edge"],
			"base_glow": 0.35,
		})

func _spawn_roadside_prop() -> void:
	var kind := randi() % 4
	var side := -1.0 if randf() < 0.5 else 1.0
	var x := side * randf_range(6.8, 9.5)
	var z := randf_range(-8.0, 8.0)
	match kind:
		0:
			_add_tree(Vector3(x, 0, z))
		1:
			_add_palm(Vector3(x, 0, z))
		2:
			_add_pillar(Vector3(x, 0, z))
		_:
			_add_ramp_marker(Vector3(x, 0, z))

func _add_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_bobbers.append(root)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.22
	tm.bottom_radius = 0.35
	tm.height = 2.4
	tm.radial_segments = 8
	trunk.mesh = tm
	trunk.position = Vector3(0, 1.2, 0)
	root.add_child(trunk)
	StyleKit.apply_to_mesh(trunk, StyleKit.PALETTE["tree_trunk"], {"outline_width": 0.04, "base_glow": 0.1})
	for off in [Vector3(0, 2.6, 0), Vector3(-0.55, 2.3, 0.2), Vector3(0.55, 2.35, -0.15), Vector3(0.1, 2.9, 0.1)]:
		var leaf := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.7
		lm.height = 1.2
		lm.radial_segments = 8
		lm.rings = 4
		leaf.mesh = lm
		leaf.position = off
		root.add_child(leaf)
		StyleKit.apply_to_mesh(leaf, StyleKit.PALETTE["tree_leaf"], {
			"outline_width": 0.045, "emission_strength": 0.35, "emission_color": StyleKit.PALETTE["tree_leaf"], "base_glow": 0.15
		})

func _add_palm(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_bobbers.append(root)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.16
	tm.bottom_radius = 0.28
	tm.height = 3.2
	tm.radial_segments = 8
	trunk.mesh = tm
	trunk.position = Vector3(0, 1.6, 0)
	trunk.rotation_degrees = Vector3(4, 0, 6)
	root.add_child(trunk)
	StyleKit.apply_to_mesh(trunk, StyleKit.PALETTE["tree_trunk"], {"outline_width": 0.035, "base_glow": 0.1})
	for i in 5:
		var frond := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.15, 0.08, 1.6)
		frond.mesh = fm
		var ang := float(i) * 72.0
		frond.position = Vector3(0, 3.2, 0)
		frond.rotation_degrees = Vector3(25.0, ang, 0.0)
		root.add_child(frond)
		StyleKit.apply_to_mesh(frond, StyleKit.PALETTE["palm_leaf"], {
			"outline_width": 0.025, "emission_strength": 0.4, "emission_color": StyleKit.PALETTE["palm_leaf"]
		})

func _add_pillar(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_bobbers.append(root)
	var pillar := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.55, 3.2, 0.55)
	pillar.mesh = m
	pillar.position = Vector3(0, 1.6, 0)
	root.add_child(pillar)
	StyleKit.apply_to_mesh(pillar, StyleKit.PALETTE["pillar"], {
		"outline_width": 0.04, "emission_strength": 0.45, "emission_color": StyleKit.PALETTE["pillar"], "base_glow": 0.15
	})
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.85, 0.25, 0.85)
	cap.mesh = cm
	cap.position = Vector3(0, 3.3, 0)
	root.add_child(cap)
	StyleKit.apply_to_mesh(cap, StyleKit.PALETTE["road_stripe"], {
		"outline_width": 0.02, "emission_strength": 1.1, "emission_color": StyleKit.PALETTE["road_stripe"]
	})

func _add_ramp_marker(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_bobbers.append(root)
	var ramp := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.4, 0.9, 2.2)
	ramp.mesh = m
	ramp.position = Vector3(0, 0.45, 0)
	root.add_child(ramp)
	StyleKit.apply_to_mesh(ramp, StyleKit.PALETTE["block"], {
		"outline_width": 0.04, "emission_strength": 0.7, "emission_color": StyleKit.PALETTE["block"]
	})
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.5, 0.08, 0.35)
	stripe.mesh = sm
	stripe.position = Vector3(0, 0.95, 0)
	root.add_child(stripe)
	StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["road_stripe"], {
		"outline_width": 0.0, "emission_strength": 1.2, "emission_color": StyleKit.PALETTE["road_stripe"]
	})
