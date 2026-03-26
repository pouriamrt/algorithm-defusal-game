extends BaseModule
## Priority Queue Module — Scheduling puzzle.
## Tasks with priorities appear. Player must click them in correct priority order
## (highest priority first).

var _tasks: Array[Dictionary] = []  # {name, priority, processed}
var _correct_order: Array[int] = []  # indices in priority order
var _player_order: Array[int] = []
var _next_expected: int = 0
var _min_priority_mode: bool = false

# UI references
var _task_buttons: Array[Button] = []
var _grid: GridContainer
var _progress_label: Label
var _feedback_label: Label
var _order_label: Label


func _ready() -> void:
	module_name = "Priority Queue"
	algorithm_name = "Priority Queue (Heap)"
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
	intro.text = "PRIORITY SCHEDULING: Process tasks by priority. Max-queue = highest first. Min-queue = lowest first. The mode varies!"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#aabbcc"))
	intro.add_theme_font_size_override("font_size", 11)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(intro)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_progress_label)

	# Task grid
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	center.add_child(_grid)

	# Processed order display
	_order_label = Label.new()
	_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_order_label.add_theme_font_size_override("font_size", 12)
	_order_label.add_theme_color_override("font_color", Color("#aabbcc"))
	_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_order_label)

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
	_tasks.clear()
	_correct_order.clear()
	_player_order.clear()
	_next_expected = 0
	_min_priority_mode = randf() < 0.35
	_generate_tasks()
	if _feedback_label:
		var mode_text: String = "lowest first (MIN-QUEUE)" if _min_priority_mode else "highest first (MAX-QUEUE)"
		_feedback_label.text = "Click tasks in priority order: %s" % mode_text
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_learn_label.text = ""
		_hint_label.text = ""
		_rebuild_grid()
		_update_progress()


func _generate_tasks() -> void:
	var task_names := ["SCAN", "PING", "SYNC", "DUMP", "LOAD", "AUTH", "SEND", "RECV", "LOCK"]
	task_names.shuffle()
	var num_tasks: int = min(9, 6 + int(GameState.current_wave * 0.3))
	var priorities_used: Array[int] = []

	for i in range(num_tasks):
		var priority: int = randi_range(1, 99)
		while priority in priorities_used:
			priority = randi_range(1, 99)
		priorities_used.append(priority)
		_tasks.append({
			"name": task_names[i % task_names.size()],
			"priority": priority,
			"processed": false,
		})

	# Build correct order based on mode
	var indexed: Array[Dictionary] = []
	for i in range(_tasks.size()):
		indexed.append({"index": i, "priority": int(_tasks[i]["priority"])})
	if _min_priority_mode:
		# Sort by priority ascending (lowest first)
		indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["priority"]) < int(b["priority"])
		)
	else:
		# Sort by priority descending (highest first)
		indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["priority"]) > int(b["priority"])
		)
	for entry in indexed:
		_correct_order.append(int(entry["index"]))


func _rebuild_grid() -> void:
	for btn in _task_buttons:
		btn.queue_free()
	_task_buttons.clear()

	for i in range(_tasks.size()):
		var task: Dictionary = _tasks[i]
		var btn := Button.new()
		btn.text = "%s\nP:%d" % [str(task["name"]), int(task["priority"])]
		btn.custom_minimum_size = Vector2(85, 55)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_task_clicked.bind(i))
		_grid.add_child(btn)
		_task_buttons.append(btn)


func _on_task_clicked(index: int) -> void:
	if is_solved or bool(_tasks[index]["processed"]):
		return
	_start_timer_if_needed()

	var expected_index: int = _correct_order[_next_expected]

	if index == expected_index:
		# Correct — process this task
		_tasks[index]["processed"] = true
		_player_order.append(index)
		_next_expected += 1

		# Gray out the button
		_task_buttons[index].disabled = true
		_task_buttons[index].add_theme_color_override("font_color", Color("#00e676"))

		_update_progress()

		if _next_expected >= _correct_order.size():
			_feedback_label.text = "QUEUE CLEARED!"
			_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
			if _learn_label:
				var mode_name: String = "min-priority queue (lowest first)" if _min_priority_mode else "max-priority queue (highest first)"
				_learn_label.text = "Key Insight: A %s extracts items by priority. Implemented as a binary heap, O(log n) per operation. Used in Dijkstra's, OS scheduling, and event systems." % mode_name
			complete_module()
		else:
			var next_hint: String = "lowest" if _min_priority_mode else "highest"
			_feedback_label.text = "Correct! Next: find the %s remaining priority." % next_hint
			_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
	else:
		# Wrong — tell them why
		var clicked_priority: int = int(_tasks[index]["priority"])
		var expected_priority: int = int(_tasks[expected_index]["priority"])
		if _min_priority_mode:
			_feedback_label.text = "Wrong! P:%d is not the lowest. P:%d should go first (MIN-QUEUE: lower priority = processed first)." % [clicked_priority, expected_priority]
		else:
			_feedback_label.text = "Wrong! P:%d is not the highest. P:%d should go first (MAX-QUEUE: higher priority = processed first)." % [clicked_priority, expected_priority]
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()


func _update_progress() -> void:
	_progress_label.text = "Processed: %d / %d tasks" % [_next_expected, _tasks.size()]
	if not _player_order.is_empty():
		var parts: Array[String] = []
		for idx in _player_order:
			parts.append("%s(P:%d)" % [str(_tasks[idx]["name"]), int(_tasks[idx]["priority"])])
		_order_label.text = "Order: " + " → ".join(parts)
	else:
		_order_label.text = ""


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"total_tasks": _tasks.size(),
		"processed": _next_expected,
		"mistakes": mistakes,
	}
