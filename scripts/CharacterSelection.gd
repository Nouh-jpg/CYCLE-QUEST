extends Control

@onready var maya_button = $HBoxContainer/MayaButton
@onready var jax_button = $HBoxContainer/JaxButton

func _ready() -> void:
	maya_button.pressed.connect(_on_maya_selected)
	jax_button.pressed.connect(_on_jax_selected)

func _on_maya_selected() -> void:
	GameManager.selected_character = "Maya"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_jax_selected() -> void:
	GameManager.selected_character = "Jax"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
