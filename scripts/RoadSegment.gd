extends Node3D

func queue_free_delayed() -> void:
	# Wait until the player has passed this segment
	await get_tree().create_timer(5.0).timeout
	queue_free()
