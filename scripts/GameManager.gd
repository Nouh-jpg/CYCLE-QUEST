extends Node

## Persists across scene changes (autoload).
var selected_character := "Maya"
var is_game_over := false
var best_score := 0
var last_score := 0
var last_distance := 0.0

const SAVE_PATH := "user://cycle_quest.cfg"

func _ready() -> void:
	_load_best()

func reset_run_state() -> void:
	is_game_over = false

func record_run(score: int, distance: float) -> void:
	last_score = score
	last_distance = distance
	if score > best_score:
		best_score = score
		_save_best()

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("stats", "best_score", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("stats", "best_score", best_score)
	cfg.save(SAVE_PATH)
