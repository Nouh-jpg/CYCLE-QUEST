extends SceneTree
## Headless checks: chaser stays off the lens, the existing slide duck
## clears the magenta hanging gate, and jump still clears a red low block.

var _failed := false

func _initialize() -> void:
	await _run()

func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn failed to load")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 40:
		await physics_frame
	var player := root.find_child("Player", true, false) as CharacterBody3D
	var chaser := root.find_child("Chaser", true, false) as CharacterBody3D
	if player == null or chaser == null:
		_fail("Player or Chaser missing")
		quit(1)
		return
	if not player.is_on_floor():
		_fail("Player never landed (y=%.2f)" % player.global_position.y)
	else:
		print("SETTLED player_y=%.3f on_floor=true" % player.global_position.y)

	await _test_slide(main, player)
	await _test_music()
	await _test_chaser(player, chaser)
	await _test_boost_and_hit(player, chaser)
	if _failed:
		print("SMOKE FAIL")
		quit(1)
	else:
		print("SMOKE PASS")
		quit(0)

func _test_slide(main: Node, player: CharacterBody3D) -> void:
	var touch := root.find_child("TouchControls", true, false)
	if touch == null or not touch.has_method("_on_down"):
		_fail("TouchControls slide wiring missing")
		return
	# physics_frame resumes before _physics_process, and action_press is
	# just_pressed on the following physics step. Wait for that step.
	touch._on_down("ui_down")
	if not Input.is_action_pressed("ui_down"):
		_fail("Slide button did not press ui_down")
		return
	await physics_frame
	await physics_frame
	touch._on_up("ui_down")
	if not player.is_sliding:
		_fail("Touch SLIDE did not start a slide (on_floor=%s)" % player.is_on_floor())
		return
	var slide_top := _capsule_top(player)
	var slide_col := player.get_node("CollisionShape3D") as CollisionShape3D
	var slide_scale_y := slide_col.scale.y
	print("SLIDE touch scale_y=%.3f world_top=%.3f" % [slide_scale_y, slide_top])
	if slide_scale_y > 0.75:
		_fail("Slide did not duck the hitbox (scale.y %.3f)" % slide_scale_y)
	if slide_top > 1.16:
		_fail("Slide hurtbox top %.3f is too tall to clear the gate" % slide_top)

	var low := _spawn_obstacle(main, "low", Vector3(player.global_position.x, 0.5, player.global_position.z))
	var low_top := _box_top(low)
	var low_hit := await _query_overlap(player, low)
	print("LOW while sliding overlap=%s low_top=%.3f" % [low_hit, low_top])
	if not low_hit:
		_fail("Slide passed through a red low block; jump would not be required")
	# Jump rise is from the road, not the ducked pose.
	var stand_half := 0.8
	var apex_bottom := 0.1 + (9.5 * 9.5) / (2.0 * 24.0)
	print("JUMP apex_bottom=%.3f low_top=%.3f" % [apex_bottom, low_top])
	if apex_bottom < low_top + 0.15:
		_fail("Jump apex bottom %.3f does not clear low top %.3f" % [apex_bottom, low_top])
	low.queue_free()

	var guard := 0
	while player.is_sliding and guard < 90:
		await physics_frame
		guard += 1
	if player.is_sliding:
		_fail("Slide did not finish")
		return
	var stand_top := _capsule_top(player)
	var stand_col := player.get_node("CollisionShape3D") as CollisionShape3D
	print("STAND scale_y=%.3f world_top=%.3f" % [stand_col.scale.y, stand_top])
	if stand_col.scale.y < 0.9:
		_fail("Hurtbox did not restore after slide")

	var bar := _spawn_obstacle(main, "overhead", Vector3(player.global_position.x, 0.0, player.global_position.z))
	if bar == null or str(bar.get("kind")) != "overhead":
		_fail("Overhead gate did not build")
		return
	var beam_bottom := _box_bottom(bar)
	var beam_top := _box_top(bar)
	print("GATE bottom=%.3f top=%.3f stand_top=%.3f" % [beam_bottom, beam_top, stand_top])
	if beam_bottom < 1.2:
		_fail("Gate crawl gap is too low (bottom %.3f)" % beam_bottom)
	if beam_top < apex_bottom + stand_half * 2.0 - 0.15:
		_fail("Gate is short enough to jump over (top %.3f)" % beam_top)
	if bar.get_node_or_null("DuckCues") == null or bar.find_children("LipStripe*", "", true, false).size() < 4:
		_fail("Hanging gate is missing the lip stripes or down-chevrons")
	var stand_hit := await _query_overlap(player, bar)
	print("GATE while standing overlap=%s" % stand_hit)
	if not stand_hit:
		_fail("Standing rider does not hit the magenta gate")

	Input.action_press("ui_down")
	await physics_frame
	await physics_frame
	Input.action_release("ui_down")
	if not player.is_sliding:
		_fail("Keyboard ui_down did not start a slide")
		return
	var slide_top_2 := _capsule_top(player)
	var slide_hit := await _query_overlap(player, bar)
	print("GATE while sliding overlap=%s slide_top=%.3f" % [slide_hit, slide_top_2])
	if slide_hit:
		_fail("Slide still hits the magenta gate (top %.3f, beam %.3f)" % [slide_top_2, beam_bottom])
	if slide_top_2 > beam_bottom - 0.05:
		_fail("Slide top %.3f is not under beam bottom %.3f" % [slide_top_2, beam_bottom])
	bar.queue_free()
	while player.is_sliding:
		await physics_frame

func _test_chaser(player: Node3D, chaser: CharacterBody3D) -> void:
	var body := chaser.get_node_or_null("Visual/Body") as MeshInstance3D
	if body == null or body.mesh == null:
		_fail("Chaser body mesh missing")
		return
	var bsize := (body.mesh as BoxMesh).size
	print("CHASER body_size=%s" % bsize)
	if bsize.y > 1.35 or bsize.x > 1.35:
		_fail("Chaser body still huge: %s" % bsize)
	var hidden := chaser.get_node_or_null("Mesh") as MeshInstance3D
	if hidden != null and hidden.visible:
		_fail("Placeholder chaser mesh is visible")
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_fail("Camera missing")
		return
	var max_area := 0.0
	var max_w := 0.0
	var max_h := 0.0
	var min_side := 100.0
	var min_clear := 100.0
	var min_gap := 100.0
	var saw_gate := false
	for i in 1500:
		_silence_obstacles()
		await physics_frame
		if bool(root.get_node("GameManager").is_game_over):
			_fail("Run ended during chaser sample frame %d" % i)
			return
		if i % 30 != 0:
			continue
		var gap := chaser.global_position.z - player.global_position.z
		var side := chaser.global_position.x - player.global_position.x
		var clear := cam.global_position.z - (chaser.global_position.z + 0.62)
		min_gap = minf(min_gap, gap)
		min_side = minf(min_side, side)
		min_clear = minf(min_clear, clear)
		if gap <= 1.55:
			_fail("Chaser caught the player during framing sample (gap %.2f)" % gap)
			return
		if clear < 3.2:
			_fail("Chaser within %.2fm of the camera" % clear)
			return
		if not root.find_children("OverheadBar", "", true, false).is_empty():
			saw_gate = true
		var span := _screen_span(cam, chaser)
		if span.x < 0.0:
			_fail("Chaser crossed the camera plane")
			return
		max_area = maxf(max_area, span.x)
		max_w = maxf(max_w, span.y)
		max_h = maxf(max_h, span.z)
	print("CHASER min_gap=%.2f min_side=%.2f min_clear=%.2f max_area=%.3f max_w=%.3f max_h=%.3f saw_gate=%s" % [
		min_gap, min_side, min_clear, max_area, max_w, max_h, saw_gate
	])
	if not saw_gate:
		_fail("No magenta OverheadBar spawned on the road")
	if min_side < 0.85:
		_fail("Chaser drifted onto the rider (side %.2f)" % min_side)
	if max_area > 0.12 or max_w > 0.45 or max_h > 0.5:
		_fail("Chaser screen coverage too large area=%.3f w=%.3f h=%.3f" % [max_area, max_w, max_h])
	if max_area <= 0.001:
		_fail("Chaser never appeared on screen")

func _test_music() -> void:
	var ga := root.get_node_or_null("GameAudio")
	if ga == null:
		_fail("GameAudio autoload missing")
		return
	var bed_player := ga.get_node_or_null("BGM") as AudioStreamPlayer
	var drive_player := ga.get_node_or_null("BGMDrive") as AudioStreamPlayer
	if bed_player == null or drive_player == null:
		_fail("Music players missing")
		return
	var bed := bed_player.stream as AudioStreamWAV
	var drive := drive_player.stream as AudioStreamWAV
	if bed == null or drive == null:
		_fail("BGM streams did not load")
		return
	print("MUSIC bed_bytes=%d drive_bytes=%d" % [bed.data.size(), drive.data.size()])
	if bed.data.size() < 700000 or drive.data.size() < 700000:
		_fail("BGM is still the short beep loop")
	if bed.data.size() != drive.data.size():
		_fail("Music layers differ in length")
	if not bed.stereo or not drive.stereo:
		_fail("Music layers are not stereo")

func _test_boost_and_hit(player: Node, chaser: Node3D) -> void:
	if not player.has_method("apply_boost") or not player.has_method("on_obstacle_hit"):
		_fail("Boost or hit handler missing")
		return
	var gm := root.get_node("GameManager")
	var cruise := float(player.cruise_speed)
	var gap0 := float(chaser.global_position.z - player.global_position.z)
	player.apply_boost()
	for _i in 50:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("Boost ended the run")
		return
	var boosted := float(player.current_speed)
	var gap1 := float(chaser.global_position.z - player.global_position.z)
	print("BOOST speed=%.1f cruise=%.1f gap %.2f -> %.2f" % [boosted, cruise, gap0, gap1])
	if boosted < cruise + 10.0:
		_fail("Boost did not surge speed (%.1f vs cruise %.1f)" % [boosted, cruise])
	if gap1 < gap0 + 0.35 and gap1 < 4.15:
		_fail("Boost did not open the chaser gap (%.2f -> %.2f)" % [gap0, gap1])
	player.set("_boost_timer", 0.0)
	var before := float(player.current_speed)
	player.on_obstacle_hit()
	for _i in 8:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("Obstacle hit ended the run")
		return
	var slowed := float(player.current_speed)
	print("HIT speed %.1f -> %.1f penalty=%.1f" % [before, slowed, float(player._speed_penalty)])
	if slowed > before - 8.0:
		_fail("Hit did not slow the player (%.1f -> %.1f)" % [before, slowed])
	var gap2 := float(chaser.global_position.z - player.global_position.z)
	for _i in 30:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("One stumble from a safe gap should not be a catch")
		return
	var gap3 := float(chaser.global_position.z - player.global_position.z)
	print("HIT gap %.2f -> %.2f" % [gap2, gap3])
	if gap3 > gap2 - 0.12:
		_fail("Chaser did not close during the slowdown (%.2f -> %.2f)" % [gap2, gap3])

func _screen_span(cam: Camera3D, chaser: Node3D) -> Vector3:
	var visual := chaser.get_node_or_null("Visual")
	if visual == null:
		return Vector3(-1, 0, 0)
	var pts: Array[Vector3] = []
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var ab: AABB = mi.mesh.get_aabb()
		var xf: Transform3D = mi.global_transform
		var a := ab.position
		var b := ab.position + ab.size
		for x in [a.x, b.x]:
			for y in [a.y, b.y]:
				for z in [a.z, b.z]:
					var world: Vector3 = xf * Vector3(x, y, z)
					if cam.is_position_behind(world):
						return Vector3(-1, 0, 0)
					pts.append(world)
	if pts.is_empty():
		return Vector3(-1, 0, 0)
	var vp := cam.get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return Vector3(-1, 0, 0)
	var min_p := Vector2(1e9, 1e9)
	var max_p := Vector2(-1e9, -1e9)
	for p in pts:
		var sp := cam.unproject_position(p)
		min_p.x = minf(min_p.x, sp.x)
		min_p.y = minf(min_p.y, sp.y)
		max_p.x = maxf(max_p.x, sp.x)
		max_p.y = maxf(max_p.y, sp.y)
	var w := clampf((max_p.x - min_p.x) / vp.x, 0.0, 4.0)
	var h := clampf((max_p.y - min_p.y) / vp.y, 0.0, 4.0)
	var center := vp * 0.5
	var covers_center := center.x >= min_p.x and center.x <= max_p.x and center.y >= min_p.y and center.y <= max_p.y
	if covers_center:
		_fail("Chaser screen rect covers the view center")
	return Vector3(w * h, w, h)

func _silence_obstacles() -> void:
	for n in root.find_children("*", "Area3D", true, false):
		if n.is_in_group("obstacles"):
			n.monitoring = false

func _spawn_obstacle(main: Node, kind: String, pos: Vector3) -> Area3D:
	var packed := load("res://scenes/Obstacle.tscn") as PackedScene
	var area := packed.instantiate() as Area3D
	area.set("kind", kind)
	main.add_child(area)
	area.global_position = pos
	for conn in area.body_entered.get_connections():
		area.body_entered.disconnect(conn.callable)
	return area

func _query_overlap(player: CharacterBody3D, area: Area3D) -> bool:
	var hit := false
	for _i in 3:
		area.global_position = Vector3(player.global_position.x, area.global_position.y, player.global_position.z)
		await physics_frame
		var space := player.get_world_3d().direct_space_state
		var params := PhysicsShapeQueryParameters3D.new()
		var col := player.get_node("CollisionShape3D") as CollisionShape3D
		params.shape = col.shape
		params.transform = col.global_transform
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.collision_mask = 4
		for item in space.intersect_shape(params, 8):
			if item.collider == area:
				hit = true
	return hit

func _capsule_top(player: CharacterBody3D) -> float:
	var col := player.get_node("CollisionShape3D") as CollisionShape3D
	var shape := col.shape as CapsuleShape3D
	return col.global_position.y + shape.height * 0.5 * absf(col.scale.y)

func _box_top(area: Area3D) -> float:
	var col := area.get_node("CollisionShape3D") as CollisionShape3D
	var shape := col.shape as BoxShape3D
	return col.global_position.y + shape.size.y * 0.5

func _box_bottom(area: Area3D) -> float:
	var col := area.get_node("CollisionShape3D") as CollisionShape3D
	var shape := col.shape as BoxShape3D
	return col.global_position.y - shape.size.y * 0.5

func _fail(msg: String) -> void:
	push_error(msg)
	print("FAIL: ", msg)
	_failed = true
