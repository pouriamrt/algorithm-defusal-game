class_name BriefingOverlay
extends Control
## Reusable classified-document styled panel with typewriter text animation.

signal deploy_pressed
signal text_complete

var _bg: ColorRect
var _panel: PanelContainer
var _header_label: Label
var _subheader_label: Label
var _body_label: Label
var _button: Button
var _full_text: String = ""
var _visible_chars: int = 0
var _typing: bool = false
var _type_speed: float = 30.0
var _type_timer: float = 0.0


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.88)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(750, 420)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	var classified := Label.new()
	classified.text = "CLASSIFIED — EYES ONLY"
	classified.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classified.add_theme_font_size_override("font_size", 12)
	classified.add_theme_color_override("font_color", Color("#ff1744", 0.6))
	vbox.add_child(classified)

	_header_label = Label.new()
	_header_label.text = ""
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 28)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	_subheader_label = Label.new()
	_subheader_label.text = ""
	_subheader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subheader_label.add_theme_font_size_override("font_size", 16)
	_subheader_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_subheader_label)

	vbox.add_child(HSeparator.new())

	_body_label = Label.new()
	_body_label.text = ""
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 20)
	_body_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_body_label.custom_minimum_size = Vector2(650, 120)
	vbox.add_child(_body_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_button = Button.new()
	_button.text = "DEPLOY"
	_button.custom_minimum_size = Vector2(200, 50)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(func(): deploy_pressed.emit())
	var btn_center := CenterContainer.new()
	btn_center.add_child(_button)
	vbox.add_child(btn_center)


func setup(header: String, subheader: String, body_text: String, button_text: String, accent: Color) -> void:
	_header_label.text = header
	_header_label.add_theme_color_override("font_color", accent)
	_subheader_label.text = subheader
	_full_text = body_text
	_body_label.text = ""
	_visible_chars = 0
	_button.text = button_text


func start_typewriter() -> void:
	_typing = true
	_type_timer = 0.0
	_visible_chars = 0
	_body_label.text = ""


func skip_typewriter() -> void:
	_typing = false
	_body_label.text = _full_text
	_visible_chars = _full_text.length()
	text_complete.emit()


func update_body_text(new_text: String) -> void:
	_full_text = new_text
	if not _typing:
		_body_label.text = new_text


func _process(delta: float) -> void:
	if not _typing:
		return
	_type_timer += delta
	var target_chars: int = int(_type_timer * _type_speed)
	if target_chars > _visible_chars:
		_visible_chars = min(target_chars, _full_text.length())
		_body_label.text = _full_text.left(_visible_chars)
		if _visible_chars >= _full_text.length():
			_typing = false
			text_complete.emit()


func _input(event: InputEvent) -> void:
	if _typing and event is InputEventMouseButton and event.pressed:
		skip_typewriter()
	elif _typing and event is InputEventKey and event.pressed:
		skip_typewriter()
