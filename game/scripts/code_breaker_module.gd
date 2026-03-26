extends BaseModule
## Code Breaker Module — Logical Deduction puzzle (Mastermind-style).
## Player guesses a 4-digit code. Feedback shows correct positions and correct digits.

var _secret: Array[int] = []
var _code_length: int = 4
var _max_digit: int = 6  # digits 1-6
var _attempt_count: int = 0
var _history: Array[Dictionary] = []  # {guess, exact, partial}

# UI references
var _spinboxes: Array[SpinBox] = []
var _input_row: HBoxContainer
var _submit_btn: Button
var _feedback_label: Label
var _history_container: VBoxContainer


func _ready() -> void:
	module_name = "Code Breaker"
	algorithm_name = "Logical Deduction"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	var instr := Label.new()
	instr.text = "Crack the 4-digit code (digits 1-%d).\nGreen = right digit, right place.\nYellow = right digit, wrong place." % _max_digit
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_color_override("font_color", Color("#e0e0e0"))
	instr.add_theme_font_size_override("font_size", 11)
	vbox.add_child(instr)

	# Input row
	_input_row = HBoxContainer.new()
	_input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_input_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_input_row)

	for i in range(_code_length):
		var sb := SpinBox.new()
		sb.min_value = 1
		sb.max_value = _max_digit
		sb.value = 1
		sb.custom_minimum_size = Vector2(55, 0)
		_input_row.add_child(sb)
		_spinboxes.append(sb)

	_submit_btn = Button.new()
	_submit_btn.text = "CRACK"
	_submit_btn.pressed.connect(_on_submit)
	_input_row.add_child(_submit_btn)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_feedback_label)

	# History scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(scroll)

	_history_container = VBoxContainer.new()
	_history_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_history_container)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_hint_label)

	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_attempt_count = 0
	_history.clear()
	_secret.clear()
	for i in range(_code_length):
		_secret.append(randi_range(1, _max_digit))
	if _feedback_label:
		_feedback_label.text = "Enter your guess"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_hint_label.text = ""
		_submit_btn.disabled = false
		# Clear history display
		for child in _history_container.get_children():
			child.queue_free()


func _on_submit() -> void:
	if is_solved:
		return
	_start_timer_if_needed()
	_attempt_count += 1

	# Read guess
	var guess: Array[int] = []
	for sb in _spinboxes:
		guess.append(int(sb.value))

	# Calculate exact matches (green) and partial matches (yellow)
	var exact: int = 0
	var partial: int = 0
	var secret_used: Array[bool] = []
	var guess_used: Array[bool] = []
	for i in range(_code_length):
		secret_used.append(false)
		guess_used.append(false)

	# Pass 1: exact matches
	for i in range(_code_length):
		if guess[i] == _secret[i]:
			exact += 1
			secret_used[i] = true
			guess_used[i] = true

	# Pass 2: partial matches
	for i in range(_code_length):
		if guess_used[i]:
			continue
		for j in range(_code_length):
			if secret_used[j]:
				continue
			if guess[i] == _secret[j]:
				partial += 1
				secret_used[j] = true
				break

	# Store in history
	_history.append({"guess": guess.duplicate(), "exact": exact, "partial": partial})

	# Add to history display
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	_history_container.add_child(row)

	var attempt_lbl := Label.new()
	attempt_lbl.text = "#%d: " % _attempt_count
	attempt_lbl.add_theme_color_override("font_color", Color("#666688"))
	attempt_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(attempt_lbl)

	for i in range(_code_length):
		var digit_lbl := Label.new()
		digit_lbl.text = str(guess[i])
		digit_lbl.add_theme_font_size_override("font_size", 16)
		digit_lbl.custom_minimum_size = Vector2(20, 0)
		digit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if guess[i] == _secret[i]:
			digit_lbl.add_theme_color_override("font_color", Color("#00e676"))
		else:
			digit_lbl.add_theme_color_override("font_color", Color("#e0e0e0"))
		row.add_child(digit_lbl)

	var result_lbl := Label.new()
	result_lbl.text = "  %d exact, %d partial" % [exact, partial]
	result_lbl.add_theme_font_size_override("font_size", 12)
	if exact == _code_length:
		result_lbl.add_theme_color_override("font_color", Color("#00e676"))
	elif exact > 0:
		result_lbl.add_theme_color_override("font_color", Color("#ffeb3b"))
	else:
		result_lbl.add_theme_color_override("font_color", Color("#888899"))
	row.add_child(result_lbl)

	# Check win
	if exact == _code_length:
		_feedback_label.text = "CODE CRACKED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		complete_module()
	else:
		_feedback_label.text = "%d exact, %d partial" % [exact, partial]
		_feedback_label.add_theme_color_override("font_color", Color("#ffeb3b"))
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"attempts": _attempt_count,
		"code_length": _code_length,
		"max_digit": _max_digit,
		"last_exact": _history[-1]["exact"] if not _history.is_empty() else 0,
		"last_partial": _history[-1]["partial"] if not _history.is_empty() else 0,
		"mistakes": mistakes,
	}
