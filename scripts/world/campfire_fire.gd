class_name CampfireFire
extends Node3D
## The flame and light of a campfire. The light shows mostly at night and in the dark of a storm, and rain weakens the flame.

const LIGHT_ENERGY := 2.2
const LIGHT_RANGE := 9.0
const FLICKER_AMOUNT := 0.2
const FLICKER_SPEED := 8.0
## How much of its light a campfire shows in full daylight.
const DAYLIGHT_LIGHT_SHARE := 0.2
## How much of the flame is left in the heaviest rain.
const RAIN_FLAME_SHARE := 0.6
const FLAME_WOBBLE := 0.2

var _light: OmniLight3D
var _flame: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	_flame = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.55
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = ModelBuilder.FIRE_COLOR
	material.emission_enabled = true
	material.emission = ModelBuilder.FIRE_COLOR
	material.emission_energy_multiplier = 2.5
	mesh.material = material
	_flame.mesh = mesh
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = Vector3.UP * 0.4
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = ModelBuilder.FIRE_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.position = Vector3.UP * 0.7
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta * FLICKER_SPEED
	var flicker := sin(_time) * 0.6 + sin(_time * 2.3) * 0.4
	var rain := _rain()
	var strength := lerpf(1.0, RAIN_FLAME_SHARE, rain)
	_light.light_energy = LIGHT_ENERGY * (1.0 + flicker * FLICKER_AMOUNT) * light_share() * strength
	var wobble := sin(_time * 1.7) * 0.5 + sin(_time * 3.1) * 0.5
	_flame.scale = Vector3(1.0 - wobble * FLAME_WOBBLE * 0.5, 1.0 + wobble * FLAME_WOBBLE, 1.0 - wobble * FLAME_WOBBLE * 0.5) * strength


## How much of the light shows at this time of day. Full at night.
func light_share() -> float:
	var day_night := get_tree().get_first_node_in_group(DayNight.GROUP) as DayNight
	return 1.0 if day_night == null else lerpf(1.0, DAYLIGHT_LIGHT_SHARE, day_night.daylight())


func _rain() -> float:
	var weather := get_tree().get_first_node_in_group(Weather.GROUP) as Weather
	return 0.0 if weather == null else clampf(weather.rain, 0.0, 1.0)
