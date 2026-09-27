extends Area3D

var _anim_t := 0.0
var _base_y := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_apply_toon_look()

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["boost"], {
		"outline_width": 0.045,
		"rim_amount": 0.6,
		"emission_strength": 2.4,
		"emission_color": StyleKit.PALETTE["boost"],
		"shade_color": Color(0.05, 0.45, 0.25),
		"base_glow": 0.4,
	})
	# Neon diamond tip
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.4, 0.4, 0.4)
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0.75, 0)
	tip.rotation_degrees = Vector3(45, 45, 0)
	tip.name = "Tip"
	add_child(tip)
	StyleKit.apply_to_mesh(tip, Color(0.55, 1.0, 0.2), {
		"outline_width": 0.02, "emission_strength": 3.0, "emission_color": Color(0.5, 1.0, 0.15), "rim_amount": 0.0
	})

func _process(delta: float) -> void:
	_anim_t += delta
	rotate_y(delta * 3.5)
	position.y = _base_y + sin(_anim_t * 6.0) * 0.22
	var s := 1.0 + sin(_anim_t * 7.0) * 0.22
	scale = Vector3(s, s, s)
	var tip := get_node_or_null("Tip") as MeshInstance3D
	if tip:
		tip.rotate_y(delta * 8.0)

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("apply_boost"):
		body.apply_boost()
		queue_free()
