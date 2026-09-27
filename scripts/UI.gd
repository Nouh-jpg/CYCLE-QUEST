extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var hint_label: Label = $HintLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var touch_controls: Control = $TouchControls

var combo_label: Label
var speed_label: Label
var speed_bar: ProgressBar
var stats_label: Label
var popup_host: Control
var danger_vignette: ColorRect
var near_miss_flash: ColorRect
var danger_edges: Array[ColorRect] = []
var _popup_seq := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_panel.visible = false
	GameManager.reset_run_state()
	get_tree().paused = false
	_sync_touch_controls(true)
	_build_extra_hud()
	_style_game_over_card()
	update_score(0)
	update_combo(0)
	update_speed(15.0, 28.0)
	var ga := get_node_or_null("/root/GameAudio")
	if ga and ga.has_method("start_music"):
		ga.start_music()

func _build_extra_hud() -> void:
	# Dark translucent backing keeps the score readable over the bright road.
	var hud_back := Panel.new()
	hud_back.name = "HudBacking"
	hud_back.position = Vector2(16, 16)
	hud_back.size = Vector2(250, 148)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.035, 0.025, 0.11, 0.78)
	hud_style.border_width_left = 2
	hud_style.border_width_top = 2
	hud_style.border_width_right = 2
	hud_style.border_width_bottom = 2
	hud_style.border_color = Color(0.45, 0.82, 1.0, 0.7)
	hud_style.corner_radius_top_left = 16
	hud_style.corner_radius_top_right = 16
	hud_style.corner_radius_bottom_left = 16
	hud_style.corner_radius_bottom_right = 16
	hud_back.add_theme_stylebox_override("panel", hud_style)
	hud_back.z_index = -1
	add_child(hud_back)
	score_label.position = Vector2(30, 25)
	score_label.size = Vector2(225, 43)
	score_label.label_settings.font_size = 31

	# Combo
	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.position = Vector2(32, 67)
	combo_label.size = Vector2(220, 30)
	combo_label.text = ""
	var cs := LabelSettings.new()
	cs.font_size = 22
	cs.font_color = Color(1.0, 0.55, 1.0)
	cs.outline_size = 5
	cs.outline_color = Color(0.15, 0.0, 0.25)
	combo_label.label_settings = cs
	add_child(combo_label)

	# Speed meter
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.position = Vector2(32, 105)
	speed_label.size = Vector2(140, 25)
	var ss := LabelSettings.new()
	ss.font_size = 17
	ss.font_color = Color(0.45, 1.0, 0.95)
	ss.outline_size = 4
	ss.outline_color = Color(0.0, 0.15, 0.2)
	speed_label.label_settings = ss
	add_child(speed_label)

	speed_bar = ProgressBar.new()
	speed_bar.name = "SpeedBar"
	speed_bar.position = Vector2(160, 108)
	speed_bar.size = Vector2(80, 14)
	speed_bar.min_value = 0
	speed_bar.max_value = 100
	speed_bar.value = 0
	speed_bar.show_percentage = false
	speed_bar.modulate = Color(0.4, 1.0, 0.9)
	speed_bar.add_theme_stylebox_override("background", _make_meter_style(Color(0.1, 0.12, 0.22, 0.95)))
	speed_bar.add_theme_stylebox_override("fill", _make_meter_style(Color(0.2, 0.95, 0.82, 1.0)))
	add_child(speed_bar)

	# Floating popup host (center-ish)
	popup_host = Control.new()
	popup_host.name = "PopupHost"
	popup_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_host)

	# Danger vignette (chaser close)
	danger_vignette = ColorRect.new()
	danger_vignette.name = "DangerVignette"
	danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	danger_vignette.color = Color(0.85, 0.05, 0.15, 0.0)
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.z_index = 40
	add_child(danger_vignette)

	near_miss_flash = ColorRect.new()
	near_miss_flash.name = "NearMissFlash"
	near_miss_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	near_miss_flash.color = Color(1.0, 0.7, 1.0, 0.0)
	near_miss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_miss_flash.z_index = 41
	add_child(near_miss_flash)
	_build_crash_vignette()

	# Punchier score label
	if score_label and score_label.label_settings:
		score_label.label_settings.font_size = 36
		score_label.label_settings.font_color = Color(1.0, 0.95, 0.35)
		score_label.label_settings.outline_size = 6

func _make_meter_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style

func _build_crash_vignette() -> void:
	# Four soft red edge panels frame danger without hiding the road.
	for edge in ["Top", "Bottom", "Left", "Right"]:
		var panel := ColorRect.new()
		panel.name = "DangerEdge%s" % edge
		panel.color = Color(1.0, 0.035, 0.12, 0.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 39
		match edge:
			"Top":
				panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
				panel.offset_bottom = 42.0
			"Bottom":
				panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				panel.offset_top = -42.0
			"Left":
				panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
				panel.offset_right = 42.0
			"Right":
				panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
				panel.offset_left = -42.0
		add_child(panel)
		danger_edges.append(panel)

func _style_game_over_card() -> void:
	game_over_panel.color = Color(0.06, 0.02, 0.14, 0.94)
	game_over_panel.offset_left = -260.0
	game_over_panel.offset_top = -150.0
	game_over_panel.offset_right = 260.0
	game_over_panel.offset_bottom = 150.0

	var go_label := game_over_panel.get_node_or_null("GameOverLabel") as Label
	if go_label and go_label.label_settings:
		go_label.label_settings.font_color = Color(1.0, 0.25, 0.45)
		go_label.label_settings.font_size = 52
		go_label.offset_bottom = 80.0

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	stats_label.anchor_top = 0.0
	stats_label.anchor_bottom = 0.0
	stats_label.offset_left = 20.0
	stats_label.offset_right = -20.0
	stats_label.offset_top = 88.0
	stats_label.offset_bottom = 170.0
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st := LabelSettings.new()
	st.font_size = 22
	st.font_color = Color(0.85, 0.95, 1.0)
	st.outline_size = 4
	st.outline_color = Color(0, 0, 0)
	stats_label.label_settings = st
	game_over_panel.add_child(stats_label)

	if restart_button:
		restart_button.text = "TRY AGAIN"
		restart_button.offset_top = -78.0
		restart_button.offset_bottom = -28.0

func update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value

func update_combo(value: int) -> void:
	if combo_label == null:
		return
	if value >= 2:
		combo_label.text = "COMBO x%d" % mini(value, 8)
		combo_label.modulate = Color(1, 1, 1, 1)
		var tw := create_tween()
		tw.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.08)
		tw.tween_property(combo_label, "scale", Vector2.ONE, 0.12)
	else:
		combo_label.text = ""

func update_speed(speed: float, max_speed: float) -> void:
	if speed_label == null:
		return
	speed_label.text = "SPEED %d" % int(round(speed))
	if speed_bar:
		speed_bar.value = clampf(speed / max_speed, 0.0, 1.0) * 100.0

func set_danger_level(level: float) -> void:
	if danger_vignette == null:
		return
	var a := clampf(level, 0.0, 1.0) * 0.42
	# Soft pulse when very close
	if level > 0.65:
		a += sin(Time.get_ticks_msec() * 0.02) * 0.06
	danger_vignette.color.a = maxf(0.0, a)
	for edge in danger_edges:
		if is_instance_valid(edge):
			edge.color.a = clampf(level, 0.0, 1.0) * 0.38

func popup_points(text: String, color: Color = Color.WHITE) -> void:
	if popup_host == null:
		return
	_popup_seq += 1
	var lbl := Label.new()
	lbl.text = text
	var ls := LabelSettings.new()
	ls.font_size = 34 if text.begins_with("CLOSE") or text.begins_with("BOOST") else 28
	ls.font_color = color
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 1)
	lbl.label_settings = ls
	lbl.position = Vector2(520 + randf_range(-40, 40), 220 + randf_range(-20, 20))
	lbl.z_index = 50
	popup_host.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 70.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

func flash_near_miss() -> void:
	if near_miss_flash == null:
		return
	near_miss_flash.color.a = 0.35
	var tw := create_tween()
	tw.tween_property(near_miss_flash, "color:a", 0.0, 0.25)

func show_game_over() -> void:
	if GameManager.is_game_over:
		return
	GameManager.is_game_over = true
	var player = get_tree().root.find_child("Player", true, false)
	var dist := 0.0
	var sc := 0
	if player:
		if "distance_traveled" in player:
			dist = float(player.distance_traveled)
		if "score" in player:
			sc = int(player.score)
	GameManager.record_run(sc, dist)
	var ga := get_node_or_null("/root/GameAudio")
	if ga:
		if ga.has_method("play_sfx"):
			ga.play_sfx("crash")
		if ga.has_method("stop_music"):
			ga.stop_music()
	if stats_label:
		stats_label.text = "Distance: %dm\nScore: %d\nBest: %d" % [
			int(round(dist)), sc, GameManager.best_score
		]
	game_over_panel.visible = true
	_sync_touch_controls(false)
	get_tree().paused = true

func _on_restart_pressed() -> void:
	GameManager.reset_run_state()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _sync_touch_controls(active: bool) -> void:
	if touch_controls and touch_controls.has_method("set_gameplay_active"):
		touch_controls.set_gameplay_active(active)
	# Hide keyboard hint when on-screen pads are visible to avoid overlap.
	if hint_label:
		var pads_visible := touch_controls != null and touch_controls.visible
		hint_label.visible = not pads_visible
