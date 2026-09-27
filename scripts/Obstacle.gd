extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_toon_look()

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["obstacle"], {
		"outline_width": 0.045,
		"rim_amount": 0.4,
		"emission_strength": 0.3,
		"emission_color": StyleKit.PALETTE["obstacle"],
		"shade_color": Color(0.45, 0.05, 0.15),
	})
	# Warning stripe accent
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.05, 0.2, 1.05)
	stripe.mesh = sm
	stripe.position = Vector3(0, 0.35, 0)
	add_child(stripe)
	StyleKit.apply_to_mesh(stripe, StyleKit.PALETTE["obstacle_accent"], {
		"outline_width": 0.0, "emission_strength": 0.9, "emission_color": StyleKit.PALETTE["obstacle_accent"], "rim_amount": 0.0
	})

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if body.is_in_group("player") or body.name == "Player":
		var ui = get_tree().root.find_child("UI", true, false)
		if ui and ui.has_method("show_game_over"):
			ui.show_game_over()
