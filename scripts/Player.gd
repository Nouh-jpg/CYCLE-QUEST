extends CharacterBody3D

## Constants for movement
const LANE_WIDTH := 3.0
const BASE_FORWARD_SPEED := 15.0
const BOOST_SPEED := 25.0
const FORWARD_SPEED := BASE_FORWARD_SPEED
const LANE_SWITCH_SPEED := 10.0
const JUMP_FORCE := 8.0
const GRAVITY := 20.0

## State variables
var target_lane := 0 # -1: Left, 0: Center, 1: Right
var is_jumping := false
var is_sliding := false
var score := 0
var current_speed := BASE_FORWARD_SPEED

func _physics_process(delta: float) -> void:
	# Set character visuals based on selection (only once at start)
	if not "visuals_set" in self:
		if GameManager.selected_character == "Maya":
			self.modulate = Color(1, 0.6, 0.8)
		else:
			self.modulate = Color(0.6, 0.8, 1)
		set("visuals_set", true)

	# 1. Forward Movement
	velocity.z = -current_speed
	
	# 2. Lane Switching Logic
	var target_x := target_lane * LANE_WIDTH
	velocity.x = (target_x - global_position.x) * LANE_SWITCH_SPEED
	
	# 3. Jumping & Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		is_jumping = false
		
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_FORCE
		is_jumping = true
		
	# 4. Inputs for Lane Switching
	if Input.is_action_just_pressed("ui_left"):
		target_lane = max(-1, target_lane - 1)
	elif Input.is_action_just_pressed("ui_right"):
		target_lane = min(1, target_lane + 1)
		
	# 5. Slide Logic (Placeholder)
	if Input.is_action_just_pressed("ui_down") and is_on_floor():
		_start_slide()

	move_and_slide()

func _start_slide() -> void:
	is_sliding = true
	await get_tree().create_timer(1.0).timeout
	is_sliding = false

func collect_coin() -> void:
	score += 1
	var ui = get_tree().root.find_child("UI", true, false)
	if ui:
		ui.update_score(score)

func apply_boost() -> void:
	current_speed = BOOST_SPEED
	print("BOOST!")
	await get_tree().create_timer(3.0).timeout
	current_speed = BASE_FORWARD_SPEED
	print("Boost ended.")
