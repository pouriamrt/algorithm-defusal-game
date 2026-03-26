extends BaseModule
## Logic Gates Module — Boolean Logic puzzle.
## Player sets input switches (ON/OFF) to produce a target output
## through a circuit of AND, OR, NOT gates.

var _num_inputs: int = 3
var _gates: Array[Dictionary] = []  # {type, input_a, input_b, output}
var _target_output: bool = true
var _input_values: Array[bool] = []
var _attempt_count: int = 0

# UI references
var _input_buttons: Array[Button] = []
var _gate_labels: Array[Label] = []
var _output_label: Label
var _target_label: Label
var _submit_btn: Button
var _feedback_label: Label
var _circuit_container: VBoxContainer


func _ready() -> void:
	module_name = "Logic Gates"
	algorithm_name = "Boolean Logic"
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
	intro.text = "BOOLEAN LOGIC: AND = both 1. OR = any 1. XOR = exactly one 1. NAND = NOT AND. NOT flips. Set inputs to produce the target."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	# Target
	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_target_label)

	# Input switches
	var input_header := Label.new()
	input_header.text = "INPUT SWITCHES"
	input_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_header.add_theme_font_size_override("font_size", 10)
	input_header.add_theme_color_override("font_color", Color("#556677"))
	vbox.add_child(input_header)

	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	input_row.add_theme_constant_override("separation", 10)
	vbox.add_child(input_row)

	for i in range(_num_inputs):
		var btn := Button.new()
		btn.text = "A" if i == 0 else ("B" if i == 1 else "C")
		btn.custom_minimum_size = Vector2(55, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_input_toggle.bind(i))
		input_row.add_child(btn)
		_input_buttons.append(btn)

	# Circuit display
	var circuit_header := Label.new()
	circuit_header.text = "CIRCUIT"
	circuit_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	circuit_header.add_theme_font_size_override("font_size", 10)
	circuit_header.add_theme_color_override("font_color", Color("#556677"))
	vbox.add_child(circuit_header)

	_circuit_container = VBoxContainer.new()
	_circuit_container.add_theme_constant_override("separation", 4)
	_circuit_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_circuit_container)

	# Output display
	_output_label = Label.new()
	_output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_output_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_output_label)

	# Submit
	_submit_btn = Button.new()
	_submit_btn.text = "TEST CIRCUIT"
	_submit_btn.pressed.connect(_on_submit)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_submit_btn)
	vbox.add_child(btn_center)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 12)
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
	_attempt_count = 0
	_input_values.clear()
	_gates.clear()
	for i in range(_num_inputs):
		_input_values.append(false)
	_generate_circuit()
	if _feedback_label:
		_feedback_label.text = "Set inputs to make output = %s" % ("1 (TRUE)" if _target_output else "0 (FALSE)")
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_learn_label.text = ""
		_hint_label.text = ""
		_submit_btn.disabled = false
		_update_display()


func _generate_circuit() -> void:
	_gates.clear()
	var gate_types := ["AND", "OR", "XOR", "NAND"]

	# Build a 2-layer circuit:
	# Layer 1: gate1 = A op B, gate2 = NOT C (or just C)
	# Layer 2: output = gate1 op gate2
	var gate1_type: String = gate_types[randi() % gate_types.size()]
	var use_not: bool = randf() < 0.5
	var gate2_type: String = gate_types[randi() % gate_types.size()]

	_gates.append({"type": gate1_type, "inputs": "A, B", "desc": "%s(A, B)" % gate1_type})
	if use_not:
		_gates.append({"type": "NOT", "inputs": "C", "desc": "NOT(C)"})
	else:
		_gates.append({"type": "PASS", "inputs": "C", "desc": "C"})
	_gates.append({"type": gate2_type, "inputs": "G1, G2", "desc": "%s(Gate1, Gate2)" % gate2_type})

	# Find a valid target — try random first, then flip, then regenerate
	_target_output = randf() < 0.5
	if not _has_valid_input(_target_output):
		_target_output = not _target_output
		if not _has_valid_input(_target_output):
			_generate_circuit()
			return


func _has_valid_input(target: bool) -> bool:
	for a in [false, true]:
		for b in [false, true]:
			for c in [false, true]:
				if _evaluate_circuit(a, b, c) == target:
					return true
	return false


func _evaluate_circuit(a: bool, b: bool, c: bool) -> bool:
	# Gate 1: op(A, B)
	var g1: bool = _apply_gate(str(_gates[0]["type"]), a, b)
	# Gate 2: NOT(C) or C
	var g2: bool = c
	if str(_gates[1]["type"]) == "NOT":
		g2 = not c
	# Output: op(G1, G2)
	var out: bool = _apply_gate(str(_gates[2]["type"]), g1, g2)
	return out


func _apply_gate(gate_type: String, a: bool, b: bool) -> bool:
	match gate_type:
		"AND": return a and b
		"OR": return a or b
		"XOR": return a != b
		"NAND": return not (a and b)
		"NOT": return not a
		_: return a


func _on_input_toggle(index: int) -> void:
	if is_solved:
		return
	_start_timer_if_needed()
	_input_values[index] = not _input_values[index]
	_update_display()


func _update_display() -> void:
	# Update input buttons
	var labels := ["A", "B", "C"]
	for i in range(_num_inputs):
		var val_str: String = "1" if _input_values[i] else "0"
		_input_buttons[i].text = "%s:%s" % [labels[i], val_str]
		if _input_values[i]:
			_input_buttons[i].add_theme_color_override("font_color", Color("#00e5ff"))
		else:
			_input_buttons[i].add_theme_color_override("font_color", Color("#555566"))

	# Update circuit display
	for child in _circuit_container.get_children():
		child.queue_free()
	_gate_labels.clear()

	var a: bool = _input_values[0]
	var b: bool = _input_values[1]
	var c: bool = _input_values[2]
	var g1: bool = _apply_gate(str(_gates[0]["type"]), a, b)
	var g2: bool = c
	if str(_gates[1]["type"]) == "NOT":
		g2 = not c
	var output: bool = _apply_gate(str(_gates[2]["type"]), g1, g2)

	# Gate 1
	var g1_lbl := Label.new()
	g1_lbl.text = "Gate1: %s(%d, %d) → %d" % [str(_gates[0]["type"]), int(a), int(b), int(g1)]
	g1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g1_lbl.add_theme_font_size_override("font_size", 13)
	g1_lbl.add_theme_color_override("font_color", Color("#00e5ff") if g1 else Color("#888899"))
	_circuit_container.add_child(g1_lbl)

	# Gate 2
	var g2_lbl := Label.new()
	if str(_gates[1]["type"]) == "NOT":
		g2_lbl.text = "Gate2: NOT(%d) → %d" % [int(c), int(g2)]
	else:
		g2_lbl.text = "Gate2: C = %d" % int(c)
	g2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g2_lbl.add_theme_font_size_override("font_size", 13)
	g2_lbl.add_theme_color_override("font_color", Color("#00e5ff") if g2 else Color("#888899"))
	_circuit_container.add_child(g2_lbl)

	# Output gate
	var out_lbl := Label.new()
	out_lbl.text = "Output: %s(%d, %d) → %d" % [str(_gates[2]["type"]), int(g1), int(g2), int(output)]
	out_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out_lbl.add_theme_font_size_override("font_size", 14)
	out_lbl.add_theme_color_override("font_color", Color("#00e676") if output == _target_output else Color("#ff6f00"))
	_circuit_container.add_child(out_lbl)

	# Main output display
	_output_label.text = "OUTPUT: %d  (need: %d)" % [int(output), int(_target_output)]
	if output == _target_output:
		_output_label.add_theme_color_override("font_color", Color("#00e676"))
	else:
		_output_label.add_theme_color_override("font_color", Color("#ff6f00"))

	_target_label.text = "TARGET OUTPUT: %s" % ("1 (TRUE)" if _target_output else "0 (FALSE)")
	_target_label.add_theme_color_override("font_color", Color("#ffeb3b"))


func _on_submit() -> void:
	if is_solved:
		return
	_attempt_count += 1
	var a: bool = _input_values[0]
	var b: bool = _input_values[1]
	var c: bool = _input_values[2]
	var output: bool = _evaluate_circuit(a, b, c)

	if output == _target_output:
		_feedback_label.text = "CIRCUIT SOLVED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		if _learn_label:
			_learn_label.text = "Key Insight: Boolean logic is the foundation of all computing. CPUs are built from billions of AND, OR, NOT gates. Every if-statement is a logic gate."
		complete_module()
	else:
		# Educational feedback
		var g1: bool = _apply_gate(str(_gates[0]["type"]), a, b)
		var g2: bool = c
		if str(_gates[1]["type"]) == "NOT":
			g2 = not c
		var gate_name: String = str(_gates[2]["type"])
		match gate_name:
			"AND":
				_feedback_label.text = "AND needs BOTH inputs = 1. Gate1=%d, Gate2=%d." % [int(g1), int(g2)]
			"OR":
				_feedback_label.text = "OR needs at LEAST ONE input = 1. Gate1=%d, Gate2=%d." % [int(g1), int(g2)]
			"XOR":
				_feedback_label.text = "XOR needs EXACTLY ONE input = 1 (not both, not neither). Gate1=%d, Gate2=%d." % [int(g1), int(g2)]
			"NAND":
				_feedback_label.text = "NAND outputs 0 only when BOTH inputs = 1. Gate1=%d, Gate2=%d." % [int(g1), int(g2)]
			_:
				_feedback_label.text = "Wrong output. Gate1=%d, Gate2=%d. Try different inputs." % [int(g1), int(g2)]
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"inputs": [_input_values[0], _input_values[1], _input_values[2]],
		"attempts": _attempt_count,
		"circuit": str(_gates),
		"mistakes": mistakes,
	}
