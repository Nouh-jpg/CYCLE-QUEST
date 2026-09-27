extends Node

## Persists across scene changes (autoload).
var selected_character := "Maya"
var is_game_over := false

func reset_run_state() -> void:
	is_game_over = false
