extends Control
## Result screen. Shows win/lose outcome, stats, and algorithm explanations.
## Victory mode: animated background, per-city campaign summary, celebration.

const COLOR_GREEN := Color("#00e676")
const COLOR_CYAN := Color("#00e5ff")

var _outcome_label: Label
var _stats_label: Label
var _explanation_label: Label
var _replay_btn: Button
var _city_container: VBoxContainer
var _tech_bg: TechBackground = null
var _screen_fx: ScreenEffects = null
var _bomb_visual: BombVisual = null
var _is_victory: bool = false
var _anim_time: float = 0.0
var _title_label: Label = null


func _ready() -> void:
	var stats: Dictionary = DifficultyManager.get_total_stats()
	_is_victory = int(stats["waves_survived"]) >= WaveData.TOTAL_WAVES
	_build_ui()
	_display_results(stats)
	if _is_victory:
		_screen_fx.trigger_defuse_flash()


func _process(delta: float) -> void:
	if not _is_victory:
		return
	_anim_time += delta
	var t: float = (sin(_anim_time * 1.5) + 1.0) / 2.0
	if _title_label:
		_title_label.add_theme_color_override("font_color", COLOR_GREEN.lerp(COLOR_CYAN, t))


func _build_ui() -> void:
	if _is_victory:
		_tech_bg = TechBackground.new()
		_tech_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_tech_bg)
		_tech_bg.set_accent_color(COLOR_GREEN)
		_tech_bg.set_watermark("VICTORY")

		_screen_fx = ScreenEffects.new()
		add_child(_screen_fx)
	else:
		var bg := ColorRect.new()
		bg.color = Color("#0a0e17")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.custom_minimum_size = Vector2(700, 0)
	center.add_child(vbox)

	if _is_victory:
		_build_victory_ui(vbox)
	else:
		_build_failure_ui(vbox)


func _build_victory_ui(vbox: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	_title_label = Label.new()
	_title_label.text = "MISSION COMPLETE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", COLOR_GREEN)
	vbox.add_child(_title_label)

	vbox.add_child(HSeparator.new())

	_outcome_label = Label.new()
	_outcome_label.text = "WORLD SAVED — ALL THREATS NEUTRALIZED"
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 28)
	_outcome_label.add_theme_color_override("font_color", COLOR_GREEN)
	vbox.add_child(_outcome_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	var map_title := Label.new()
	map_title.text = "CAMPAIGN SUMMARY"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 20)
	map_title.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(map_title)

	_city_container = VBoxContainer.new()
	_city_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_city_container)

	vbox.add_child(HSeparator.new())

	var bomb_center := CenterContainer.new()
	vbox.add_child(bomb_center)

	_bomb_visual = BombVisual.new()
	_bomb_visual.custom_minimum_size = Vector2(160, 140)
	bomb_center.add_child(_bomb_visual)
	_bomb_visual.accent_color = COLOR_GREEN
	_bomb_visual.trigger_defused()

	vbox.add_child(HSeparator.new())

	var expl_title := Label.new()
	expl_title.text = "ALGORITHM MASTERY"
	expl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expl_title.add_theme_font_size_override("font_size", 20)
	expl_title.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(expl_title)

	_explanation_label = Label.new()
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation_label.add_theme_font_size_override("font_size", 14)
	_explanation_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_explanation_label.custom_minimum_size = Vector2(600, 80)
	vbox.add_child(_explanation_label)

	vbox.add_child(HSeparator.new())
	_build_buttons(vbox, "NEW CAMPAIGN", 220, 50, 20)


func _build_failure_ui(vbox: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "MISSION DEBRIEF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_outcome_label = Label.new()
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_outcome_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	var expl_title := Label.new()
	expl_title.text = "ALGORITHM ANALYSIS"
	expl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expl_title.add_theme_font_size_override("font_size", 20)
	expl_title.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(expl_title)

	_explanation_label = Label.new()
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation_label.add_theme_font_size_override("font_size", 14)
	_explanation_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_explanation_label.custom_minimum_size = Vector2(600, 80)
	vbox.add_child(_explanation_label)

	vbox.add_child(HSeparator.new())

	var module_title := Label.new()
	module_title.text = "MODULE BREAKDOWN"
	module_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	module_title.add_theme_font_size_override("font_size", 20)
	module_title.add_theme_color_override("font_color", COLOR_CYAN)
	vbox.add_child(module_title)

	for result in GameState.module_results:
		var mod_label := Label.new()
		mod_label.text = "  %s — %d mistake(s) — Algorithm: %s" % [
			result.get("name", "?"),
			result.get("mistakes", 0),
			result.get("algorithm", "?"),
		]
		mod_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		vbox.add_child(mod_label)

	vbox.add_child(HSeparator.new())
	_build_buttons(vbox, "REPLAY MISSION", 200, 45, 18)


func _build_buttons(vbox: VBoxContainer, replay_text: String, btn_w: int, btn_h: int, font_sz: int) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	_replay_btn = Button.new()
	_replay_btn.text = replay_text
	_replay_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	_replay_btn.add_theme_font_size_override("font_size", font_sz)
	_replay_btn.pressed.connect(_on_replay)
	btn_row.add_child(_replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	menu_btn.add_theme_font_size_override("font_size", font_sz)
	menu_btn.pressed.connect(_on_main_menu)
	btn_row.add_child(menu_btn)


func _display_results(stats: Dictionary) -> void:
	var waves_survived: int = int(stats["waves_survived"])

	if _is_victory:
		_display_victory_results(stats)
	else:
		_display_failure_results(stats, waves_survived)

	# LLM summary (shared by both paths)
	var perf_data := {
		"game_outcome": GameState.game_outcome,
		"timer_remaining": GameState.timer_remaining,
		"total_mistakes": int(stats["total_mistakes"]),
		"module_results": GameState.module_results,
		"waves_survived": waves_survived,
		"city_name": GameState.city_name,
	}
	_explanation_label.text = LLMService.get_results_summary(perf_data)
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _display_victory_results(stats: Dictionary) -> void:
	_stats_label.text = "10 cities saved  |  %d total mistakes  |  Time remaining: %.0fs" % [
		int(stats["total_mistakes"]),
		GameState.timer_remaining,
	]

	# Build lookup for O(1) access per wave
	var history_by_wave: Dictionary = {}
	for entry in DifficultyManager.wave_history:
		history_by_wave[int(entry["wave"])] = entry

	for w in range(1, WaveData.TOTAL_WAVES + 1):
		var city: Dictionary = WaveData.get_city(w)
		var accent: Color = Color(str(city.get("accent", "#e0e0e0")))
		var wave_entry: Dictionary = history_by_wave.get(w, {})
		var wave_mistakes: int = int(wave_entry.get("mistakes", 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_city_container.add_child(row)

		var check := Label.new()
		check.text = "[OK]"
		check.add_theme_color_override("font_color", COLOR_GREEN)
		check.add_theme_font_size_override("font_size", 13)
		check.custom_minimum_size = Vector2(40, 0)
		row.add_child(check)

		var wave_lbl := Label.new()
		wave_lbl.text = "Wave %d" % w
		wave_lbl.add_theme_color_override("font_color", Color("#667788"))
		wave_lbl.add_theme_font_size_override("font_size", 13)
		wave_lbl.custom_minimum_size = Vector2(65, 0)
		row.add_child(wave_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(city.get("name", "???"))
		name_lbl.add_theme_color_override("font_color", accent)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(name_lbl)

		var region_lbl := Label.new()
		region_lbl.text = str(city.get("region", ""))
		region_lbl.add_theme_color_override("font_color", Color("#556677"))
		region_lbl.add_theme_font_size_override("font_size", 12)
		region_lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(region_lbl)

		var mistakes_lbl := Label.new()
		mistakes_lbl.text = "%d err" % wave_mistakes
		if wave_mistakes == 0:
			mistakes_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		elif wave_mistakes <= 3:
			mistakes_lbl.add_theme_color_override("font_color", Color("#ffeb3b"))
		else:
			mistakes_lbl.add_theme_color_override("font_color", Color("#ff6f00"))
		mistakes_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(mistakes_lbl)


func _display_failure_results(stats: Dictionary, waves_survived: int) -> void:
	match GameState.game_outcome:
		"defused":
			_outcome_label.text = "BOMB DEFUSED"
			_outcome_label.add_theme_color_override("font_color", COLOR_GREEN)
		"exploded_timer":
			_outcome_label.text = "DETONATION — TIME EXPIRED"
			_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
		"exploded_stability":
			_outcome_label.text = "DETONATION — STABILITY FAILURE"
			_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
		_:
			_outcome_label.text = "MISSION STATUS UNKNOWN"
			_outcome_label.add_theme_color_override("font_color", Color("#ff6f00"))

	_stats_label.text = "Waves: %d/%d  |  Mistakes: %d  |  City: %s" % [
		waves_survived, WaveData.TOTAL_WAVES,
		int(stats["total_mistakes"]),
		GameState.city_name,
	]


func _on_llm_response(context: String, text: String) -> void:
	if context == "results_summary":
		_explanation_label.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)


func _on_replay() -> void:
	if _is_victory:
		get_tree().change_scene_to_file("res://scenes/opening_briefing.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
