extends BaseModule
## Code Breaker Module — Logical Deduction puzzle (Mastermind-style).
## Enhanced with digit tracker, Wordle-style coloring, deduction log,
## and progressive strategy teaching.

var _secret: Array[int] = []
var _code_length: int = 4
var _max_digit: int = 6
var _attempt_count: int = 0
var _history: Array[Dictionary] = []

# Deduction tracking: for each digit 1-6, track status per position
# Status: "unknown", "confirmed", "eliminated", "present" (in code but position unknown)
var _digit_info: Dictionary = {}  # digit -> {"status": String, "positions_tried": Array}
var _position_confirmed: Array[int] = []  # -1 = unconfirmed, digit = confirmed

# UI references
var _spinboxes: Array[SpinBox] = []
var _input_row: HBoxContainer
var _submit_btn: Button
var _feedback_label: Label
var _strategy_label: Label
var _history_container: VBoxContainer
var _tracker_container: HBoxContainer
var _tracker_labels: Dictionary = {}  # digit -> Label
var _deduction_label: Label
var _possibilities_label: Label


func _ready() -> void:
	module_name = "Code Breaker"
	algorithm_name = "Logical Deduction"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
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
	intro.text = "CONSTRAINT SATISFACTION: Each guess reveals information. Use it to systematically eliminate possibilities."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	# --- Digit Tracker Panel ---
	var tracker_header := Label.new()
	tracker_header.text = "DIGIT TRACKER"
	tracker_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tracker_header.add_theme_font_size_override("font_size", 10)
	tracker_header.add_theme_color_override("font_color", Color("#556677"))
	vbox.add_child(tracker_header)

	_tracker_container = HBoxContainer.new()
	_tracker_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_tracker_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_tracker_container)

	for d in range(1, _max_digit + 1):
		var lbl := Label.new()
		lbl.text = str(d)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(30, 26)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color("#888899"))
		_tracker_container.add_child(lbl)
		_tracker_labels[d] = lbl

	# Possibilities counter
	_possibilities_label = Label.new()
	_possibilities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_possibilities_label.add_theme_font_size_override("font_size", 10)
	_possibilities_label.add_theme_color_override("font_color", Color("#667788"))
	vbox.add_child(_possibilities_label)

	# Input row
	_input_row = HBoxContainer.new()
	_input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_input_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_input_row)

	for i in range(_code_length):
		var sb := SpinBox.new()
		sb.min_value = 1
		sb.max_value = _max_digit
		sb.value = 1
		sb.custom_minimum_size = Vector2(52, 0)
		_input_row.add_child(sb)
		_spinboxes.append(sb)

	_submit_btn = Button.new()
	_submit_btn.text = "CRACK"
	_submit_btn.pressed.connect(_on_submit)
	_input_row.add_child(_submit_btn)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Strategy tip (escalates with attempts)
	_strategy_label = Label.new()
	_strategy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strategy_label.add_theme_font_size_override("font_size", 10)
	_strategy_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_strategy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_strategy_label)

	# History scroll with Wordle-style colored digits
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(scroll)

	_history_container = VBoxContainer.new()
	_history_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_container.add_theme_constant_override("separation", 3)
	scroll.add_child(_history_container)

	# Deduction log (what we know so far)
	_deduction_label = Label.new()
	_deduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deduction_label.add_theme_font_size_override("font_size", 10)
	_deduction_label.add_theme_color_override("font_color", Color("#88aacc"))
	_deduction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deduction_label.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(_deduction_label)

	# Learn label
	_learn_label = Label.new()
	_learn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_label.add_theme_color_override("font_color", Color("#00e676"))
	_learn_label.add_theme_font_size_override("font_size", 11)
	_learn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learn_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_learn_label)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 20)
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
	_digit_info.clear()
	_position_confirmed.clear()

	for i in range(_code_length):
		_secret.append(randi_range(1, _max_digit))
		_position_confirmed.append(-1)

	for d in range(1, _max_digit + 1):
		_digit_info[d] = {"status": "unknown", "positions_tried": []}

	if _feedback_label:
		_feedback_label.text = "Enter your first guess"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_strategy_label.text = "Strategy: Start by testing which digits are in the code."
		_hint_label.text = ""
		_deduction_label.text = ""
		_learn_label.text = ""
		_submit_btn.disabled = false
		_update_tracker()
		_update_possibilities()
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

	# Calculate matches
	var exact: int = 0
	var partial: int = 0
	var secret_used: Array[bool] = []
	var guess_used: Array[bool] = []
	var exact_positions: Array[bool] = []
	var partial_positions: Array[bool] = []

	for i in range(_code_length):
		secret_used.append(false)
		guess_used.append(false)
		exact_positions.append(false)
		partial_positions.append(false)

	# Pass 1: exact
	for i in range(_code_length):
		if guess[i] == _secret[i]:
			exact += 1
			secret_used[i] = true
			guess_used[i] = true
			exact_positions[i] = true

	# Pass 2: partial
	for i in range(_code_length):
		if guess_used[i]:
			continue
		for j in range(_code_length):
			if secret_used[j]:
				continue
			if guess[i] == _secret[j]:
				partial += 1
				secret_used[j] = true
				partial_positions[i] = true
				break

	_history.append({"guess": guess.duplicate(), "exact": exact, "partial": partial,
		"exact_pos": exact_positions.duplicate(), "partial_pos": partial_positions.duplicate()})

	# Update deduction tracking
	_update_deductions(guess, exact_positions, partial_positions)

	# Build Wordle-style history row
	_add_history_row(guess, exact_positions, partial_positions, exact, partial)

	# Update tracker display
	_update_tracker()
	_update_possibilities()

	# Check win
	if exact == _code_length:
		_feedback_label.text = "CODE CRACKED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		_strategy_label.text = ""
		_deduction_label.text = "All constraints satisfied — code fully determined."

		var total_possible: int = int(pow(_max_digit, _code_length))
		if _learn_label:
			_learn_label.text = (
				"Key Insight: You searched through %d possible codes using logical deduction. "
				% total_possible
				+ "Each guess eliminated possibilities, narrowing from %d to 1 in %d steps. "
				% [total_possible, _attempt_count]
				+ "This is constraint propagation — the basis of SAT solvers and AI reasoning."
			)
		complete_module()
	else:
		# Educational feedback based on what was learned
		var new_info := _describe_new_info(guess, exact_positions, partial_positions, exact, partial)
		_feedback_label.text = new_info
		_feedback_label.add_theme_color_override("font_color", Color("#ffeb3b"))

		# Progressive strategy tips
		_strategy_label.text = _get_strategy_tip()

		record_wrong_action()


func _update_deductions(guess: Array[int], exact_pos: Array[bool], partial_pos: Array[bool]) -> void:
	# Update position confirmations
	for i in range(_code_length):
		if exact_pos[i]:
			_position_confirmed[i] = guess[i]
			_digit_info[guess[i]]["status"] = "confirmed"

	# Track which positions each digit has been tried in
	for i in range(_code_length):
		var d: int = guess[i]
		if not (i in _digit_info[d]["positions_tried"]):
			_digit_info[d]["positions_tried"].append(i)

	# If a digit appears in guess but got no exact or partial credit, it might be eliminated
	# (Only if we can determine it's not in the code at all)
	var guess_digits: Dictionary = {}
	for i in range(_code_length):
		var d: int = guess[i]
		if not guess_digits.has(d):
			guess_digits[d] = {"count": 0, "exact": 0, "partial": 0}
		guess_digits[d]["count"] += 1
		if exact_pos[i]:
			guess_digits[d]["exact"] += 1
		elif partial_pos[i]:
			guess_digits[d]["partial"] += 1

	for d in guess_digits:
		var info: Dictionary = guess_digits[d]
		var matched: int = int(info["exact"]) + int(info["partial"])
		if matched == 0 and _digit_info[d]["status"] == "unknown":
			_digit_info[d]["status"] = "eliminated"
		elif matched > 0 and _digit_info[d]["status"] == "unknown":
			_digit_info[d]["status"] = "present"


func _update_tracker() -> void:
	for d in range(1, _max_digit + 1):
		var lbl: Label = _tracker_labels[d]
		var status: String = str(_digit_info[d]["status"])
		match status:
			"confirmed":
				lbl.add_theme_color_override("font_color", Color("#00e676"))
				lbl.text = str(d) + "!"
			"present":
				lbl.add_theme_color_override("font_color", Color("#ffeb3b"))
				lbl.text = str(d) + "?"
			"eliminated":
				lbl.add_theme_color_override("font_color", Color("#ff1744", 0.4))
				lbl.text = str(d) + "X"
			_:
				lbl.add_theme_color_override("font_color", Color("#888899"))
				lbl.text = str(d)


func _update_possibilities() -> void:
	var eliminated_count: int = 0
	var confirmed_count: int = 0
	for d in range(1, _max_digit + 1):
		var status: String = str(_digit_info[d]["status"])
		if status == "eliminated":
			eliminated_count += 1
		elif status == "confirmed":
			confirmed_count += 1

	var remaining_digits: int = _max_digit - eliminated_count
	var unknown_positions: int = _code_length - confirmed_count
	var possibilities: int = max(1, int(pow(remaining_digits, unknown_positions)))
	_possibilities_label.text = "Remaining possibilities: ~%d  |  Digits eliminated: %d  |  Positions locked: %d" % [possibilities, eliminated_count, confirmed_count]


func _add_history_row(guess: Array[int], exact_pos: Array[bool], partial_pos: Array[bool], exact: int, partial: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	_history_container.add_child(row)

	var attempt_lbl := Label.new()
	attempt_lbl.text = "#%d " % _attempt_count
	attempt_lbl.add_theme_color_override("font_color", Color("#556677"))
	attempt_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(attempt_lbl)

	# Wordle-style colored digit boxes
	for i in range(_code_length):
		var box := Label.new()
		box.text = " %d " % guess[i]
		box.add_theme_font_size_override("font_size", 14)
		box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.custom_minimum_size = Vector2(24, 24)

		if exact_pos[i]:
			# Green — exact match
			box.add_theme_color_override("font_color", Color("#00e676"))
			box.text = "[%d]" % guess[i]
		elif partial_pos[i]:
			# Yellow — partial match
			box.add_theme_color_override("font_color", Color("#ffeb3b"))
			box.text = "(%d)" % guess[i]
		else:
			# Gray — no match
			box.add_theme_color_override("font_color", Color("#555566"))
			box.text = " %d " % guess[i]
		row.add_child(box)

	# Summary
	var summary := Label.new()
	summary.text = " %d" % exact + "G" + " %d" % partial + "Y"
	summary.add_theme_font_size_override("font_size", 10)
	if exact > 0:
		summary.add_theme_color_override("font_color", Color("#00e676"))
	elif partial > 0:
		summary.add_theme_color_override("font_color", Color("#ffeb3b"))
	else:
		summary.add_theme_color_override("font_color", Color("#555566"))
	row.add_child(summary)


func _describe_new_info(guess: Array[int], exact_pos: Array[bool], partial_pos: Array[bool], exact: int, partial: int) -> String:
	# Build educational feedback describing what was learned
	var parts: Array[String] = []

	if exact > 0:
		var exact_digits: Array[String] = []
		for i in range(_code_length):
			if exact_pos[i]:
				exact_digits.append("%d in slot %d" % [guess[i], i + 1])
		parts.append("Locked: " + ", ".join(exact_digits))

	if partial > 0:
		var partial_digits: Array[String] = []
		for i in range(_code_length):
			if partial_pos[i]:
				partial_digits.append(str(guess[i]))
		parts.append("In code but wrong slot: " + ", ".join(partial_digits))

	# Check for newly eliminated digits
	var eliminated: Array[String] = []
	for i in range(_code_length):
		if not exact_pos[i] and not partial_pos[i]:
			var d: int = guess[i]
			if str(_digit_info[d]["status"]) == "eliminated":
				if str(d) not in eliminated:
					eliminated.append(str(d))
	if not eliminated.is_empty():
		parts.append("Eliminated: " + ", ".join(eliminated))

	if parts.is_empty():
		return "No new information. Try a different combination of digits."

	return " | ".join(parts)


func _get_strategy_tip() -> String:
	match _attempt_count:
		1:
			return "Tip: Note which digits got any match. Eliminated digits are crossed out above."
		2:
			return "Tip: Try keeping exact matches (green) in place and moving partial matches (yellow)."
		3:
			return "Tip: Each guess should test a hypothesis. Don't guess randomly — use what you know."
		4:
			return "Tip: With enough eliminations, you can deduce the remaining digits by exclusion."
		5:
			return "Tip: If 3 positions are locked, the last position is constrained to remaining digits."
		_:
			var confirmed: int = 0
			for i in range(_code_length):
				if _position_confirmed[i] >= 0:
					confirmed += 1
			if confirmed >= 3:
				return "Almost there! %d of %d positions confirmed. Focus on the remaining." % [confirmed, _code_length]
			return "Use elimination: try digits you haven't tested yet in unknown positions."


func get_module_state() -> Dictionary:
	var eliminated: int = 0
	var confirmed: int = 0
	for d in range(1, _max_digit + 1):
		var status: String = str(_digit_info[d]["status"])
		if status == "eliminated":
			eliminated += 1
		elif status == "confirmed":
			confirmed += 1
	return {
		"module_name": module_name,
		"attempts": _attempt_count,
		"code_length": _code_length,
		"max_digit": _max_digit,
		"digits_eliminated": eliminated,
		"positions_confirmed": confirmed,
		"last_exact": int(_history[-1]["exact"]) if not _history.is_empty() else 0,
		"last_partial": int(_history[-1]["partial"]) if not _history.is_empty() else 0,
		"mistakes": mistakes,
	}
