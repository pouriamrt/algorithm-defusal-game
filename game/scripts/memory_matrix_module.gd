extends BaseModule
## Memory Matrix Module — Spatial Memory puzzle.
## A grid pattern is shown briefly, then hidden. Player must reproduce it from memory.

var _grid_size: int = 4  # 4x4 grid
var _num_highlighted: int = 6  # cells to remember
var _target_cells: Array[int] = []  # flat indices of highlighted cells
var _player_cells: Array[int] = []  # cells the player has clicked
var _showing_pattern: bool = true
var _show_timer: float = 3.0  # seconds to memorize
var _show_remaining: float = 3.0
var _attempt_count: int = 0

# UI references
var _grid_container: GridContainer
var _buttons: Array[Button] = []
var _status_label: Label
var _timer_label: Label
var _confirm_btn: Button


func _ready() -> void:
	module_name = "Memory Matrix"
	algorithm_name = "Spatial Memory (Caching)"
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

	_status_label = Label.new()
	_status_label.text = "MEMORIZE THE PATTERN"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color("#ffeb3b"))
	vbox.add_child(_status_label)

	_timer_label = Label.new()
	_timer_label.text = ""
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 12)
	_timer_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_timer_label)

	# Grid
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)

	_grid_container = GridContainer.new()
	_grid_container.columns = _grid_size
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 4)
	grid_center.add_child(_grid_container)

	# Confirm button
	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRM PATTERN"
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.visible = false
	vbox.add_child(_confirm_btn)

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
	_player_cells.clear()
	_showing_pattern = true
	_show_remaining = _show_timer
	_generate_pattern()
	_rebuild_grid()
	if _status_label:
		_status_label.text = "MEMORIZE THE PATTERN"
		_status_label.add_theme_color_override("font_color", Color("#ffeb3b"))
		_hint_label.text = ""
		_confirm_btn.visible = false


func _generate_pattern() -> void:
	_target_cells.clear()
	var total_cells: int = _grid_size * _grid_size
	# Adjust highlighted count based on wave difficulty
	var wave: int = GameState.current_wave
	_num_highlighted = min(total_cells - 2, 5 + int(wave * 0.5))

	var all_indices: Array[int] = []
	for i in range(total_cells):
		all_indices.append(i)

	# Shuffle and pick
	for i in range(all_indices.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var temp: int = all_indices[i]
		all_indices[i] = all_indices[j]
		all_indices[j] = temp

	for i in range(_num_highlighted):
		_target_cells.append(all_indices[i])


func _rebuild_grid() -> void:
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	var total: int = _grid_size * _grid_size
	var btn_size: float = 50.0

	for i in range(total):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(btn_size, btn_size)
		btn.text = ""
		btn.pressed.connect(_on_cell_pressed.bind(i))

		if _showing_pattern and i in _target_cells:
			btn.add_theme_color_override("font_color", Color("#00e5ff"))
			_set_button_highlight(btn, true)
		else:
			_set_button_highlight(btn, false)

		_grid_container.add_child(btn)
		_buttons.append(btn)


func _set_button_highlight(btn: Button, highlighted: bool) -> void:
	if highlighted:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#00e5ff", 0.6)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#141b2d")
		style.border_color = Color("#333355")
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)


func _process(delta: float) -> void:
	if is_solved or not _showing_pattern:
		return

	_show_remaining -= delta
	_timer_label.text = "%.1fs" % max(0.0, _show_remaining)

	if _show_remaining <= 0:
		_showing_pattern = false
		_timer_label.text = ""
		_status_label.text = "Reproduce the pattern! (%d cells)" % _num_highlighted
		_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_confirm_btn.visible = true
		# Hide all highlights
		for btn in _buttons:
			_set_button_highlight(btn, false)


func _on_cell_pressed(index: int) -> void:
	if is_solved or _showing_pattern:
		return
	_start_timer_if_needed()

	if index in _player_cells:
		# Deselect
		_player_cells.erase(index)
		_set_button_highlight(_buttons[index], false)
	else:
		_player_cells.append(index)
		# Show as selected (orange to distinguish from original cyan)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#ff6f00", 0.6)
		style.set_corner_radius_all(4)
		_buttons[index].add_theme_stylebox_override("normal", style)

	_status_label.text = "Selected: %d / %d cells" % [_player_cells.size(), _num_highlighted]


func _on_confirm() -> void:
	if is_solved:
		return
	_attempt_count += 1

	# Check if player's selection matches target
	var correct: int = 0
	for cell in _player_cells:
		if cell in _target_cells:
			correct += 1

	var wrong: int = _player_cells.size() - correct
	var missed: int = _num_highlighted - correct

	if correct == _num_highlighted and wrong == 0:
		_status_label.text = "PATTERN MATCHED!"
		_status_label.add_theme_color_override("font_color", Color("#00e676"))
		_confirm_btn.visible = false
		# Show correct pattern in green
		for i in range(_buttons.size()):
			if i in _target_cells:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("#00e676", 0.6)
				style.set_corner_radius_all(4)
				_buttons[i].add_theme_stylebox_override("normal", style)
		complete_module()
	else:
		_status_label.text = "%d correct, %d wrong, %d missed. Try again!" % [correct, wrong, missed]
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()
		# Reset player selection but don't show pattern again
		_player_cells.clear()
		for btn in _buttons:
			_set_button_highlight(btn, false)


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"grid_size": _grid_size,
		"num_highlighted": _num_highlighted,
		"attempts": _attempt_count,
		"player_selected": _player_cells.size(),
		"mistakes": mistakes,
	}
