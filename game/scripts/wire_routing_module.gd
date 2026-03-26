extends BaseModule
## Wire Routing Module — Shortest Path puzzle.
## Player clicks nodes to build a path through a weighted graph.
## Validates against Dijkstra's optimal shortest path.

var _num_nodes: int = 6
var _num_extra_edges: int = 2
const GRAPH_SIZE: Vector2 = Vector2(300, 280)
const NODE_RADIUS: float = 20.0

var _nodes: Array[Vector2] = []  # positions
var _edges: Array[Dictionary] = []  # {from, to, cost}
var _adjacency: Dictionary = {}  # node_index -> [{to, cost}]
var _source: int = 0
var _target: int = 5
var _optimal_cost: int = 0
var _player_path: Array[int] = []
var _player_cost: int = 0
var _attempt_count: int = 0

# UI references
var _graph_panel: Panel
var _graph_draw: Control
var _path_label: Label
var _cost_label: Label
var _confirm_btn: Button
var _reset_btn: Button


func _ready() -> void:
	module_name = "Wire Routing"
	algorithm_name = "Shortest Path (Dijkstra)"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	# Graph drawing area
	_graph_panel = Panel.new()
	_graph_panel.custom_minimum_size = GRAPH_SIZE
	vbox.add_child(_graph_panel)

	_graph_draw = Control.new()
	_graph_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph_draw.draw.connect(_on_draw)
	_graph_draw.gui_input.connect(_on_graph_input)
	_graph_panel.add_child(_graph_draw)

	# Path display
	_path_label = Label.new()
	_path_label.text = "Path: (click nodes)"
	_path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_path_label)

	# Cost display
	_cost_label = Label.new()
	_cost_label.text = "Cost: 0"
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_cost_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRM ROUTE"
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "RESET PATH"
	_reset_btn.pressed.connect(_on_reset_path)
	btn_row.add_child(_reset_btn)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_hint_label)

	# Hint button
	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_num_nodes = GameState.graph_nodes
	_num_extra_edges = GameState.graph_extra_edges
	_target = _num_nodes - 1
	_player_path.clear()
	_player_cost = 0
	_attempt_count = 0
	_generate_graph()
	_compute_shortest_path()
	if _path_label:
		_update_path_display()
		_hint_label.text = ""
		_confirm_btn.disabled = false
		_graph_draw.queue_redraw()


func _generate_graph() -> void:
	"""Generate node positions and edges with guaranteed connectivity."""
	_nodes.clear()
	_edges.clear()
	_adjacency.clear()

	# Place nodes in a dynamic grid-like pattern with some randomness
	var cols: int = max(2, (_num_nodes + 1) / 2)
	var rows: int = max(2, int(ceil(float(_num_nodes) / cols)))
	var cell_w: float = GRAPH_SIZE.x / cols
	var cell_h: float = GRAPH_SIZE.y / rows
	for i in range(_num_nodes):
		var r: int = i / cols
		var c: int = i % cols
		var x: float = cell_w * (c + 0.5) + randf_range(-20, 20)
		var y: float = cell_h * (r + 0.5) + randf_range(-15, 15)
		_nodes.append(Vector2(x, y))

	# Initialize adjacency
	for i in range(_num_nodes):
		_adjacency[i] = []

	# Ensure connectivity with a spanning path: 0->1->2->...->target
	for i in range(_num_nodes - 1):
		var cost: int = randi_range(1, 9)
		_add_edge(i, i + 1, cost)

	# Add extra edges for variety (some shortcuts, some traps)
	var extra_edges: Array = []
	for a in range(_num_nodes):
		for b in range(a + 2, _num_nodes):
			extra_edges.append([a, b])
	extra_edges.shuffle()
	for i in range(min(_num_extra_edges, extra_edges.size())):
		var pair: Array = extra_edges[i]
		if not _has_edge(pair[0], pair[1]):
			var cost: int = randi_range(1, 9)
			_add_edge(pair[0], pair[1], cost)


func _add_edge(from: int, to: int, cost: int) -> void:
	_edges.append({"from": from, "to": to, "cost": cost})
	_adjacency[from].append({"to": to, "cost": cost})
	_adjacency[to].append({"to": from, "cost": cost})


func _has_edge(from: int, to: int) -> bool:
	for edge in _edges:
		if (edge["from"] == from and edge["to"] == to) or \
		   (edge["from"] == to and edge["to"] == from):
			return true
	return false


func _compute_shortest_path() -> void:
	"""Dijkstra's algorithm to find optimal cost from source to target."""
	var dist: Array[int] = []
	var visited: Array[bool] = []
	for i in range(_num_nodes):
		dist.append(999999)
		visited.append(false)
	dist[_source] = 0

	for _i in range(_num_nodes):
		# Find unvisited node with smallest distance
		var u: int = -1
		var min_d: int = 999999
		for v in range(_num_nodes):
			if not visited[v] and dist[v] < min_d:
				min_d = dist[v]
				u = v
		if u == -1:
			break
		visited[u] = true
		# Relax neighbors
		for neighbor in _adjacency[u]:
			var v: int = neighbor["to"]
			var w: int = neighbor["cost"]
			if dist[u] + w < dist[v]:
				dist[v] = dist[u] + w

	_optimal_cost = dist[_target]


func _on_graph_input(event: InputEvent) -> void:
	if is_solved:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_timer_if_needed()
		# Check which node was clicked
		for i in range(_nodes.size()):
			if event.position.distance_to(_nodes[i]) <= NODE_RADIUS + 5:
				_handle_node_click(i)
				break


func _handle_node_click(node_index: int) -> void:
	if _player_path.is_empty():
		# Must start from source
		if node_index != _source:
			return
		_player_path.append(node_index)
	else:
		var last: int = _player_path[-1]
		if node_index == last:
			return
		# Prevent revisiting nodes (simple paths only)
		if node_index in _player_path:
			return
		# Check if edge exists between last and clicked node
		var edge_cost: int = _get_edge_cost(last, node_index)
		if edge_cost < 0:
			return  # No edge — ignore click
		_player_path.append(node_index)
		_player_cost += edge_cost

	_update_path_display()
	_graph_draw.queue_redraw()


func _get_edge_cost(from: int, to: int) -> int:
	"""Return edge cost or -1 if no edge exists."""
	for neighbor in _adjacency[from]:
		if neighbor["to"] == to:
			return neighbor["cost"]
	return -1


func _update_path_display() -> void:
	if _player_path.is_empty():
		_path_label.text = "Path: (click source node S)"
		_cost_label.text = "Cost: 0"
	else:
		var path_str := ""
		for i in range(_player_path.size()):
			if i > 0:
				path_str += " -> "
			path_str += _node_label(_player_path[i])
		_path_label.text = "Path: " + path_str
		_cost_label.text = "Cost: %d" % _player_cost


func _node_label(index: int) -> String:
	if index == _source:
		return "S"
	elif index == _target:
		return "T"
	else:
		return str(index)


func _on_confirm() -> void:
	if is_solved or _player_path.is_empty():
		return
	_attempt_count += 1

	# Must end at target
	if _player_path[-1] != _target:
		_path_label.text = "Route must end at target T!"
		_path_label.add_theme_color_override("font_color", Color("#ff1744"))
		return

	if _player_cost == _optimal_cost:
		_path_label.text = "OPTIMAL ROUTE FOUND!"
		_path_label.add_theme_color_override("font_color", Color("#00e676"))
		_confirm_btn.disabled = true
		complete_module()
	else:
		_path_label.text = "Not optimal (cost %d vs best %d). Try again!" % [_player_cost, _optimal_cost]
		_path_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()
		_on_reset_path()


func _on_reset_path() -> void:
	"""Reset the current path without penalty."""
	_player_path.clear()
	_player_cost = 0
	_update_path_display()
	_path_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_graph_draw.queue_redraw()


func _on_draw() -> void:
	"""Draw the graph: edges with costs, nodes as circles, player path highlighted."""
	# Draw edges
	for edge in _edges:
		var from_pos: Vector2 = _nodes[edge["from"]]
		var to_pos: Vector2 = _nodes[edge["to"]]
		var color := Color("#555555")

		# Highlight edges in player path
		for i in range(_player_path.size() - 1):
			if (_player_path[i] == edge["from"] and _player_path[i + 1] == edge["to"]) or \
			   (_player_path[i] == edge["to"] and _player_path[i + 1] == edge["from"]):
				color = Color("#00e5ff")
				break

		_graph_draw.draw_line(from_pos, to_pos, color, 2.0)

		# Draw cost label at midpoint
		var mid: Vector2 = (from_pos + to_pos) / 2.0
		var cost_str := str(edge["cost"])
		_graph_draw.draw_string(
			ThemeDB.fallback_font,
			mid + Vector2(-4, -4),
			cost_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14,
			Color("#ffeb3b")
		)

	# Draw nodes
	for i in range(_nodes.size()):
		var pos: Vector2 = _nodes[i]
		var color := Color("#e0e0e0")
		if i == _source:
			color = Color("#00e676")
		elif i == _target:
			color = Color("#ff1744")
		elif i in _player_path:
			color = Color("#00e5ff")

		_graph_draw.draw_circle(pos, NODE_RADIUS, color)
		# Node label
		var label := _node_label(i)
		_graph_draw.draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-6, 5),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14,
			Color("#0a0e17")
		)


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"attempts": _attempt_count,
		"current_cost": _player_cost,
		"optimal_cost": _optimal_cost,
		"path_length": _player_path.size(),
		"mistakes": mistakes,
	}
