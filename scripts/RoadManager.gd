extends Node3D

const SEGMENT_LENGTH := 20.0
const INITIAL_SEGMENTS := 10
const RENDER_DISTANCE := 5

@export var road_segment_scene: PackedScene = preload("res://scenes/RoadSegment.tscn")
@export var obstacle_scene: PackedScene = preload("res://scenes/Obstacle.tscn")
@export var coin_scene: PackedScene = preload("res://scenes/Coin.tscn")
@export var boost_scene: PackedScene = preload("res://scenes/Boost.tscn")
@onready var player = get_tree().root.find_child("Player", true, false)

var next_spawn_z := 0.0
var active_segments: Array[Node3D] = []

func _ready() -> void:
	# Initial road setup
	for i in range(INITIAL_SEGMENTS):
		spawn_segment()

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().root.find_child("Player", true, false)
		return
	
	# Spawn new segments as player moves forward
	if player.global_position.z < next_spawn_z + (RENDER_DISTANCE * SEGMENT_LENGTH):
		spawn_segment()
	
	# Clean up old segments
	_cleanup_segments()

func spawn_segment() -> void:
	var segment = road_segment_scene.instantiate()
	segment.position.z = next_spawn_z
	add_child(segment)
	active_segments.append(segment)
	
	# Randomly spawn an obstacle on this segment
	if randf() < 0.3: # 30% chance
		spawn_obstacle(next_spawn_z)
	
	# Randomly spawn collectibles
	if randf() < 0.5: # 50% chance
		spawn_coin(next_spawn_z)
		
	if randf() < 0.1: # 10% chance
		spawn_boost(next_spawn_z)
	
	next_spawn_z -= SEGMENT_LENGTH
	
	# Let the segment handle its own delayed cleanup
	segment.queue_free_delayed()

func spawn_obstacle(z_pos: float) -> void:
	var obstacle = obstacle_scene.instantiate()
	var lane = randi_range(-1, 1)
	var x_pos = lane * 3.0
	obstacle.position = Vector3(x_pos, 0.5, z_pos)
	add_child(obstacle)

func spawn_coin(z_pos: float) -> void:
	var coin = coin_scene.instantiate()
	var lane = randi_range(-1, 1)
	var x_pos = lane * 3.0
	coin.position = Vector3(x_pos, 0.5, z_pos)
	add_child(coin)

func spawn_boost(z_pos: float) -> void:
	var boost = boost_scene.instantiate()
	var lane = randi_range(-1, 1)
	var x_pos = lane * 3.0
	boost.position = Vector3(x_pos, 0.5, z_pos)
	add_child(boost)

func _cleanup_segments() -> void:
	# We remove from our tracking list when they are deleted by queue_free_delayed
	# but we can also explicitly check distance here if needed.
	active_segments = active_segments.filter(func(s): return s.is_inside_tree())
