extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_toon_look()
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector3(1.25, 1.25, 1.25), 0.45)
	tween.tween_property(self, "scale", Vector3.ONE, 0.45)

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["boost"], {
		"outline_width": 0.04,
		"rim_amount": 0.6,
		"emission_strength": 1.6,
		"emission_color": StyleKit.PALETTE["boost"],
		"shade_color": Color(0.05, 0.45, 0.25),
	})
	# Neon diamond tip
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.35, 0.35, 0.35)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.7, 0)
	tip.rotation_degrees = Vector3(45, 45, 0)
	add_child(tip)
	StyleKit.apply_to_mesh(tip, Color(0.6, 1.0, 0.3), {
		"outline_width": 0.02, "emission_strength": 2.2, "emission_color": Color(0.5, 1.0, 0.2), "rim_amount": 0.0
	})

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("apply_boost"):
		body.apply_boost()
		queue_free()
