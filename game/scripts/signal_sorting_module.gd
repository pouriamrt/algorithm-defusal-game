extends BaseModule
## Signal Sorting Module — Sorting puzzle.
## Player swaps elements to sort an array. Non-improving swaps are penalized.

var _num_elements: int = 6
var _sort_descending: bool = false
var _sorted_target: Array[int] = []

var _values: Array[int] = []
var _selected_index: int = -1
var _swap_count: int = 0

# UI references
var _buttons: Array[Button] = []
var _button_row: HBoxContainer
var _status_label: Label
var _swap_count_label: Label


func _ready() -> void:
	module_name = "Signal Sorting"
	algorithm_name = "Sorting (Inversions)"
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

	vbox.add_child(HSeparator.new())

	# Algorithm intro
	var intro := Label.new()
	intro.text = "SORTING: Arrange values in order by swapping pairs. Each swap should reduce inversions (out-of-order pairs). Sort direction varies!"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	# Instructions
	var instr := Label.new()
	instr.text = "Click two values to swap them."
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_color_override("font_color", Color("#e0e0e0"))
	instr.add_theme_font_size_override("font_size", 12)
	vbox.add_child(instr)

	# Button row
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_button_row)

	# Status
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	# Swap count
	_swap_count_label = Label.new()
	_swap_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_count_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_swap_count_label)

	# Learn label (populated on completion)
	_learn_label = Label.new()
	_learn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_label.add_theme_color_override("font_color", Color("#00e676"))
	_learn_label.add_theme_font_size_override("font_size", 11)
	_learn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_learn_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_learn_label)

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
	_num_elements = GameState.sort_elements
	_sort_descending = randf() < 0.3
	_selected_index = -1
	_swap_count = 0
	_generate_values()
	_rebuild_buttons()
	if _status_label:
		var dir_text: String = "descending (largest first)" if _sort_descending else "ascending (smallest first)"
		_status_label.text = "Sort %s to defuse" % dir_text
		_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_swap_count_label.text = "Swaps: 0"
		_hint_label.text = ""


func _generate_values() -> void:
	_values.clear()
	for i in range(_num_elements):
		_values.append(randi_range(10, 99))
	# Compute and cache sorted target once
	_sorted_target = _values.duplicate()
	_sorted_target.sort()
	if _sort_descending:
		_sorted_target.reverse()
	while _values == _sorted_target:
		_values.shuffle()


func _rebuild_buttons() -> void:
	"""Recreate the button row from current values."""
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	for i in range(_values.size()):
		var btn := Button.new()
		btn.text = str(_values[i])
		btn.custom_minimum_size = Vector2(50, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_button_pressed.bind(i))
		_button_row.add_child(btn)
		_buttons.append(btn)

	_update_button_colors()


func _update_button_colors() -> void:
	for i in range(_buttons.size()):
		if i == _selected_index:
			_buttons[i].add_theme_color_override("font_color", Color("#00e5ff"))
		elif _values[i] == _sorted_target[i]:
			_buttons[i].add_theme_color_override("font_color", Color("#00e676"))
		else:
			_buttons[i].add_theme_color_override("font_color", Color("#e0e0e0"))


func _on_button_pressed(index: int) -> void:
	if is_solved:
		return
	_start_timer_if_needed()

	if _selected_index == -1:
		# First selection
		_selected_index = index
		_update_button_colors()
		_status_label.text = "Now select second value to swap"
	elif _selected_index == index:
		# Deselect
		_selected_index = -1
		_update_button_colors()
		_status_label.text = "Select two values to swap"
	else:
		# Perform swap
		var inversions_before := _count_inversions()
		var temp: int = _values[_selected_index]
		_values[_selected_index] = _values[index]
		_values[index] = temp
		var inversions_after := _count_inversions()

		_swap_count += 1
		_swap_count_label.text = "Swaps: %d" % _swap_count
		_selected_index = -1

		if inversions_after >= inversions_before:
			# Non-improving swap — penalty
			var dir_hint: String = "a smaller value precedes a larger one" if _sort_descending else "a larger value precedes a smaller one"
			_status_label.text = "Bad swap! Inversions: %d → %d (must decrease). An inversion is any pair where %s." % [inversions_before, inversions_after, dir_hint]
			_status_label.add_theme_color_override("font_color", Color("#ff1744"))
			record_wrong_action()
		else:
			_status_label.text = "Good swap! Inversions: %d → %d" % [inversions_before, inversions_after]
			_status_label.add_theme_color_override("font_color", Color("#00e676"))

		# Update buttons with new values
		for i in range(_buttons.size()):
			_buttons[i].text = str(_values[i])
		_update_button_colors()

		# Check if sorted
		if _is_sorted():
			_status_label.text = "SIGNAL SORTED!"
			_status_label.add_theme_color_override("font_color", Color("#00e676"))
			if _learn_label:
				var dir_name: String = "descending" if _sort_descending else "ascending"
				_learn_label.text = "Key Insight: Sorting algorithms work by systematically reducing inversions. You sorted %d elements %s in %d swaps." % [_num_elements, dir_name, _swap_count]
			complete_module()


func _count_inversions() -> int:
	var count := 0
	for i in range(_values.size()):
		for j in range(i + 1, _values.size()):
			if (_values[i] > _values[j]) != _sort_descending:
				count += 1
	return count


func _is_sorted() -> bool:
	return _values == _sorted_target


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"values": _values.duplicate(),
		"inversions": _count_inversions(),
		"swaps": _swap_count,
		"sort_direction": "descending" if _sort_descending else "ascending",
		"mistakes": mistakes,
	}
