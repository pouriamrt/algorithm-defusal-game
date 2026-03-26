extends BaseModule
## Stack Overflow Module — Stack / Queue Data Structure puzzle.
## Shows a sequence of PUSH/POP (or ENQUEUE/DEQUEUE) operations.
## Player must predict what values get popped/dequeued (the output sequence).

var _operations: Array[Dictionary] = []  # {type: "push"/"pop", value: int}
var _expected_output: Array[int] = []
var _player_output: Array[int] = []
var _current_op_index: int = 0
var _queue_mode: bool = false  # when true, FIFO queue instead of LIFO stack

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
var _intro_label: Label
var _struct_title_label: Label
var _out_title_label: Label


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

	_intro_label = Label.new()
	_intro_label.text = "STACK (LIFO): Last In, First Out. PUSH adds to top, POP removes from top. Predict what values get popped."
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.add_theme_color_override("font_color", Color("#aabbcc"))
	_intro_label.add_theme_font_size_override("font_size", 11)
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_intro_label)

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

	_struct_title_label = Label.new()
	_struct_title_label.text = "STACK"
	_struct_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_struct_title_label.add_theme_font_size_override("font_size", 11)
	_struct_title_label.add_theme_color_override("font_color", Color("#556677"))
	stack_frame.add_child(_struct_title_label)

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

	_out_title_label = Label.new()
	_out_title_label.text = "POP output: "
	_out_title_label.add_theme_color_override("font_color", Color("#aabbcc"))
	_out_title_label.add_theme_font_size_override("font_size", 12)
	out_row.add_child(_out_title_label)

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
	_current_op_index = 0

	# Decide variant: 40% chance of FIFO queue mode
	_queue_mode = randf() < 0.4
	if _queue_mode:
		module_name = "Data Queue"
		algorithm_name = "Queue (FIFO)"
	else:
		module_name = "Stack Overflow"
		algorithm_name = "Stack (LIFO)"

	_generate_operations()
	if _feedback_label:
		if _queue_mode:
			_feedback_label.text = "Click values in the order they get dequeued"
		else:
			_feedback_label.text = "Click values in the order they get popped"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_learn_label.text = ""
		_hint_label.text = ""

		# Update variant-dependent labels
		if _header_label:
			_header_label.text = module_name
		if _intro_label:
			if _queue_mode:
				_intro_label.text = "QUEUE (FIFO): First In, First Out. ENQUEUE adds to back, DEQUEUE removes from front. Predict what values get dequeued."
			else:
				_intro_label.text = "STACK (LIFO): Last In, First Out. PUSH adds to top, POP removes from top. Predict what values get popped."
		if _struct_title_label:
			_struct_title_label.text = "QUEUE" if _queue_mode else "STACK"
		if _out_title_label:
			_out_title_label.text = "DEQUEUE output: " if _queue_mode else "POP output: "

		_display_operations()
		_build_answer_buttons()
		_update_output_display()
		_update_stack_visual()


func _generate_operations() -> void:
	# Choose a pattern style for more varied challenges
	var pattern: int = randi() % 4
	var stack: Array[int] = []
	var values_used: Array[int] = []

	if pattern == 0:
		# Classic random mix (original)
		var num_ops: int = randi_range(6, 8)
		for i in range(num_ops):
			if stack.is_empty() or (randf() < 0.6 and i < num_ops - 2):
				_push_unique(stack, values_used)
			else:
				_pop_to_output(stack)
	elif pattern == 1:
		# Burst push then burst pop (tests deep stack tracing)
		var burst: int = randi_range(3, 5)
		for i in range(burst):
			_push_unique(stack, values_used)
		for i in range(randi_range(1, 2)):
			_pop_to_output(stack)
		for i in range(randi_range(1, 3)):
			_push_unique(stack, values_used)
		while not stack.is_empty():
			_pop_to_output(stack)
	elif pattern == 2:
		# Interleaved: push-push-pop, push-push-pop, ... (tests LIFO intuition)
		for _round in range(randi_range(2, 3)):
			_push_unique(stack, values_used)
			_push_unique(stack, values_used)
			_pop_to_output(stack)
		# Drain remaining
		while not stack.is_empty():
			_pop_to_output(stack)
	else:
		# Staircase: push N, pop 1, push N-1, pop 1, ...
		# depth=3 → 3+2+1=6 pushes (safe), depth=4 → 10 pushes (exceeds 9 unique values)
		var depth: int = 3
		for level in range(depth, 0, -1):
			for i in range(level):
				_push_unique(stack, values_used)
			_pop_to_output(stack)
		while not stack.is_empty():
			_pop_to_output(stack)

	# Guarantee at least 2 pops
	while _expected_output.size() < 2 and not stack.is_empty():
		_pop_to_output(stack)


func _push_unique(stack: Array[int], values_used: Array[int]) -> void:
	var available: Array[int] = []
	for v in range(1, 10):
		if v not in values_used:
			available.append(v)
	if available.is_empty():
		return
	var val: int = available[randi() % available.size()]
	values_used.append(val)
	stack.append(val)
	_operations.append({"type": "push", "value": val})


func _pop_to_output(stack: Array[int]) -> void:
	if stack.is_empty():
		return
	var popped: int
	if _queue_mode:
		popped = stack.pop_front()  # FIFO: remove from front
	else:
		popped = stack.pop_back()   # LIFO: remove from top
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
			if _queue_mode:
				lbl.text = "ENQUEUE(%d)" % int(op["value"])
			else:
				lbl.text = "PUSH(%d)" % int(op["value"])
			lbl.add_theme_color_override("font_color", Color("#00e5ff"))
		else:
			if _queue_mode:
				lbl.text = "DEQUEUE → ?"
			else:
				lbl.text = "POP → ?"
			lbl.add_theme_color_override("font_color", Color("#ffeb3b"))
		lbl.add_theme_font_size_override("font_size", 13)
		_ops_container.add_child(lbl)

	if _queue_mode:
		_step_label.text = "Predict the %d DEQUEUE output(s) in order" % _expected_output.size()
	else:
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

	# Draw stack/queue top-to-bottom
	if sim_stack.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", Color("#555566"))
		empty.add_theme_font_size_override("font_size", 10)
		_stack_visual.add_child(empty)
	else:
		if _queue_mode:
			# Queue: show FRONT label at top, items in insertion order (front first)
			var front_lbl := Label.new()
			front_lbl.text = "FRONT"
			front_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			front_lbl.add_theme_font_size_override("font_size", 9)
			front_lbl.add_theme_color_override("font_color", Color("#556677"))
			_stack_visual.add_child(front_lbl)

			for i in range(sim_stack.size()):
				var slot := Label.new()
				slot.text = "[ %d ]" % sim_stack[i]
				slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				slot.add_theme_font_size_override("font_size", 13)
				if i == 0:
					# Highlight the front item (next to be dequeued)
					slot.add_theme_color_override("font_color", Color("#00e5ff"))
				else:
					slot.add_theme_color_override("font_color", Color("#888899"))
				_stack_visual.add_child(slot)
		else:
			# Stack: show TOP label, items in reverse order (top first)
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
		if _queue_mode:
			_feedback_label.text = "QUEUE DRAINED!"
		else:
			_feedback_label.text = "STACK CLEARED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		# Reveal POPs/DEQUEUEs in operation list
		var pop_prefix: String = "DEQUEUE" if _queue_mode else "POP"
		var pop_idx: int = 0
		for child in _ops_container.get_children():
			if child.text.begins_with(pop_prefix):
				if pop_idx < _expected_output.size():
					child.text = "%s → %d" % [pop_prefix, _expected_output[pop_idx]]
					child.add_theme_color_override("font_color", Color("#00e676"))
					pop_idx += 1
		if _learn_label:
			if _queue_mode:
				_learn_label.text = "Key Insight: Queues are FIFO — the first item enqueued is the first dequeued. Used in BFS, print spooling, task scheduling, and message passing."
			else:
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
			if _queue_mode:
				_feedback_label.text = "Wrong at position %d: you said %d, but FIFO means %d gets dequeued first (it was enqueued earliest)." % [first_wrong + 1, _player_output[first_wrong], _expected_output[first_wrong]]
			else:
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
		"queue_mode": _queue_mode,
		"num_operations": _operations.size(),
		"expected_outputs": _expected_output.size(),
		"player_progress": _player_output.size(),
		"mistakes": mistakes,
	}
