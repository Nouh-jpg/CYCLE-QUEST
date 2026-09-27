extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_toon_look()
	var tween := create_tween().set_loops()
	tween.tween_property(self, "rotation:y", TAU, 2.0).from(0.0)

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["coin"], {
		"outline_width": 0.03,
		"rim_amount": 0.55,
		"emission_strength": 1.4,
		"emission_color": StyleKit.PALETTE["coin"],
		"highlight_mix": 0.4,
		"shade_color": Color(0.7, 0.45, 0.05),
	})

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("collect_coin"):
		body.collect_coin()
		queue_free()
