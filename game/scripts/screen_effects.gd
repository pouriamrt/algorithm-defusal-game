class_name ScreenEffects
extends CanvasLayer
## Full-screen post-processing effects: vignette, scanlines, chromatic aberration,
## screen flash, and damage distortion. Applied as a CanvasLayer overlay.

var _overlay: ColorRect
var _shader_material: ShaderMaterial

# Damage effect
var _damage_intensity: float = 0.0
var _flash_intensity: float = 0.0
var _time: float = 0.0

const SHADER_CODE := """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float time;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float aberration : hint_range(0.0, 0.02) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.0, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration on damage
	float r = texture(screen_texture, uv + vec2(aberration, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(aberration, 0.0)).b;
	vec4 color = vec4(r, g, b, 1.0);

	// Scanlines
	float scanline = sin(uv.y * 800.0 + time * 2.0) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_strength);
	color.rgb *= scanline;

	// Vignette
	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.7, 0.3, dist);
	vignette = mix(vignette, 1.0, 1.0 - vignette_strength);
	color.rgb *= vignette;

	// Screen flash
	color.rgb = mix(color.rgb, flash_color.rgb, flash);

	// Slight noise grain
	float noise = fract(sin(dot(uv * time, vec2(12.9898, 78.233))) * 43758.5453);
	color.rgb += (noise - 0.5) * 0.015;

	COLOR = color;
}
"""


func _ready() -> void:
	layer = 10  # Render on top of everything

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Must have a color for the shader to run, but it's fully replaced by the shader
	_overlay.color = Color(0, 0, 0, 1)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_overlay.material = _shader_material

	add_child(_overlay)


func _process(delta: float) -> void:
	_time += delta

	# Decay effects
	_damage_intensity = max(0.0, _damage_intensity - delta * 3.0)
	_flash_intensity = max(0.0, _flash_intensity - delta * 4.0)

	# Update shader uniforms
	_shader_material.set_shader_parameter("time", _time)
	_shader_material.set_shader_parameter("aberration", _damage_intensity * 0.008)
	_shader_material.set_shader_parameter("flash", _flash_intensity)


func trigger_damage() -> void:
	"""Flash red + chromatic aberration on wrong action."""
	_damage_intensity = 1.0
	_flash_intensity = 0.3


func trigger_explosion_flash() -> void:
	"""Bright white flash for explosion."""
	_flash_intensity = 1.0
	_shader_material.set_shader_parameter("flash_color", Color(1.0, 0.9, 0.7, 1.0))


func trigger_defuse_flash() -> void:
	"""Green flash for successful defuse."""
	_flash_intensity = 0.5
	_shader_material.set_shader_parameter("flash_color", Color(0.0, 0.9, 0.4, 1.0))
