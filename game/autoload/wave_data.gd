class_name WaveDataClass
extends Node
## Static data for all 10 cities. Each city has a unique combination of 3 puzzle modules.

# Module scene paths
const MOD_FREQ := "res://modules/frequency_lock_module.tscn"
const MOD_SORT := "res://modules/signal_sorting_module.tscn"
const MOD_WIRE := "res://modules/wire_routing_module.tscn"
const MOD_PATTERN := "res://modules/pattern_sequence_module.tscn"
const MOD_CODE := "res://modules/code_breaker_module.tscn"
const MOD_MEMORY := "res://modules/memory_matrix_module.tscn"

const CITIES: Array[Dictionary] = [
	{"name": "Washington D.C.", "region": "North America", "accent": "#4488ff", "threat": "LOW",
	 "x": 0.23, "y": 0.38, "modules": [MOD_FREQ, MOD_SORT, MOD_PATTERN]},
	{"name": "London", "region": "Europe", "accent": "#7799bb", "threat": "LOW",
	 "x": 0.47, "y": 0.28, "modules": [MOD_CODE, MOD_WIRE, MOD_MEMORY]},
	{"name": "Paris", "region": "Europe", "accent": "#ddaa44", "threat": "MODERATE",
	 "x": 0.48, "y": 0.32, "modules": [MOD_FREQ, MOD_MEMORY, MOD_WIRE]},
	{"name": "Tokyo", "region": "Asia", "accent": "#ff44aa", "threat": "MODERATE",
	 "x": 0.85, "y": 0.37, "modules": [MOD_PATTERN, MOD_CODE, MOD_SORT]},
	{"name": "Cairo", "region": "Africa", "accent": "#ddaa55", "threat": "ELEVATED",
	 "x": 0.55, "y": 0.42, "modules": [MOD_SORT, MOD_WIRE, MOD_CODE]},
	{"name": "Moscow", "region": "Europe", "accent": "#aaccee", "threat": "ELEVATED",
	 "x": 0.58, "y": 0.25, "modules": [MOD_MEMORY, MOD_FREQ, MOD_PATTERN]},
	{"name": "Mumbai", "region": "Asia", "accent": "#ff8833", "threat": "HIGH",
	 "x": 0.68, "y": 0.45, "modules": [MOD_CODE, MOD_PATTERN, MOD_WIRE]},
	{"name": "Sydney", "region": "Oceania", "accent": "#33bbaa", "threat": "HIGH",
	 "x": 0.88, "y": 0.72, "modules": [MOD_FREQ, MOD_SORT, MOD_MEMORY]},
	{"name": "Rio de Janeiro", "region": "South America", "accent": "#44dd66", "threat": "SEVERE",
	 "x": 0.32, "y": 0.65, "modules": [MOD_WIRE, MOD_MEMORY, MOD_CODE]},
	{"name": "Pyongyang", "region": "Asia", "accent": "#dd2222", "threat": "CRITICAL",
	 "x": 0.82, "y": 0.35, "modules": [MOD_FREQ, MOD_CODE, MOD_WIRE]},
]

const TOTAL_WAVES: int = 10


func get_city(wave: int) -> Dictionary:
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


func get_module_scenes(wave: int) -> Array:
	var city: Dictionary = get_city(wave)
	if city.is_empty() or not city.has("modules"):
		return [MOD_FREQ, MOD_SORT, MOD_WIRE]
	return city["modules"]
