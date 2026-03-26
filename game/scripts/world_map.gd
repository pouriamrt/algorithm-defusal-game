extends Control
## World map screen between waves. Shows cities, flight path, and intel briefing.

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

const MAP_RECT: Rect2 = Rect2(30, 30, 800, 660)

const CONTINENT_LINES: Array = [
	[Vector2(0.05, 0.25), Vector2(0.12, 0.18), Vector2(0.22, 0.15), Vector2(0.28, 0.20),
	 Vector2(0.30, 0.30), Vector2(0.28, 0.40), Vector2(0.22, 0.48), Vector2(0.15, 0.45),
	 Vector2(0.08, 0.35), Vector2(0.05, 0.25)],
	[Vector2(0.22, 0.50), Vector2(0.28, 0.48), Vector2(0.35, 0.55), Vector2(0.37, 0.65),
	 Vector2(0.34, 0.78), Vector2(0.28, 0.85), Vector2(0.24, 0.75), Vector2(0.22, 0.60),
	 Vector2(0.22, 0.50)],
	[Vector2(0.44, 0.18), Vector2(0.50, 0.15), Vector2(0.55, 0.18), Vector2(0.53, 0.28),
	 Vector2(0.48, 0.35), Vector2(0.43, 0.32), Vector2(0.44, 0.18)],
	[Vector2(0.44, 0.38), Vector2(0.50, 0.35), Vector2(0.58, 0.40), Vector2(0.60, 0.55),
	 Vector2(0.55, 0.72), Vector2(0.48, 0.70), Vector2(0.44, 0.55), Vector2(0.44, 0.38)],
	[Vector2(0.55, 0.15), Vector2(0.65, 0.12), Vector2(0.78, 0.15), Vector2(0.88, 0.22),
	 Vector2(0.90, 0.35), Vector2(0.82, 0.45), Vector2(0.72, 0.48), Vector2(0.62, 0.42),
	 Vector2(0.58, 0.30), Vector2(0.55, 0.15)],
	[Vector2(0.82, 0.62), Vector2(0.92, 0.60), Vector2(0.95, 0.68), Vector2(0.90, 0.78),
	 Vector2(0.82, 0.75), Vector2(0.82, 0.62)],
]


func _ready() -> void:
	_build_ui()
	_start_flight_animation()
	_load_city_briefing()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#050810")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_map_draw = Control.new()
	_map_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_draw.draw.connect(_on_map_draw)
	add_child(_map_draw)

	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0, 0, 0, 0.7)
	panel_bg.position = Vector2(860, 30)
	panel_bg.size = Vector2(390, 660)
	add_child(panel_bg)

	_info_panel = VBoxContainer.new()
	_info_panel.position = Vector2(880, 50)
	_info_panel.custom_minimum_size = Vector2(350, 600)
	_info_panel.add_theme_constant_override("separation", 12)
	add_child(_info_panel)

	var current_city: Dictionary = WaveData.get_city(DifficultyManager.current_wave)
	var accent: Color = WaveData.get_accent_color(DifficultyManager.current_wave)

	_wave_label = Label.new()
	_wave_label.text = "WAVE %d OF %d" % [DifficultyManager.current_wave, WaveData.TOTAL_WAVES]
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color("#888899"))
	_info_panel.add_child(_wave_label)

	_city_label = Label.new()
	_city_label.text = str(current_city.get("name", "Unknown"))
	_city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_city_label.add_theme_font_size_override("font_size", 28)
	_city_label.add_theme_color_override("font_color", accent)
	_info_panel.add_child(_city_label)

	_region_label = Label.new()
	_region_label.text = str(current_city.get("region", ""))
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 14)
	_region_label.add_theme_color_override("font_color", Color("#aaaabb"))
	_info_panel.add_child(_region_label)

	_threat_label = Label.new()
	var threat_str: String = str(current_city.get("threat", "LOW"))
	_threat_label.text = "THREAT: %s" % threat_str
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_threat_label.add_theme_font_size_override("font_size", 16)
	var threat_color := Color("#00e676")
	if threat_str == "MODERATE":
		threat_color = Color("#ddaa44")
	elif threat_str == "ELEVATED":
		threat_color = Color("#ff6f00")
	elif threat_str == "HIGH":
		threat_color = Color("#ff4444")
	elif threat_str == "SEVERE":
		threat_color = Color("#dd2222")
	elif threat_str == "CRITICAL":
		threat_color = Color("#ff0000")
	_threat_label.add_theme_color_override("font_color", threat_color)
	_info_panel.add_child(_threat_label)

	_info_panel.add_child(HSeparator.new())

	var params: Dictionary = DifficultyManager.get_wave_params()
	_timer_preview = Label.new()
	_timer_preview.text = "Timer: %ds  |  Stability: %d" % [int(params["timer_total"]), int(params["stability_max"])]
	_timer_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_preview.add_theme_font_size_override("font_size", 14)
	_timer_preview.add_theme_color_override("font_color", Color("#aaaacc"))
	_info_panel.add_child(_timer_preview)

	_info_panel.add_child(HSeparator.new())

	var intel_header := Label.new()
	intel_header.text = "INTELLIGENCE BRIEFING"
	intel_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intel_header.add_theme_font_size_override("font_size", 12)
	intel_header.add_theme_color_override("font_color", Color("#666688"))
	_info_panel.add_child(intel_header)

	_briefing_text = Label.new()
	_briefing_text.text = "Receiving intel..."
	_briefing_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_text.add_theme_font_size_override("font_size", 16)
	_briefing_text.add_theme_color_override("font_color", Color("#e0e0e0"))
	_briefing_text.custom_minimum_size = Vector2(330, 150)
	_info_panel.add_child(_briefing_text)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_panel.add_child(spacer)

	_deploy_btn = Button.new()
	_deploy_btn.text = "DEPLOY"
	_deploy_btn.custom_minimum_size = Vector2(300, 55)
	_deploy_btn.add_theme_font_size_override("font_size", 22)
	_deploy_btn.pressed.connect(_on_deploy)
	_info_panel.add_child(_deploy_btn)


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
		_flight_progress = min(1.0, _flight_progress + delta * 0.7)
		if _flight_progress >= 1.0:
			_flight_animating = false
	_map_draw.queue_redraw()


func _on_map_draw() -> void:
	var draw_ctrl := _map_draw

	# Draw continents
	for continent in CONTINENT_LINES:
		for i in range(continent.size() - 1):
			var p1: Vector2 = _map_pos(continent[i])
			var p2: Vector2 = _map_pos(continent[i + 1])
			draw_ctrl.draw_line(p1, p2, Color(0.15, 0.3, 0.5, 0.3), 1.5)
			draw_ctrl.draw_line(p1, p2, Color(0.1, 0.25, 0.45, 0.1), 4.0)

	var current_wave: int = DifficultyManager.current_wave

	# Draw flight path from previous city
	if current_wave > 1:
		var prev_city: Dictionary = WaveData.get_city(current_wave - 1)
		var curr_city: Dictionary = WaveData.get_city(current_wave)
		var p1: Vector2 = _map_pos(Vector2(float(prev_city["x"]), float(prev_city["y"])))
		var p2: Vector2 = _map_pos(Vector2(float(curr_city["x"]), float(curr_city["y"])))

		var seg_count: int = 20
		for i in range(seg_count):
			var t1: float = float(i) / seg_count
			var t2: float = float(i + 1) / seg_count
			if t2 > _flight_progress:
				break
			if i % 2 == 0:
				var s1: Vector2 = p1.lerp(p2, t1)
				var s2: Vector2 = p1.lerp(p2, min(t2, _flight_progress))
				draw_ctrl.draw_line(s1, s2, Color("#00e5ff", 0.6), 2.0)

		if _flight_animating:
			var flight_end: Vector2 = p1.lerp(p2, _flight_progress)
			var dir: Vector2 = (p2 - p1).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			draw_ctrl.draw_polygon(
				PackedVector2Array([
					flight_end + dir * 8,
					flight_end - dir * 5 + perp * 4,
					flight_end - dir * 5 - perp * 4,
				]),
				PackedColorArray([Color("#00e5ff")])
			)

	# Completed paths
	for w in range(1, current_wave - 1):
		var c1: Dictionary = WaveData.get_city(w)
		var c2: Dictionary = WaveData.get_city(w + 1)
		var cp1: Vector2 = _map_pos(Vector2(float(c1["x"]), float(c1["y"])))
		var cp2: Vector2 = _map_pos(Vector2(float(c2["x"]), float(c2["y"])))
		draw_ctrl.draw_line(cp1, cp2, Color(0, 0.9, 0.4, 0.2), 1.5)

	# City dots
	for w in range(1, WaveData.TOTAL_WAVES + 1):
		var city: Dictionary = WaveData.get_city(w)
		var pos: Vector2 = _map_pos(Vector2(float(city["x"]), float(city["y"])))
		var accent: Color = Color(city["accent"])

		if w < current_wave:
			draw_ctrl.draw_circle(pos, 6, Color(0, 0.9, 0.4, 0.8))
			draw_ctrl.draw_circle(pos, 3, Color(0, 1, 0.5))
		elif w == current_wave:
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			draw_ctrl.draw_circle(pos, 14 + pulse * 4, Color(1, 0.1, 0, 0.15))
			draw_ctrl.draw_circle(pos, 10, Color(1, 0.15, 0, 0.3))
			draw_ctrl.draw_circle(pos, 6, accent)
			draw_ctrl.draw_circle(pos, 3, Color(1, 1, 1, 0.6))
			draw_ctrl.draw_string(ThemeDB.fallback_font, pos + Vector2(12, -8), str(city["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
		else:
			draw_ctrl.draw_circle(pos, 4, Color(0.3, 0.3, 0.4, 0.5))

	draw_ctrl.draw_string(ThemeDB.fallback_font, Vector2(40, 25), "GLOBAL THREAT MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#00e5ff", 0.5))


func _map_pos(normalized: Vector2) -> Vector2:
	return Vector2(
		MAP_RECT.position.x + normalized.x * MAP_RECT.size.x,
		MAP_RECT.position.y + normalized.y * MAP_RECT.size.y
	)


func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")
