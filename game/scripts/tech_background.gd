class_name TechBackground
extends Control
## Animated sci-fi grid background with pulsing lines, floating particles,
## and data stream effects. Creates a futuristic control room atmosphere.

var _time: float = 0.0
var _particles: Array[Dictionary] = []
var _data_streams: Array[Dictionary] = []
var _alert_level: float = 0.0  # 0.0 = calm, 1.0 = critical

const NUM_PARTICLES: int = 40
const NUM_STREAMS: int = 8
const GRID_SPACING: float = 60.0


func _ready() -> void:
	# Initialize floating particles
	for i in range(NUM_PARTICLES):
		_particles.append({
			"pos": Vector2(randf() * 1280, randf() * 720),
			"vel": Vector2(randf_range(-15, 15), randf_range(-10, -30)),
			"size": randf_range(1.0, 3.0),
			"alpha": randf_range(0.1, 0.4),
			"phase": randf() * TAU,
		})

	# Initialize data streams (vertical falling characters)
	for i in range(NUM_STREAMS):
		_data_streams.append({
			"x": randf() * 1280,
			"speed": randf_range(40, 120),
			"chars": [],
			"next_char": 0.0,
			"alpha": randf_range(0.05, 0.15),
		})


func _process(delta: float) -> void:
	_time += delta
	_update_particles(delta)
	_update_streams(delta)
	queue_redraw()


func _draw() -> void:
	# Base gradient background
	_draw_gradient()
	# Animated grid
	_draw_grid()
	# Data streams
	_draw_streams()
	# Floating particles
	_draw_particles()
	# Corner brackets (HUD frame)
	_draw_hud_frame()


func _draw_gradient() -> void:
	# Dark gradient from deep navy to slightly lighter at edges
	draw_rect(Rect2(Vector2.ZERO, size), Color("#060a12"))
	# Subtle radial gradient in center
	var center := size / 2.0
	for i in range(8):
		var radius: float = size.length() * 0.5 * (1.0 - float(i) / 8.0)
		var alpha: float = 0.02 * (1.0 - float(i) / 8.0)
		draw_circle(center, radius, Color(0.0, 0.15, 0.3, alpha))


func _draw_grid() -> void:
	var grid_color := Color(0.0, 0.4, 0.6, 0.06)
	var grid_pulse_color := Color(0.0, 0.8, 1.0, 0.12)

	# Vertical lines
	var x: float = fmod(_time * 5.0, GRID_SPACING)
	while x < size.x:
		var pulse := sin(_time * 0.5 + x * 0.01) * 0.5 + 0.5
		var col := grid_color.lerp(grid_pulse_color, pulse * 0.3)
		# Alert mode shifts grid color toward red
		if _alert_level > 0:
			col = col.lerp(Color(0.8, 0.1, 0.0, col.a), _alert_level * 0.5)
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
		x += GRID_SPACING

	# Horizontal lines
	var y: float = fmod(_time * 3.0, GRID_SPACING)
	while y < size.y:
		var pulse := sin(_time * 0.7 + y * 0.01) * 0.5 + 0.5
		var col := grid_color.lerp(grid_pulse_color, pulse * 0.3)
		if _alert_level > 0:
			col = col.lerp(Color(0.8, 0.1, 0.0, col.a), _alert_level * 0.5)
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
		y += GRID_SPACING

	# Pulsing horizontal scan line
	var scan_y := fmod(_time * 80.0, size.y)
	draw_line(Vector2(0, scan_y), Vector2(size.x, scan_y), Color(0, 0.8, 1.0, 0.08), 2.0)
	# Glow around scan line
	for offset in [-3.0, -1.5, 1.5, 3.0]:
		draw_line(
			Vector2(0, scan_y + offset),
			Vector2(size.x, scan_y + offset),
			Color(0, 0.6, 0.9, 0.03), 1.0
		)


func _draw_particles() -> void:
	for p in _particles:
		var pulse := sin(_time * 2.0 + p["phase"]) * 0.3 + 0.7
		var alpha: float = p["alpha"] * pulse
		var particle_color := Color(0, 0.8, 1.0, alpha)
		if _alert_level > 0.5:
			particle_color = particle_color.lerp(Color(1, 0.3, 0, alpha), _alert_level)
		draw_circle(p["pos"], p["size"], particle_color)


func _draw_streams() -> void:
	for stream in _data_streams:
		for ch in stream["chars"]:
			var char_alpha: float = stream["alpha"] * ch["alpha"]
			var col := Color(0, 0.8, 0.6, char_alpha)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(stream["x"], ch["y"]),
				ch["char"],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				col
			)


func _draw_hud_frame() -> void:
	var corner_len: float = 40.0
	var corner_color := Color(0, 0.8, 1.0, 0.3)
	if _alert_level > 0.5:
		corner_color = Color(1, 0.2, 0, 0.4)
	var w: float = size.x
	var h: float = size.y
	var m: float = 8.0  # margin

	# Top-left
	draw_line(Vector2(m, m), Vector2(m + corner_len, m), corner_color, 2.0)
	draw_line(Vector2(m, m), Vector2(m, m + corner_len), corner_color, 2.0)
	# Top-right
	draw_line(Vector2(w - m, m), Vector2(w - m - corner_len, m), corner_color, 2.0)
	draw_line(Vector2(w - m, m), Vector2(w - m, m + corner_len), corner_color, 2.0)
	# Bottom-left
	draw_line(Vector2(m, h - m), Vector2(m + corner_len, h - m), corner_color, 2.0)
	draw_line(Vector2(m, h - m), Vector2(m, h - m - corner_len), corner_color, 2.0)
	# Bottom-right
	draw_line(Vector2(w - m, h - m), Vector2(w - m - corner_len, h - m), corner_color, 2.0)
	draw_line(Vector2(w - m, h - m), Vector2(w - m, h - m - corner_len), corner_color, 2.0)


func _update_particles(delta: float) -> void:
	for p in _particles:
		p["pos"] += p["vel"] * delta
		# Gentle drift
		p["pos"].x += sin(_time + p["phase"]) * 8.0 * delta
		# Wrap around
		if p["pos"].y < -10:
			p["pos"].y = size.y + 10
			p["pos"].x = randf() * size.x
		if p["pos"].x < -10:
			p["pos"].x = size.x + 10
		elif p["pos"].x > size.x + 10:
			p["pos"].x = -10


func _update_streams(delta: float) -> void:
	var chars := "01アイウエオカキクケコ:.;=+<>"
	for stream in _data_streams:
		stream["next_char"] -= delta
		if stream["next_char"] <= 0:
			stream["next_char"] = randf_range(0.05, 0.2)
			stream["chars"].append({
				"y": -10.0,
				"char": chars[randi() % chars.length()],
				"alpha": 1.0,
			})
		# Move characters down
		var i: int = stream["chars"].size() - 1
		while i >= 0:
			stream["chars"][i]["y"] += stream["speed"] * delta
			stream["chars"][i]["alpha"] -= delta * 0.5
			if stream["chars"][i]["y"] > size.y or stream["chars"][i]["alpha"] <= 0:
				stream["chars"].remove_at(i)
			i -= 1


func set_alert_level(level: float) -> void:
	"""Set alert level 0.0-1.0. Shifts colors from cyan to red."""
	_alert_level = clampf(level, 0.0, 1.0)
