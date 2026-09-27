extends CharacterBody3D

const BASE_CHASE_SPEED := 14.0
const SPEED_INCREMENT := 0.08

var current_speed := BASE_CHASE_SPEED
var player: Node3D

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return

	current_speed += SPEED_INCREMENT * delta
	velocity.z = -current_speed
	velocity.x = (player.global_position.x - global_position.x) * 2.5
	velocity.y = 0.0
	# Keep chaser grounded at player height visually
	global_position.y = player.global_position.y
	move_and_slide()

	# Player is ahead on -Z; catch when chaser closes the gap
	var gap := global_position.z - player.global_position.z
	if gap <= 1.5:
		_catch_player()

func _catch_player() -> void:
	if GameManager.is_game_over:
		return
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("show_game_over"):
		ui.show_game_over()
