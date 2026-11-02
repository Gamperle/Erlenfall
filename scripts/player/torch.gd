class_name Torch
extends Node3D
## A burning torch with a flickering light.

const LIGHT_ENERGY := 1.8
const LIGHT_RANGE := 12.0
const FLICKER_AMOUNT := 0.2
const FLICKER_SPEED := 9.0
## How much of its light a torch shows in full daylight, when it would only tint what it's near.
const DAYLIGHT_LIGHT_SHARE := 0.15
const FLAME_WOBBLE := 0.18
const SMOKE_COLOR := Color(0.25, 0.24, 0.23, 0.35)

## Stays vertical however the hand holding it moves.
var keep_upright := false

var _light: OmniLight3D
var _time := 0.0
var _flame: Node3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D


func _ready() -> void:
	var model := ModelBuilder.torch()
	add_child(model)
	_flame = model.get_node("Flame")
	_sparks = _build_particles(4, 0.9, 0.012, ModelBuilder.FIRE_COLOR, 0.5, 1.2)
	_smoke = _build_particles(6, 1.6, 0.05, SMOKE_COLOR, 0.3, 0.7)
	_light = OmniLight3D.new()
	_light.light_color = ModelBuilder.FIRE_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.position = Vector3.UP * ModelBuilder.TORCH_FLAME_HEIGHT
	add_child(_light)
	set_lit(false)


func set_lit(lit: bool) -> void:
	visible = lit
	set_process(lit)
	_sparks.emitting = lit
	_smoke.emitting = lit


func _process(delta: float) -> void:
	if keep_upright:
		global_basis = Basis.IDENTITY.scaled(global_basis.get_scale())
	_time += delta * FLICKER_SPEED
	var flicker := sin(_time) * 0.6 + sin(_time * 2.3) * 0.4
	_light.light_energy = LIGHT_ENERGY * (1.0 + flicker * FLICKER_AMOUNT) * light_share()
	var wobble := sin(_time * 1.7) * 0.5 + sin(_time * 3.1) * 0.5
	_flame.scale = Vector3(1.0 - wobble * FLAME_WOBBLE * 0.5, 1.0 + wobble * FLAME_WOBBLE, 1.0 - wobble * FLAME_WOBBLE * 0.5)
	_flame.rotation.z = sin(_time * 0.8) * FLAME_WOBBLE


## How much of the light shows at this time of day. Full at night, and little at noon.
func light_share() -> float:
	var day_night := get_tree().get_first_node_in_group(DayNight.GROUP) as DayNight
	return 1.0 if day_night == null else lerpf(1.0, DAYLIGHT_LIGHT_SHARE, day_night.daylight())


func _build_particles(amount: int, lifetime: float, size: float, color: Color, speed_min: float, speed_max: float) -> CPUParticles3D:
	# Small spheres stay round from every side, without needing a texture.
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.amount = amount
	particles.lifetime = lifetime
	particles.position = Vector3.UP * (ModelBuilder.TORCH_FLAME_HEIGHT + 0.08)
	particles.direction = Vector3.UP
	particles.spread = 18.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.emitting = false
	add_child(particles)
	return particles
