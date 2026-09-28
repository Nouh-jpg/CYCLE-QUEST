extends SceneTree
## Headless checks: the chaser stays offstage until a hit, one stumble does
## not end the run, slide clears the magenta gate, and jump clears a red block.

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
	var lower_col := bar.get_node("CollisionShape3D") as CollisionShape3D
	var lower_shape := lower_col.shape as BoxShape3D
	print("GATE bottom=%.3f thick=%.3f stand_top=%.3f" % [beam_bottom, lower_shape.size.y, stand_top])
	if lower_shape.size.y > 0.55:
		_fail("Limbo bar is still a wall (thickness %.3f)" % lower_shape.size.y)
	if beam_bottom < 1.35:
		_fail("Gate crawl gap is too low (bottom %.3f)" % beam_bottom)
	var upper := bar.get_node_or_null("UpperRail") as CollisionShape3D
	if upper == null or not (upper.shape is BoxShape3D):
		_fail("Jump rail is missing")
		return
	var upper_shape := upper.shape as BoxShape3D
	if upper_shape.size.y > 0.55:
		_fail("Upper rail is too thick (%.3f)" % upper_shape.size.y)
	var posts := bar.find_children("GatePost*", "", true, false)
	if posts.size() < 2:
		_fail("Gate posts missing")
	else:
		var post_mesh := (posts[0] as MeshInstance3D).mesh as BoxMesh
		if post_mesh != null and post_mesh.size.y > 3.05:
			_fail("Gate posts are still a wall (height %.2f)" % post_mesh.size.y)
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
	var slide_visual := player.get("visual_root") as Node3D
	if slide_visual:
		var card_top := 3.0 * slide_visual.scale.y
		print("SLIDE card_top=%.3f bar_bottom=%.3f" % [card_top, beam_bottom])
		if card_top > beam_bottom - 0.22:
			_fail("Crouch still fills the gap under the bar (card %.3f, bar %.3f)" % [card_top, beam_bottom])
	var slide_hit := await _query_overlap(player, bar)
	print("GATE while sliding overlap=%s slide_top=%.3f" % [slide_hit, slide_top_2])
	if slide_hit:
		_fail("Slide still hits the magenta gate (top %.3f, beam %.3f)" % [slide_top_2, beam_bottom])
	if slide_top_2 > beam_bottom - 0.2:
		_fail("Slide top %.3f is not clearly under beam bottom %.3f" % [slide_top_2, beam_bottom])
	while player.is_sliding:
		await physics_frame
	# Standing capsule at jump apex. The ducked pose must not be what we test.
	var jump_rise := (9.5 * 9.5) / (2.0 * 24.0)
	var jump_hit := await _query_overlap_rise(player, bar, jump_rise)
	print("JUMP into gate overlap=%s rise=%.3f" % [jump_hit, jump_rise])
	if not jump_hit:
		_fail("Jump clears the hanging gate")
	bar.queue_free()

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
	if bool(chaser.engaged) or chaser.visible:
		_fail("Chaser is in the chase before any hit")
		return
	var opening_gap := chaser.global_position.z - player.global_position.z
	print("CHASER opening_gap=%.2f engaged=%s" % [opening_gap, chaser.engaged])
	if opening_gap < 18.0:
		_fail("Chaser starts too close (gap %.2f)" % opening_gap)
		return
	# Several seconds of clean riding: no hit, so the chaser must stay offstage.
	const GRACE_FRAMES := 480
	var min_gap := opening_gap
	var saw_gate := false
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	for i in 1500:
		_silence_obstacles()
		await physics_frame
		if bool(root.get_node("GameManager").is_game_over):
			_fail("Run ended during the opening (frame %d, no hits)" % i)
			return
		if bool(chaser.engaged) or chaser.visible:
			_fail("Chaser engaged with no hit at frame %d" % i)
			return
		if cam and _chaser_drawn_in_view(cam, chaser):
			_fail("Chaser is on screen during the clean opening at frame %d" % i)
			return
		var gap := chaser.global_position.z - player.global_position.z
		min_gap = minf(min_gap, gap)
		if gap < 18.0:
			_fail("Chaser approached before any hit (gap %.2f at frame %d)" % [gap, i])
			return
		if i == GRACE_FRAMES - 1:
			print("GRACE %.1fs gap=%.2f game_over=false" % [float(GRACE_FRAMES) / 60.0, gap])
		if not root.find_children("OverheadBar", "", true, false).is_empty():
			saw_gate = true
	print("CHASER dormant min_gap=%.2f saw_gate=%s" % [min_gap, saw_gate])
	if not saw_gate:
		_fail("No magenta OverheadBar spawned on the road")

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
	if bool(chaser.engaged) or gap0 < 18.0:
		_fail("Chaser was already chasing before the boost (gap %.2f)" % gap0)
		return
	player.apply_boost()
	for _i in 50:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("Boost ended the run")
		return
	if bool(chaser.engaged):
		_fail("Boost summoned the chaser")
		return
	var boosted := float(player.current_speed)
	var gap1 := float(chaser.global_position.z - player.global_position.z)
	print("BOOST speed=%.1f cruise=%.1f gap %.2f -> %.2f" % [boosted, cruise, gap0, gap1])
	if boosted < cruise + 10.0:
		_fail("Boost did not surge speed (%.1f vs cruise %.1f)" % [boosted, cruise])
	if gap1 < 18.0:
		_fail("Chaser approached during the opening boost (%.2f -> %.2f)" % [gap0, gap1])
	player.set("_boost_timer", 0.0)
	var before := float(player.current_speed)
	player.on_obstacle_hit()
	if not bool(chaser.engaged):
		_fail("Obstacle hit did not bring the chaser in")
		return
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
	_assert_chaser_in_frame(player, chaser)
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
	# Rest of this stumble, with no second hit and no boost. One hit is not a catch.
	var min_gap := gap3
	for _i in 220:
		_silence_obstacles()
		await physics_frame
		if bool(gm.is_game_over):
			_fail("A single obstacle hit ended the run")
			return
		min_gap = minf(min_gap, chaser.global_position.z - player.global_position.z)
	print("HIT survived min_gap=%.2f" % min_gap)
	if min_gap <= 1.55:
		_fail("A single hit let the chaser catch (min gap %.2f)" % min_gap)
	var away_cam := player.get_node_or_null("Camera3D") as Camera3D
	player.apply_boost()
	for _i in 20:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("Boost after a hit ended the run")
		return
	var gap_away := float(chaser.global_position.z - player.global_position.z)
	print("AWAY engaged=%s visible=%s gap=%.2f speed=%.1f" % [
		chaser.engaged, chaser.visible, gap_away, float(player.current_speed)
	])
	if bool(chaser.engaged) or chaser.visible:
		_fail("Boost did not stop the chase")
		return
	if float(player.current_speed) < float(player.cruise_speed) + 10.0:
		_fail("Boost after a hit did not surge speed")
	if gap_away < 18.0:
		_fail("Chaser still close after boost (gap %.2f)" % gap_away)
	if away_cam and _chaser_drawn_in_view(away_cam, chaser):
		_fail("Chaser still on screen after the boost")
	# A later crash brings the pursuer back. That hit is still not a catch.
	player.on_obstacle_hit()
	for _i in 12:
		_silence_obstacles()
		await physics_frame
	if bool(gm.is_game_over):
		_fail("Second hit ended the run")
		return
	if not bool(chaser.engaged) or not chaser.visible:
		_fail("A later hit did not bring the chaser back")
		return
	_assert_chaser_in_frame(player, chaser)

func _assert_chaser_in_frame(player: Node, chaser: Node3D) -> void:
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_fail("Camera missing")
		return
	var gap := float(chaser.global_position.z - player.global_position.z)
	var side := float(chaser.global_position.x - player.global_position.x)
	var clear := cam.global_position.z - (chaser.global_position.z + 0.62)
	print("CHASER engaged gap=%.2f side=%.2f clear=%.2f" % [gap, side, clear])
	if gap <= 1.55:
		_fail("Chaser caught on arrival (gap %.2f)" % gap)
	if clear < 3.2:
		_fail("Chaser within %.2fm of the camera" % clear)
	if side < 0.85:
		_fail("Chaser drifted onto the rider (side %.2f)" % side)
	var span := _screen_span(cam, chaser)
	if span.x < 0.0:
		_fail("Chaser crossed the camera plane")
		return
	if span.x > 0.12 or span.y > 0.45 or span.z > 0.5:
		_fail("Chaser screen coverage too large area=%.3f w=%.3f h=%.3f" % [span.x, span.y, span.z])
	if span.x <= 0.001:
		_fail("Chaser never appeared on screen after the hit")

func _chaser_drawn_in_view(cam: Camera3D, chaser: Node3D) -> bool:
	if not chaser.visible:
		return false
	var visual := chaser.get_node_or_null("Visual") as Node3D
	if visual == null or not visual.visible:
		return false
	var vp := cam.get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return false
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
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
						continue
					var sp := cam.unproject_position(world)
					if sp.x >= -8.0 and sp.x <= vp.x + 8.0 and sp.y >= -8.0 and sp.y <= vp.y + 8.0:
						return true
	return false

func _query_overlap_rise(player: CharacterBody3D, area: Area3D, rise: float) -> bool:
	area.global_position = Vector3(player.global_position.x, area.global_position.y, player.global_position.z)
	await physics_frame
	var space := player.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var col := player.get_node("CollisionShape3D") as CollisionShape3D
	params.shape = col.shape
	var xf := col.global_transform
	xf.origin.y += rise
	params.transform = xf
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 4
	for item in space.intersect_shape(params, 8):
		if item.collider == area:
			return true
	return false

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
