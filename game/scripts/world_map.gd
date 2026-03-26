extends Control
## World map screen between waves. Shows a polished global threat map
## with filled continents, ocean grid, city markers, flight paths, and intel panel.

var _map_draw: Control
var _info_panel: VBoxContainer
var _city_label: Label
var _region_label: Label
var _wave_label: Label
var _threat_label: Label
var _timer_preview: Label
var _briefing_text: Label
var _deploy_btn: Button
var _time: float = 0.0
var _flight_progress: float = 0.0
var _flight_animating: bool = true
var _particles: Array[Dictionary] = []

# Map occupies left ~65% of screen, panel on right
const MAP_MARGIN: float = 25.0
const PANEL_WIDTH_RATIO: float = 0.32

# More detailed continent polygons (normalized 0-1)
const CONTINENTS: Array = [
	# North America
	[Vector2(0.05, 0.22), Vector2(0.08, 0.16), Vector2(0.14, 0.10), Vector2(0.20, 0.08),
	 Vector2(0.26, 0.12), Vector2(0.28, 0.18), Vector2(0.30, 0.24), Vector2(0.28, 0.30),
	 Vector2(0.26, 0.36), Vector2(0.22, 0.42), Vector2(0.20, 0.46), Vector2(0.17, 0.48),
	 Vector2(0.14, 0.46), Vector2(0.10, 0.42), Vector2(0.07, 0.35), Vector2(0.05, 0.28)],
	# Central America
	[Vector2(0.17, 0.48), Vector2(0.19, 0.47), Vector2(0.21, 0.50), Vector2(0.20, 0.54),
	 Vector2(0.18, 0.52)],
	# South America
	[Vector2(0.21, 0.52), Vector2(0.25, 0.50), Vector2(0.30, 0.52), Vector2(0.34, 0.56),
	 Vector2(0.36, 0.62), Vector2(0.37, 0.68), Vector2(0.35, 0.75), Vector2(0.32, 0.80),
	 Vector2(0.28, 0.84), Vector2(0.26, 0.80), Vector2(0.24, 0.72), Vector2(0.22, 0.64),
	 Vector2(0.21, 0.58)],
	# Europe
	[Vector2(0.44, 0.14), Vector2(0.47, 0.12), Vector2(0.50, 0.13), Vector2(0.53, 0.15),
	 Vector2(0.55, 0.18), Vector2(0.54, 0.24), Vector2(0.52, 0.28), Vector2(0.50, 0.32),
	 Vector2(0.47, 0.34), Vector2(0.44, 0.32), Vector2(0.42, 0.28), Vector2(0.43, 0.22)],
	# Africa
	[Vector2(0.44, 0.36), Vector2(0.47, 0.34), Vector2(0.52, 0.36), Vector2(0.56, 0.38),
	 Vector2(0.58, 0.42), Vector2(0.60, 0.48), Vector2(0.60, 0.56), Vector2(0.58, 0.64),
	 Vector2(0.55, 0.70), Vector2(0.52, 0.74), Vector2(0.48, 0.72), Vector2(0.46, 0.66),
	 Vector2(0.44, 0.58), Vector2(0.43, 0.48), Vector2(0.44, 0.40)],
	# Asia
	[Vector2(0.55, 0.12), Vector2(0.60, 0.08), Vector2(0.68, 0.10), Vector2(0.75, 0.12),
	 Vector2(0.82, 0.16), Vector2(0.88, 0.20), Vector2(0.90, 0.28), Vector2(0.88, 0.34),
	 Vector2(0.84, 0.38), Vector2(0.78, 0.42), Vector2(0.72, 0.46), Vector2(0.66, 0.48),
	 Vector2(0.62, 0.44), Vector2(0.58, 0.38), Vector2(0.56, 0.30), Vector2(0.55, 0.22)],
	# India subcontinent
	[Vector2(0.66, 0.40), Vector2(0.70, 0.42), Vector2(0.72, 0.48), Vector2(0.70, 0.54),
	 Vector2(0.67, 0.52), Vector2(0.65, 0.46)],
	# Australia
	[Vector2(0.82, 0.60), Vector2(0.86, 0.58), Vector2(0.92, 0.60), Vector2(0.95, 0.64),
	 Vector2(0.94, 0.72), Vector2(0.90, 0.76), Vector2(0.85, 0.74), Vector2(0.82, 0.68)],
]


func _ready() -> void:
	# Initialize ambient particles
	for i in range(30):
		_particles.append({
			"pos": Vector2(randf(), randf()),
			"speed": randf_range(0.002, 0.008),
			"phase": randf() * TAU,
			"size": randf_range(1.0, 2.5),
		})
	_build_ui()
	_start_flight_animation()
	_load_city_briefing()


func _build_ui() -> void:
	# Deep ocean background
	var bg := ColorRect.new()
	bg.color = Color("#030610")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Map drawing area (full screen, panel overlays on right)
	_map_draw = Control.new()
	_map_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_draw.draw.connect(_on_map_draw)
	add_child(_map_draw)

	# Right info panel with glass-morphism style
	var panel_anchor := MarginContainer.new()
	panel_anchor.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel_anchor.add_theme_constant_override("margin_top", 20)
	panel_anchor.add_theme_constant_override("margin_bottom", 20)
	panel_anchor.add_theme_constant_override("margin_right", 20)
	panel_anchor.add_theme_constant_override("margin_left", 0)
	panel_anchor.custom_minimum_size = Vector2(380, 0)
	add_child(panel_anchor)

	var panel_bg := PanelContainer.new()
	panel_anchor.add_child(panel_bg)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 25)
	panel_margin.add_theme_constant_override("margin_right", 25)
	panel_margin.add_theme_constant_override("margin_top", 25)
	panel_margin.add_theme_constant_override("margin_bottom", 25)
	panel_bg.add_child(panel_margin)

	_info_panel = VBoxContainer.new()
	_info_panel.add_theme_constant_override("separation", 10)
	panel_margin.add_child(_info_panel)

	var current_city: Dictionary = WaveData.get_city(DifficultyManager.current_wave)
	var accent: Color = WaveData.get_accent_color(DifficultyManager.current_wave)

	# CIA header
	var cia_header := Label.new()
	cia_header.text = "C.A.T.U. — MISSION BRIEF"
	cia_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cia_header.add_theme_font_size_override("font_size", 11)
	cia_header.add_theme_color_override("font_color", Color("#ff1744", 0.5))
	_info_panel.add_child(cia_header)

	_wave_label = Label.new()
	_wave_label.text = "WAVE %d OF %d" % [DifficultyManager.current_wave, WaveData.TOTAL_WAVES]
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 13)
	_wave_label.add_theme_color_override("font_color", Color("#667788"))
	_info_panel.add_child(_wave_label)

	_city_label = Label.new()
	_city_label.text = str(current_city.get("name", "Unknown"))
	_city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_city_label.add_theme_font_size_override("font_size", 26)
	_city_label.add_theme_color_override("font_color", accent)
	_info_panel.add_child(_city_label)

	_region_label = Label.new()
	_region_label.text = str(current_city.get("region", ""))
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 13)
	_region_label.add_theme_color_override("font_color", Color("#8899aa"))
	_info_panel.add_child(_region_label)

	# Threat level with icon-style display
	_threat_label = Label.new()
	var threat_str: String = str(current_city.get("threat", "LOW"))
	_threat_label.text = "THREAT LEVEL: %s" % threat_str
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_threat_label.add_theme_font_size_override("font_size", 15)
	var threat_color := Color("#00e676")
	match threat_str:
		"MODERATE": threat_color = Color("#ddaa44")
		"ELEVATED": threat_color = Color("#ff6f00")
		"HIGH": threat_color = Color("#ff4444")
		"SEVERE": threat_color = Color("#dd2222")
		"CRITICAL": threat_color = Color("#ff0000")
	_threat_label.add_theme_color_override("font_color", threat_color)
	_info_panel.add_child(_threat_label)

	_info_panel.add_child(HSeparator.new())

	# Difficulty preview with bars
	var params: Dictionary = DifficultyManager.get_wave_params()
	var diff_header := Label.new()
	diff_header.text = "PARAMETERS"
	diff_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_header.add_theme_font_size_override("font_size", 11)
	diff_header.add_theme_color_override("font_color", Color("#556677"))
	_info_panel.add_child(diff_header)

	_timer_preview = Label.new()
	_timer_preview.text = "Time: %ds   Stability: %d   Penalty: %d" % [
		int(params["timer_total"]), int(params["stability_max"]), int(params["stability_penalty"])]
	_timer_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_preview.add_theme_font_size_override("font_size", 12)
	_timer_preview.add_theme_color_override("font_color", Color("#8899bb"))
	_info_panel.add_child(_timer_preview)

	_info_panel.add_child(HSeparator.new())

	# Intel briefing
	var intel_header := Label.new()
	intel_header.text = "INTELLIGENCE BRIEFING"
	intel_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intel_header.add_theme_font_size_override("font_size", 11)
	intel_header.add_theme_color_override("font_color", Color("#556677"))
	_info_panel.add_child(intel_header)

	_briefing_text = Label.new()
	_briefing_text.text = "Receiving intel..."
	_briefing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_text.add_theme_font_size_override("font_size", 15)
	_briefing_text.add_theme_color_override("font_color", Color("#ccccdd"))
	_briefing_text.custom_minimum_size = Vector2(300, 100)
	_info_panel.add_child(_briefing_text)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_panel.add_child(spacer)

	_deploy_btn = Button.new()
	_deploy_btn.text = "DEPLOY AGENT"
	_deploy_btn.custom_minimum_size = Vector2(280, 50)
	_deploy_btn.add_theme_font_size_override("font_size", 20)
	_deploy_btn.pressed.connect(_on_deploy)
	var btn_center := CenterContainer.new()
	btn_center.add_child(_deploy_btn)
	_info_panel.add_child(btn_center)


func _load_city_briefing() -> void:
	var city: Dictionary = WaveData.get_city(DifficultyManager.current_wave)
	var city_name: String = str(city.get("name", "Unknown"))
	var threat: String = str(city.get("threat", "LOW"))
	var fallback := "Intel confirms a NEXUS device in %s. Threat level: %s. Proceed with caution, Agent." % [city_name, threat]
	_briefing_text.text = fallback
	var llm_text: String = LLMService.get_city_briefing(city_name, DifficultyManager.current_wave, threat)
	if llm_text != "":
		_briefing_text.text = llm_text
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "city_briefing":
		_briefing_text.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)


func _start_flight_animation() -> void:
	_flight_progress = 0.0
	_flight_animating = true


func _process(delta: float) -> void:
	_time += delta
	if _flight_animating:
		_flight_progress = min(1.0, _flight_progress + delta * 0.6)
		if _flight_progress >= 1.0:
			_flight_animating = false
	_map_draw.queue_redraw()


func _get_map_rect() -> Rect2:
	"""Map area scales with window, leaving room for panel on right."""
	var panel_w: float = size.x * PANEL_WIDTH_RATIO
	return Rect2(
		MAP_MARGIN, MAP_MARGIN,
		size.x - panel_w - MAP_MARGIN * 2,
		size.y - MAP_MARGIN * 2
	)


func _map_pos(normalized: Vector2) -> Vector2:
	var mr: Rect2 = _get_map_rect()
	return Vector2(
		mr.position.x + normalized.x * mr.size.x,
		mr.position.y + normalized.y * mr.size.y
	)


func _on_map_draw() -> void:
	var d := _map_draw
	var mr: Rect2 = _get_map_rect()

	# Ocean grid lines (subtle lat/lon)
	_draw_ocean_grid(d, mr)

	# Filled continents with glow
	_draw_continents(d)

	# Ambient particles
	_draw_ambient_particles(d, mr)

	# Flight paths and cities
	var current_wave: int = DifficultyManager.current_wave
	_draw_completed_paths(d, current_wave)
	_draw_flight_animation(d, current_wave)
	_draw_cities(d, current_wave)

	# Title and frame
	_draw_map_frame(d, mr)


func _draw_ocean_grid(d: Control, mr: Rect2) -> void:
	# Latitude lines
	var lat_count: int = 8
	for i in range(lat_count + 1):
		var y: float = mr.position.y + mr.size.y * float(i) / lat_count
		var alpha: float = 0.04 + 0.02 * sin(_time * 0.3 + i)
		d.draw_line(Vector2(mr.position.x, y), Vector2(mr.position.x + mr.size.x, y), Color(0.1, 0.2, 0.4, alpha), 1.0)

	# Longitude lines
	var lon_count: int = 12
	for i in range(lon_count + 1):
		var x: float = mr.position.x + mr.size.x * float(i) / lon_count
		var alpha: float = 0.04 + 0.02 * sin(_time * 0.4 + i)
		d.draw_line(Vector2(x, mr.position.y), Vector2(x, mr.position.y + mr.size.y), Color(0.1, 0.2, 0.4, alpha), 1.0)


func _draw_continents(d: Control) -> void:
	for continent in CONTINENTS:
		if continent.size() < 3:
			continue
		# Convert to screen positions
		var points := PackedVector2Array()
		for p in continent:
			points.append(_map_pos(p))

		# Filled continent (dark land mass)
		var fill_color := Color(0.06, 0.10, 0.18, 0.8)
		d.draw_polygon(points, PackedColorArray([fill_color]))

		# Outer glow
		for i in range(points.size()):
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[(i + 1) % points.size()]
			d.draw_line(p1, p2, Color(0.08, 0.25, 0.45, 0.15), 5.0)

		# Continent outline
		for i in range(points.size()):
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[(i + 1) % points.size()]
			d.draw_line(p1, p2, Color(0.15, 0.35, 0.55, 0.5), 1.5)


func _draw_ambient_particles(d: Control, mr: Rect2) -> void:
	for p in _particles:
		# Drift upward slowly
		p["pos"] = Vector2(
			fmod(float(p["pos"].x) + sin(_time + float(p["phase"])) * 0.0003, 1.0),
			fmod(float(p["pos"].y) - float(p["speed"]) * 0.1, 1.0)
		)
		if float(p["pos"].y) < 0:
			p["pos"] = Vector2(p["pos"].x, 1.0)
		var screen_pos: Vector2 = _map_pos(p["pos"])
		if mr.has_point(screen_pos):
			var alpha: float = 0.15 + 0.1 * sin(_time * 2.0 + float(p["phase"]))
			d.draw_circle(screen_pos, float(p["size"]), Color(0.2, 0.5, 0.8, alpha))


func _draw_completed_paths(d: Control, current_wave: int) -> void:
	for w in range(1, current_wave - 1):
		var c1: Dictionary = WaveData.get_city(w)
		var c2: Dictionary = WaveData.get_city(w + 1)
		var cp1: Vector2 = _map_pos(Vector2(float(c1["x"]), float(c1["y"])))
		var cp2: Vector2 = _map_pos(Vector2(float(c2["x"]), float(c2["y"])))
		# Glow
		d.draw_line(cp1, cp2, Color(0, 0.9, 0.4, 0.08), 4.0)
		d.draw_line(cp1, cp2, Color(0, 0.9, 0.4, 0.25), 1.5)


func _draw_flight_animation(d: Control, current_wave: int) -> void:
	if current_wave <= 1:
		return
	var prev_city: Dictionary = WaveData.get_city(current_wave - 1)
	var curr_city: Dictionary = WaveData.get_city(current_wave)
	var p1: Vector2 = _map_pos(Vector2(float(prev_city["x"]), float(prev_city["y"])))
	var p2: Vector2 = _map_pos(Vector2(float(curr_city["x"]), float(curr_city["y"])))

	# Animated dashed flight line
	var seg_count: int = 30
	for i in range(seg_count):
		var t1: float = float(i) / seg_count
		var t2: float = float(i + 1) / seg_count
		if t2 > _flight_progress:
			break
		if i % 2 == 0:
			var s1: Vector2 = p1.lerp(p2, t1)
			var s2: Vector2 = p1.lerp(p2, min(t2, _flight_progress))
			d.draw_line(s1, s2, Color(0, 0.9, 1.0, 0.7), 2.0)
			d.draw_line(s1, s2, Color(0, 0.6, 0.8, 0.2), 5.0)

	# Plane icon
	if _flight_animating:
		var flight_end: Vector2 = p1.lerp(p2, _flight_progress)
		var dir: Vector2 = (p2 - p1).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		# Plane glow
		d.draw_circle(flight_end, 8, Color(0, 0.9, 1.0, 0.2))
		# Plane body
		d.draw_polygon(
			PackedVector2Array([
				flight_end + dir * 10,
				flight_end - dir * 6 + perp * 5,
				flight_end - dir * 3,
				flight_end - dir * 6 - perp * 5,
			]),
			PackedColorArray([Color(0, 0.9, 1.0, 0.9)])
		)


func _draw_cities(d: Control, current_wave: int) -> void:
	for w in range(1, WaveData.TOTAL_WAVES + 1):
		var city: Dictionary = WaveData.get_city(w)
		var pos: Vector2 = _map_pos(Vector2(float(city["x"]), float(city["y"])))
		var accent: Color = Color(city["accent"])
		var city_name: String = str(city["name"])

		if w < current_wave:
			# Completed — green with checkmark feel
			d.draw_circle(pos, 8, Color(0, 0.9, 0.4, 0.15))
			d.draw_circle(pos, 5, Color(0, 0.8, 0.4, 0.6))
			d.draw_circle(pos, 2.5, Color(0.5, 1, 0.7))
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(10, -6), city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0.8, 0.4, 0.5))
		elif w == current_wave:
			# Current target — large pulsing marker
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			# Outer pulse rings
			d.draw_arc(pos, 20 + pulse * 6, 0, TAU, 32, Color(1, 0.15, 0, 0.2 + pulse * 0.1), 2.0)
			d.draw_arc(pos, 14 + pulse * 3, 0, TAU, 32, Color(1, 0.2, 0, 0.3), 1.5)
			# Inner dot
			d.draw_circle(pos, 8, Color(accent, 0.8))
			d.draw_circle(pos, 4, Color(1, 1, 1, 0.7))
			# City name (larger, brighter)
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(14, -10), city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
			# Target crosshair
			var ch_size: float = 12.0
			d.draw_line(pos + Vector2(-ch_size, 0), pos + Vector2(-6, 0), Color(1, 0.3, 0, 0.4), 1.0)
			d.draw_line(pos + Vector2(6, 0), pos + Vector2(ch_size, 0), Color(1, 0.3, 0, 0.4), 1.0)
			d.draw_line(pos + Vector2(0, -ch_size), pos + Vector2(0, -6), Color(1, 0.3, 0, 0.4), 1.0)
			d.draw_line(pos + Vector2(0, 6), pos + Vector2(0, ch_size), Color(1, 0.3, 0, 0.4), 1.0)
		else:
			# Upcoming — small dim dot with name on hover proximity
			d.draw_circle(pos, 3, Color(0.25, 0.3, 0.4, 0.5))
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(6, -4), city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.35, 0.45, 0.35))


func _draw_map_frame(d: Control, mr: Rect2) -> void:
	# Title
	d.draw_string(ThemeDB.fallback_font, Vector2(mr.position.x + 5, mr.position.y - 5),
		"GLOBAL THREAT MAP — OPERATION DARKFIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0.7, 1.0, 0.4))

	# Corner brackets
	var cl: float = 30.0
	var cc := Color(0, 0.6, 0.9, 0.25)
	var x1: float = mr.position.x
	var y1: float = mr.position.y
	var x2: float = mr.position.x + mr.size.x
	var y2: float = mr.position.y + mr.size.y

	d.draw_line(Vector2(x1, y1), Vector2(x1 + cl, y1), cc, 1.5)
	d.draw_line(Vector2(x1, y1), Vector2(x1, y1 + cl), cc, 1.5)
	d.draw_line(Vector2(x2, y1), Vector2(x2 - cl, y1), cc, 1.5)
	d.draw_line(Vector2(x2, y1), Vector2(x2, y1 + cl), cc, 1.5)
	d.draw_line(Vector2(x1, y2), Vector2(x1 + cl, y2), cc, 1.5)
	d.draw_line(Vector2(x1, y2), Vector2(x1, y2 - cl), cc, 1.5)
	d.draw_line(Vector2(x2, y2), Vector2(x2 - cl, y2), cc, 1.5)
	d.draw_line(Vector2(x2, y2), Vector2(x2, y2 - cl), cc, 1.5)

	# Scan line
	var scan_y: float = mr.position.y + fmod(_time * 40.0, mr.size.y)
	d.draw_line(Vector2(x1, scan_y), Vector2(x2, scan_y), Color(0, 0.7, 1.0, 0.04), 1.0)


func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")
