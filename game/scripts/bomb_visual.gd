class_name BombVisual
extends Control
## Advanced bomb visualization with metallic shading, glowing core,
## wire veins, LED indicators, animated fuse with smoke, and dramatic explosion.

# Bomb geometry
const BOMB_RADIUS: float = 50.0
const FUSE_LENGTH: float = 55.0

# State
var timer_ratio: float = 1.0
var stability_ratio: float = 1.0
var is_exploding: bool = false
var is_defused: bool = false
var _time: float = 0.0

# Explosion
var _explosion_time: float = 0.0
const EXPLOSION_DURATION: float = 2.0

# Particles
var _sparks: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _explosion_debris: Array[Dictionary] = []

# Shake
var _shake_intensity: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

# LED blink state
var _led_states: Array[bool] = [true, false, true, true, false, true]


func _ready() -> void:
	custom_minimum_size = Vector2(200, 180)


func _process(delta: float) -> void:
	_time += delta

	# Shake decay
	if _shake_intensity > 0:
		_shake_intensity = max(0, _shake_intensity - delta * 12.0)
		_shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		_shake_offset = Vector2.ZERO

	# LED blink
	if fmod(_time, 0.4) < delta:
		for i in range(_led_states.size()):
			if randf() < 0.3:
				_led_states[i] = not _led_states[i]

	# Explosion
	if is_exploding:
		_explosion_time += delta
		_update_explosion_debris(delta)

	# Particles
	_update_sparks(delta)
	_update_smoke(delta)

	queue_redraw()


func _draw() -> void:
	var center := size / 2.0 + _shake_offset + Vector2(0, 10)

	if is_exploding:
		_draw_explosion(center)
		return
	if is_defused:
		_draw_defused(center)
		return

	_draw_ambient_glow(center)
	_draw_bomb_body(center)
	_draw_wire_veins(center)
	_draw_core_glow(center)
	_draw_nozzle(center)
	_draw_fuse(center)
	_draw_leds(center)
	_draw_timer_display(center)
	_draw_stability_ring(center)
	_draw_smoke_particles()
	_draw_spark_particles()


# --- BOMB BODY ---


func _draw_ambient_glow(center: Vector2) -> void:
	# Outer ambient glow
	var glow_color := Color(0, 0.5, 0.8, 0.05)
	if stability_ratio < 0.3:
		glow_color = Color(1, 0.1, 0, 0.08 + 0.06 * abs(sin(_time * 5.0)))
	for i in range(5):
		var r: float = BOMB_RADIUS + 25 - i * 4
		draw_circle(center, r, glow_color)


func _draw_bomb_body(center: Vector2) -> void:
	# Shadow
	draw_circle(center + Vector2(4, 5), BOMB_RADIUS + 2, Color(0, 0, 0, 0.5))

	# Main body - dark metallic gradient (concentric circles simulating sphere)
	var layers := 16
	for i in range(layers):
		var t := float(i) / layers
		var r := BOMB_RADIUS * (1.0 - t * 0.02)
		# Metallic gradient: dark edges, slightly lighter center-left
		var brightness := 0.06 + t * 0.04
		var col := Color(brightness * 0.5, brightness * 0.55, brightness * 0.8, 1.0)
		var offset := Vector2(-t * 3, -t * 3)  # light source offset
		draw_circle(center + offset, r - i * 0.5, col)

	# Specular highlight (top-left)
	var highlight_pos := center + Vector2(-18, -20)
	for i in range(6):
		var highlight_r := 12.0 - i * 1.5
		var highlight_alpha := 0.15 - i * 0.02
		draw_circle(highlight_pos + Vector2(i * 0.5, i * 0.5), highlight_r, Color(0.6, 0.7, 1.0, highlight_alpha))

	# Outline
	draw_arc(center, BOMB_RADIUS, 0, TAU, 64, Color(0.2, 0.25, 0.4, 0.8), 1.5)

	# Rivet details around the equator
	var num_rivets := 12
	for i in range(num_rivets):
		var angle := float(i) / num_rivets * TAU
		var rivet_pos := center + Vector2(cos(angle), sin(angle)) * (BOMB_RADIUS - 4)
		draw_circle(rivet_pos, 2.5, Color(0.15, 0.15, 0.25))
		draw_circle(rivet_pos + Vector2(-0.5, -0.5), 1.2, Color(0.25, 0.25, 0.4))

	# Band/seam around equator
	draw_arc(center, BOMB_RADIUS - 4, -0.1, PI + 0.1, 32, Color(0.12, 0.12, 0.2, 0.6), 2.0)


func _draw_wire_veins(center: Vector2) -> void:
	# Glowing circuit-like veins on the bomb surface
	var vein_color := Color(0, 0.7, 1.0, 0.2 + 0.1 * sin(_time * 3.0))
	if stability_ratio < 0.3:
		vein_color = Color(1, 0.2, 0, 0.3 + 0.15 * sin(_time * 6.0))

	# Draw several curved veins
	var veins := [
		{"start_angle": -0.5, "end_angle": 0.8, "radius_offset": -8},
		{"start_angle": 1.5, "end_angle": 2.8, "radius_offset": -6},
		{"start_angle": 3.0, "end_angle": 4.5, "radius_offset": -10},
		{"start_angle": 4.8, "end_angle": 5.8, "radius_offset": -5},
	]
	for vein in veins:
		var r: float = BOMB_RADIUS + vein["radius_offset"]
		# Pulsing glow along the vein
		var pulse_offset := _time * 2.0
		var segments := 16
		for j in range(segments):
			var t1 := float(j) / segments
			var t2 := float(j + 1) / segments
			var a1: float = lerp(vein["start_angle"], vein["end_angle"], t1)
			var a2: float = lerp(vein["start_angle"], vein["end_angle"], t2)
			var p1 := center + Vector2(cos(a1), sin(a1)) * r
			var p2 := center + Vector2(cos(a2), sin(a2)) * r
			var pulse := sin(t1 * 5.0 + pulse_offset) * 0.5 + 0.5
			var seg_color := vein_color
			seg_color.a *= (0.4 + 0.6 * pulse)
			draw_line(p1, p2, seg_color, 1.5)


func _draw_core_glow(center: Vector2) -> void:
	# Inner core glow - pulsing
	var pulse := 0.5 + 0.5 * sin(_time * 2.5)
	var core_color := Color(0, 0.6, 1.0, 0.08 * pulse)
	if stability_ratio < 0.3:
		core_color = Color(1, 0.1, 0, 0.12 * (0.5 + 0.5 * sin(_time * 6.0)))
	for i in range(4):
		draw_circle(center, BOMB_RADIUS * (0.4 - i * 0.08), core_color)


func _draw_nozzle(center: Vector2) -> void:
	# Fuse attachment nozzle at top
	var nozzle_base := center + Vector2(0, -BOMB_RADIUS + 3)

	# Cylindrical nozzle
	var nozzle_rect := Rect2(nozzle_base + Vector2(-7, -12), Vector2(14, 14))
	draw_rect(nozzle_rect, Color(0.15, 0.15, 0.25))
	# Highlight
	draw_rect(Rect2(nozzle_base + Vector2(-7, -12), Vector2(3, 14)), Color(0.2, 0.2, 0.35))
	# Top cap
	draw_rect(Rect2(nozzle_base + Vector2(-9, -14), Vector2(18, 3)), Color(0.18, 0.18, 0.3))


func _draw_fuse(center: Vector2) -> void:
	var fuse_start := center + Vector2(0, -BOMB_RADIUS - 8)
	var fuse_end_full := fuse_start + Vector2(30, -FUSE_LENGTH)
	var fuse_end := fuse_start.lerp(fuse_end_full, timer_ratio)

	if timer_ratio <= 0.01:
		return

	# Draw fuse as a thick rope with texture
	var segments := 20
	var prev := fuse_start
	for i in range(1, segments + 1):
		var t := float(i) / segments * timer_ratio
		var point := fuse_start.lerp(fuse_end_full, t)
		# Wavy fuse
		point.x += sin(t * 8.0 + _time * 1.5) * 4.0
		point.y += cos(t * 6.0) * 2.0

		# Burnt near the tip, normal further away
		var burn_t := 1.0 - (t / timer_ratio)  # 0 at start, 1 at tip
		var fuse_color: Color
		if burn_t > 0.8:
			fuse_color = Color(0.3, 0.15, 0.05)  # burnt
		else:
			fuse_color = Color(0.55, 0.4, 0.15).lerp(Color(0.4, 0.3, 0.1), t)

		draw_line(prev, point, fuse_color, 3.5)
		# Rope texture lines
		if i % 3 == 0:
			draw_line(prev, point, Color(fuse_color, 0.5), 1.0)
		prev = point

	# Flame at fuse tip
	var tip := prev
	_draw_flame(tip)

	# Emit sparks
	if randi() % 2 == 0:
		_sparks.append({
			"pos": tip,
			"vel": Vector2(randf_range(-50, 50), randf_range(-80, -30)),
			"life": randf_range(0.3, 0.7),
			"size": randf_range(1.5, 3.5),
			"color_t": randf(),
		})

	# Emit smoke
	if randi() % 4 == 0:
		_smoke.append({
			"pos": tip + Vector2(randf_range(-5, 5), -5),
			"vel": Vector2(randf_range(-10, 10), randf_range(-40, -20)),
			"life": randf_range(0.8, 2.0),
			"max_life": randf_range(0.8, 2.0),
			"size": randf_range(3, 6),
		})


func _draw_flame(pos: Vector2) -> void:
	# Multi-layered animated flame
	var flame_height := 12.0 + sin(_time * 15.0) * 4.0
	var flame_width := 8.0 + sin(_time * 12.0) * 2.0

	# Outer glow
	draw_circle(pos + Vector2(0, -3), flame_height * 1.2, Color(1, 0.3, 0, 0.15))

	# Flame layers (bottom to top: red → orange → yellow → white)
	var flame_layers := [
		{"offset": Vector2(0, 0), "size": Vector2(flame_width, flame_height * 0.4), "color": Color(1, 0.15, 0, 0.9)},
		{"offset": Vector2(0, -3), "size": Vector2(flame_width * 0.8, flame_height * 0.6), "color": Color(1, 0.5, 0, 0.85)},
		{"offset": Vector2(0, -5), "size": Vector2(flame_width * 0.5, flame_height * 0.8), "color": Color(1, 0.85, 0.2, 0.8)},
		{"offset": Vector2(0, -7), "size": Vector2(flame_width * 0.3, flame_height * 0.3), "color": Color(1, 1, 0.8, 0.7)},
	]
	for layer in flame_layers:
		var p: Vector2 = pos + layer["offset"]
		p.x += sin(_time * 20.0 + layer["offset"].y) * 2.0
		draw_circle(p, layer["size"].x, layer["color"])


func _draw_leds(center: Vector2) -> void:
	# Small LED indicator lights around the bomb
	var led_positions: Array[Vector2] = [
		Vector2(-25, 15), Vector2(25, 15), Vector2(-30, -5),
		Vector2(30, -5), Vector2(-15, 25), Vector2(15, 25),
	]
	for i in range(led_positions.size()):
		var led_pos: Vector2 = center + led_positions[i]
		var is_on: bool = _led_states[i]
		if is_on:
			var led_color := Color(0, 1, 0, 0.9) if stability_ratio > 0.3 else Color(1, 0, 0, 0.9)
			# Glow
			draw_circle(led_pos, 4, Color(led_color, 0.2))
			draw_circle(led_pos, 2.5, led_color)
			draw_circle(led_pos, 1.2, Color(1, 1, 1, 0.5))
		else:
			draw_circle(led_pos, 2.5, Color(0.1, 0.1, 0.15))


func _draw_timer_display(center: Vector2) -> void:
	# Digital readout on bomb face
	var time_sec := timer_ratio * 120.0
	var minutes := int(time_sec) / 60
	var seconds := int(time_sec) % 60
	var time_str := "%02d:%02d" % [minutes, seconds]

	# Display background
	var display_rect := Rect2(center + Vector2(-28, -10), Vector2(56, 22))
	draw_rect(display_rect, Color(0, 0, 0, 0.7))
	draw_rect(display_rect, Color(0, 0.3, 0.5, 0.3), false, 1.0)

	# Timer text
	var time_color := Color("#00e5ff")
	if timer_ratio < 0.15:
		time_color = Color(1, 0.1, 0, 0.6 + 0.4 * abs(sin(_time * 10.0)))
	elif timer_ratio < 0.4:
		time_color = Color(1, 0.5, 0, 0.7 + 0.3 * abs(sin(_time * 4.0)))

	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-24, 7),
		time_str,
		HORIZONTAL_ALIGNMENT_CENTER,
		52,
		16,
		time_color
	)


func _draw_stability_ring(center: Vector2) -> void:
	# Arc around bomb showing stability level
	var arc_radius := BOMB_RADIUS + 8
	var stability_angle := stability_ratio * TAU

	# Background arc (dark)
	draw_arc(center, arc_radius, -PI / 2, -PI / 2 + TAU, 64, Color(0.1, 0.1, 0.15, 0.4), 3.0)

	# Stability arc
	var arc_color := Color(0, 0.9, 0.4)
	if stability_ratio < 0.3:
		arc_color = Color(1, 0.1, 0, 0.7 + 0.3 * abs(sin(_time * 6.0)))
	elif stability_ratio < 0.6:
		arc_color = Color(1, 0.5, 0)

	if stability_angle > 0.01:
		draw_arc(center, arc_radius, -PI / 2, -PI / 2 + stability_angle, 64, arc_color, 3.0)


# --- PARTICLES ---


func _draw_spark_particles() -> void:
	for spark in _sparks:
		var alpha: float = float(spark["life"]) / 0.7
		var col: Color = Color(1, 0.8, 0, alpha).lerp(Color(1, 0.3, 0, alpha), float(spark["color_t"]))
		draw_circle(spark["pos"], float(spark["size"]) * alpha, col)
		# Trail
		var spark_vel: Vector2 = spark["vel"]
		var trail_end: Vector2 = Vector2(spark["pos"]) - spark_vel.normalized() * 4.0 * alpha
		draw_line(spark["pos"], trail_end, Color(col, alpha * 0.5), 1.0)


func _draw_smoke_particles() -> void:
	for smoke in _smoke:
		var life_ratio: float = float(smoke["life"]) / float(smoke["max_life"])
		var alpha: float = life_ratio * 0.3
		var s: float = float(smoke["size"]) * (1.0 + (1.0 - life_ratio) * 3.0)
		draw_circle(smoke["pos"], s, Color(0.4, 0.4, 0.45, alpha))


func _update_sparks(delta: float) -> void:
	var i := _sparks.size() - 1
	while i >= 0:
		_sparks[i]["pos"] += _sparks[i]["vel"] * delta
		_sparks[i]["vel"].y += 120.0 * delta
		_sparks[i]["life"] -= delta
		if _sparks[i]["life"] <= 0:
			_sparks.remove_at(i)
		i -= 1


func _update_smoke(delta: float) -> void:
	var i := _smoke.size() - 1
	while i >= 0:
		_smoke[i]["pos"] += _smoke[i]["vel"] * delta
		_smoke[i]["vel"].x += sin(_time + i) * 5.0 * delta
		_smoke[i]["life"] -= delta
		if _smoke[i]["life"] <= 0:
			_smoke.remove_at(i)
		i -= 1


# --- EXPLOSION ---


func _draw_explosion(center: Vector2) -> void:
	var t := _explosion_time / EXPLOSION_DURATION
	if t > 1.0:
		t = 1.0

	var max_radius := size.length() * 0.7

	# Phase 1: Initial flash (0 - 0.1)
	if t < 0.15:
		var flash_t := t / 0.15
		var flash_alpha := 1.0 - flash_t
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.9, flash_alpha * 0.9))
		draw_circle(center, BOMB_RADIUS * (1.0 + flash_t * 3.0), Color(1, 0.8, 0.2, flash_alpha))

	# Phase 2: Fireball expansion (0.05 - 0.6)
	if t > 0.05:
		var fire_t := clampf((t - 0.05) / 0.55, 0, 1)
		# Multiple fire layers
		var fire_layers := [
			{"scale": 1.0, "color": Color(1, 0.9, 0.3)},  # yellow core
			{"scale": 0.85, "color": Color(1, 0.6, 0.1)},  # orange
			{"scale": 0.7, "color": Color(1, 0.25, 0.0)},  # red-orange
			{"scale": 0.55, "color": Color(0.8, 0.1, 0.0)}, # red
			{"scale": 0.4, "color": Color(0.3, 0.05, 0.0)}, # dark red
		]
		for layer in fire_layers:
			var radius: float = fire_t * max_radius * float(layer["scale"])
			var alpha: float = (1.0 - fire_t) * 0.7
			var col: Color = Color(layer["color"])
			col.a = alpha
			draw_circle(center + _shake_offset * 2, radius, col)

	# Phase 3: Shockwave ring (0.1 - 0.5)
	if t > 0.1 and t < 0.6:
		var ring_t := (t - 0.1) / 0.5
		var ring_radius := ring_t * max_radius * 1.2
		var ring_alpha := (1.0 - ring_t) * 0.6
		var ring_width := 4.0 + ring_t * 8.0
		draw_arc(center, ring_radius, 0, TAU, 64, Color(1, 0.8, 0.4, ring_alpha), ring_width)
		# Inner bright ring
		draw_arc(center, ring_radius - 3, 0, TAU, 64, Color(1, 1, 0.9, ring_alpha * 0.5), 2.0)

	# Debris particles
	for debris in _explosion_debris:
		var d_alpha: float = float(debris["life"]) / float(debris["max_life"])
		var debris_color: Color = Color(1, 0.5, 0.1, d_alpha).lerp(Color(0.3, 0.3, 0.3, d_alpha * 0.5), 1.0 - d_alpha)
		draw_circle(debris["pos"], float(debris["size"]) * d_alpha, debris_color)
		# Ember trail
		var d_vel: Vector2 = debris["vel"]
		var trail: Vector2 = Vector2(debris["pos"]) - d_vel.normalized() * 6.0 * d_alpha
		draw_line(debris["pos"], trail, Color(1, 0.4, 0, d_alpha * 0.3), 1.5)

	# Smoke cloud (late phase)
	if t > 0.3:
		var smoke_t := (t - 0.3) / 0.7
		var smoke_alpha := smoke_t * 0.4 * (1.0 - smoke_t)
		for i in range(6):
			var angle := i * TAU / 6.0 + _time * 0.3
			var dist := smoke_t * max_radius * 0.5 * (0.6 + 0.4 * sin(i * 1.7))
			var smoke_pos := center + Vector2(cos(angle), sin(angle)) * dist
			var smoke_size := 20 + smoke_t * 30
			draw_circle(smoke_pos, smoke_size, Color(0.2, 0.2, 0.2, smoke_alpha))

	# "BOOM" text with glow
	if t > 0.08 and t < 0.7:
		var text_alpha := 1.0 if t < 0.4 else (0.7 - t) / 0.3
		var text_size := int(40 + t * 30)
		# Glow behind text
		draw_string(ThemeDB.fallback_font, center + Vector2(-55, 12), "BOOM!", HORIZONTAL_ALIGNMENT_CENTER, 120, text_size + 4, Color(1, 0.3, 0, text_alpha * 0.4))
		draw_string(ThemeDB.fallback_font, center + Vector2(-53, 10), "BOOM!", HORIZONTAL_ALIGNMENT_CENTER, 120, text_size, Color(1, 0.8, 0.2, text_alpha))


func _update_explosion_debris(delta: float) -> void:
	# Spawn debris at start
	if _explosion_time < 0.2 and randi() % 2 == 0:
		var center := size / 2.0
		var angle := randf() * TAU
		var speed := randf_range(100, 400)
		_explosion_debris.append({
			"pos": center + Vector2(cos(angle), sin(angle)) * 10,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.8, 1.8),
			"max_life": randf_range(0.8, 1.8),
			"size": randf_range(2, 6),
		})

	var i := _explosion_debris.size() - 1
	while i >= 0:
		_explosion_debris[i]["pos"] += _explosion_debris[i]["vel"] * delta
		_explosion_debris[i]["vel"].y += 60.0 * delta  # gravity
		_explosion_debris[i]["vel"] *= 0.98  # drag
		_explosion_debris[i]["life"] -= delta
		if _explosion_debris[i]["life"] <= 0:
			_explosion_debris.remove_at(i)
		i -= 1


# --- DEFUSED ---


func _draw_defused(center: Vector2) -> void:
	# Peaceful green-tinted bomb
	draw_circle(center + Vector2(3, 4), BOMB_RADIUS, Color(0, 0, 0, 0.3))
	# Body with green tint
	for i in range(12):
		var t := float(i) / 12
		var r := BOMB_RADIUS - i * 0.3
		var brightness := 0.08 + t * 0.03
		draw_circle(center + Vector2(-t * 2, -t * 2), r, Color(brightness * 0.3, brightness * 1.2, brightness * 0.5))

	# Green glow
	for i in range(4):
		draw_circle(center, BOMB_RADIUS + 12 - i * 3, Color(0, 0.9, 0.4, 0.04))

	# Outline
	draw_arc(center, BOMB_RADIUS, 0, TAU, 64, Color(0, 0.9, 0.4, 0.6), 2.5)

	# Checkmark
	var check_start := center + Vector2(-20, 5)
	var check_mid := center + Vector2(-5, 22)
	var check_end := center + Vector2(22, -15)
	# Glow
	draw_line(check_start, check_mid, Color(0, 1, 0.4, 0.3), 8.0)
	draw_line(check_mid, check_end, Color(0, 1, 0.4, 0.3), 8.0)
	# Main line
	draw_line(check_start, check_mid, Color(0, 1, 0.5, 0.9), 4.0)
	draw_line(check_mid, check_end, Color(0, 1, 0.5, 0.9), 4.0)

	# "DEFUSED" text
	draw_string(ThemeDB.fallback_font, center + Vector2(-35, -20), "DEFUSED", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(0, 1, 0.5, 0.8 + 0.2 * sin(_time * 2.0)))

	# Full stability ring (green)
	draw_arc(center, BOMB_RADIUS + 8, 0, TAU, 64, Color(0, 0.9, 0.4, 0.5), 3.0)


# --- PUBLIC API ---


func trigger_shake(intensity: float = 6.0) -> void:
	_shake_intensity = intensity


func trigger_explosion() -> void:
	is_exploding = true
	_explosion_time = 0.0
	_shake_intensity = 15.0


func trigger_defused() -> void:
	is_defused = true
