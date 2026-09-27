extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween := create_tween().set_loops()
	tween.tween_property(self, "rotation:y", TAU, 2.0).from(0.0)

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if (body.is_in_group("player") or body.name == "Player") and body.has_method("collect_coin"):
		body.collect_coin()
		queue_free()
