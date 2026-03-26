extends Control
## World map screen between waves. Uses a real map texture with interactive overlays.

var _map_draw: Control
var _map_image: Texture2D
var _briefing_text: Label
var _time: float = 0.0
var _flight_progress: float = 0.0
var _flight_animating: bool = true
var _particles: Array[Dictionary] = []


func _ready() -> void:
	for i in range(25):
		_particles.append({
			"pos": Vector2(randf(), randf()),
			"speed": randf_range(0.003, 0.01),
			"phase": randf() * TAU,
			"size": randf_range(1.0, 2.0),
		})
	_build_ui()
	_flight_progress = 0.0
	_flight_animating = true
	_load_city_briefing()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color("#030610")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main horizontal split
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# LEFT: Map area — single Control draws both texture and overlays
	_map_image = load("res://assets/world_map.png")
	_map_draw = Control.new()
	_map_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_draw.size_flags_stretch_ratio = 2.0
	_map_draw.draw.connect(_on_map_draw)
	hbox.add_child(_map_draw)

	# RIGHT: Info panel
	var panel_wrapper := Control.new()
	panel_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_wrapper.size_flags_stretch_ratio = 0.85
	hbox.add_child(panel_wrapper)

	# Dark background
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.02, 0.04, 0.08, 0.95)
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_wrapper.add_child(panel_bg)

	# Margin for content
	var panel_outer := MarginContainer.new()
	panel_outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_outer.add_theme_constant_override("margin_left", 25)
	panel_outer.add_theme_constant_override("margin_right", 25)
	panel_outer.add_theme_constant_override("margin_top", 30)
	panel_outer.add_theme_constant_override("margin_bottom", 30)
	panel_wrapper.add_child(panel_outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel_outer.add_child(vbox)

	var current_city: Dictionary = WaveData.get_city(DifficultyManager.current_wave)
	var accent: Color = WaveData.get_accent_color(DifficultyManager.current_wave)

	# CIA header
	var cia := Label.new()
	cia.text = "C.A.T.U. INTELLIGENCE"
	cia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cia.add_theme_font_size_override("font_size", 11)
	cia.add_theme_color_override("font_color", Color("#ff1744", 0.5))
	vbox.add_child(cia)

	# Wave
	var wave_lbl := Label.new()
	wave_lbl.text = "— WAVE %d OF %d —" % [DifficultyManager.current_wave, WaveData.TOTAL_WAVES]
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_font_size_override("font_size", 13)
	wave_lbl.add_theme_color_override("font_color", Color("#667788"))
	vbox.add_child(wave_lbl)

	# City name
	var city_lbl := Label.new()
	city_lbl.text = str(current_city.get("name", "Unknown"))
	city_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	city_lbl.add_theme_font_size_override("font_size", 30)
	city_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(city_lbl)

	# Region
	var region_lbl := Label.new()
	region_lbl.text = str(current_city.get("region", ""))
	region_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_lbl.add_theme_font_size_override("font_size", 14)
	region_lbl.add_theme_color_override("font_color", Color("#8899aa"))
	vbox.add_child(region_lbl)

	# Threat
	var threat_str: String = str(current_city.get("threat", "LOW"))
	var threat_lbl := Label.new()
	threat_lbl.text = "THREAT: %s" % threat_str
	threat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	threat_lbl.add_theme_font_size_override("font_size", 16)
	var tc := Color("#00e676")
	match threat_str:
		"MODERATE": tc = Color("#ddaa44")
		"ELEVATED": tc = Color("#ff6f00")
		"HIGH": tc = Color("#ff4444")
		"SEVERE": tc = Color("#dd2222")
		"CRITICAL": tc = Color("#ff0000")
	threat_lbl.add_theme_color_override("font_color", tc)
	vbox.add_child(threat_lbl)

	vbox.add_child(HSeparator.new())

	# Parameters
	var params: Dictionary = DifficultyManager.get_wave_params()
	var params_lbl := Label.new()
	params_lbl.text = "Timer: %ds  |  Stability: %d  |  Penalty: %d" % [
		int(params["timer_total"]), int(params["stability_max"]), int(params["stability_penalty"])]
	params_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	params_lbl.add_theme_font_size_override("font_size", 12)
	params_lbl.add_theme_color_override("font_color", Color("#7788aa"))
	vbox.add_child(params_lbl)

	vbox.add_child(HSeparator.new())

	# Intel header
	var intel_hdr := Label.new()
	intel_hdr.text = "INTELLIGENCE BRIEFING"
	intel_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intel_hdr.add_theme_font_size_override("font_size", 11)
	intel_hdr.add_theme_color_override("font_color", Color("#556677"))
	vbox.add_child(intel_hdr)

	# Briefing text
	_briefing_text = Label.new()
	_briefing_text.text = "Receiving intel..."
	_briefing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_text.add_theme_font_size_override("font_size", 16)
	_briefing_text.add_theme_color_override("font_color", Color("#ccccdd"))
	_briefing_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_briefing_text)

	# Deploy button
	var deploy := Button.new()
	deploy.text = "DEPLOY AGENT"
	deploy.custom_minimum_size = Vector2(0, 55)
	deploy.add_theme_font_size_override("font_size", 22)
	deploy.pressed.connect(_on_deploy)
	vbox.add_child(deploy)

	# Left border accent line on panel
	var accent_line := ColorRect.new()
	accent_line.color = accent
	accent_line.custom_minimum_size = Vector2(2, 0)
	accent_line.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent_line.size = Vector2(2, 0)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_wrapper.add_child(accent_line)


func _load_city_briefing() -> void:
	var city: Dictionary = WaveData.get_city(DifficultyManager.current_wave)
	var city_name: String = str(city.get("name", "Unknown"))
	var threat: String = str(city.get("threat", "LOW"))
	_briefing_text.text = "Intel confirms a NEXUS device in %s. Threat level: %s. Proceed with caution, Agent." % [city_name, threat]
	LLMService.get_city_briefing(city_name, DifficultyManager.current_wave, threat)
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "city_briefing":
		_briefing_text.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)


func _process(delta: float) -> void:
	_time += delta
	if _flight_animating:
		_flight_progress = min(1.0, _flight_progress + delta * 0.6)
		if _flight_progress >= 1.0:
			_flight_animating = false
	_map_draw.queue_redraw()


func _map_pos(normalized: Vector2) -> Vector2:
	"""Convert normalized 0-1 coordinates to screen position matching the map texture."""
	var s: Vector2 = _map_draw.size
	# The map texture covers the full area (no margins), so map directly
	return Vector2(normalized.x * s.x, normalized.y * s.y)


func _on_map_draw() -> void:
	var d := _map_draw
	var s: Vector2 = d.size

	# Draw the map texture first — fills the entire control area
	if _map_image:
		d.draw_texture_rect(_map_image, Rect2(Vector2.ZERO, s), false)

	# Draw overlays in the same coordinate space
	var w: int = DifficultyManager.current_wave
	_draw_completed_paths(d, w)
	_draw_flight_animation(d, w)
	_draw_cities(d, w)
	_draw_frame(d, s)


func _draw_completed_paths(d: Control, current_wave: int) -> void:
	for wi in range(1, current_wave - 1):
		var c1: Dictionary = WaveData.get_city(wi)
		var c2: Dictionary = WaveData.get_city(wi + 1)
		var p1: Vector2 = _map_pos(Vector2(float(c1["x"]), float(c1["y"])))
		var p2: Vector2 = _map_pos(Vector2(float(c2["x"]), float(c2["y"])))
		d.draw_line(p1, p2, Color(0, 0.8, 0.4, 0.06), 4.0)
		d.draw_line(p1, p2, Color(0, 0.8, 0.4, 0.2), 1.5)


func _draw_flight_animation(d: Control, current_wave: int) -> void:
	if current_wave <= 1:
		return
	var prev: Dictionary = WaveData.get_city(current_wave - 1)
	var curr: Dictionary = WaveData.get_city(current_wave)
	var p1: Vector2 = _map_pos(Vector2(float(prev["x"]), float(prev["y"])))
	var p2: Vector2 = _map_pos(Vector2(float(curr["x"]), float(curr["y"])))

	var segs: int = 30
	for i in range(segs):
		var t1: float = float(i) / segs
		var t2: float = float(i + 1) / segs
		if t2 > _flight_progress:
			break
		if i % 2 == 0:
			var s1: Vector2 = p1.lerp(p2, t1)
			var s2: Vector2 = p1.lerp(p2, min(t2, _flight_progress))
			d.draw_line(s1, s2, Color(0, 0.85, 1.0, 0.6), 2.0)

	if _flight_animating:
		var end_pos: Vector2 = p1.lerp(p2, _flight_progress)
		var dir: Vector2 = (p2 - p1).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		d.draw_circle(end_pos, 6, Color(0, 0.9, 1.0, 0.2))
		d.draw_polygon(
			PackedVector2Array([end_pos + dir * 8, end_pos - dir * 5 + perp * 4, end_pos - dir * 2, end_pos - dir * 5 - perp * 4]),
			PackedColorArray([Color(0, 0.9, 1.0, 0.85)])
		)


func _draw_cities(d: Control, current_wave: int) -> void:
	for wi in range(1, WaveData.TOTAL_WAVES + 1):
		var city: Dictionary = WaveData.get_city(wi)
		var pos: Vector2 = _map_pos(Vector2(float(city["x"]), float(city["y"])))
		var accent: Color = Color(city["accent"])
		var cn: String = str(city["name"])

		if wi < current_wave:
			d.draw_circle(pos, 7, Color(0, 0.8, 0.4, 0.12))
			d.draw_circle(pos, 4, Color(0, 0.8, 0.4, 0.5))
			d.draw_circle(pos, 2, Color(0.5, 1, 0.7))
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(9, -5), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0.7, 0.4, 0.4))
		elif wi == current_wave:
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			d.draw_arc(pos, 18 + pulse * 5, 0, TAU, 32, Color(1, 0.15, 0, 0.15 + pulse * 0.1), 2.0)
			d.draw_arc(pos, 12 + pulse * 2, 0, TAU, 32, Color(1, 0.2, 0, 0.25), 1.5)
			d.draw_circle(pos, 7, Color(accent, 0.85))
			d.draw_circle(pos, 3.5, Color(1, 1, 1, 0.7))
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(12, -8), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)
			# Crosshair
			for offset in [Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 14)]:
				var inner: Vector2 = offset.normalized() * 7
				d.draw_line(pos + inner, pos + offset, Color(1, 0.3, 0, 0.35), 1.0)
		else:
			d.draw_circle(pos, 3, Color(0.2, 0.25, 0.35, 0.4))
			d.draw_string(ThemeDB.fallback_font, pos + Vector2(6, -3), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.25, 0.3, 0.4, 0.3))


func _draw_frame(d: Control, s: Vector2) -> void:
	var m: float = 15.0
	var cl: float = 25.0
	var cc := Color(0, 0.5, 0.8, 0.2)
	d.draw_line(Vector2(m, m), Vector2(m + cl, m), cc, 1.5)
	d.draw_line(Vector2(m, m), Vector2(m, m + cl), cc, 1.5)
	d.draw_line(Vector2(s.x - m, m), Vector2(s.x - m - cl, m), cc, 1.5)
	d.draw_line(Vector2(s.x - m, m), Vector2(s.x - m, m + cl), cc, 1.5)
	d.draw_line(Vector2(m, s.y - m), Vector2(m + cl, s.y - m), cc, 1.5)
	d.draw_line(Vector2(m, s.y - m), Vector2(m, s.y - m - cl), cc, 1.5)
	d.draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m - cl, s.y - m), cc, 1.5)
	d.draw_line(Vector2(s.x - m, s.y - m), Vector2(s.x - m, s.y - m - cl), cc, 1.5)
	# Title
	d.draw_string(ThemeDB.fallback_font, Vector2(m + 5, m + 12), "GLOBAL THREAT MAP — OPERATION DARKFIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0.6, 0.9, 0.35))


func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")
