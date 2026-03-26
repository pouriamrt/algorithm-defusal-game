extends Control
## CIA classified opening briefing. Sets up narrative, transitions to WorldMap.

var _briefing: BriefingOverlay
var _tech_bg: TechBackground


func _ready() -> void:
	DifficultyManager.reset_campaign()

	_tech_bg = TechBackground.new()
	_tech_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tech_bg)

	_briefing = BriefingOverlay.new()
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_briefing)

	var fallback := (
		"Agent CIPHER, this is Director Kane. NEXUS has activated Protocol Darkfire. "
		+ "Our satellites have detected 10 algorithm-locked explosive devices planted across "
		+ "major cities worldwide. Each device is more sophisticated than the last. "
		+ "You are the only operative qualified for counter-algorithm defusal. "
		+ "The world is counting on you. Proceed to your first deployment immediately."
	)

	_briefing.setup(
		"COUNTER-ALGORITHM TERRORISM UNIT",
		"OPERATION DARKFIRE — GLOBAL THREAT ALERT",
		fallback,
		"ACCEPT MISSION",
		Color("#00e5ff")
	)
	_briefing.start_typewriter()
	_briefing.deploy_pressed.connect(_on_accept)

	LLMService.get_mission_briefing()
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "mission_briefing":
		_briefing.update_body_text(text)
		_briefing.start_typewriter()


func _exit_tree() -> void:
	if LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.disconnect(_on_llm_response)


func _on_accept() -> void:
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
