extends Node3D

const SEGMENT_LENGTH := 20.0
const INITIAL_SEGMENTS := 12
const RENDER_DISTANCE := 6
const CLEANUP_DISTANCE := 40.0

@export var road_segment_scene: PackedScene = preload("res://scenes/RoadSegment.tscn")
@export var obstacle_scene: PackedScene = preload("res://scenes/Obstacle.tscn")
@export var coin_scene: PackedScene = preload("res://scenes/Coin.tscn")
@export var boost_scene: PackedScene = preload("res://scenes/Boost.tscn")

var player: Node3D
var next_spawn_z := 0.0
var active_segments: Array[Node3D] = []
var active_props: Array[Node3D] = []

func _ready() -> void:
	player = get_tree().root.find_child("Player", true, false)
	for i in range(INITIAL_SEGMENTS):
		# First few segments are clear so the player can start safely
		spawn_segment(i >= 3)

func _process(_delta: float) -> void:
	if GameManager.is_game_over:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().root.find_child("Player", true, false)
		return

	if player.global_position.z < next_spawn_z + (RENDER_DISTANCE * SEGMENT_LENGTH):
		spawn_segment(true)

	_cleanup_behind_player()

func spawn_segment(with_props: bool = true) -> void:
	var segment: Node3D = road_segment_scene.instantiate()
	segment.position.z = next_spawn_z
	add_child(segment)
	active_segments.append(segment)

	if with_props:
		if randf() < 0.35:
			_spawn_prop(obstacle_scene, next_spawn_z, 0.5)
		if randf() < 0.55:
			_spawn_prop(coin_scene, next_spawn_z, 1.0)
		if randf() < 0.12:
			_spawn_prop(boost_scene, next_spawn_z, 0.75)

	next_spawn_z -= SEGMENT_LENGTH

func _spawn_prop(scene: PackedScene, z_pos: float, y_pos: float) -> void:
	var prop: Node3D = scene.instantiate()
	var lane := randi_range(-1, 1)
	prop.position = Vector3(lane * 3.0, y_pos, z_pos - randf_range(2.0, 16.0))
	add_child(prop)
	active_props.append(prop)

func _cleanup_behind_player() -> void:
	var cutoff := player.global_position.z + CLEANUP_DISTANCE
	active_segments = active_segments.filter(func(s: Node3D) -> bool:
		if not is_instance_valid(s):
			return false
		if s.global_position.z > cutoff:
			s.queue_free()
			return false
		return true
	)
	active_props = active_props.filter(func(p: Node3D) -> bool:
		if not is_instance_valid(p):
			return false
		if p.global_position.z > cutoff:
			p.queue_free()
			return false
		return true
	)
