class_name DayNight
extends Node
## Moves the sun and shifts sky, fog, and light through a 24-hour cycle.

const GROUP := "day_night"
const DAY_LENGTH_SECONDS := 600.0
const FAST_FORWARD := 30.0
const SUNRISE := 6.0
const SUNSET := 20.0
## How far the sun leans to the south at midday. North is -Z and east is +X.
const SOUTH_TILT := deg_to_rad(40.0)

const DAY_TOP := Color(0.34, 0.45, 0.58)
const DAY_HORIZON := Color(0.72, 0.76, 0.8)
const DUSK_TOP := Color(0.25, 0.25, 0.42)
const DUSK_HORIZON := Color(0.85, 0.5, 0.35)
const NIGHT_TOP := Color(0.05, 0.07, 0.15)
const NIGHT_HORIZON := Color(0.11, 0.15, 0.24)
const DAY_SUN := Color(1.0, 0.95, 0.85)
const DUSK_SUN := Color(1.0, 0.6, 0.35)
const MOON_LIGHT := Color(0.6, 0.7, 1.0)
const MOON_ENERGY := 0.35

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var mist: Mist
@export var sky_dome: SkyDome
@export_range(0.0, 24.0) var hour := 9.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	var speed := FAST_FORWARD if Input.is_action_pressed("fast_forward_time") else 1.0
	hour = fmod(hour + delta * speed * 24.0 / DAY_LENGTH_SECONDS, 24.0)
	_apply()


## 0 at night, 1 in full daylight.
func daylight() -> float:
	var day_progress := (hour - SUNRISE) / (SUNSET - SUNRISE)
	return smoothstep(0.0, 0.12, sin(day_progress * PI)) if day_progress > 0.0 and day_progress < 1.0 else 0.0


## Returns where the sun or moon is at this share of its path, from the east over the south to the west.
func sky_direction(progress: float) -> Vector3:
	var arc := sin(progress * PI)
	return Vector3(cos(progress * PI), arc * cos(SOUTH_TILT), arc * sin(SOUTH_TILT))


func _aim_light(progress: float) -> void:
	sun.basis = Basis.looking_at(-sky_direction(progress))


func _apply() -> void:
	var day_progress := (hour - SUNRISE) / (SUNSET - SUNRISE)
	var light := daylight()
	var dusk := light * (1.0 - smoothstep(0.1, 0.45, sin(clampf(day_progress, 0.0, 1.0) * PI)))

	# The same light plays the sun by day and the moon by night, fading out as they swap.
	if light > 0.0:
		_aim_light(clampf(day_progress, 0.0, 1.0))
		sun.light_energy = light * 1.2
		sun.light_color = DAY_SUN.lerp(DUSK_SUN, dusk)
	else:
		var night_progress := fposmod(hour - SUNSET, 24.0) / (24.0 - SUNSET + SUNRISE)
		_aim_light(night_progress)
		sun.light_energy = sin(night_progress * PI) * MOON_ENERGY
		sun.light_color = MOON_LIGHT

	if sky_dome:
		var moon_progress := fposmod(hour - SUNSET, 24.0) / (24.0 - SUNSET + SUNRISE)
		sky_dome.set_time(hour, light, dusk, sky_direction(moon_progress), moon_progress < 1.0)
	var environment := world_environment.environment
	var sky: ProceduralSkyMaterial = environment.sky.sky_material
	var top := NIGHT_TOP.lerp(DAY_TOP, light).lerp(DUSK_TOP, dusk)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, light).lerp(DUSK_HORIZON, dusk)
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon
	sky.ground_bottom_color = horizon.darkened(0.4)
	environment.fog_light_color = horizon
	mist.set_color(horizon.lerp(top, 0.2).lightened(0.15))
	environment.ambient_light_energy = lerpf(0.6, 1.0, light)
