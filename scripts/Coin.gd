extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Make it rotate for a nice effect
	var tween = create_tween().set_loops()
	tween.tween_property(self, "rotation:y", TAU, 2.0)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player" and body.has_method("collect_coin"):
		body.collect_coin()
		queue_free()
