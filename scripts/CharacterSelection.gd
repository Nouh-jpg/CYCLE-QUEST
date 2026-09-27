extends Control

@onready var maya_button: Button = $HBoxContainer/MayaButton
@onready var jax_button: Button = $HBoxContainer/JaxButton

func _ready() -> void:
	get_tree().paused = false
	GameManager.reset_run_state()
	maya_button.pressed.connect(_on_maya_selected)
	jax_button.pressed.connect(_on_jax_selected)

func _on_maya_selected() -> void:
	GameManager.selected_character = "Maya"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_jax_selected() -> void:
	GameManager.selected_character = "Jax"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
