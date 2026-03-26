# Wave System, Adaptive Difficulty & Visual Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-wave CIA campaign with 10 cities, adaptive difficulty, world map, typewriter briefings, and visual polish to the Bomb Defusal game.

**Architecture:** New autoloads (DifficultyManager, WaveData) drive wave progression. New scenes (OpeningBriefing, WorldMap) handle narrative flow. Existing modules read difficulty params from GameState. BombGame transitions to WorldMap on defuse, ResultScreen on failure. Backend gets city-aware briefing endpoint.

**Tech Stack:** Godot 4.x GDScript, Python FastAPI, OpenAI gpt-4o-mini

**Spec:** `docs/superpowers/specs/2026-03-26-wave-system-design.md`

---

## File Map

### New Files

| File | Purpose |
|------|---------|
| `game/autoload/wave_data.gd` | Static city definitions: name, coords, accent, threat |
| `game/autoload/difficulty_manager.gd` | Adaptive difficulty engine: wave params, efficiency tracking |
| `game/scripts/briefing_overlay.gd` | Reusable typewriter text panel (used by opening + world map) |
| `game/scripts/opening_briefing.gd` | CIA classified document intro scene |
| `game/scenes/opening_briefing.tscn` | Opening scene file |
| `game/scripts/world_map.gd` | World map with cities, flight path, deploy button |
| `game/scenes/world_map.tscn` | Map scene file |

### Modified Files

| File | Changes |
|------|---------|
| `game/project.godot` | Register DifficultyManager + WaveData autoloads |
| `game/autoload/game_state.gd` | Accept params dict in reset(), store current_wave, city info |
| `game/autoload/llm_service.gd` | City-aware briefing, wave-aware summaries |
| `game/scripts/main_menu.gd` | Navigate to opening_briefing, add subtitle/version update |
| `game/scripts/base_module.gd` | Read difficulty params from GameState |
| `game/scripts/frequency_lock_module.gd` | Configurable range_max from params |
| `game/scripts/signal_sorting_module.gd` | Configurable num_elements from params |
| `game/scripts/wire_routing_module.gd` | Configurable num_nodes/edges from params |
| `game/scripts/bomb_game.gd` | Wave-aware reset, accent color, defuse→world_map transition |
| `game/scripts/bomb_visual.gd` | Accept accent_color, wave-based vein count |
| `game/scripts/tech_background.gd` | Accept accent_color, city watermark |
| `game/scripts/result_screen.gd` | Wave stats, debrief cards, victory screen |
| `backend/main.py` | City-aware /api/mission-briefing, wave-aware /api/results-summary |

---

## Task 1: WaveData Autoload (City Definitions)

**Files:**
- Create: `game/autoload/wave_data.gd`

- [ ] **Step 1: Write wave_data.gd**

```gdscript
class_name WaveDataClass
extends Node
## Static data for all 10 cities. Provides city info by wave number.

const CITIES: Array[Dictionary] = [
	{"name": "Washington D.C.", "region": "North America", "accent": "#4488ff", "threat": "LOW", "x": 0.23, "y": 0.38},
	{"name": "London", "region": "Europe", "accent": "#7799bb", "threat": "LOW", "x": 0.47, "y": 0.28},
	{"name": "Paris", "region": "Europe", "accent": "#ddaa44", "threat": "MODERATE", "x": 0.48, "y": 0.32},
	{"name": "Tokyo", "region": "Asia", "accent": "#ff44aa", "threat": "MODERATE", "x": 0.85, "y": 0.37},
	{"name": "Cairo", "region": "Africa", "accent": "#ddaa55", "threat": "ELEVATED", "x": 0.55, "y": 0.42},
	{"name": "Moscow", "region": "Europe", "accent": "#aaccee", "threat": "ELEVATED", "x": 0.58, "y": 0.25},
	{"name": "Mumbai", "region": "Asia", "accent": "#ff8833", "threat": "HIGH", "x": 0.68, "y": 0.45},
	{"name": "Sydney", "region": "Oceania", "accent": "#33bbaa", "threat": "HIGH", "x": 0.88, "y": 0.72},
	{"name": "Rio de Janeiro", "region": "South America", "accent": "#44dd66", "threat": "SEVERE", "x": 0.32, "y": 0.65},
	{"name": "Pyongyang", "region": "Asia", "accent": "#dd2222", "threat": "CRITICAL", "x": 0.82, "y": 0.35},
]

const TOTAL_WAVES: int = 10


func get_city(wave: int) -> Dictionary:
	"""Get city data for a wave (1-based). Returns empty dict if out of range."""
	var idx: int = wave - 1
	if idx < 0 or idx >= CITIES.size():
		return {}
	return CITIES[idx]


func get_accent_color(wave: int) -> Color:
	var city: Dictionary = get_city(wave)
	if city.is_empty():
		return Color("#00e5ff")
	return Color(city["accent"])


func get_city_name(wave: int) -> String:
	var city: Dictionary = get_city(wave)
	if city.is_empty():
		return "Unknown"
	return city["name"]
```

- [ ] **Step 2: Commit**

```bash
git add game/autoload/wave_data.gd
git commit -m "feat: add WaveData autoload with 10 city definitions"
```

---

## Task 2: DifficultyManager Autoload

**Files:**
- Create: `game/autoload/difficulty_manager.gd`

- [ ] **Step 1: Write difficulty_manager.gd**

```gdscript
class_name DifficultyManagerClass
extends Node
## Adaptive difficulty engine. Tracks wave progression and player performance.
## Calculates difficulty parameters for each wave based on base scaling + adaptive bonus.

var current_wave: int = 1
var wave_history: Array[Dictionary] = []
var last_efficiency: float = -1.0  # -1 means no previous wave


func reset_campaign() -> void:
	"""Reset for a new campaign (new game from main menu)."""
	current_wave = 1
	wave_history.clear()
	last_efficiency = -1.0


func advance_wave() -> void:
	"""Move to the next wave after a successful defusal."""
	current_wave += 1


func record_wave_performance(time_used: float, timer_total: float, mistakes: int, max_mistakes: int) -> void:
	"""Record performance after a wave. Calculates efficiency score."""
	var time_ratio: float = 1.0 - clampf(time_used / timer_total, 0.0, 1.0)
	var mistake_ratio: float = 1.0 - clampf(float(mistakes) / float(max(1, max_mistakes)), 0.0, 1.0)
	var efficiency: float = time_ratio * 0.5 + mistake_ratio * 0.5
	last_efficiency = clampf(efficiency, 0.0, 1.0)
	wave_history.append({
		"wave": current_wave,
		"time_used": time_used,
		"mistakes": mistakes,
		"efficiency": last_efficiency,
	})


func get_wave_params() -> Dictionary:
	"""Return difficulty parameters for the current wave."""
	var w: int = current_wave
	var adaptive_timer_bonus: int = 0
	var adaptive_sort_bonus: int = 0
	var adaptive_graph_bonus: int = 0

	# Adaptive adjustments based on previous wave performance
	if last_efficiency > 0.7 and w > 1:
		adaptive_timer_bonus = 10
		adaptive_sort_bonus = 1
		adaptive_graph_bonus = 1

	# Mercy round: if player struggled, keep same difficulty
	var mercy: bool = (last_efficiency >= 0.0 and last_efficiency < 0.3 and w > 1)

	var params: Dictionary = {}
	if mercy and not wave_history.is_empty():
		# Use previous wave's params
		var prev_wave: int = max(1, w - 1)
		params = _calc_base_params(prev_wave, 0, 0, 0)
	else:
		params = _calc_base_params(w, adaptive_timer_bonus, adaptive_sort_bonus, adaptive_graph_bonus)

	params["wave"] = w
	params["city"] = WaveData.get_city(w)
	params["accent_color"] = WaveData.get_accent_color(w)
	params["is_mercy"] = mercy
	return params


func _calc_base_params(w: int, timer_bonus: int, sort_bonus: int, graph_bonus: int) -> Dictionary:
	return {
		"timer_total": float(max(60, 150 - (w - 1) * 10 - timer_bonus)),
		"stability_max": max(50, 100 - (w - 1) * 5),
		"stability_penalty": int(10 + (w - 1) * 1.5),
		"freq_range_max": min(1000, int(50 * pow(1.4, w - 1))),
		"sort_elements": min(10, 5 + int((w - 1) * 0.5) + sort_bonus),
		"graph_nodes": min(9, 5 + int((w - 1) * 0.4) + graph_bonus),
		"graph_extra_edges": min(6, 2 + int((w - 1) * 0.4)),
	}


func get_total_stats() -> Dictionary:
	"""Get cumulative stats across all waves for the results screen."""
	var total_time: float = 0.0
	var total_mistakes: int = 0
	for entry in wave_history:
		total_time += float(entry["time_used"])
		total_mistakes += int(entry["mistakes"])
	return {
		"waves_survived": wave_history.size(),
		"total_time_used": total_time,
		"total_mistakes": total_mistakes,
	}
```

- [ ] **Step 2: Register autoloads in project.godot**

Add to the `[autoload]` section of `game/project.godot`:

```ini
WaveData="*res://autoload/wave_data.gd"
DifficultyManager="*res://autoload/difficulty_manager.gd"
```

The full `[autoload]` section should be:

```ini
[autoload]

GameState="*res://autoload/game_state.gd"
LLMService="*res://autoload/llm_service.gd"
WaveData="*res://autoload/wave_data.gd"
DifficultyManager="*res://autoload/difficulty_manager.gd"
```

- [ ] **Step 3: Commit**

```bash
git add game/autoload/difficulty_manager.gd game/project.godot
git commit -m "feat: add DifficultyManager autoload with adaptive difficulty engine"
```

---

## Task 3: Update GameState for Wave System

**Files:**
- Modify: `game/autoload/game_state.gd`

- [ ] **Step 1: Rewrite game_state.gd to accept wave params**

```gdscript
extends Node
## Global game state singleton. Persists across scene transitions.
## Tracks timer, stability, module completion, and per-module results.
## Now accepts difficulty params from DifficultyManager.

signal stability_changed(new_value: int)
signal timer_updated(remaining: float)
signal game_over(outcome: String)

# Configuration (set by DifficultyManager params)
var timer_total: float = 150.0
var stability_max: int = 100
var stability_penalty: int = 10

# Wave info
var current_wave: int = 1
var city_name: String = ""
var accent_color: Color = Color("#00e5ff")

# Module difficulty params (read by modules)
var freq_range_max: int = 50
var sort_elements: int = 5
var graph_nodes: int = 5
var graph_extra_edges: int = 2

# Runtime state
var timer_remaining: float = 150.0
var stability: int = 100
var mistakes: int = 0
var modules_solved: int = 0
var modules_total: int = 3
var game_outcome: String = ""
var module_results: Array[Dictionary] = []
var is_game_active: bool = false


func reset_with_params(params: Dictionary) -> void:
	"""Reset state using difficulty parameters from DifficultyManager."""
	# Apply difficulty params
	timer_total = float(params.get("timer_total", 150.0))
	stability_max = int(params.get("stability_max", 100))
	stability_penalty = int(params.get("stability_penalty", 10))
	freq_range_max = int(params.get("freq_range_max", 50))
	sort_elements = int(params.get("sort_elements", 5))
	graph_nodes = int(params.get("graph_nodes", 5))
	graph_extra_edges = int(params.get("graph_extra_edges", 2))

	# Wave info
	current_wave = int(params.get("wave", 1))
	var city: Dictionary = params.get("city", {})
	city_name = str(city.get("name", "Unknown"))
	accent_color = Color(params.get("accent_color", Color("#00e5ff")))

	# Reset runtime
	timer_remaining = timer_total
	stability = stability_max
	mistakes = 0
	modules_solved = 0
	game_outcome = ""
	module_results.clear()
	is_game_active = true


func reset() -> void:
	"""Legacy reset — uses current DifficultyManager params."""
	reset_with_params(DifficultyManager.get_wave_params())


func record_wrong_action() -> void:
	if not is_game_active:
		return
	mistakes += 1
	stability = max(0, stability - stability_penalty)
	stability_changed.emit(stability)
	if stability <= 0:
		game_outcome = "exploded_stability"
		is_game_active = false
		game_over.emit(game_outcome)


func record_module_solved(result: Dictionary) -> void:
	if not is_game_active:
		return
	modules_solved += 1
	module_results.append(result)
	if modules_solved >= modules_total:
		game_outcome = "defused"
		is_game_active = false
		game_over.emit(game_outcome)


func tick_timer(delta: float) -> void:
	if not is_game_active:
		return
	timer_remaining = max(0.0, timer_remaining - delta)
	timer_updated.emit(timer_remaining)
	if timer_remaining <= 0.0:
		game_outcome = "exploded_timer"
		is_game_active = false
		game_over.emit(game_outcome)
```

- [ ] **Step 2: Commit**

```bash
git add game/autoload/game_state.gd
git commit -m "feat: update GameState to accept wave difficulty params"
```

---

## Task 4: Briefing Overlay (Reusable Typewriter Panel)

**Files:**
- Create: `game/scripts/briefing_overlay.gd`

- [ ] **Step 1: Write briefing_overlay.gd**

```gdscript
class_name BriefingOverlay
extends Control
## Reusable classified-document styled panel with typewriter text animation.
## Used by OpeningBriefing and WorldMap scenes.

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
var _type_speed: float = 30.0  # chars per second
var _type_timer: float = 0.0


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Dark overlay background
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.88)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Center container
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

	# "CLASSIFIED" header
	var classified := Label.new()
	classified.text = "CLASSIFIED — EYES ONLY"
	classified.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classified.add_theme_font_size_override("font_size", 12)
	classified.add_theme_color_override("font_color", Color("#ff1744", 0.6))
	vbox.add_child(classified)

	# Main header (city name / title)
	_header_label = Label.new()
	_header_label.text = ""
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 28)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	# Subheader (region / threat level)
	_subheader_label = Label.new()
	_subheader_label.text = ""
	_subheader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subheader_label.add_theme_font_size_override("font_size", 16)
	_subheader_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_subheader_label)

	vbox.add_child(HSeparator.new())

	# Body text (typewriter)
	_body_label = Label.new()
	_body_label.text = ""
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 20)
	_body_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_body_label.custom_minimum_size = Vector2(650, 120)
	vbox.add_child(_body_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Deploy button
	_button = Button.new()
	_button.text = "DEPLOY"
	_button.custom_minimum_size = Vector2(200, 50)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(func(): deploy_pressed.emit())
	var btn_center := CenterContainer.new()
	btn_center.add_child(_button)
	vbox.add_child(btn_center)


func setup(header: String, subheader: String, body_text: String, button_text: String, accent: Color) -> void:
	"""Configure the briefing overlay content."""
	_header_label.text = header
	_header_label.add_theme_color_override("font_color", accent)
	_subheader_label.text = subheader
	_full_text = body_text
	_body_label.text = ""
	_visible_chars = 0
	_button.text = button_text


func start_typewriter() -> void:
	"""Begin the typewriter animation."""
	_typing = true
	_type_timer = 0.0
	_visible_chars = 0
	_body_label.text = ""


func skip_typewriter() -> void:
	"""Instantly show all text."""
	_typing = false
	_body_label.text = _full_text
	_visible_chars = _full_text.length()
	text_complete.emit()


func update_body_text(new_text: String) -> void:
	"""Update the body text (e.g., when LLM response arrives)."""
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
	# Click or key press skips typewriter
	if _typing and event is InputEventMouseButton and event.pressed:
		skip_typewriter()
	elif _typing and event is InputEventKey and event.pressed:
		skip_typewriter()
```

- [ ] **Step 2: Commit**

```bash
git add game/scripts/briefing_overlay.gd
git commit -m "feat: add BriefingOverlay with typewriter text animation"
```

---

## Task 5: Opening Briefing Scene

**Files:**
- Create: `game/scripts/opening_briefing.gd`
- Create: `game/scenes/opening_briefing.tscn`

- [ ] **Step 1: Write opening_briefing.gd**

```gdscript
extends Control
## CIA classified opening briefing. Sets up the narrative, then transitions to WorldMap.

var _briefing: BriefingOverlay
var _tech_bg: TechBackground


func _ready() -> void:
	# Reset campaign
	DifficultyManager.reset_campaign()

	# Background
	_tech_bg = TechBackground.new()
	_tech_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tech_bg)

	# Briefing overlay
	_briefing = BriefingOverlay.new()
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_briefing)

	# Get briefing text
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

	# Request LLM briefing
	var llm_text: String = LLMService.get_mission_briefing()
	if llm_text != fallback:
		_briefing.update_body_text(llm_text)
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
```

- [ ] **Step 2: Create opening_briefing.tscn**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/opening_briefing.gd" id="1"]

[node name="OpeningBriefing" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Update main_menu.gd to go to opening briefing**

In `game/scripts/main_menu.gd`, change the `_on_start` function:

```gdscript
func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/opening_briefing.tscn")
```

Also update the version label text:

```gdscript
	version.text = "v0.2.0 — OPERATION DARKFIRE"
```

- [ ] **Step 4: Commit**

```bash
git add game/scripts/opening_briefing.gd game/scenes/opening_briefing.tscn game/scripts/main_menu.gd
git commit -m "feat: add opening CIA briefing scene with typewriter animation"
```

---

## Task 6: World Map Scene

**Files:**
- Create: `game/scripts/world_map.gd`
- Create: `game/scenes/world_map.tscn`

- [ ] **Step 1: Write world_map.gd**

This is a large file. It draws a simplified world map with continent outlines, city dots, flight paths, and a city info panel with the briefing overlay.

```gdscript
extends Control
## World map screen between waves. Shows cities, flight path, and intel briefing.

var _map_draw: Control
var _info_panel: VBoxContainer
var _city_label: Label
var _region_label: Label
var _wave_label: Label
var _threat_label: Label
var _timer_preview: Label
var _stability_preview: Label
var _briefing_text: Label
var _deploy_btn: Button
var _time: float = 0.0
var _flight_progress: float = 0.0
var _flight_animating: bool = true

# Map area dimensions (left portion of screen)
const MAP_RECT: Rect2 = Rect2(30, 30, 800, 660)

# Simplified continent outlines (normalized 0-1 coordinates)
const CONTINENT_LINES: Array = [
	# North America (simplified)
	[Vector2(0.05, 0.25), Vector2(0.12, 0.18), Vector2(0.22, 0.15), Vector2(0.28, 0.20),
	 Vector2(0.30, 0.30), Vector2(0.28, 0.40), Vector2(0.22, 0.48), Vector2(0.15, 0.45),
	 Vector2(0.08, 0.35), Vector2(0.05, 0.25)],
	# South America
	[Vector2(0.22, 0.50), Vector2(0.28, 0.48), Vector2(0.35, 0.55), Vector2(0.37, 0.65),
	 Vector2(0.34, 0.78), Vector2(0.28, 0.85), Vector2(0.24, 0.75), Vector2(0.22, 0.60),
	 Vector2(0.22, 0.50)],
	# Europe
	[Vector2(0.44, 0.18), Vector2(0.50, 0.15), Vector2(0.55, 0.18), Vector2(0.53, 0.28),
	 Vector2(0.48, 0.35), Vector2(0.43, 0.32), Vector2(0.44, 0.18)],
	# Africa
	[Vector2(0.44, 0.38), Vector2(0.50, 0.35), Vector2(0.58, 0.40), Vector2(0.60, 0.55),
	 Vector2(0.55, 0.72), Vector2(0.48, 0.70), Vector2(0.44, 0.55), Vector2(0.44, 0.38)],
	# Asia
	[Vector2(0.55, 0.15), Vector2(0.65, 0.12), Vector2(0.78, 0.15), Vector2(0.88, 0.22),
	 Vector2(0.90, 0.35), Vector2(0.82, 0.45), Vector2(0.72, 0.48), Vector2(0.62, 0.42),
	 Vector2(0.58, 0.30), Vector2(0.55, 0.15)],
	# Australia
	[Vector2(0.82, 0.62), Vector2(0.92, 0.60), Vector2(0.95, 0.68), Vector2(0.90, 0.78),
	 Vector2(0.82, 0.75), Vector2(0.82, 0.62)],
]


func _ready() -> void:
	_build_ui()
	_start_flight_animation()
	_load_city_briefing()


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color("#050810")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Map drawing area
	_map_draw = Control.new()
	_map_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_draw.draw.connect(_on_map_draw)
	add_child(_map_draw)

	# Right info panel
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

	# Wave number
	_wave_label = Label.new()
	_wave_label.text = "WAVE %d OF %d" % [DifficultyManager.current_wave, WaveData.TOTAL_WAVES]
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color("#888899"))
	_info_panel.add_child(_wave_label)

	# City name
	_city_label = Label.new()
	_city_label.text = str(current_city.get("name", "Unknown"))
	_city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_city_label.add_theme_font_size_override("font_size", 28)
	_city_label.add_theme_color_override("font_color", accent)
	_info_panel.add_child(_city_label)

	# Region
	_region_label = Label.new()
	_region_label.text = str(current_city.get("region", ""))
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.add_theme_font_size_override("font_size", 14)
	_region_label.add_theme_color_override("font_color", Color("#aaaabb"))
	_info_panel.add_child(_region_label)

	# Threat level
	_threat_label = Label.new()
	_threat_label.text = "THREAT: %s" % str(current_city.get("threat", "UNKNOWN"))
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_threat_label.add_theme_font_size_override("font_size", 16)
	var threat_str: String = str(current_city.get("threat", "LOW"))
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

	# Difficulty preview
	var params: Dictionary = DifficultyManager.get_wave_params()
	_timer_preview = Label.new()
	_timer_preview.text = "Timer: %ds  |  Stability: %d" % [int(params["timer_total"]), int(params["stability_max"])]
	_timer_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_preview.add_theme_font_size_override("font_size", 14)
	_timer_preview.add_theme_color_override("font_color", Color("#aaaacc"))
	_info_panel.add_child(_timer_preview)

	_info_panel.add_child(HSeparator.new())

	# Intel briefing label
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

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_panel.add_child(spacer)

	# Deploy button
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

	# Request LLM city briefing
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
	var draw := _map_draw

	# Draw continents
	for continent in CONTINENT_LINES:
		for i in range(continent.size() - 1):
			var p1: Vector2 = _map_pos(continent[i])
			var p2: Vector2 = _map_pos(continent[i + 1])
			draw.draw_line(p1, p2, Color(0.15, 0.3, 0.5, 0.3), 1.5)
			# Glow
			draw.draw_line(p1, p2, Color(0.1, 0.25, 0.45, 0.1), 4.0)

	# Draw flight path from previous city to current
	var current_wave: int = DifficultyManager.current_wave
	if current_wave > 1:
		var prev_city: Dictionary = WaveData.get_city(current_wave - 1)
		var curr_city: Dictionary = WaveData.get_city(current_wave)
		var p1: Vector2 = _map_pos(Vector2(float(prev_city["x"]), float(prev_city["y"])))
		var p2: Vector2 = _map_pos(Vector2(float(curr_city["x"]), float(curr_city["y"])))
		var flight_end: Vector2 = p1.lerp(p2, _flight_progress)

		# Dashed flight line
		var seg_count: int = 20
		for i in range(seg_count):
			var t1: float = float(i) / seg_count
			var t2: float = float(i + 1) / seg_count
			if t2 > _flight_progress:
				break
			if i % 2 == 0:
				var s1: Vector2 = p1.lerp(p2, t1)
				var s2: Vector2 = p1.lerp(p2, min(t2, _flight_progress))
				draw.draw_line(s1, s2, Color("#00e5ff", 0.6), 2.0)

		# Plane icon (small triangle) at flight end
		if _flight_animating:
			var dir: Vector2 = (p2 - p1).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			draw.draw_polygon(
				PackedVector2Array([
					flight_end + dir * 8,
					flight_end - dir * 5 + perp * 4,
					flight_end - dir * 5 - perp * 4,
				]),
				PackedColorArray([Color("#00e5ff")])
			)

	# Draw completed city paths
	for w in range(1, current_wave - 1):
		var c1: Dictionary = WaveData.get_city(w)
		var c2: Dictionary = WaveData.get_city(w + 1)
		var cp1: Vector2 = _map_pos(Vector2(float(c1["x"]), float(c1["y"])))
		var cp2: Vector2 = _map_pos(Vector2(float(c2["x"]), float(c2["y"])))
		draw.draw_line(cp1, cp2, Color(0, 0.9, 0.4, 0.2), 1.5)

	# Draw city dots
	for w in range(1, WaveData.TOTAL_WAVES + 1):
		var city: Dictionary = WaveData.get_city(w)
		var pos: Vector2 = _map_pos(Vector2(float(city["x"]), float(city["y"])))
		var accent: Color = Color(city["accent"])

		if w < current_wave:
			# Completed — green
			draw.draw_circle(pos, 6, Color(0, 0.9, 0.4, 0.8))
			draw.draw_circle(pos, 3, Color(0, 1, 0.5))
		elif w == current_wave:
			# Current target — pulsing red
			var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
			draw.draw_circle(pos, 14 + pulse * 4, Color(1, 0.1, 0, 0.15))
			draw.draw_circle(pos, 10, Color(1, 0.15, 0, 0.3))
			draw.draw_circle(pos, 6, accent)
			draw.draw_circle(pos, 3, Color(1, 1, 1, 0.6))
			# City name
			draw.draw_string(ThemeDB.fallback_font, pos + Vector2(12, -8), str(city["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
		else:
			# Upcoming — dim
			draw.draw_circle(pos, 4, Color(0.3, 0.3, 0.4, 0.5))

	# Title
	draw.draw_string(ThemeDB.fallback_font, Vector2(40, 25), "GLOBAL THREAT MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#00e5ff", 0.5))


func _map_pos(normalized: Vector2) -> Vector2:
	"""Convert normalized (0-1) coordinates to map pixel position."""
	return Vector2(
		MAP_RECT.position.x + normalized.x * MAP_RECT.size.x,
		MAP_RECT.position.y + normalized.y * MAP_RECT.size.y
	)


func _on_deploy() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")
```

- [ ] **Step 2: Create world_map.tscn**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/world_map.gd" id="1"]

[node name="WorldMap" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/world_map.gd game/scenes/world_map.tscn
git commit -m "feat: add world map scene with cities, flight path, and intel panel"
```

---

## Task 7: Update LLMService for City-Aware Briefings

**Files:**
- Modify: `game/autoload/llm_service.gd`

- [ ] **Step 1: Add get_city_briefing method**

Add this new method to `llm_service.gd` after the existing `get_mission_briefing`:

```gdscript
func get_city_briefing(city_name: String, wave: int, threat_level: String) -> String:
	"""Returns fallback city briefing. Async LLM result emitted as 'city_briefing'."""
	var fallback := _fallback_city_briefing(city_name, wave, threat_level)
	if use_llm:
		print("[LLMService] Requesting city briefing for '%s'..." % city_name)
		_post_request(
			"/api/mission-briefing",
			{"city": city_name, "wave": wave, "threat_level": threat_level},
			"city_briefing"
		)
	return fallback
```

Add the fallback method in the fallback section:

```gdscript
func _fallback_city_briefing(city_name: String, wave: int, threat_level: String) -> String:
	var templates := [
		"NEXUS operatives have planted a device in %s. Threat assessment: %s. Local authorities are unaware. You have one shot at this, Agent.",
		"Intelligence confirms an algorithm-locked device in %s. NEXUS is using increasingly complex encryption. Threat level: %s. Proceed with extreme caution.",
		"Satellite imagery shows suspicious activity in %s. Our analysts believe a %s-level device is active. This is wave %d — they're getting smarter.",
	]
	return templates[wave % templates.size()] % [city_name, threat_level, wave]
```

- [ ] **Step 2: Update get_results_summary to include wave data**

Modify `_fallback_results_summary` to include wave count:

```gdscript
func _fallback_results_summary(performance_data: Dictionary) -> String:
	var outcome: String = str(performance_data.get("game_outcome", "unknown"))
	var time_left: float = float(performance_data.get("timer_remaining", 0.0))
	var total_mistakes: int = int(performance_data.get("total_mistakes", 0))
	var waves_survived: int = int(performance_data.get("waves_survived", 0))

	if outcome == "defused" or waves_survived >= 10:
		return (
			"Outstanding work, Agent CIPHER! You neutralized all threats across %d cities "
			% waves_survived
			+ "with %.1fs remaining on the final device and %d total mistake(s). "
			% [time_left, total_mistakes]
			+ "The Frequency Lock tested binary search, Signal Sorting explored inversions, "
			+ "and Wire Routing challenged shortest-path reasoning. NEXUS has been dismantled."
		)
	else:
		return (
			"Agent CIPHER, the device detonated in wave %d. You survived %d city(ies) "
			% [waves_survived + 1, waves_survived]
			+ "with %d total mistake(s). " % total_mistakes
			+ "Review the algorithms: binary search, sorting inversions, and Dijkstra's shortest path. "
			+ "NEXUS remains active. Regroup and try again."
		)
```

- [ ] **Step 3: Commit**

```bash
git add game/autoload/llm_service.gd
git commit -m "feat: add city-aware LLM briefings and wave-aware summaries"
```

---

## Task 8: Update Backend for City-Aware Briefings

**Files:**
- Modify: `backend/main.py`

- [ ] **Step 1: Update mission-briefing endpoint to accept city data**

Add a request model:

```python
class MissionBriefingRequest(BaseModel):
    city: str = ""
    wave: int = 1
    threat_level: str = "LOW"
```

Update the endpoint:

```python
@app.post("/api/mission-briefing")
def mission_briefing(req: MissionBriefingRequest = MissionBriefingRequest()):
    system = (
        "You are a CIA mission briefing narrator for a bomb defusal game. "
        "The player is Agent CIPHER, a counter-algorithm terrorism operative. "
        "A terrorist organization called NEXUS has planted algorithm-locked bombs worldwide. "
        "Write a 2-3 sentence tense, immersive briefing specific to the given city. "
        "Reference the city's characteristics. Keep it short and punchy."
    )
    if req.city:
        user = (
            f"Generate a mission briefing for wave {req.wave} in {req.city}. "
            f"Threat level: {req.threat_level}. "
            f"The agent is deploying to defuse a NEXUS device."
        )
    else:
        user = (
            "Generate the opening briefing for Operation Darkfire. "
            "NEXUS has planted 10 algorithm-locked bombs in cities worldwide. "
            "Agent CIPHER is being activated."
        )
    text = _chat(system, user)
    return {"text": text}
```

Update the results-summary model to include waves:

```python
class ResultsSummaryRequest(BaseModel):
    game_outcome: str
    timer_remaining: float
    total_mistakes: int
    module_results: list[dict[str, Any]]
    waves_survived: int = 0
    city_name: str = ""
```

Update the results_summary endpoint system prompt:

```python
@app.post("/api/results-summary")
def results_summary(req: ResultsSummaryRequest):
    system = (
        "You are an educational debrief AI for a CIA bomb defusal game that teaches algorithms. "
        "The player is Agent CIPHER fighting NEXUS across world cities. "
        "Summarize the player's performance, mention how many waves/cities they survived, "
        "and explain the algorithm behind each module. "
        "Be encouraging, educational, and concise. Use 3-5 sentences total."
    )
    modules_str = "\n".join(
        f"- {m.get('name', '?')}: {m.get('mistakes', 0)} mistakes, "
        f"algorithm: {m.get('algorithm', '?')}"
        for m in req.module_results
    )
    user = (
        f"Game outcome: {req.game_outcome}\n"
        f"Waves survived: {req.waves_survived}/10\n"
        f"Last city: {req.city_name}\n"
        f"Time remaining: {req.timer_remaining:.1f}s\n"
        f"Total mistakes: {req.total_mistakes}\n"
        f"Modules:\n{modules_str}\n\n"
        f"Give a short educational debrief."
    )
    text = _chat(system, user)
    return {"text": text}
```

- [ ] **Step 2: Commit**

```bash
git add backend/main.py
git commit -m "feat: update backend with city-aware briefings and wave-aware summaries"
```

---

## Task 9: Update Modules for Configurable Difficulty

**Files:**
- Modify: `game/scripts/frequency_lock_module.gd`
- Modify: `game/scripts/signal_sorting_module.gd`
- Modify: `game/scripts/wire_routing_module.gd`

- [ ] **Step 1: Update frequency_lock_module.gd**

Replace the hardcoded range with GameState params. Change `reset_module`:

```gdscript
func reset_module() -> void:
	super.reset_module()
	var range_max: int = GameState.freq_range_max
	_target = randi_range(1, range_max)
	_guess_count = 0
	_range_low = 1
	_range_high = range_max
	if _feedback_label:
		_feedback_label.text = "Find the safe frequency"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_range_label.text = "Range: [1 — %d]" % range_max
		_guess_count_label.text = "Guesses: 0"
		_hint_label.text = ""
		_spinbox.max_value = range_max
		_spinbox.value = range_max / 2
		_submit_btn.disabled = false
```

- [ ] **Step 2: Update signal_sorting_module.gd**

Replace `const NUM_ELEMENTS` with a var that reads from GameState:

```gdscript
# Change line 5 from:
# const NUM_ELEMENTS: int = 6
# To:
var _num_elements: int = 6
```

In `reset_module`, read from GameState:

```gdscript
func reset_module() -> void:
	super.reset_module()
	_num_elements = GameState.sort_elements
	_selected_index = -1
	_swap_count = 0
	_generate_values()
	_rebuild_buttons()
	if _status_label:
		_status_label.text = "Select two values to swap"
		_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_swap_count_label.text = "Swaps: 0"
		_hint_label.text = ""
```

Update `_generate_values` to use `_num_elements`:

```gdscript
func _generate_values() -> void:
	_values.clear()
	for i in range(_num_elements):
		_values.append(randi_range(10, 99))
	var sorted_copy := _values.duplicate()
	sorted_copy.sort()
	while _values == sorted_copy:
		_values.shuffle()
```

- [ ] **Step 3: Update wire_routing_module.gd**

Replace `const NUM_NODES` with a var:

```gdscript
# Change from:
# const NUM_NODES: int = 6
# To:
var _num_nodes: int = 6
var _num_extra_edges: int = 2
```

In `reset_module`, read from GameState:

```gdscript
func reset_module() -> void:
	super.reset_module()
	_num_nodes = GameState.graph_nodes
	_num_extra_edges = GameState.graph_extra_edges
	_target = _num_nodes - 1
	_player_path.clear()
	_player_cost = 0
	_attempt_count = 0
	_generate_graph()
	_compute_shortest_path()
	if _path_label:
		_update_path_display()
		_hint_label.text = ""
		_confirm_btn.disabled = false
		_graph_draw.queue_redraw()
```

Update `_generate_graph` to use `_num_nodes` and `_num_extra_edges`. Replace references to `NUM_NODES` with `_num_nodes`. Adjust the grid layout dynamically:

```gdscript
func _generate_graph() -> void:
	_nodes.clear()
	_edges.clear()
	_adjacency.clear()

	# Dynamic grid layout
	var cols: int = max(2, (_num_nodes + 1) / 2)
	var rows: int = max(2, int(ceil(float(_num_nodes) / cols)))
	var cell_w: float = GRAPH_SIZE.x / cols
	var cell_h: float = GRAPH_SIZE.y / rows
	for i in range(_num_nodes):
		var r: int = i / cols
		var c: int = i % cols
		var x: float = cell_w * (c + 0.5) + randf_range(-15, 15)
		var y: float = cell_h * (r + 0.5) + randf_range(-10, 10)
		_nodes.append(Vector2(x, y))

	for i in range(_num_nodes):
		_adjacency[i] = []

	# Spanning path
	for i in range(_num_nodes - 1):
		var cost: int = randi_range(1, 9)
		_add_edge(i, i + 1, cost)

	# Extra edges
	var possible_extras: Array = []
	for a in range(_num_nodes):
		for b in range(a + 2, _num_nodes):
			possible_extras.append([a, b])
	possible_extras.shuffle()
	var to_add: int = min(_num_extra_edges, possible_extras.size())
	for i in range(to_add):
		var pair: Array = possible_extras[i]
		if not _has_edge(pair[0], pair[1]):
			_add_edge(pair[0], pair[1], randi_range(1, 9))
```

Update `_compute_shortest_path` and `_on_draw` to use `_num_nodes` instead of `NUM_NODES`.

- [ ] **Step 4: Commit**

```bash
git add game/scripts/frequency_lock_module.gd game/scripts/signal_sorting_module.gd game/scripts/wire_routing_module.gd
git commit -m "feat: make puzzle modules read difficulty params from GameState"
```

---

## Task 10: Update BombGame for Wave Transitions

**Files:**
- Modify: `game/scripts/bomb_game.gd`

- [ ] **Step 1: Update bomb_game.gd**

Key changes:
1. `_ready` calls `GameState.reset()` (which now reads DifficultyManager params)
2. Pass accent color to TechBackground and BombVisual
3. Show wave/city info in the title
4. On defuse: record performance → advance wave → go to WorldMap (or ResultScreen if wave 10)
5. On explosion: go to ResultScreen

Update `_ready`:

```gdscript
func _ready() -> void:
	_build_ui()
	GameState.reset()
	_apply_wave_theme()
	_instantiate_modules()
	_setup_signals()
	_load_mission_briefing()
```

Add `_apply_wave_theme`:

```gdscript
func _apply_wave_theme() -> void:
	var accent: Color = GameState.accent_color
	_tech_bg.set_accent_color(accent)
	_tech_bg.set_watermark(GameState.city_name)
	_bomb_visual.accent_color = accent
	_bomb_visual.wave_number = GameState.current_wave
```

Update the title label in `_build_ui` to show wave/city:

```gdscript
	var title := Label.new()
	title.text = "WAVE %d — %s" % [GameState.current_wave, GameState.city_name.to_upper()]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GameState.accent_color)
	left_col.add_child(title)
```

Update `_on_game_over` for wave transitions:

```gdscript
func _on_game_over(outcome: String) -> void:
	_game_ended = true

	if outcome == "defused":
		_status_label.text = "BOMB DEFUSED! Well done, Agent."
		_status_label.add_theme_color_override("font_color", Color("#00e676"))
		_bomb_visual.trigger_defused()
		_screen_fx.trigger_defuse_flash()

		# Record performance and advance
		var time_used: float = GameState.timer_total - GameState.timer_remaining
		var max_mistakes: int = int(float(GameState.stability_max) / float(GameState.stability_penalty))
		DifficultyManager.record_wave_performance(time_used, GameState.timer_total, GameState.mistakes, max_mistakes)

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

		# Record failed wave
		var time_used: float = GameState.timer_total - GameState.timer_remaining
		var max_mistakes: int = int(float(GameState.stability_max) / float(GameState.stability_penalty))
		DifficultyManager.record_wave_performance(time_used, GameState.timer_total, GameState.mistakes, max_mistakes)

		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
```

- [ ] **Step 2: Commit**

```bash
git add game/scripts/bomb_game.gd
git commit -m "feat: update BombGame for wave transitions and city-themed visuals"
```

---

## Task 11: Update TechBackground and BombVisual for City Accents

**Files:**
- Modify: `game/scripts/tech_background.gd`
- Modify: `game/scripts/bomb_visual.gd`

- [ ] **Step 1: Add accent_color and watermark to TechBackground**

Add new variables at the top of `tech_background.gd`:

```gdscript
var _accent_color: Color = Color(0, 0.8, 1.0)
var _watermark_text: String = ""
```

Add setter methods:

```gdscript
func set_accent_color(color: Color) -> void:
	_accent_color = color

func set_watermark(text: String) -> void:
	_watermark_text = text
```

In `_draw_grid`, replace hardcoded `Color(0.0, 0.4, 0.6, 0.06)` with `Color(_accent_color, 0.06)` and the pulse color with `Color(_accent_color, 0.12)`.

In `_draw_hud_frame`, replace `Color(0, 0.8, 1.0, 0.3)` with `Color(_accent_color, 0.3)`.

In `_draw_particles`, replace `Color(0, 0.8, 1.0, alpha)` with `Color(_accent_color, alpha)`.

Add watermark drawing at the end of `_draw`:

```gdscript
	# City watermark
	if _watermark_text != "":
		draw_string(
			ThemeDB.fallback_font,
			size / 2.0 + Vector2(-200, 50),
			_watermark_text.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER,
			500,
			60,
			Color(_accent_color, 0.03)
		)
```

- [ ] **Step 2: Add accent_color and wave_number to BombVisual**

Add variables at the top of `bomb_visual.gd`:

```gdscript
var accent_color: Color = Color(0, 0.7, 1.0)
var wave_number: int = 1
```

In `_draw_wire_veins`, replace hardcoded `Color(0, 0.7, 1.0, ...)` with `Color(accent_color, ...)`. Add extra veins based on wave_number:

```gdscript
	# Number of veins scales with wave
	var num_veins: int = min(8, 3 + wave_number / 2)
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/tech_background.gd game/scripts/bomb_visual.gd
git commit -m "feat: add city accent colors and watermark to TechBackground and BombVisual"
```

---

## Task 12: Update ResultScreen for Wave Stats

**Files:**
- Modify: `game/scripts/result_screen.gd`

- [ ] **Step 1: Rewrite result_screen.gd with wave stats and debrief cards**

The result screen now shows:
- Waves survived (out of 10)
- Victory screen if all 10 completed
- Per-module algorithm explanation cards
- Total stats
- LLM debrief at 18px

Key changes to `_display_results`:

```gdscript
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
				_outcome_label.text = "MISSION COMPLETE"
				_outcome_label.add_theme_color_override("font_color", Color("#00e676"))
			"exploded_timer":
				_outcome_label.text = "DETONATION — TIME EXPIRED"
				_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
			"exploded_stability":
				_outcome_label.text = "DETONATION — STABILITY FAILURE"
				_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))

	# Stats
	_stats_label.text = "Waves Survived: %d/%d  |  Mistakes: %d  |  Last City: %s" % [
		waves_survived, WaveData.TOTAL_WAVES,
		int(stats["total_mistakes"]),
		GameState.city_name,
	]

	# LLM summary with wave data
	var perf_data := {
		"game_outcome": GameState.game_outcome,
		"timer_remaining": GameState.timer_remaining,
		"total_mistakes": int(stats["total_mistakes"]),
		"module_results": GameState.module_results,
		"waves_survived": waves_survived,
		"city_name": GameState.city_name,
	}
	_explanation_label.text = LLMService.get_results_summary(perf_data)
```

- [ ] **Step 2: Commit**

```bash
git add game/scripts/result_screen.gd
git commit -m "feat: update ResultScreen with wave stats and city info"
```

---

## Self-Review Checklist

### Spec Coverage
- [x] Story/narrative: Opening briefing (Task 5), CIA theme throughout
- [x] 10 cities with data: WaveData (Task 1)
- [x] Game flow: MainMenu→Opening→WorldMap→BombGame→WorldMap/Result (Tasks 5,6,10)
- [x] DifficultyManager with adaptive params (Task 2)
- [x] Efficiency scoring and adaptive bonus/mercy (Task 2)
- [x] GameState accepts params (Task 3)
- [x] Typewriter briefing overlay (Task 4)
- [x] World map with continents, cities, flight path (Task 6)
- [x] LLM city-aware briefings (Tasks 7, 8)
- [x] Bigger LLM text: 20px in briefings, 16px in-game (Tasks 4, 6)
- [x] Module difficulty scaling (Task 9)
- [x] City accent colors in TechBackground + BombVisual (Task 11)
- [x] City watermark (Task 11)
- [x] Wave stats in ResultScreen (Task 12)
- [x] Backend city-aware endpoints (Task 8)
- [x] project.godot autoload registration (Task 2)

### Placeholder Scan
- No TBD/TODO found
- All code blocks complete

### Type Consistency
- `DifficultyManager.get_wave_params()` → Dictionary — consistent across Tasks 2,3,10
- `WaveData.get_city(wave)` → Dictionary — consistent across Tasks 1,6
- `GameState.reset()` calls `reset_with_params()` → consistent in Tasks 3,10
- `LLMService.get_city_briefing()` → consistent between Tasks 6,7
- `accent_color` property on BombVisual and method on TechBackground — consistent in Tasks 10,11
