extends BaseModule
## Frequency Lock Module — Binary Search puzzle.
## Player guesses a hidden number 1-100, getting "too high"/"too low" feedback.

var _target: int = 0
var _guess_count: int = 0
var _range_low: int = 1
var _range_high: int = 100

# UI references (built in _ready)
var _spinbox: SpinBox
var _submit_btn: Button
var _feedback_label: Label
var _range_label: Label
var _guess_count_label: Label


func _ready() -> void:
	module_name = "Frequency Lock"
	algorithm_name = "Binary Search"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Range display
	_range_label = Label.new()
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_range_label)

	# Guess input row
	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_row)

	_spinbox = SpinBox.new()
	_spinbox.min_value = 1
	_spinbox.max_value = 1000
	_spinbox.value = 50
	_spinbox.custom_minimum_size = Vector2(100, 0)
	input_row.add_child(_spinbox)

	_submit_btn = Button.new()
	_submit_btn.text = "SUBMIT"
	_submit_btn.pressed.connect(_on_submit)
	input_row.add_child(_submit_btn)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 20)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Guess count
	_guess_count_label = Label.new()
	_guess_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guess_count_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_guess_count_label)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_hint_label)

	# Hint button
	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_target = randi_range(1, GameState.freq_range_max)
	_guess_count = 0
	_range_low = 1
	_range_high = GameState.freq_range_max
	if _feedback_label:
		_feedback_label.text = "Find the safe frequency"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_range_label.text = "Range: [1 — %d]" % GameState.freq_range_max
		_guess_count_label.text = "Guesses: 0"
		_hint_label.text = ""
		_spinbox.max_value = GameState.freq_range_max
		_spinbox.value = GameState.freq_range_max / 2
		_submit_btn.disabled = false


func _on_submit() -> void:
	if is_solved:
		return
	_start_timer_if_needed()

	var guess: int = int(_spinbox.value)
	_guess_count += 1
	_guess_count_label.text = "Guesses: %d" % _guess_count

	if guess == _target:
		_feedback_label.text = "FREQUENCY LOCKED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		complete_module()
	elif guess < _target:
		_feedback_label.text = "TOO LOW"
		_feedback_label.add_theme_color_override("font_color", Color("#42a5f5"))
		_range_low = max(_range_low, guess + 1)
		_range_label.text = "Range: [%d — %d]" % [_range_low, _range_high]
		record_wrong_action()
	else:
		_feedback_label.text = "TOO HIGH"
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		_range_high = min(_range_high, guess - 1)
		_range_label.text = "Range: [%d — %d]" % [_range_low, _range_high]
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"guesses": _guess_count,
		"range_low": _range_low,
		"range_high": _range_high,
		"mistakes": mistakes,
	}
