extends Node3D

const SEGMENT_LENGTH := 20.0
const INITIAL_SEGMENTS := 12
const RENDER_DISTANCE := 6
const CLEANUP_DISTANCE := 40.0
const LANE_WIDTH := 3.0

@export var road_segment_scene: PackedScene = preload("res://scenes/RoadSegment.tscn")
@export var obstacle_scene: PackedScene = preload("res://scenes/Obstacle.tscn")
@export var coin_scene: PackedScene = preload("res://scenes/Coin.tscn")
@export var boost_scene: PackedScene = preload("res://scenes/Boost.tscn")

var player: Node3D
var next_spawn_z := 0.0
var active_segments: Array[Node3D] = []
var active_props: Array[Node3D] = []
## Soft telegraph: skip hard patterns for a few segments after a dense one.
var _ease_segments := 0
var _pattern_index := 0
var _overhead_introduced := false

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
		_spawn_pattern(next_spawn_z)

	next_spawn_z -= SEGMENT_LENGTH

func _spawn_pattern(seg_z: float) -> void:
	# Readable, telegraphed patterns — not pure random soup.
	if _ease_segments > 0:
		_ease_segments -= 1
		# Light coin snack during ease so the road never feels empty
		if randf() < 0.55:
			_pattern_coin_line(seg_z, randi_range(-1, 1), 3)
		return

	var patterns := [
		"single_block",
		"two_gate",
		"coin_line",
		"coin_arc",
		"coins_then_block",
		"boost_lane",
		"overhead_bar",
		"overhead_bar",
		"empty",
	]
	# Weight toward readable hazards after warm-up
	_pattern_index += 1
	var pick: String = patterns[randi() % patterns.size()]
	if _pattern_index < 4 and pick in ["two_gate", "coins_then_block", "overhead_bar"]:
		pick = "coin_line"
	# Teach the duck once the opening stretch is over, then keep it in the mix.
	if not _overhead_introduced and _pattern_index >= 4:
		pick = "overhead_bar"
		_overhead_introduced = true

	match pick:
		"single_block":
			_pattern_single_block(seg_z)
			_ease_segments = 1
		"two_gate":
			_pattern_two_gate(seg_z)
			_ease_segments = 1
		"overhead_bar":
			_pattern_overhead_bar(seg_z)
			_ease_segments = 1
		"coin_line":
			_pattern_coin_line(seg_z, randi_range(-1, 1), 5)
		"coin_arc":
			_pattern_coin_arc(seg_z)
		"coins_then_block":
			_pattern_coins_then_block(seg_z)
			_ease_segments = 1
		"boost_lane":
			_pattern_boost(seg_z)
		_:
			pass

func _pattern_overhead_bar(seg_z: float) -> void:
	# Full-width magenta hanging gate. Red blocks stay jump-only.
	# The lip sits above the slide duck and the panel rises past jump apex.
	var bar: Node3D = obstacle_scene.instantiate()
	bar.set("kind", "overhead")
	bar.name = "OverheadBar"
	bar.position = Vector3(0.0, 0.0, seg_z - 10.0)
	add_child(bar)
	active_props.append(bar)
	for lane in [-1, 0, 1]:
		_spawn_at(coin_scene, lane, 0.32, seg_z - 10.0)

func _pattern_single_block(seg_z: float) -> void:
	var lane := randi_range(-1, 1)
	# Mid-segment so camera sees it with reaction space
	_spawn_at(obstacle_scene, lane, 0.5, seg_z - 10.0)

func _pattern_two_gate(seg_z: float) -> void:
	var open := randi_range(-1, 1)
	for lane in [-1, 0, 1]:
		if lane != open:
			_spawn_at(obstacle_scene, lane, 0.5, seg_z - 10.0)
	# Coin bait through the open lane
	_spawn_at(coin_scene, open, 1.0, seg_z - 6.0)
	_spawn_at(coin_scene, open, 1.0, seg_z - 14.0)

func _pattern_coin_line(seg_z: float, lane: int, count: int) -> void:
	var start := 4.0
	var step := 2.6
	for i in count:
		_spawn_at(coin_scene, lane, 1.0, seg_z - start - float(i) * step)

func _pattern_coin_arc(seg_z: float) -> void:
	# Arc across lanes: L -> C -> R -> C -> L (or mirrored)
	var lanes := [-1, 0, 1, 0, -1]
	if randf() < 0.5:
		lanes = [1, 0, -1, 0, 1]
	var start := 3.5
	var step := 2.8
	for i in lanes.size():
		_spawn_at(coin_scene, lanes[i], 1.0, seg_z - start - float(i) * step)

func _pattern_coins_then_block(seg_z: float) -> void:
	var lane := randi_range(-1, 1)
	# Coins first (farther ahead = more negative relative offset from seg front)
	_spawn_at(coin_scene, lane, 1.0, seg_z - 4.0)
	_spawn_at(coin_scene, lane, 1.0, seg_z - 6.5)
	_spawn_at(coin_scene, lane, 1.0, seg_z - 9.0)
	# Late obstacle after the reward — telegraph by spacing
	_spawn_at(obstacle_scene, lane, 0.5, seg_z - 15.5)

func _pattern_boost(seg_z: float) -> void:
	var lane := randi_range(-1, 1)
	_spawn_at(boost_scene, lane, 0.75, seg_z - 10.0)
	# Clear the other lanes lightly so boost is readable
	if randf() < 0.4:
		var other := lane + 1 if lane < 1 else -1
		_spawn_at(coin_scene, other, 1.0, seg_z - 6.0)

func _spawn_at(scene: PackedScene, lane: int, y_pos: float, z_pos: float) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = Vector3(float(lane) * LANE_WIDTH, y_pos, z_pos)
	add_child(prop)
	active_props.append(prop)

func _cleanup_behind_player() -> void:
	var cutoff := player.global_position.z + CLEANUP_DISTANCE
	# Typed Array.filter returns an untyped Array on Godot 4.5 and the
	# assignment throws every frame, so props never actually drop.
	active_segments = _keep_ahead(active_segments, cutoff)
	active_props = _keep_ahead(active_props, cutoff)

func _keep_ahead(nodes: Array[Node3D], cutoff: float) -> Array[Node3D]:
	var kept: Array[Node3D] = []
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if n.global_position.z > cutoff:
			n.queue_free()
			continue
		kept.append(n)
	return kept
