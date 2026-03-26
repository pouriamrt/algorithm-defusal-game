extends Control
## Main game scene. Manages timer, stability, module instantiation, and win/lose.

const FrequencyLockScene := preload("res://modules/frequency_lock_module.tscn")
const SignalSortingScene := preload("res://modules/signal_sorting_module.tscn")
const WireRoutingScene := preload("res://modules/wire_routing_module.tscn")

# UI references
var _timer_label: Label
var _stability_bar: ProgressBar
var _stability_label: Label
var _mission_label: Label
var _status_label: Label
var _module_container: HBoxContainer

# Pulse animation state
var _pulse_time: float = 0.0


func _ready() -> void:
	_build_ui()
	GameState.reset()
	_instantiate_modules()
	_setup_signals()
	_load_mission_briefing()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# --- Header row ---
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var title := Label.new()
	title.text = "BOMB DEFUSAL SYSTEM"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#00e5ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_timer_label = Label.new()
	_timer_label.text = "02:00"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_timer_label)

	# --- Stability bar ---
	var stability_row := HBoxContainer.new()
	stability_row.add_theme_constant_override("separation", 10)
	vbox.add_child(stability_row)

	var stab_title := Label.new()
	stab_title.text = "Stability:"
	stab_title.add_theme_color_override("font_color", Color("#e0e0e0"))
	stability_row.add_child(stab_title)

	_stability_bar = ProgressBar.new()
	_stability_bar.min_value = 0
	_stability_bar.max_value = 100
	_stability_bar.value = 100
	_stability_bar.custom_minimum_size = Vector2(300, 20)
	_stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stability_bar.show_percentage = false
	stability_row.add_child(_stability_bar)

	_stability_label = Label.new()
	_stability_label.text = "100%"
	_stability_label.add_theme_color_override("font_color", Color("#00e676"))
	stability_row.add_child(_stability_label)

	# --- Mission text ---
	_mission_label = Label.new()
	_mission_label.text = "Loading mission briefing..."
	_mission_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_mission_label.add_theme_font_size_override("font_size", 14)
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_mission_label)

	vbox.add_child(HSeparator.new())

	# --- Module container ---
	_module_container = HBoxContainer.new()
	_module_container.add_theme_constant_override("separation", 15)
	_module_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_module_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_module_container)

	vbox.add_child(HSeparator.new())

	# --- Status bar ---
	_status_label = Label.new()
	_status_label.text = "3 modules remaining"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_status_label)


func _instantiate_modules() -> void:
	var modules: Array[PackedScene] = [FrequencyLockScene, SignalSortingScene, WireRoutingScene]
	for scene in modules:
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
	# If LLM is active, update when async response arrives
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "mission_briefing":
		_mission_label.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)
	if GameState.stability_changed.is_connected(_on_stability_changed):
		GameState.stability_changed.disconnect(_on_stability_changed)
	if GameState.game_over.is_connected(_on_game_over):
		GameState.game_over.disconnect(_on_game_over)


func _process(delta: float) -> void:
	if not GameState.is_game_active:
		return

	# Tick timer
	GameState.tick_timer(delta)

	# Update timer display
	var t: float = GameState.timer_remaining
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Timer color states
	_pulse_time += delta
	if t > 30.0:
		_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	elif t > 10.0:
		# Amber pulse
		var alpha: float = 0.7 + 0.3 * sin(_pulse_time * 3.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff6f00", alpha))
	else:
		# Red fast pulse
		var alpha: float = 0.5 + 0.5 * sin(_pulse_time * 8.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff1744", alpha))

	# Update status
	var remaining: int = GameState.modules_total - GameState.modules_solved
	_status_label.text = "%d module(s) remaining" % remaining


func _on_module_solved(module_name: String) -> void:
	# Find the module and get its result
	for child in _module_container.get_children():
		if child is BaseModule and child.module_name == module_name:
			GameState.record_module_solved(child.get_result())
			break


func _on_wrong_action(_module_name: String) -> void:
	GameState.record_wrong_action()


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
	# Short delay for dramatic effect, then transition
	var timer := get_tree().create_timer(1.5)
	if outcome == "defused":
		_status_label.text = "BOMB DEFUSED! Well done, technician."
		_status_label.add_theme_color_override("font_color", Color("#00e676"))
	elif outcome == "exploded_timer":
		_status_label.text = "TIME'S UP — DETONATION!"
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
	else:
		_status_label.text = "STABILITY CRITICAL — DETONATION!"
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
	await timer.timeout
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
