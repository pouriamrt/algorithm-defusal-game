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
