extends Node
## Global game state singleton. Persists across scene transitions.
## Accepts difficulty params from DifficultyManager for wave-based scaling.
## Also handles global input like fullscreen toggle (F11).

signal stability_changed(new_value: int)
signal timer_updated(remaining: float)
signal game_over(outcome: String)

# Configuration (set by DifficultyManager params)
var timer_total: float = 150.0
var stability_max: int = 100
var stability_penalty: int = 10

# Wave info
var current_wave: int = 1
var city_name: String = ""
var accent_color: Color = Color("#00e5ff")

# Module difficulty params (read by modules)
var freq_range_max: int = 50
var sort_elements: int = 5
var graph_nodes: int = 5
var graph_extra_edges: int = 2

# Runtime state
var timer_remaining: float = 150.0
var stability: int = 100
var mistakes: int = 0
var modules_solved: int = 0
var modules_total: int = 3
var game_outcome: String = ""
var module_results: Array[Dictionary] = []
var is_game_active: bool = false


func reset_with_params(params: Dictionary) -> void:
	"""Reset state using difficulty parameters from DifficultyManager."""
	timer_total = float(params.get("timer_total", 150.0))
	stability_max = int(params.get("stability_max", 100))
	stability_penalty = int(params.get("stability_penalty", 10))
	freq_range_max = int(params.get("freq_range_max", 50))
	sort_elements = int(params.get("sort_elements", 5))
	graph_nodes = int(params.get("graph_nodes", 5))
	graph_extra_edges = int(params.get("graph_extra_edges", 2))

	current_wave = int(params.get("wave", 1))
	var city: Dictionary = params.get("city", {})
	city_name = str(city.get("name", "Unknown"))
	accent_color = Color(params.get("accent_color", Color("#00e5ff")))

	timer_remaining = timer_total
	stability = stability_max
	mistakes = 0
	modules_solved = 0
	game_outcome = ""
	module_results.clear()
	is_game_active = true


func reset() -> void:
	"""Reset using current DifficultyManager params."""
	reset_with_params(DifficultyManager.get_wave_params())


func record_wrong_action() -> void:
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
	if not is_game_active:
		return
	modules_solved += 1
	module_results.append(result)
	if modules_solved >= modules_total:
		game_outcome = "defused"
		is_game_active = false
		game_over.emit(game_outcome)


func tick_timer(delta: float) -> void:
	if not is_game_active:
		return
	timer_remaining = max(0.0, timer_remaining - delta)
	timer_updated.emit(timer_remaining)
	if timer_remaining <= 0.0:
		game_outcome = "exploded_timer"
		is_game_active = false
		game_over.emit(game_outcome)


func _input(event: InputEvent) -> void:
	# F11 toggles fullscreen
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
