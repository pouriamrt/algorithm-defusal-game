extends Control
## Main game scene. Manages timer, stability, module instantiation, and win/lose.
## Features a visual bomb with burning fuse, explosion, and screen shake.

# Module scenes loaded dynamically per city from WaveData

# UI references
var _timer_label: Label
var _stability_bar: ProgressBar
var _stability_label: Label
var _mission_label: Label
var _status_label: Label
var _module_container: HBoxContainer
var _bomb_visual: BombVisual
var _tech_bg: TechBackground
var _screen_fx: ScreenEffects
var _commentary_label: Label
var _commentary_icon: Label

# Pulse animation state
var _pulse_time: float = 0.0
var _game_ended: bool = false

# Commentary message queue
var _commentary_queue: Array[String] = []
var _commentary_display_timer: float = 0.0
const COMMENTARY_DISPLAY_DURATION: float = 5.0
var _commentary_fade_timer: float = 0.0

# Time-based commentary triggers
var _half_time_triggered: bool = false
var _time_warning_triggered: bool = false
var _stability_warning_triggered: bool = false


func _ready() -> void:
	_build_ui()
	GameState.reset()
	_apply_wave_theme()
	_instantiate_modules()
	_setup_signals()
	_load_mission_briefing()


func _build_ui() -> void:
	# Animated tech background (replaces static color)
	_tech_bg = TechBackground.new()
	_tech_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tech_bg)

	# Screen effects overlay (post-processing)
	_screen_fx = ScreenEffects.new()
	add_child(_screen_fx)

	# Main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# --- Header row with bomb visual ---
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 15)
	vbox.add_child(header_row)

	# Left side: title + stability
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 6)
	header_row.add_child(left_col)

	var title := Label.new()
	title.text = "WAVE %d — %s" % [GameState.current_wave, GameState.city_name.to_upper()]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameState.accent_color)
	left_col.add_child(title)

	# Stability bar
	var stability_row := HBoxContainer.new()
	stability_row.add_theme_constant_override("separation", 8)
	left_col.add_child(stability_row)

	var stab_title := Label.new()
	stab_title.text = "Stability:"
	stab_title.add_theme_color_override("font_color", Color("#e0e0e0"))
	stability_row.add_child(stab_title)

	_stability_bar = ProgressBar.new()
	_stability_bar.min_value = 0
	_stability_bar.max_value = 100
	_stability_bar.value = 100
	_stability_bar.custom_minimum_size = Vector2(200, 18)
	_stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stability_bar.show_percentage = false
	stability_row.add_child(_stability_bar)

	_stability_label = Label.new()
	_stability_label.text = "100%"
	_stability_label.add_theme_color_override("font_color", Color("#00e676"))
	stability_row.add_child(_stability_label)

	# Mission text
	_mission_label = Label.new()
	_mission_label.text = "Loading mission briefing..."
	_mission_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_mission_label.add_theme_font_size_override("font_size", 13)
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.custom_minimum_size = Vector2(0, 35)
	left_col.add_child(_mission_label)

	# Center: bomb visual
	_bomb_visual = BombVisual.new()
	_bomb_visual.custom_minimum_size = Vector2(180, 160)
	header_row.add_child(_bomb_visual)

	# Right side: timer
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	header_row.add_child(right_col)

	var timer_title := Label.new()
	timer_title.text = "TIME"
	timer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_title.add_theme_color_override("font_color", Color("#555577"))
	timer_title.add_theme_font_size_override("font_size", 12)
	right_col.add_child(timer_title)

	_timer_label = Label.new()
	_timer_label.text = "02:00"
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(_timer_label)

	vbox.add_child(HSeparator.new())

	# --- Module container ---
	_module_container = HBoxContainer.new()
	_module_container.add_theme_constant_override("separation", 15)
	_module_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_module_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_module_container)

	vbox.add_child(HSeparator.new())

	# --- AI Commentary Bar ---
	var commentary_row := HBoxContainer.new()
	commentary_row.add_theme_constant_override("separation", 8)
	commentary_row.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(commentary_row)

	_commentary_icon = Label.new()
	_commentary_icon.text = "AI"
	_commentary_icon.add_theme_font_size_override("font_size", 12)
	_commentary_icon.add_theme_color_override("font_color", Color("#00e5ff"))
	_commentary_icon.custom_minimum_size = Vector2(28, 0)
	commentary_row.add_child(_commentary_icon)

	_commentary_label = Label.new()
	_commentary_label.text = ""
	_commentary_label.add_theme_font_size_override("font_size", 15)
	_commentary_label.add_theme_color_override("font_color", Color("#ffeb3b"))
	_commentary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commentary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commentary_row.add_child(_commentary_label)

	vbox.add_child(HSeparator.new())

	# --- Bottom bar: status + buttons ---
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 15)
	vbox.add_child(bottom_row)

	# Menu button
	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(120, 32)
	menu_btn.add_theme_font_size_override("font_size", 12)
	menu_btn.pressed.connect(_on_main_menu)
	bottom_row.add_child(menu_btn)

	# Status label (center, expanding)
	_status_label = Label.new()
	_status_label.text = "3 modules remaining"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(_status_label)

	# Restart button
	var restart_btn := Button.new()
	restart_btn.text = "RESTART WAVE"
	restart_btn.custom_minimum_size = Vector2(120, 32)
	restart_btn.add_theme_font_size_override("font_size", 12)
	restart_btn.pressed.connect(_on_restart)
	bottom_row.add_child(restart_btn)


func _apply_wave_theme() -> void:
	var accent: Color = GameState.accent_color
	_tech_bg.set_accent_color(accent)
	_tech_bg.set_watermark(GameState.city_name)
	_bomb_visual.accent_color = accent
	_bomb_visual.wave_number = GameState.current_wave


func _instantiate_modules() -> void:
	var module_paths: Array = WaveData.get_module_scenes(GameState.current_wave)
	for path in module_paths:
		var scene: PackedScene = load(str(path))
		var module: BaseModule = scene.instantiate()
		module.module_solved.connect(_on_module_solved)
		module.wrong_action.connect(_on_wrong_action)
		_module_container.add_child(module)


func _setup_signals() -> void:
	GameState.stability_changed.connect(_on_stability_changed)
	GameState.game_over.connect(_on_game_over)


func _load_mission_briefing() -> void:
	var fallback := LLMService.get_mission_briefing()
	_mission_label.text = fallback
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "mission_briefing":
		_mission_label.text = text
	elif context == "commentary":
		_show_commentary(text)


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)
	if GameState.stability_changed.is_connected(_on_stability_changed):
		GameState.stability_changed.disconnect(_on_stability_changed)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


func _process(delta: float) -> void:
	if _game_ended:
		return

	if not GameState.is_game_active:
		return

	# Tick timer
	GameState.tick_timer(delta)

	# Update timer display
	var t: float = GameState.timer_remaining
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Update bomb visual
	var timer_ratio := t / GameState.timer_total
	var stability_ratio := float(GameState.stability) / float(GameState.stability_max)
	_bomb_visual.timer_ratio = timer_ratio
	_bomb_visual.stability_ratio = stability_ratio

	# Timer color states
	_pulse_time += delta
	if t > 30.0:
		_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	elif t > 10.0:
		var alpha: float = 0.7 + 0.3 * sin(_pulse_time * 3.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff6f00", alpha))
	else:
		var alpha: float = 0.5 + 0.5 * sin(_pulse_time * 8.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff1744", alpha))

	# Update background alert level based on stability + timer
	var danger: float = max(1.0 - stability_ratio, 1.0 - timer_ratio)
	_tech_bg.set_alert_level(clampf(danger * 1.5 - 0.3, 0.0, 1.0))

	# Update status
	var remaining: int = GameState.modules_total - GameState.modules_solved
	_status_label.text = "%d module(s) remaining" % remaining

	# Commentary display timer
	if _commentary_display_timer > 0:
		_commentary_display_timer -= delta
		if _commentary_display_timer <= 1.0:
			# Fade out
			_commentary_label.add_theme_color_override("font_color", Color("#ffeb3b", _commentary_display_timer))
		if _commentary_display_timer <= 0:
			_commentary_label.text = ""
			# Show next queued message if any
			if not _commentary_queue.is_empty():
				var next_msg: String = _commentary_queue.pop_front()
				_commentary_label.text = next_msg
				_commentary_label.add_theme_color_override("font_color", Color("#ffeb3b"))
				_commentary_display_timer = COMMENTARY_DISPLAY_DURATION

	# Time-based commentary triggers
	if not _half_time_triggered and timer_ratio < 0.5:
		_half_time_triggered = true
		_request_commentary("half_time", "", {"modules_remaining": remaining, "seconds_left": int(t)})
	if not _time_warning_triggered and t < 30.0:
		_time_warning_triggered = true
		_request_commentary("time_warning", "", {"seconds_left": int(t)})
	if not _stability_warning_triggered and stability_ratio < 0.3:
		_stability_warning_triggered = true
		_request_commentary("stability_warning", "", {"stability": GameState.stability})


func _on_module_solved(module_name: String) -> void:
	for child in _module_container.get_children():
		if child is BaseModule and child.module_name == module_name:
			GameState.record_module_solved(child.get_result())
			_request_commentary("module_solved", module_name, {"mistakes": child.mistakes})
			break


func _on_wrong_action(module_name: String) -> void:
	GameState.record_wrong_action()
	_bomb_visual.trigger_shake(6.0)
	_screen_fx.trigger_damage()
	_request_commentary("wrong_action", module_name, {"stability": GameState.stability, "mistakes": GameState.mistakes})


func _on_stability_changed(new_value: int) -> void:
	_stability_bar.value = new_value
	_stability_label.text = "%d%%" % new_value
	if new_value > 60:
		_stability_label.add_theme_color_override("font_color", Color("#00e676"))
	elif new_value > 30:
		_stability_label.add_theme_color_override("font_color", Color("#ff6f00"))
	else:
		_stability_label.add_theme_color_override("font_color", Color("#ff1744"))


func _on_game_over(outcome: String) -> void:
	_game_ended = true

	# Record performance
	var time_used: float = GameState.timer_total - GameState.timer_remaining
	var max_mistakes: int = max(1, int(float(GameState.stability_max) / float(GameState.stability_penalty)))
	DifficultyManager.record_wave_performance(time_used, GameState.timer_total, GameState.mistakes, max_mistakes)

	if outcome == "defused":
		_status_label.text = "BOMB DEFUSED! Well done, Agent."
		_status_label.add_theme_color_override("font_color", Color("#00e676"))
		_bomb_visual.trigger_defused()
		_screen_fx.trigger_defuse_flash()
		await get_tree().create_timer(2.0).timeout

		if DifficultyManager.current_wave >= WaveData.TOTAL_WAVES:
			# All waves complete — victory!
			DifficultyManager.advance_wave()
			get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
		else:
			DifficultyManager.advance_wave()
			get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	else:
		if outcome == "exploded_timer":
			_status_label.text = "TIME'S UP — DETONATION!"
		else:
			_status_label.text = "STABILITY CRITICAL — DETONATION!"
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
		_bomb_visual.trigger_explosion()
		_screen_fx.trigger_explosion_flash()
		_tech_bg.set_alert_level(1.0)
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/result_screen.tscn")


func _on_main_menu() -> void:
	GameState.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_restart() -> void:
	GameState.is_game_active = false
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")


func _request_commentary(event: String, module_name: String, details: Dictionary) -> void:
	"""Request real-time commentary. Shows fallback immediately, updates with LLM if available."""
	var fallback: String = LLMService.get_commentary(event, module_name, details)
	_show_commentary(fallback)


func _show_commentary(text: String) -> void:
	"""Display commentary text in the bar. Queues if a message is already showing."""
	if _commentary_display_timer > 0 and _commentary_label.text != "":
		# Current message still showing — queue the new one
		_commentary_queue.append(text)
	else:
		_commentary_label.text = text
		_commentary_label.add_theme_color_override("font_color", Color("#ffeb3b"))
		_commentary_display_timer = COMMENTARY_DISPLAY_DURATION
		# Pulse the AI icon
		_commentary_icon.add_theme_color_override("font_color", Color("#00e676"))
