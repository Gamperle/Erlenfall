class_name SkyDome
extends MeshInstance3D
## Stars, a moon disc, and drifting clouds on a big dome that follows the camera, drawn over the sky gradient.

const RADIUS := 2500.0
## Which way the clouds drift, as a flat direction, and how fast in cloud-space units per second.
const WIND := Vector2(0.6, 0.25)
const WIND_SPEED := 0.004
## The stars turn around the pole that sits north, a little above the horizon.
const POLE := Vector3(0.0, 0.6, -0.8)
const CLOUD_OCTAVES := { "low": 2, "medium": 3, "high": 4 }

const CLOUD_DAY := Color(1.0, 1.0, 1.0)
const CLOUD_DAY_SHADE := Color(0.62, 0.67, 0.74)
const CLOUD_DUSK := Color(1.0, 0.62, 0.45)
const CLOUD_DUSK_SHADE := Color(0.45, 0.35, 0.45)
const CLOUD_NIGHT := Color(0.16, 0.2, 0.32)
const CLOUD_NIGHT_SHADE := Color(0.05, 0.07, 0.14)

var _material := ShaderMaterial.new()
var _wind_time := 0.0


func _init() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh = sphere
	_material.shader = load("res://shaders/sky_dome.gdshader")
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE * -RADIUS, Vector3.ONE * RADIUS * 2.0)
	set_quality(Settings.graphics)


func _process(delta: float) -> void:
	_wind_time += delta
	_material.set_shader_parameter("cloud_offset", WIND.normalized() * WIND_SPEED * _wind_time)
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
	global_basis = Basis.IDENTITY


func set_quality(level: String) -> void:
	_material.set_shader_parameter("cloud_octaves", CLOUD_OCTAVES.get(level, 3))


## light is 0 at night and 1 by day, dusk is how much of the light is sunset glow, and moon_direction points at the moon.
func set_time(hour: float, light: float, dusk: float, moon_direction: Vector3, moon_up: bool) -> void:
	var night := 1.0 - light
	_material.set_shader_parameter("star_visibility", clampf(night * 1.4 - 0.3, 0.0, 1.0))
	_material.set_shader_parameter("star_rotation", Basis(POLE.normalized(), hour / 24.0 * TAU))
	_material.set_shader_parameter("moon_direction", moon_direction)
	_material.set_shader_parameter("moon_visibility", clampf(night * 1.2, 0.0, 1.0) if moon_up else 0.0)
	_material.set_shader_parameter("cloud_light_color", CLOUD_NIGHT.lerp(CLOUD_DAY, light).lerp(CLOUD_DUSK, dusk))
	_material.set_shader_parameter("cloud_shade_color", CLOUD_NIGHT_SHADE.lerp(CLOUD_DAY_SHADE, light).lerp(CLOUD_DUSK_SHADE, dusk))
