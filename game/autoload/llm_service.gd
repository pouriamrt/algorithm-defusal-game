extends Node
## LLM integration service. Calls FastAPI backend when available,
## falls back to hardcoded text when backend is unreachable.

signal llm_response_received(context: String, text: String)

const BACKEND_URL: String = "http://127.0.0.1:8000"
const TIMEOUT_SEC: float = 5.0

var use_llm: bool = false


func _ready() -> void:
	_check_backend_health()


func _check_backend_health() -> void:
	"""Try to reach the backend. Sets use_llm accordingly."""
	print("[LLMService] Checking backend at %s/health ..." % BACKEND_URL)
	var health_http := HTTPRequest.new()
	health_http.timeout = 3.0
	add_child(health_http)
	health_http.request_completed.connect(_on_health_check.bind(health_http))
	var err := health_http.request(BACKEND_URL + "/health")
	if err != OK:
		print("[LLMService] Health request failed to start, error code: %d" % err)
		use_llm = false
		health_http.queue_free()


func _on_health_check(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, health_http: HTTPRequest) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		use_llm = true
		print("[LLMService] Backend connected — LLM mode active")
	else:
		use_llm = false
		print("[LLMService] Backend unreachable (result=%d, code=%d) — using fallback text" % [result, response_code])
	health_http.queue_free()


# --- Public API ---


func get_mission_briefing() -> String:
	"""Returns fallback immediately. If LLM is active, fires async request
	and emits llm_response_received('mission_briefing', text) when done."""
	var fallback := _fallback_mission_briefing()
	if use_llm:
		print("[LLMService] Requesting mission briefing from LLM...")
		_post_request("/api/mission-briefing", {}, "mission_briefing")
	else:
		print("[LLMService] Using fallback mission briefing (use_llm=%s)" % str(use_llm))
	return fallback


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


func get_module_hint(module_name: String, current_state: Dictionary) -> String:
	"""Returns fallback hint immediately. Async LLM result emitted if available."""
	var fallback := _fallback_module_hint(module_name)
	if use_llm:
		print("[LLMService] Requesting hint for '%s' from LLM..." % module_name)
		_post_request(
			"/api/module-hint",
			{"module_name": module_name, "current_state": current_state},
			"module_hint"
		)
	return fallback


func get_results_summary(performance_data: Dictionary) -> String:
	"""Returns fallback summary immediately. Async LLM result emitted if available."""
	var fallback := _fallback_results_summary(performance_data)
	if use_llm:
		print("[LLMService] Requesting results summary from LLM...")
		_post_request("/api/results-summary", performance_data, "results_summary")
	return fallback


# --- HTTP helpers ---


func _post_request(endpoint: String, body: Dictionary, context: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	req.request_completed.connect(_on_post_response.bind(context, req))
	var json_str := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := req.request(BACKEND_URL + endpoint, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		print("[LLMService] POST %s failed to start, error: %d" % [endpoint, err])
		req.queue_free()


func _on_post_response(result: int, response_code: int, _headers: PackedStringArray, response_body: PackedByteArray, context: String, req: HTTPRequest) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str := response_body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json and json.has("text"):
			print("[LLMService] Got LLM response for '%s' (%d chars)" % [context, json["text"].length()])
			llm_response_received.emit(context, json["text"])
		else:
			print("[LLMService] Invalid JSON response for '%s': %s" % [context, body_str.left(100)])
	else:
		print("[LLMService] POST failed for '%s' (result=%d, code=%d)" % [context, result, response_code])
	req.queue_free()


# --- Fallback text ---


func _fallback_mission_briefing() -> String:
	var briefings := [
		"ALERT: A rogue AI has armed an algorithmic explosive in Sector 7-G. You have 120 seconds to solve its puzzle locks before detonation. Trust your instincts, technician.",
		"INCOMING TRANSMISSION: An unstable device has been detected in the server core. Three encrypted modules stand between you and safety. The clock is ticking.",
		"PRIORITY ONE: A cascade failure bomb has been planted in the neural network hub. Solve the algorithmic locks to prevent total system collapse. Move fast.",
		"WARNING: Hostile code has armed a logic bomb in the mainframe. Only a skilled technician can crack its three cipher modules in time. You're our last hope.",
		"URGENT: An encrypted detonator is counting down in the quantum relay station. Three algorithm puzzles guard the kill switch. Precision over speed, technician.",
	]
	return briefings[randi() % briefings.size()]


func _fallback_city_briefing(city_name: String, wave: int, threat_level: String) -> String:
	var templates := [
		"NEXUS operatives have planted a device in %s. Threat assessment: %s. Wave %d. Local authorities are unaware. You have one shot at this, Agent.",
		"Intelligence confirms an algorithm-locked device in %s. NEXUS is using increasingly complex encryption. Threat level: %s. Wave %d. Proceed with extreme caution.",
		"Satellite imagery shows suspicious activity in %s. Our analysts believe a %s-level device is active. This is wave %d — they're getting smarter.",
	]
	return templates[wave % templates.size()] % [city_name, threat_level, wave]


func _fallback_module_hint(module_name: String) -> String:
	var hints := {
		"Frequency Lock": [
			"Think about cutting the search space in half with each guess.",
			"What if you always guessed the middle of the remaining range?",
			"The optimal strategy eliminates half the possibilities every time.",
		],
		"Signal Sorting": [
			"Look for the largest out-of-place element and move it toward its correct position.",
			"Count how many pairs are in the wrong order — try to reduce that number with each swap.",
			"Focus on making progress: each swap should bring you closer to sorted order.",
		],
		"Wire Routing": [
			"The shortest path isn't always the one with fewest hops — watch the edge weights.",
			"Try to find the path where the sum of all edge costs is minimized.",
			"Compare routes by adding up their total cost, not just counting steps.",
		],
		"Pattern Sequence": [
			"Look at the differences between consecutive numbers — is there a pattern?",
			"Try checking if the sequence grows by addition, multiplication, or something else.",
			"Some sequences add the two previous numbers. Others square them. What rule fits?",
		],
		"Code Breaker": [
			"Use exact matches to lock in correct positions, then use partial matches to find misplaced digits.",
			"If a digit gets 0 exact and 0 partial, eliminate it from all positions.",
			"Think systematically — change one digit at a time to isolate which positions are correct.",
		],
		"Memory Matrix": [
			"Focus on the overall shape of the pattern, not individual cells.",
			"Try to remember the pattern as clusters or groups rather than individual positions.",
			"Look for symmetry or familiar shapes in the highlighted cells.",
		],
	}
	var module_hints: Array = hints.get(module_name, ["Think carefully about your next move."])
	return module_hints[randi() % module_hints.size()]


func _fallback_results_summary(performance_data: Dictionary) -> String:
	var outcome: String = str(performance_data.get("game_outcome", "unknown"))
	var time_left: float = float(performance_data.get("timer_remaining", 0.0))
	var total_mistakes: int = int(performance_data.get("total_mistakes", 0))
	var waves_survived: int = int(performance_data.get("waves_survived", 0))

	if outcome == "defused" or waves_survived >= 10:
		return (
			"Outstanding work, Agent CIPHER! You neutralized threats across %d cities "
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
