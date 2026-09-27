extends Area3D

func _ready() -> void:
	# Connect the body_entered signal to detect the player
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		print("Player hit an obstacle!")
		var ui = get_tree().root.find_child("UI", true, false)
		if ui:
			ui.show_game_over()
		else:
			get_tree().reload_current_scene()
	
	# Cleanup obstacle if it's passed
	await get_tree().create_timer(5.0).timeout
	queue_free()
