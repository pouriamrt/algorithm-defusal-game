extends BaseModule
## Bit Cipher Module — Binary Representation puzzle.
## Player toggles binary bits to match a target decimal number.

var _target_decimal: int = 0
var _num_bits: int = 6
var _current_bits: Array[bool] = []
var _attempt_count: int = 0
var _decode_mode: bool = false

# UI references
var _bit_buttons: Array[Button] = []
var _bit_row: HBoxContainer
var _target_label: Label
var _current_label: Label
var _feedback_label: Label
var _submit_btn: Button
var _answer_input: SpinBox = null


func _ready() -> void:
	module_name = "Bit Cipher"
	algorithm_name = "Binary Representation"
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

	var intro := Label.new()
	intro.text = "BINARY: Each bit represents a power of 2. Toggle bits ON/OFF to build the target number. Rightmost bit = 1, next = 2, then 4, 8..."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	# Target number
	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", 22)
	_target_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_target_label)

	# Power labels row
	var power_row := HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.add_theme_constant_override("separation", 6)
	vbox.add_child(power_row)

	for i in range(_num_bits):
		var power_val: int = int(pow(2, _num_bits - 1 - i))
		var plbl := Label.new()
		plbl.text = str(power_val)
		plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plbl.custom_minimum_size = Vector2(42, 0)
		plbl.add_theme_font_size_override("font_size", 10)
		plbl.add_theme_color_override("font_color", Color("#667788"))
		power_row.add_child(plbl)

	# Bit toggle buttons
	_bit_row = HBoxContainer.new()
	_bit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bit_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_bit_row)

	for i in range(_num_bits):
		var btn := Button.new()
		btn.text = "0"
		btn.custom_minimum_size = Vector2(42, 42)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_bit_toggle.bind(i))
		_bit_row.add_child(btn)
		_bit_buttons.append(btn)

	# Current decimal value
	_current_label = Label.new()
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.add_theme_font_size_override("font_size", 16)
	_current_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_current_label)

	# Submit
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_submit_btn = Button.new()
	_submit_btn.text = "DECODE"
	_submit_btn.pressed.connect(_on_submit)
	btn_row.add_child(_submit_btn)

	_answer_input = SpinBox.new()
	_answer_input.min_value = 0
	_answer_input.max_value = 255
	_answer_input.custom_minimum_size = Vector2(100, 0)
	_answer_input.visible = false
	btn_row.add_child(_answer_input)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Learn label
	_learn_label = Label.new()
	_learn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_label.add_theme_color_override("font_color", Color("#00e676"))
	_learn_label.add_theme_font_size_override("font_size", 11)
	_learn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learn_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_learn_label)

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
	_current_bits.clear()
	for i in range(_num_bits):
		_current_bits.append(false)

	# Decide mode: decode variant on waves >= 3 with 40% chance
	_decode_mode = GameState.current_wave >= 3 and randf() < 0.4

	if not _target_label:
		return

	_learn_label.text = ""
	_hint_label.text = ""
	_submit_btn.disabled = false
	_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))

	if _decode_mode:
		# --- Decode mode: player reads binary and types the decimal ---
		_answer_input.visible = true
		_answer_input.value = 0
		_submit_btn.text = "SUBMIT"

		# Pre-set random bits (ensure at least one is ON)
		for i in range(_num_bits):
			_current_bits[i] = randf() < 0.5
		var any_on: bool = false
		for b in _current_bits:
			if b:
				any_on = true
				break
		if not any_on:
			_current_bits[randi_range(0, _num_bits - 1)] = true

		_target_decimal = _bits_to_decimal()
		_target_label.text = "DECODE THIS BINARY"
		_current_label.text = "Your answer:"
		_feedback_label.text = "Read the binary and type its decimal value"

		# Disable bit buttons so the player cannot toggle them
		for i in range(_num_bits):
			_bit_buttons[i].disabled = true
		_update_buttons()
	else:
		# --- Normal encode mode ---
		_answer_input.visible = false
		_submit_btn.text = "DECODE"

		var max_val: int = int(pow(2, _num_bits)) - 1
		_target_decimal = randi_range(1, max_val)

		_target_label.text = "TARGET: %d" % _target_decimal
		_current_label.text = "Current: 0"
		_feedback_label.text = "Toggle bits to build the target number"

		# Enable bit buttons
		for i in range(_num_bits):
			_bit_buttons[i].disabled = false
		_update_buttons()


func _on_bit_toggle(index: int) -> void:
	if is_solved or _decode_mode:
		return
	_start_timer_if_needed()
	_current_bits[index] = not _current_bits[index]
	_update_buttons()


func _update_buttons() -> void:
	var decimal: int = _bits_to_decimal()
	for i in range(_num_bits):
		if _current_bits[i]:
			_bit_buttons[i].text = "1"
			_bit_buttons[i].add_theme_color_override("font_color", Color("#00e5ff"))
		else:
			_bit_buttons[i].text = "0"
			_bit_buttons[i].add_theme_color_override("font_color", Color("#555566"))
	if not _decode_mode:
		_current_label.text = "Current: %d" % decimal
		if decimal == _target_decimal:
			_current_label.add_theme_color_override("font_color", Color("#00e676"))
		else:
			_current_label.add_theme_color_override("font_color", Color("#e0e0e0"))


func _bits_to_decimal() -> int:
	var val: int = 0
	for i in range(_num_bits):
		if _current_bits[i]:
			val += int(pow(2, _num_bits - 1 - i))
	return val


func _on_submit() -> void:
	if is_solved:
		return
	_start_timer_if_needed()
	_attempt_count += 1

	var breakdown: String = _build_breakdown()

	if _decode_mode:
		_handle_decode_submit(breakdown)
	else:
		_handle_encode_submit(breakdown)


func _build_breakdown() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in range(_num_bits):
		if _current_bits[i]:
			parts.append("%d" % int(pow(2, _num_bits - 1 - i)))
	return " + ".join(parts)


func _handle_encode_submit(breakdown: String) -> void:
	var current: int = _bits_to_decimal()

	if current == _target_decimal:
		_feedback_label.text = "CIPHER DECODED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		if _learn_label:
			_learn_label.text = "Key Insight: %d = %s. Binary is how computers store ALL data — each bit doubles the range." % [_target_decimal, breakdown]
		complete_module()
	else:
		var diff: int = abs(current - _target_decimal)
		if current > _target_decimal:
			_feedback_label.text = "Too high by %d. Turn OFF a bit worth >= %d." % [diff, diff]
		else:
			_feedback_label.text = "Too low by %d. Turn ON a bit worth >= %d." % [diff, diff]
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()


func _handle_decode_submit(breakdown: String) -> void:
	var player_answer: int = int(_answer_input.value)

	if player_answer == _target_decimal:
		_feedback_label.text = "CIPHER DECODED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		if _learn_label:
			_learn_label.text = "Key Insight: Reading binary is the reverse of writing it. %d in binary is %s. Each 1-bit adds its power of 2 to the total." % [_target_decimal, breakdown]
		complete_module()
	else:
		_feedback_label.text = "Wrong! The binary shown equals %d. Remember: add up the powers of 2 for each ON bit." % _target_decimal
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"target": _target_decimal,
		"current": _bits_to_decimal(),
		"attempts": _attempt_count,
		"mistakes": mistakes,
		"decode_mode": _decode_mode,
	}
