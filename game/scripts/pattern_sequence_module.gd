extends BaseModule
## Pattern Sequence Module — Pattern Recognition puzzle.
## Player must identify the pattern in a number sequence and fill in the missing value.

var _sequence: Array[int] = []
var _answer: int = 0
var _hidden_index: int = 0
var _pattern_type: String = ""
var _attempt_count: int = 0

# UI references
var _labels: Array[Label] = []
var _label_row: HBoxContainer
var _input: SpinBox
var _submit_btn: Button
var _feedback_label: Label


func _ready() -> void:
	module_name = "Pattern Sequence"
	algorithm_name = "Pattern Recognition"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	# Algorithm intro
	var intro := Label.new()
	intro.text = "PATTERN RECOGNITION: Identify the mathematical rule governing this sequence. Look at differences, ratios, or relationships between consecutive terms."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	var instr := Label.new()
	instr.text = "Find the missing number in the sequence."
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_color_override("font_color", Color("#e0e0e0"))
	instr.add_theme_font_size_override("font_size", 12)
	vbox.add_child(instr)

	_label_row = HBoxContainer.new()
	_label_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_label_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_label_row)

	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_row)

	_input = SpinBox.new()
	_input.min_value = -500
	_input.max_value = 5000
	_input.value = 0
	_input.custom_minimum_size = Vector2(100, 0)
	input_row.add_child(_input)

	_submit_btn = Button.new()
	_submit_btn.text = "SUBMIT"
	_submit_btn.pressed.connect(_on_submit)
	input_row.add_child(_submit_btn)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 18)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Learn label (populated on completion)
	_learn_label = Label.new()
	_learn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_label.add_theme_color_override("font_color", Color("#00e676"))
	_learn_label.add_theme_font_size_override("font_size", 11)
	_learn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learn_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_learn_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_hint_label)

	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_attempt_count = 0
	_generate_sequence()
	_rebuild_labels()
	if _feedback_label:
		_feedback_label.text = "What number completes the pattern?"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_hint_label.text = ""
		_input.value = 0
		_submit_btn.disabled = false


func _generate_sequence() -> void:
	_sequence.clear()
	var seq_length: int = 6
	var roll: int = randi() % 4

	if roll == 0:
		# Arithmetic: a, a+d, a+2d, ...
		_pattern_type = "arithmetic"
		var a: int = randi_range(1, 20)
		var d: int = randi_range(2, 8)
		for i in range(seq_length):
			_sequence.append(a + d * i)
	elif roll == 1:
		# Geometric: a, a*r, a*r^2, ...
		_pattern_type = "geometric"
		var a: int = randi_range(1, 5)
		var r: int = randi_range(2, 3)
		for i in range(seq_length):
			_sequence.append(a * int(pow(r, i)))
	elif roll == 2:
		# Fibonacci-like: each = sum of two previous
		_pattern_type = "fibonacci"
		var a: int = randi_range(1, 5)
		var b: int = randi_range(1, 5)
		_sequence.append(a)
		_sequence.append(b)
		for i in range(2, seq_length):
			_sequence.append(_sequence[i - 1] + _sequence[i - 2])
	else:
		# Squares: 1, 4, 9, 16, ...
		_pattern_type = "squares"
		var offset: int = randi_range(0, 3)
		for i in range(seq_length):
			_sequence.append((i + 1 + offset) * (i + 1 + offset))

	# Hide one element (not first or last for better clues)
	_hidden_index = randi_range(1, seq_length - 2)
	_answer = _sequence[_hidden_index]


func _rebuild_labels() -> void:
	for lbl in _labels:
		lbl.queue_free()
	_labels.clear()

	for i in range(_sequence.size()):
		var lbl := Label.new()
		if i == _hidden_index:
			lbl.text = "?"
			lbl.add_theme_color_override("font_color", Color("#ff6f00"))
		else:
			lbl.text = str(_sequence[i])
			lbl.add_theme_color_override("font_color", Color("#e0e0e0"))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(50, 0)
		_label_row.add_child(lbl)
		_labels.append(lbl)

		# Add comma separator (except last)
		if i < _sequence.size() - 1:
			var comma := Label.new()
			comma.text = ","
			comma.add_theme_color_override("font_color", Color("#666666"))
			comma.add_theme_font_size_override("font_size", 22)
			_label_row.add_child(comma)
			_labels.append(comma)


func _on_submit() -> void:
	if is_solved:
		return
	_start_timer_if_needed()
	_attempt_count += 1

	var guess: int = int(_input.value)
	if guess == _answer:
		_feedback_label.text = "PATTERN DECODED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		# Reveal the answer
		for i in range(_labels.size()):
			pass
		if _learn_label:
			_learn_label.text = "Key Insight: This was a %s sequence. Recognizing patterns is fundamental to algorithm design and data compression." % _pattern_type
		complete_module()
	else:
		_feedback_label.text = "Not quite. Study the gaps between numbers — is the pattern adding, multiplying, or something else?"
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"pattern_type": _pattern_type,
		"attempts": _attempt_count,
		"sequence_visible": str(_sequence),
		"mistakes": mistakes,
	}
