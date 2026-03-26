class_name BombVisual
extends Control
## Draws a cartoon bomb with burning fuse, spark effects, and explosion animation.
## The fuse length corresponds to the timer. Pulses red when stability is low.

# Bomb geometry
const BOMB_RADIUS: float = 45.0
const FUSE_LENGTH: float = 50.0
const FUSE_ATTACH: Vector2 = Vector2(25, -35)  # relative to bomb center

# State
var timer_ratio: float = 1.0  # 0.0 = no time left, 1.0 = full
var stability_ratio: float = 1.0  # 0.0 = critical, 1.0 = full
var is_exploding: bool = false
var is_defused: bool = false
var _time: float = 0.0

# Explosion animation
var _explosion_time: float = 0.0
const EXPLOSION_DURATION: float = 1.5

# Spark particles
var _sparks: Array[Dictionary] = []

# Screen shake
var _shake_intensity: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(200, 160)


func _process(delta: float) -> void:
	_time += delta

	# Decay screen shake
	if _shake_intensity > 0:
		_shake_intensity = max(0, _shake_intensity - delta * 15.0)
		_shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		_shake_offset = Vector2.ZERO

	# Update explosion
	if is_exploding:
		_explosion_time += delta

	# Update sparks
	_update_sparks(delta)

	queue_redraw()


func _draw() -> void:
	var center := size / 2.0 + _shake_offset

	if is_exploding:
		_draw_explosion(center)
		return

	if is_defused:
		_draw_defused_bomb(center)
		return

	_draw_bomb(center)
	_draw_fuse(center)
	_draw_sparks()
	_draw_stability_glow(center)


func _draw_bomb(center: Vector2) -> void:
	# Shadow
	draw_circle(center + Vector2(3, 3), BOMB_RADIUS, Color(0, 0, 0, 0.3))

	# Main bomb body — dark gradient effect using concentric circles
	draw_circle(center, BOMB_RADIUS, Color("#1a1a2e"))
	draw_circle(center, BOMB_RADIUS - 3, Color("#16213e"))
	draw_circle(center + Vector2(-8, -8), BOMB_RADIUS * 0.3, Color("#1a1a3e", 0.5))  # highlight

	# Bomb outline
	draw_arc(center, BOMB_RADIUS, 0, TAU, 64, Color("#333355"), 2.0)

	# Nozzle (fuse connector) — small trapezoid at top
	var nozzle_base := center + Vector2(0, -BOMB_RADIUS + 5)
	draw_circle(nozzle_base, 8, Color("#444466"))
	draw_circle(nozzle_base, 5, Color("#555577"))

	# Timer display on bomb face
	var time_sec := timer_ratio * 120.0
	var minutes := int(time_sec) / 60
	var seconds := int(time_sec) % 60
	var time_str := "%02d:%02d" % [minutes, seconds]
	var time_color := Color("#00e5ff")
	if timer_ratio < 0.25:
		time_color = Color("#ff1744")
	elif timer_ratio < 0.5:
		time_color = Color("#ff6f00")

	# Pulsing timer text
	var pulse := 1.0
	if timer_ratio < 0.15:
		pulse = 0.6 + 0.4 * abs(sin(_time * 8.0))
	time_color.a = pulse

	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-25, 8),
		time_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		18,
		time_color
	)


func _draw_fuse(center: Vector2) -> void:
	var fuse_start := center + Vector2(0, -BOMB_RADIUS + 2)
	var fuse_tip_full := fuse_start + Vector2(FUSE_ATTACH.x, -FUSE_LENGTH)
	var fuse_tip := fuse_start.lerp(fuse_tip_full, timer_ratio)

	# Fuse line (wavy)
	var segments := 12
	var prev := fuse_start
	for i in range(1, segments + 1):
		var t := float(i) / segments * timer_ratio
		var point := fuse_start.lerp(fuse_tip_full, t)
		# Add waviness
		var wave := sin(t * 10.0 + _time * 3.0) * 3.0
		point.x += wave
		var fuse_color := Color("#8b6914") if t > timer_ratio * 0.1 else Color("#ff4444")
		draw_line(prev, point, fuse_color, 2.5)
		prev = point

	# Spark/flame at fuse tip
	if timer_ratio > 0.01:
		var spark_pos := prev
		var flame_size := 6.0 + sin(_time * 12.0) * 3.0
		draw_circle(spark_pos, flame_size, Color("#ff6f00", 0.8))
		draw_circle(spark_pos, flame_size * 0.6, Color("#ffeb3b", 0.9))
		draw_circle(spark_pos, flame_size * 0.3, Color("#ffffff", 0.7))

		# Emit spark particles
		if randi() % 3 == 0:
			_sparks.append({
				"pos": spark_pos,
				"vel": Vector2(randf_range(-40, 40), randf_range(-60, -20)),
				"life": 0.5,
				"size": randf_range(1.5, 3.0),
			})


func _draw_stability_glow(center: Vector2) -> void:
	if stability_ratio >= 0.3:
		return
	# Red warning glow around bomb
	var glow_alpha := (1.0 - stability_ratio / 0.3) * 0.4
	glow_alpha *= 0.5 + 0.5 * abs(sin(_time * 5.0))
	draw_circle(center, BOMB_RADIUS + 15, Color(1, 0.1, 0.15, glow_alpha))
	draw_circle(center, BOMB_RADIUS + 10, Color(1, 0.2, 0.1, glow_alpha * 0.5))


func _draw_sparks() -> void:
	for spark in _sparks:
		var alpha: float = spark["life"] / 0.5
		var spark_color := Color("#ffeb3b", alpha)
		draw_circle(spark["pos"], spark["size"] * alpha, spark_color)


func _update_sparks(delta: float) -> void:
	var i := _sparks.size() - 1
	while i >= 0:
		_sparks[i]["pos"] += _sparks[i]["vel"] * delta
		_sparks[i]["vel"].y += 80.0 * delta  # gravity
		_sparks[i]["life"] -= delta
		if _sparks[i]["life"] <= 0:
			_sparks.remove_at(i)
		i -= 1


func _draw_explosion(center: Vector2) -> void:
	var t := _explosion_time / EXPLOSION_DURATION
	if t > 1.0:
		t = 1.0

	# Screen flash
	if t < 0.15:
		var flash_alpha := 1.0 - t / 0.15
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash_alpha))

	# Expanding fire rings
	var max_radius := size.length() * 0.6
	for ring in range(5):
		var ring_t := clampf(t - ring * 0.05, 0, 1)
		var radius := ring_t * max_radius * (1.0 - ring * 0.12)
		var alpha := (1.0 - ring_t) * 0.8

		var colors := [
			Color(1.0, 0.9, 0.2, alpha),       # yellow core
			Color(1.0, 0.5, 0.0, alpha),        # orange
			Color(1.0, 0.15, 0.0, alpha * 0.8), # red
			Color(0.3, 0.0, 0.0, alpha * 0.5),  # dark red
			Color(0.1, 0.1, 0.1, alpha * 0.3),  # smoke
		]
		draw_circle(center, radius, colors[ring])

	# Debris particles
	for i in range(12):
		var angle := i * TAU / 12.0 + _time
		var dist := t * max_radius * 0.8 * (0.7 + 0.3 * sin(i * 2.5))
		var debris_pos := center + Vector2(cos(angle), sin(angle)) * dist
		var debris_alpha := (1.0 - t) * 0.9
		var debris_size := (1.0 - t) * 6.0
		draw_circle(debris_pos, debris_size, Color(1, 0.6, 0, debris_alpha))

	# "BOOM" text
	if t > 0.1 and t < 0.8:
		var text_alpha := 1.0 if t < 0.5 else (0.8 - t) / 0.3
		var text_size := int(48 + t * 20)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-50, 10),
			"BOOM!",
			HORIZONTAL_ALIGNMENT_CENTER,
			120,
			text_size,
			Color(1, 0.2, 0, text_alpha)
		)


func _draw_defused_bomb(center: Vector2) -> void:
	# Greyed-out bomb
	draw_circle(center, BOMB_RADIUS, Color("#1a3a1a"))
	draw_arc(center, BOMB_RADIUS, 0, TAU, 64, Color("#00e676"), 3.0)

	# Checkmark
	var check_start := center + Vector2(-15, 5)
	var check_mid := center + Vector2(-3, 18)
	var check_end := center + Vector2(18, -12)
	draw_line(check_start, check_mid, Color("#00e676"), 4.0)
	draw_line(check_mid, check_end, Color("#00e676"), 4.0)

	# "DEFUSED" text
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-35, -15),
		"DEFUSED",
		HORIZONTAL_ALIGNMENT_CENTER,
		80,
		16,
		Color("#00e676")
	)


# --- Public methods ---


func trigger_shake(intensity: float = 5.0) -> void:
	"""Trigger screen shake (call on wrong action)."""
	_shake_intensity = intensity


func trigger_explosion() -> void:
	"""Start explosion animation."""
	is_exploding = true
	_explosion_time = 0.0
	_shake_intensity = 12.0


func trigger_defused() -> void:
	"""Show defused state."""
	is_defused = true
