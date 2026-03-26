extends Node
## Global game state singleton. Persists across scene transitions.
## Tracks timer, stability, module completion, and per-module results.

signal stability_changed(new_value: int)
signal timer_updated(remaining: float)
signal game_over(outcome: String)

# Configuration
var timer_total: float = 120.0
var stability_max: int = 100
var stability_penalty: int = 10

# Runtime state
var timer_remaining: float = 120.0
var stability: int = 100
var mistakes: int = 0
var modules_solved: int = 0
var modules_total: int = 3
var game_outcome: String = ""  # "defused", "exploded_timer", "exploded_stability"
var module_results: Array[Dictionary] = []
var is_game_active: bool = false


func reset() -> void:
	"""Reset all state for a new game."""
	timer_remaining = timer_total
	stability = stability_max
	mistakes = 0
	modules_solved = 0
	game_outcome = ""
	module_results.clear()
	is_game_active = true


func record_wrong_action() -> void:
	"""Called when a module reports a wrong action."""
	if not is_game_active:
		return
	mistakes += 1
	stability = max(0, stability - stability_penalty)
	stability_changed.emit(stability)
	if stability <= 0:
		game_outcome = "exploded_stability"
		is_game_active = false
		game_over.emit(game_outcome)


func record_module_solved(result: Dictionary) -> void:
	"""Called when a module is completed. result has: name, mistakes, algorithm."""
	if not is_game_active:
		return
	modules_solved += 1
	module_results.append(result)
	if modules_solved >= modules_total:
		game_outcome = "defused"
		is_game_active = false
		game_over.emit(game_outcome)


func tick_timer(delta: float) -> void:
	"""Called each frame by BombGame._process."""
	if not is_game_active:
		return
	timer_remaining = max(0.0, timer_remaining - delta)
	timer_updated.emit(timer_remaining)
	if timer_remaining <= 0.0:
		game_outcome = "exploded_timer"
		is_game_active = false
		game_over.emit(game_outcome)
