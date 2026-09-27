extends CharacterBody3D

const STARTING_DISTANCE := 15.0
const BASE_CHASE_SPEED := 14.5 # Slightly slower than player's base speed (15.0)
const SPEED_INCREMENT := 0.05 # Speed increases over time to make it harder

var current_speed := BASE_CHASE_SPEED
@onready var player = get_tree().root.find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# 1. Constant acceleration to increase tension
	current_speed += SPEED_INCREMENT * delta
	
	# 2. Move towards the player on the Z axis
	velocity.z = -current_speed
	
	# 3. Smoothly follow player's lane (X axis)
	var target_x = player.global_position.x
	velocity.x = (target_x - global_position.x) * 2.0
	
	move_and_slide()
	
	# 4. Check for "Catching" the player
	var distance_to_player = global_position.z - player.global_position.z
	if distance_to_player <= 2.0:
		_catch_player()

func _catch_player() -> void:
	print("The Chaser caught you!")
	var ui = get_tree().root.find_child("UI", true, false)
	if ui:
		ui.show_game_over()
	else:
		get_tree().reload_current_scene()
