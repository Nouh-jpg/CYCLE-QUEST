extends Node3D
## Stylized anime road chunk with lane stripes, neon edges, and optional props.

func _ready() -> void:
	_style_road()
	_add_lane_stripes()
	_add_neon_edges()
	if randf() < 0.4:
		_spawn_anime_prop()

func _style_road() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["road"], {
			"outline_width": 0.02,
			"rim_amount": 0.15,
			"shade_color": Color(0.2, 0.12, 0.4),
			"shade_threshold": 0.5,
		})

func _add_lane_stripes() -> void:
	for x in [-3.0, 0.0, 3.0]:
		var stripe := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.18, 0.04, 18.0)
		stripe.mesh = m
		stripe.position = Vector3(x, 0.12, 0)
		add_child(stripe)
		StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["road_stripe"], {
			"outline_width": 0.0,
			"emission_strength": 0.55,
			"emission_color": StyleKit.PALETTE["road_stripe"],
			"rim_amount": 0.0,
		})

func _add_neon_edges() -> void:
	for x in [-5.1, 5.1]:
		var edge := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.25, 0.35, 20.0)
		edge.mesh = m
		edge.position = Vector3(x, 0.2, 0)
		add_child(edge)
		StyleKit.apply_to_mesh(edge, StyleKit.PALETTE["road_edge"], {
			"outline_width": 0.02,
			"emission_strength": 1.2,
			"emission_color": StyleKit.PALETTE["road_edge"],
			"rim_amount": 0.3,
		})
		# Tall posts every segment side
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.2, 1.8, 0.2)
		post.mesh = pm
		post.position = Vector3(x, 1.0, 0)
		add_child(post)
		StyleKit.apply_to_mesh(post, Color(0.55, 0.3, 1.0), {
			"outline_width": 0.025, "emission_strength": 0.4, "emission_color": Color(0.55, 0.3, 1.0)
		})

func _spawn_anime_prop() -> void:
	var kind := randi() % 3
	var side := -1.0 if randf() < 0.5 else 1.0
	var x := side * randf_range(6.5, 8.5)
	var z := randf_range(-7.0, 7.0)
	match kind:
		0:
			_add_mushroom(Vector3(x, 0, z))
		1:
			_add_floating_block(Vector3(x, randf_range(1.5, 3.0), z))
		_:
			_add_neon_accent(Vector3(x, 0.5, z))

func _add_mushroom(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.35
	sm.bottom_radius = 0.45
	sm.height = 1.2
	sm.radial_segments = 10
	stem.mesh = sm
	stem.position = Vector3(0, 0.6, 0)
	root.add_child(stem)
	StyleKit.apply_to_mesh(stem, StyleKit.PALETTE["mushroom_stem"], {"outline_width": 0.035})
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.9
	cm.height = 1.1
	cm.radial_segments = 12
	cm.rings = 6
	cap.mesh = cm
	cap.position = Vector3(0, 1.35, 0)
	cap.scale = Vector3(1.0, 0.65, 1.0)
	root.add_child(cap)
	StyleKit.apply_to_mesh(cap, StyleKit.PALETTE["mushroom_cap"], {
		"outline_width": 0.04, "emission_strength": 0.25, "emission_color": StyleKit.PALETTE["mushroom_cap"], "rim_amount": 0.5
	})
	# Spots
	for i in 3:
		var spot := MeshInstance3D.new()
		var spm := SphereMesh.new()
		spm.radius = 0.18
		spm.height = 0.36
		spm.radial_segments = 6
		spm.rings = 3
		spot.mesh = spm
		spot.position = Vector3(randf_range(-0.4, 0.4), 1.55, randf_range(-0.4, 0.4))
		root.add_child(spot)
		StyleKit.apply_to_mesh(spot, Color(1, 1, 1), {"outline_width": 0.0, "rim_amount": 0.0})

func _add_floating_block(pos: Vector3) -> void:
	var block := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.2, 1.2, 1.2)
	block.mesh = m
	block.position = pos
	block.rotation_degrees = Vector3(15, 35, 10)
	add_child(block)
	StyleKit.apply_to_mesh(block, StyleKit.PALETTE["block"], {
		"outline_width": 0.045, "emission_strength": 0.5, "emission_color": StyleKit.PALETTE["block"], "rim_amount": 0.55
	})
	var tw := create_tween().set_loops()
	tw.tween_property(block, "position:y", pos.y + 0.4, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(block, "position:y", pos.y, 1.2).set_trans(Tween.TRANS_SINE)

func _add_neon_accent(pos: Vector3) -> void:
	var pillar := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.35, 2.5, 0.35)
	pillar.mesh = m
	pillar.position = pos + Vector3(0, 1.25, 0)
	add_child(pillar)
	StyleKit.apply_to_mesh(pillar, StyleKit.PALETTE["neon"], {
		"outline_width": 0.03, "emission_strength": 2.0, "emission_color": StyleKit.PALETTE["neon"], "rim_amount": 0.2
	})
	var orb := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.4
	om.height = 0.8
	om.radial_segments = 10
	om.rings = 6
	orb.mesh = om
	orb.position = pos + Vector3(0, 2.8, 0)
	add_child(orb)
	StyleKit.apply_to_mesh(orb, Color(1.0, 0.4, 1.0), {
		"outline_width": 0.02, "emission_strength": 2.5, "emission_color": Color(1.0, 0.35, 1.0), "rim_amount": 0.0
	})
