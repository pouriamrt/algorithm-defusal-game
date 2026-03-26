class_name WaveDataClass
extends Node
## Static data for all 10 cities. Each city has a unique combination of 3 puzzle modules
## drawn from a pool of 10 module types covering different CS/algorithm concepts.

# Module scene paths — 10 distinct puzzle types
const MOD_FREQ := "res://modules/frequency_lock_module.tscn"      # Binary Search
const MOD_SORT := "res://modules/signal_sorting_module.tscn"      # Sorting / Inversions
const MOD_WIRE := "res://modules/wire_routing_module.tscn"        # Shortest Path / Dijkstra
const MOD_PATTERN := "res://modules/pattern_sequence_module.tscn" # Pattern Recognition
const MOD_CODE := "res://modules/code_breaker_module.tscn"        # Logical Deduction
const MOD_MEMORY := "res://modules/memory_matrix_module.tscn"     # Spatial Memory / Caching
const MOD_BITS := "res://modules/bit_cipher_module.tscn"          # Binary Representation
const MOD_STACK := "res://modules/stack_overflow_module.tscn"     # Stack (LIFO)
const MOD_PQUEUE := "res://modules/priority_queue_module.tscn"    # Priority Queue / Heap
const MOD_LOGIC := "res://modules/logic_gates_module.tscn"        # Boolean Logic / Circuits

# City coordinates use equirectangular projection:
# x = (longitude + 180) / 360, y = (90 - latitude) / 180
const CITIES: Array[Dictionary] = [
	{"name": "Washington D.C.", "region": "North America", "accent": "#4488ff", "threat": "LOW",
	 "x": 0.285, "y": 0.285, "modules": [MOD_FREQ, MOD_BITS, MOD_PATTERN]},
	{"name": "London", "region": "Europe", "accent": "#7799bb", "threat": "LOW",
	 "x": 0.500, "y": 0.215, "modules": [MOD_LOGIC, MOD_SORT, MOD_STACK]},
	{"name": "Paris", "region": "Europe", "accent": "#ddaa44", "threat": "MODERATE",
	 "x": 0.507, "y": 0.232, "modules": [MOD_MEMORY, MOD_WIRE, MOD_PQUEUE]},
	{"name": "Tokyo", "region": "Asia", "accent": "#ff44aa", "threat": "MODERATE",
	 "x": 0.889, "y": 0.252, "modules": [MOD_CODE, MOD_BITS, MOD_SORT]},
	{"name": "Cairo", "region": "Africa", "accent": "#ddaa55", "threat": "ELEVATED",
	 "x": 0.587, "y": 0.333, "modules": [MOD_STACK, MOD_PATTERN, MOD_WIRE]},
	{"name": "Moscow", "region": "Europe", "accent": "#aaccee", "threat": "ELEVATED",
	 "x": 0.604, "y": 0.192, "modules": [MOD_PQUEUE, MOD_LOGIC, MOD_FREQ]},
	{"name": "Mumbai", "region": "Asia", "accent": "#ff8833", "threat": "HIGH",
	 "x": 0.703, "y": 0.395, "modules": [MOD_CODE, MOD_MEMORY, MOD_STACK]},
	{"name": "Sydney", "region": "Oceania", "accent": "#33bbaa", "threat": "HIGH",
	 "x": 0.919, "y": 0.688, "modules": [MOD_BITS, MOD_PQUEUE, MOD_PATTERN]},
	{"name": "Rio de Janeiro", "region": "South America", "accent": "#44dd66", "threat": "SEVERE",
	 "x": 0.381, "y": 0.627, "modules": [MOD_WIRE, MOD_LOGIC, MOD_MEMORY]},
	{"name": "Pyongyang", "region": "Asia", "accent": "#dd2222", "threat": "CRITICAL",
	 "x": 0.853, "y": 0.278, "modules": [MOD_FREQ, MOD_CODE, MOD_SORT]},
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
