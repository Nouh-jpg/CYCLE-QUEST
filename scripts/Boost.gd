extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Pulse effect
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.5)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and body.has_method("apply_boost"):
		body.apply_boost()
		queue_free()
