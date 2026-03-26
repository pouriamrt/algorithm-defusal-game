extends BaseModule
## Stack Overflow Module — Stack Data Structure puzzle.
## Shows a sequence of PUSH/POP operations. Player must predict
## what values get popped (the output sequence).

var _operations: Array[Dictionary] = []  # {type: "push"/"pop", value: int}
var _expected_output: Array[int] = []
var _player_output: Array[int] = []
var _current_op_index: int = 0
var _stack_display: Array[int] = []  # current visual stack state

# UI references
var _ops_container: VBoxContainer
var _stack_visual: VBoxContainer
var _output_label: Label
var _expected_label: Label
var _buttons_row: HBoxContainer
var _digit_buttons: Array[Button] = []
var _submit_btn: Button
var _feedback_label: Label
var _step_label: Label


func _ready() -> void:
	module_name = "Stack Overflow"
	algorithm_name = "Stack (LIFO)"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)

	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	var intro := Label.new()
	intro.text = "STACK (LIFO): Last In, First Out. PUSH adds to top, POP removes from top. Predict what values get popped."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	# Operations display and stack side by side
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Left: operations list
	var ops_frame := VBoxContainer.new()
	ops_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(ops_frame)

	var ops_title := Label.new()
	ops_title.text = "OPERATIONS"
	ops_title.add_theme_font_size_override("font_size", 11)
	ops_title.add_theme_color_override("font_color", Color("#556677"))
	ops_frame.add_child(ops_title)

	var ops_scroll := ScrollContainer.new()
	ops_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ops_frame.add_child(ops_scroll)

	_ops_container = VBoxContainer.new()
	_ops_container.add_theme_constant_override("separation", 2)
	ops_scroll.add_child(_ops_container)

	# Right: stack visual
	var stack_frame := VBoxContainer.new()
	stack_frame.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(stack_frame)

	var stack_title := Label.new()
	stack_title.text = "STACK"
	stack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_title.add_theme_font_size_override("font_size", 11)
	stack_title.add_theme_color_override("font_color", Color("#556677"))
	stack_frame.add_child(stack_title)

	_stack_visual = VBoxContainer.new()
	_stack_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack_visual.add_theme_constant_override("separation", 2)
	stack_frame.add_child(_stack_visual)

	# Step control
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_step_label)

	# Output area
	var out_row := HBoxContainer.new()
	out_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(out_row)

	var out_title := Label.new()
	out_title.text = "POP output: "
	out_title.add_theme_color_override("font_color", Color("#aabbcc"))
	out_title.add_theme_font_size_override("font_size", 12)
	out_row.add_child(out_title)

	_output_label = Label.new()
	_output_label.text = "[ ]"
	_output_label.add_theme_font_size_override("font_size", 14)
	_output_label.add_theme_color_override("font_color", Color("#ffeb3b"))
	out_row.add_child(_output_label)

	# Answer buttons — player clicks digits to build output
	_buttons_row = HBoxContainer.new()
	_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_buttons_row)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

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
	_operations.clear()
	_expected_output.clear()
	_player_output.clear()
	_stack_display.clear()
	_current_op_index = 0
	_generate_operations()
	if _feedback_label:
		_feedback_label.text = "Click values in the order they get popped"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_learn_label.text = ""
		_hint_label.text = ""
		_display_operations()
		_build_answer_buttons()
		_update_output_display()
		_update_stack_visual()


func _generate_operations() -> void:
	# Create a mix of PUSH and POP operations
	var stack: Array[int] = []
	var values_used: Array[int] = []
	var num_ops: int = randi_range(6, 8)

	for i in range(num_ops):
		if stack.is_empty() or (randf() < 0.6 and i < num_ops - 2):
			# PUSH
			var val: int = randi_range(1, 9)
			while val in values_used:
				val = randi_range(1, 9)
			values_used.append(val)
			stack.append(val)
			_operations.append({"type": "push", "value": val})
		else:
			# POP
			var popped: int = stack.pop_back()
			_expected_output.append(popped)
			_operations.append({"type": "pop", "value": popped})

	# Ensure at least 2 pops
	while stack.size() > 0 and _expected_output.size() < 3:
		var popped: int = stack.pop_back()
		_expected_output.append(popped)
		_operations.append({"type": "pop", "value": popped})


func _display_operations() -> void:
	for child in _ops_container.get_children():
		child.queue_free()

	for i in range(_operations.size()):
		var op: Dictionary = _operations[i]
		var lbl := Label.new()
		var op_type: String = str(op["type"])
		if op_type == "push":
			lbl.text = "PUSH(%d)" % int(op["value"])
			lbl.add_theme_color_override("font_color", Color("#00e5ff"))
		else:
			lbl.text = "POP → ?"
			lbl.add_theme_color_override("font_color", Color("#ffeb3b"))
		lbl.add_theme_font_size_override("font_size", 13)
		_ops_container.add_child(lbl)

	_step_label.text = "Predict the %d POP output(s) in order" % _expected_output.size()


func _build_answer_buttons() -> void:
	for btn in _digit_buttons:
		btn.queue_free()
	_digit_buttons.clear()

	# Collect all pushed values as possible answers
	var pushed_values: Array[int] = []
	for op in _operations:
		if str(op["type"]) == "push":
			var v: int = int(op["value"])
			if v not in pushed_values:
				pushed_values.append(v)
	pushed_values.sort()

	for val in pushed_values:
		var btn := Button.new()
		btn.text = str(val)
		btn.custom_minimum_size = Vector2(36, 36)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_value_clicked.bind(val))
		_buttons_row.add_child(btn)
		_digit_buttons.append(btn)

	# Undo button
	var undo_btn := Button.new()
	undo_btn.text = "UNDO"
	undo_btn.custom_minimum_size = Vector2(50, 36)
	undo_btn.add_theme_font_size_override("font_size", 11)
	undo_btn.pressed.connect(_on_undo)
	_buttons_row.add_child(undo_btn)
	_digit_buttons.append(undo_btn)


func _on_value_clicked(val: int) -> void:
	if is_solved:
		return
	_start_timer_if_needed()

	_player_output.append(val)
	_update_output_display()

	# Check if complete
	if _player_output.size() >= _expected_output.size():
		_check_answer()


func _on_undo() -> void:
	if not _player_output.is_empty():
		_player_output.pop_back()
		_update_output_display()


func _update_output_display() -> void:
	if _player_output.is_empty():
		_output_label.text = "[ ]"
	else:
		var parts: Array[String] = []
		for v in _player_output:
			parts.append(str(v))
		_output_label.text = "[ %s ]" % ", ".join(parts)


func _update_stack_visual() -> void:
	for child in _stack_visual.get_children():
		child.queue_free()

	# Show current stack state (simulate up to current operations)
	var sim_stack: Array[int] = []
	for op in _operations:
		if str(op["type"]) == "push":
			sim_stack.append(int(op["value"]))

	# Draw stack top-to-bottom
	if sim_stack.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", Color("#555566"))
		empty.add_theme_font_size_override("font_size", 10)
		_stack_visual.add_child(empty)
	else:
		var top_lbl := Label.new()
		top_lbl.text = "TOP"
		top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_lbl.add_theme_font_size_override("font_size", 9)
		top_lbl.add_theme_color_override("font_color", Color("#556677"))
		_stack_visual.add_child(top_lbl)

		for i in range(sim_stack.size() - 1, -1, -1):
			var slot := Label.new()
			slot.text = "[ %d ]" % sim_stack[i]
			slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_theme_font_size_override("font_size", 13)
			if i == sim_stack.size() - 1:
				slot.add_theme_color_override("font_color", Color("#00e5ff"))
			else:
				slot.add_theme_color_override("font_color", Color("#888899"))
			_stack_visual.add_child(slot)


func _check_answer() -> void:
	var correct: bool = true
	if _player_output.size() != _expected_output.size():
		correct = false
	else:
		for i in range(_expected_output.size()):
			if _player_output[i] != _expected_output[i]:
				correct = false
				break

	if correct:
		_feedback_label.text = "STACK CLEARED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		# Reveal POPs in operation list
		var pop_idx: int = 0
		for child in _ops_container.get_children():
			if child.text.begins_with("POP"):
				if pop_idx < _expected_output.size():
					child.text = "POP → %d" % _expected_output[pop_idx]
					child.add_theme_color_override("font_color", Color("#00e676"))
					pop_idx += 1
		if _learn_label:
			_learn_label.text = "Key Insight: Stacks are LIFO — the last item pushed is the first popped. Used in function calls, undo systems, and expression parsing."
		complete_module()
	else:
		# Show what went wrong
		var first_wrong: int = -1
		for i in range(min(_player_output.size(), _expected_output.size())):
			if _player_output[i] != _expected_output[i]:
				first_wrong = i
				break
		if first_wrong >= 0:
			_feedback_label.text = "Wrong at position %d: you said %d, but LIFO means %d gets popped first." % [first_wrong + 1, _player_output[first_wrong], _expected_output[first_wrong]]
		else:
			_feedback_label.text = "Wrong number of values. Trace through the operations carefully."
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		_player_output.clear()
		_update_output_display()
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"num_operations": _operations.size(),
		"expected_outputs": _expected_output.size(),
		"player_progress": _player_output.size(),
		"mistakes": mistakes,
	}
