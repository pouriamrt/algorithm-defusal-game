extends Control
## Main menu screen. Start game or quit.

var _title_label: Label
var _subtitle_label: Label
var _start_btn: Button
var _quit_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "BOMB DEFUSAL"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "ALGORITHM MODE"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_subtitle_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Start button
	_start_btn = Button.new()
	_start_btn.text = "START MISSION"
	_start_btn.custom_minimum_size = Vector2(250, 50)
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.pressed.connect(_on_start)
	vbox.add_child(_start_btn)

	# Quit button
	_quit_btn = Button.new()
	_quit_btn.text = "QUIT"
	_quit_btn.custom_minimum_size = Vector2(250, 50)
	_quit_btn.add_theme_font_size_override("font_size", 20)
	_quit_btn.pressed.connect(_on_quit)
	vbox.add_child(_quit_btn)

	# Version label
	var version := Label.new()
	version.text = "v0.2.0 — OPERATION DARKFIRE"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color("#555555"))
	vbox.add_child(version)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/opening_briefing.tscn")


func _on_quit() -> void:
	get_tree().quit()
