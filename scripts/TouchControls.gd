extends Control
## Thumb-friendly on-screen controls for lane / jump / slide.
## Emits the same InputMap actions Player.gd already reads so keyboard stays intact.

const BTN := Vector2(112, 112)
const GAP := 16.0
const EDGE := 24.0

## Project setting (bool). Off for a clean Windows/Steam frame.
## Android and other touch devices still show the pads.
const SETTING_ALWAYS_SHOW := "cycle_quest/always_show_touch_controls"

var _active := true
var _left_btn: Button
var _right_btn: Button
var _jump_btn: Button
var _slide_btn: Button
var _held_actions: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_apply_visibility()
	# Re-evaluate after a frame in case DisplayServer reports late on some platforms.
	call_deferred("_apply_visibility")

func _build_ui() -> void:
	var left_cluster := HBoxContainer.new()
	left_cluster.name = "LeftCluster"
	left_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_cluster.add_theme_constant_override("separation", int(GAP))
	left_cluster.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_cluster.anchor_left = 0.0
	left_cluster.anchor_top = 1.0
	left_cluster.anchor_right = 0.0
	left_cluster.anchor_bottom = 1.0
	left_cluster.offset_left = EDGE
	left_cluster.offset_top = -(EDGE + BTN.y)
	left_cluster.offset_right = EDGE + BTN.x * 2.0 + GAP
	left_cluster.offset_bottom = -EDGE
	add_child(left_cluster)

	_left_btn = _make_button("LeftBtn", "◀", Color(0.55, 0.35, 1.0, 0.78), Color(0.75, 0.55, 1.0, 0.95))
	_right_btn = _make_button("RightBtn", "▶", Color(0.55, 0.35, 1.0, 0.78), Color(0.75, 0.55, 1.0, 0.95))
	left_cluster.add_child(_left_btn)
	left_cluster.add_child(_right_btn)

	var right_cluster := VBoxContainer.new()
	right_cluster.name = "RightCluster"
	right_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_cluster.add_theme_constant_override("separation", int(GAP))
	right_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_cluster.anchor_left = 1.0
	right_cluster.anchor_top = 1.0
	right_cluster.anchor_right = 1.0
	right_cluster.anchor_bottom = 1.0
	right_cluster.offset_left = -(EDGE + BTN.x)
	right_cluster.offset_top = -(EDGE + BTN.y * 2.0 + GAP)
	right_cluster.offset_right = -EDGE
	right_cluster.offset_bottom = -EDGE
	add_child(right_cluster)

	_jump_btn = _make_button("JumpBtn", "JUMP", Color(0.15, 0.85, 0.95, 0.78), Color(0.45, 1.0, 1.0, 0.95))
	_slide_btn = _make_button("SlideBtn", "SLIDE", Color(1.0, 0.35, 0.7, 0.78), Color(1.0, 0.55, 0.85, 0.95))
	right_cluster.add_child(_jump_btn)
	right_cluster.add_child(_slide_btn)

	_wire(_left_btn, "ui_left")
	_wire(_right_btn, "ui_right")
	_wire(_jump_btn, "ui_accept")
	_wire(_slide_btn, "ui_down")

func _make_button(p_name: String, label: String, idle: Color, pressed_col: Color) -> Button:
	var btn := Button.new()
	btn.name = p_name
	btn.text = label
	btn.custom_minimum_size = BTN
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_stylebox_override("normal", _style(idle))
	btn.add_theme_stylebox_override("hover", _style(idle.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _style(pressed_col))
	btn.add_theme_stylebox_override("disabled", _style(Color(idle.r, idle.g, idle.b, 0.35)))
	btn.add_theme_stylebox_override("focus", _style(idle))
	return btn

func _style(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left = 28
	sb.corner_radius_top_right = 28
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0.08, 0.04, 0.16, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb

func _wire(btn: Button, action: String) -> void:
	btn.button_down.connect(_on_down.bind(action))
	btn.button_up.connect(_on_up.bind(action))

func _on_down(action: String) -> void:
	if not _active or GameManager.is_game_over:
		return
	if not Input.is_action_pressed(action):
		Input.action_press(action)
		if action not in _held_actions:
			_held_actions.append(action)

func _on_up(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)
	_held_actions.erase(action)

func set_gameplay_active(active: bool) -> void:
	_active = active
	_apply_visibility()

func _set_buttons_enabled(enabled: bool) -> void:
	for btn in [_left_btn, _right_btn, _jump_btn, _slide_btn]:
		if btn:
			btn.disabled = not enabled
			btn.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _release_all() -> void:
	for action in _held_actions.duplicate():
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_held_actions.clear()

func _should_show() -> bool:
	var always := false
	if ProjectSettings.has_setting(SETTING_ALWAYS_SHOW):
		always = bool(ProjectSettings.get_setting(SETTING_ALWAYS_SHOW))
	if always:
		return true
	return (
		DisplayServer.is_touchscreen_available()
		or OS.has_feature("mobile")
		or OS.has_feature("android")
		or OS.has_feature("ios")
	)

func _apply_visibility() -> void:
	var show_controls := _should_show() and _active and not GameManager.is_game_over
	visible = show_controls
	_set_buttons_enabled(show_controls)
	if not show_controls:
		_release_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()
