extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector3(1.25, 1.25, 1.25), 0.45)
	tween.tween_property(self, "scale", Vector3.ONE, 0.45)

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("apply_boost"):
		body.apply_boost()
		queue_free()
