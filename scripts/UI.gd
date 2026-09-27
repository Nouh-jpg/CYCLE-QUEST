extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var game_over_panel: ColorRect = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_panel.visible = false
	GameManager.reset_run_state()
	get_tree().paused = false

func update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value

func show_game_over() -> void:
	if GameManager.is_game_over:
		return
	GameManager.is_game_over = true
	game_over_panel.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	GameManager.reset_run_state()
	get_tree().paused = false
	get_tree().reload_current_scene()
