class_name BaseModule
extends PanelContainer
## Abstract base class for all bomb defusal puzzle modules.
## Each module extends this and implements its own puzzle logic.

signal module_solved(module_name: String)
signal wrong_action(module_name: String)

## Display name shown in the module header
@export var module_name: String = "Module"

## Algorithm name for the results screen
@export var algorithm_name: String = "Algorithm"

## Whether this module has been solved
var is_solved: bool = false

## Number of wrong actions in this module
var mistakes: int = 0

## Timestamp when module was first interacted with
var time_started: float = 0.0

## Reference to the header label (set by subclasses)
var _header_label: Label = null

## Reference to the hint label (set by subclasses)
var _hint_label: Label = null

## Reference to the learning label (set by subclasses)
var _learn_label: Label = null


func _ready() -> void:
	# Set up base panel styling — subclasses call reset_module() after _build_ui()
	custom_minimum_size = Vector2(350, 400)


func reset_module() -> void:
	"""Override in subclass. Reset puzzle to initial state."""
	is_solved = false
	mistakes = 0
	time_started = 0.0


func complete_module() -> void:
	"""Mark module as solved and emit signal."""
	if is_solved:
		return
	is_solved = true
	if _header_label:
		_header_label.text = module_name + "  [SOLVED]"
	# Visual feedback — turn header green
	if _header_label:
		_header_label.add_theme_color_override("font_color", Color("#00e676"))
	module_solved.emit(module_name)


func record_wrong_action() -> void:
	"""Record a wrong action and emit signal."""
	mistakes += 1
	wrong_action.emit(module_name)


func apply_hint() -> void:
	"""Request and display a hint from LLMService."""
	var state := get_module_state()
	var hint_text: String = LLMService.get_module_hint(module_name, state)
	if _hint_label:
		_hint_label.text = hint_text
	# Listen for async LLM update
	if not LLMService.llm_response_received.is_connected(_on_llm_hint):
		LLMService.llm_response_received.connect(_on_llm_hint)


func _on_llm_hint(context: String, text: String) -> void:
	if context == "module_hint" and _hint_label:
		_hint_label.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_hint):
		LLMService.llm_response_received.disconnect(_on_llm_hint)


func get_module_state() -> Dictionary:
	"""Override in subclass. Return current puzzle state for hints."""
	return {"module_name": module_name, "mistakes": mistakes}


func get_result() -> Dictionary:
	"""Return result data for the results screen."""
	return {
		"name": module_name,
		"mistakes": mistakes,
		"algorithm": algorithm_name,
	}


func _start_timer_if_needed() -> void:
	"""Call this on first player interaction."""
	if time_started == 0.0:
		time_started = Time.get_ticks_msec() / 1000.0
