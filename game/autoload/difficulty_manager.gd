class_name DifficultyManagerClass
extends Node
## Adaptive difficulty engine. Tracks wave progression and player performance.

var current_wave: int = 1
var wave_history: Array[Dictionary] = []
var last_efficiency: float = -1.0


func reset_campaign() -> void:
	current_wave = 1
	wave_history.clear()
	last_efficiency = -1.0


func advance_wave() -> void:
	current_wave += 1


func record_wave_performance(time_used: float, timer_total: float, mistakes: int, max_mistakes: int) -> void:
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
	var w: int = current_wave
	var adaptive_timer_bonus: int = 0
	var adaptive_sort_bonus: int = 0
	var adaptive_graph_bonus: int = 0

	if last_efficiency > 0.7 and w > 1:
		adaptive_timer_bonus = 10
		adaptive_sort_bonus = 1
		adaptive_graph_bonus = 1

	var mercy: bool = (last_efficiency >= 0.0 and last_efficiency < 0.3 and w > 1)

	var params: Dictionary = {}
	if mercy and not wave_history.is_empty():
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
