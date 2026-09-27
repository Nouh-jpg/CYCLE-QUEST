extends Area3D

var _anim_t := 0.0
var _base_y := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_apply_toon_look()
	add_to_group("coins")

func _apply_toon_look() -> void:
	var mesh_node := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	StyleKit.apply_to_mesh(mesh_node, StyleKit.PALETTE["coin"], {
		"outline_width": 0.035,
		"rim_amount": 0.55,
		"emission_strength": 0.65,
		"emission_color": StyleKit.PALETTE["coin"],
		"highlight_mix": 0.4,
		"shade_color": Color(0.7, 0.45, 0.05),
		"base_glow": 0.06,
	})

func _process(delta: float) -> void:
	_anim_t += delta
	# Fast spin + bob — arcade cabinet obvious
	rotate_y(delta * 7.5)
	position.y = _base_y + sin(_anim_t * 5.5) * 0.18
	var s := 1.0 + sin(_anim_t * 8.0) * 0.08
	scale = Vector3(s, s, s)

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("collect_coin"):
		body.collect_coin()
		queue_free()
