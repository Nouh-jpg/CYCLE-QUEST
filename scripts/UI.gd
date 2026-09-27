extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var hint_label: Label = $HintLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var touch_controls: Control = $TouchControls

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_panel.visible = false
	GameManager.reset_run_state()
	get_tree().paused = false
	_sync_touch_controls(true)

func update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value

func show_game_over() -> void:
	if GameManager.is_game_over:
		return
	GameManager.is_game_over = true
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
