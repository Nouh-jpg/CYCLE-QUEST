extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var game_over_panel = $GameOverPanel
@onready var restart_button = $GameOverPanel/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_panel.visible = false

func update_score(value: int) -> void:
	score_label.text = "SCORE: %d" % value

func show_game_over() -> void:
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
