extends Control
## Result screen. Shows win/lose outcome, stats, and algorithm explanations.

var _outcome_label: Label
var _stats_label: Label
var _explanation_label: Label


func _ready() -> void:
	_build_ui()
	_display_results()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center
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

	# Title
	var title := Label.new()
	title.text = "MISSION DEBRIEF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Outcome
	_outcome_label = Label.new()
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_outcome_label)

	# Stats
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	# Algorithm explanations
	var expl_title := Label.new()
	expl_title.text = "ALGORITHM ANALYSIS"
	expl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expl_title.add_theme_font_size_override("font_size", 20)
	expl_title.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(expl_title)

	_explanation_label = Label.new()
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation_label.add_theme_font_size_override("font_size", 14)
	_explanation_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_explanation_label.custom_minimum_size = Vector2(600, 80)
	vbox.add_child(_explanation_label)

	vbox.add_child(HSeparator.new())

	# Per-module breakdown
	var module_title := Label.new()
	module_title.text = "MODULE BREAKDOWN"
	module_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	module_title.add_theme_font_size_override("font_size", 20)
	module_title.add_theme_color_override("font_color", Color("#00e5ff"))
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

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var replay_btn := Button.new()
	replay_btn.text = "REPLAY MISSION"
	replay_btn.custom_minimum_size = Vector2(200, 45)
	replay_btn.add_theme_font_size_override("font_size", 18)
	replay_btn.pressed.connect(_on_replay)
	btn_row.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(200, 45)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_on_main_menu)
	btn_row.add_child(menu_btn)


func _display_results() -> void:
	var stats: Dictionary = DifficultyManager.get_total_stats()
	var waves_survived: int = int(stats["waves_survived"])

	# Outcome
	if waves_survived >= WaveData.TOTAL_WAVES:
		_outcome_label.text = "WORLD SAVED — ALL THREATS NEUTRALIZED"
		_outcome_label.add_theme_color_override("font_color", Color("#00e676"))
	else:
		match GameState.game_outcome:
			"defused":
				_outcome_label.text = "BOMB DEFUSED"
				_outcome_label.add_theme_color_override("font_color", Color("#00e676"))
			"exploded_timer":
				_outcome_label.text = "DETONATION — TIME EXPIRED"
				_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
			"exploded_stability":
				_outcome_label.text = "DETONATION — STABILITY FAILURE"
				_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
			_:
				_outcome_label.text = "MISSION STATUS UNKNOWN"
				_outcome_label.add_theme_color_override("font_color", Color("#ff6f00"))

	# Stats
	_stats_label.text = "Waves: %d/%d  |  Mistakes: %d  |  City: %s" % [
		waves_survived, WaveData.TOTAL_WAVES,
		int(stats["total_mistakes"]),
		GameState.city_name,
	]

	# LLM summary
	var perf_data := {
		"game_outcome": GameState.game_outcome,
		"timer_remaining": GameState.timer_remaining,
		"total_mistakes": int(stats["total_mistakes"]),
		"module_results": GameState.module_results,
		"waves_survived": waves_survived,
		"city_name": GameState.city_name,
	}
	_explanation_label.text = LLMService.get_results_summary(perf_data)

	# Listen for async LLM update
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "results_summary":
		_explanation_label.text = text


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)


func _on_replay() -> void:
	# Restart the wave the player failed on (don't reset campaign)
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
