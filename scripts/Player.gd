extends CharacterBody3D

const LANE_WIDTH := 3.0
const BASE_FORWARD_SPEED := 15.0
const BOOST_SPEED := 25.0
const LANE_SWITCH_SPEED := 12.0
const JUMP_FORCE := 8.0
const GRAVITY := 20.0

var target_lane := 0 # -1 Left, 0 Center, 1 Right
var is_jumping := false
var is_sliding := false
var score := 0
var current_speed := BASE_FORWARD_SPEED
var _visuals_applied := false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	_apply_character_visuals()

func _apply_character_visuals() -> void:
	if _visuals_applied or mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	if GameManager.selected_character == "Maya":
		mat.albedo_color = Color(1.0, 0.55, 0.75) # pink / Maya
	else:
		mat.albedo_color = Color(0.45, 0.7, 1.0) # blue / Jax
	mesh_instance.material_override = mat
	_visuals_applied = true

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return

	# Forward movement (world -Z)
	velocity.z = -current_speed

	# Lane switching
	var target_x := target_lane * LANE_WIDTH
	velocity.x = (target_x - global_position.x) * LANE_SWITCH_SPEED

	# Gravity / jump
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		is_jumping = false
		if velocity.y < 0.0:
			velocity.y = 0.0

	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")) and is_on_floor() and not is_sliding:
		velocity.y = JUMP_FORCE
		is_jumping = true

	if Input.is_action_just_pressed("ui_left"):
		target_lane = max(-1, target_lane - 1)
	elif Input.is_action_just_pressed("ui_right"):
		target_lane = min(1, target_lane + 1)

	if Input.is_action_just_pressed("ui_down") and is_on_floor() and not is_sliding:
		_start_slide()

	move_and_slide()

func _start_slide() -> void:
	is_sliding = true
	# Shrink collision briefly so "slide under" can work later
	if collision_shape:
		collision_shape.scale.y = 0.5
		collision_shape.position.y = -0.25
	if mesh_instance:
		mesh_instance.scale.y = 0.5
	await get_tree().create_timer(0.8).timeout
	if collision_shape:
		collision_shape.scale.y = 1.0
		collision_shape.position.y = 0.0
	if mesh_instance:
		mesh_instance.scale.y = 1.0
	is_sliding = false

func collect_coin() -> void:
	if GameManager.is_game_over:
		return
	score += 1
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("update_score"):
		ui.update_score(score)

func apply_boost() -> void:
	if GameManager.is_game_over:
		return
	current_speed = BOOST_SPEED
	await get_tree().create_timer(3.0).timeout
	if not GameManager.is_game_over:
		current_speed = BASE_FORWARD_SPEED
