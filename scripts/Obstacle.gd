extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if GameManager.is_game_over:
		return
	if body.is_in_group("player") or body.name == "Player":
		var ui = get_tree().root.find_child("UI", true, false)
		if ui and ui.has_method("show_game_over"):
			ui.show_game_over()
