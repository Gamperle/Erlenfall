class_name Weather
extends Node
## Simple weather: clear, overcast, and rain, changing at random and blending smoothly. It holds three
## values that other systems read: how overcast the sky is, how hard it rains, and how windy it is.
## DayNight dims the light and greys the sky with them, SkyDome thickens and speeds up the clouds,
## GrassField sways, and one GPUParticles3D that follows the camera draws the rain. The rain shader reads a coarse roof map
## (RoofMap), so drops stop at house roofs and bridge decks seen from outside too.

const GROUP := "weather"
const STATES := {
	"clear": { "overcast": 0.0, "rain": 0.0, "wind": 0.2 },
	"overcast": { "overcast": 0.7, "rain": 0.0, "wind": 0.45 },
	"rain": { "overcast": 1.0, "rain": 1.0, "wind": 0.8 },
}
## Which state can follow which, with weights. Rain always eases through overcast sky first or after.
const NEXT := {
	"clear": { "overcast": 1.0 },
	"overcast": { "clear": 0.45, "rain": 0.55 },
	"rain": { "overcast": 0.8, "clear": 0.2 },
}
## How many rain particles each graphics level allows at full rain.
const RAIN_AMOUNT := { "low": 500, "medium": 900, "high": 1500 }
const RAIN_HEIGHT := 14.0
const RAIN_SPEED := 24.0
## How often (seconds) a single upward ray checks whether the camera stands under a roof.
const COVER_CHECK_INTERVAL := 0.2
## How fast the rain fades in and out when moving under or out from cover, per second.
const COVER_FADE_SPEED := 2.5
## At full overcast the sun is this share of its strength, and the sky this much darker.
const OVERCAST_LIGHT := 0.35
const OVERCAST_GREY := 0.75
const CLEAR_FOG := 0.0005
const OVERCAST_FOG := 0.0016

var state := "clear"
## 0 under a clear sky, 1 under full cloud. Rain counts as full cloud.
var overcast := 0.0
var rain := 0.0
var wind := 0.2

## 1 when a roof or other solid thing is overhead, so the rain is hidden, 0 in the open.
var cover := 0.0
var _cover_target := 0.0
var _cover_timer := 0.0
var _time_left := 0.0
var _rng := RandomNumberGenerator.new()
var _rain_particles: GPUParticles3D
var _rain_material: ParticleProcessMaterial
var _streak_material: ShaderMaterial
var _roof_map: RoofMap
var _roof_texture: ImageTexture
var _roof_version := -1
var _sky_dome: SkyDome
var _grass: GrassField


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_rng.randomize()
	_time_left = _next_duration()
	if FeatureFlags.enabled("weather"):
		_build_rain()
		set_quality(Settings.graphics)
	else:
		set_process(false)
	_push()


func _process(delta: float) -> void:
	update(delta)
	_update_cover(delta)


## Moves time on: counts down to the next change and eases the values towards the current state.
func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		state = pick_next(state, _rng.randf())
		_time_left = _next_duration()
	var target: Dictionary = STATES[state]
	var step := delta / maxf(FeatureFlags.value("weather_blend_seconds", 20.0), 0.1)
	overcast = move_toward(overcast, target["overcast"], step)
	rain = move_toward(rain, target["rain"], step)
	wind = move_toward(wind, target["wind"], step * 0.5)
	_push()


## The state that follows this one, for a roll between 0 and 1.
static func pick_next(from: String, roll: float) -> String:
	var options: Dictionary = NEXT[from]
	var total := 0.0
	for weight: float in options.values():
		total += weight
	var left := roll * total
	for option: String in options:
		left -= options[option]
		if left <= 0.0:
			return option
	return options.keys().back()


## Switches to this state, at once unless told to blend.
func set_state(new_state: String, instant := true) -> void:
	if not STATES.has(new_state):
		push_error("Unknown weather: %s" % new_state)
		return
	state = new_state
	_time_left = _next_duration()
	if instant:
		overcast = STATES[state]["overcast"]
		rain = STATES[state]["rain"]
		wind = STATES[state]["wind"]
	_push()


## How much of the sun's light gets through the clouds, 1 under a clear sky.
func light_factor() -> float:
	return lerpf(1.0, OVERCAST_LIGHT, overcast)


func fog_density() -> float:
	return lerpf(CLEAR_FOG, OVERCAST_FOG, overcast)


## Pulls a sky colour towards a darker grey as the clouds thicken.
func grey_sky(color: Color) -> Color:
	var grey := Color.from_hsv(0.6, 0.06, color.v * OVERCAST_GREY)
	return color.lerp(grey, overcast * 0.8)


## True when something solid (a roof, a bridge, a ceiling) is within rain height above this point.
## One ray, no per-drop work.
func is_covered(point: Vector3) -> bool:
	var world := get_viewport().world_3d if is_inside_tree() else null
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3(0.0, RAIN_HEIGHT, 0.0))
	query.exclude = _body_rids()
	return not world.direct_space_state.intersect_ray(query).is_empty()


## Rebuilds the roof map when the village has new or repaired roofs, then hands it to the rain shader.
func refresh_roofs() -> void:
	var village := get_parent().get_node_or_null("Village") as Village if get_parent() else null
	if _streak_material == null or village == null or village.roof_version == _roof_version:
		return
	_roof_version = village.roof_version
	_roof_map = RoofMap.build(village.roof_covers)
	_roof_texture = ImageTexture.create_from_image(_roof_map.image)
	_streak_material.set_shader_parameter("roof_map", _roof_texture)
	_streak_material.set_shader_parameter("roof_origin", _roof_map.origin)
	_streak_material.set_shader_parameter("roof_size", _roof_map.size)


## The top of the roof or deck above this x and z that keeps the rain off, or RoofMap.NONE in the open.
func roof_height_at(x: float, z: float) -> float:
	return _roof_map.height_at(x, z) if _roof_map else RoofMap.NONE


func rain_particles() -> GPUParticles3D:
	return _rain_particles


func set_quality(level: String) -> void:
	if _rain_particles:
		_rain_particles.amount = RAIN_AMOUNT.get(level, RAIN_AMOUNT["medium"])
		_push()


func to_data() -> Dictionary:
	return { "state": state, "overcast": overcast, "rain": rain, "wind": wind, "time_left": _time_left }


## Restores a saved state. Games saved before weather existed give an empty dictionary and stay clear.
func load_data(data: Dictionary) -> void:
	if not STATES.has(data.get("state", "")):
		return
	state = data["state"]
	overcast = clampf(float(data.get("overcast", STATES[state]["overcast"])), 0.0, 1.0)
	rain = clampf(float(data.get("rain", STATES[state]["rain"])), 0.0, 1.0)
	wind = clampf(float(data.get("wind", STATES[state]["wind"])), 0.0, 1.0)
	_time_left = maxf(float(data.get("time_left", _next_duration())), 1.0)
	_push()


## Checks for a roof over the camera a few times a second, and fades the rain out under one.
func _update_cover(delta: float) -> void:
	if _rain_particles == null:
		return
	_cover_timer -= delta
	if _cover_timer <= 0.0:
		_cover_timer = COVER_CHECK_INTERVAL
		refresh_roofs()
		var camera := get_viewport().get_camera_3d()
		_cover_target = 1.0 if rain > 0.02 and camera and is_covered(camera.global_position) else 0.0
	var before := cover
	cover = move_toward(cover, _cover_target, COVER_FADE_SPEED * delta)
	if cover != before:
		_push()


## Characters carry colliders that must not count as a roof.
func _body_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is CollisionObject3D:
			rids.append(node.get_rid())
	return rids


func _next_duration() -> float:
	var shortest: float = FeatureFlags.value("weather_min_seconds", 180.0)
	var longest: float = FeatureFlags.value("weather_max_seconds", 420.0)
	return _rng.randf_range(shortest, maxf(longest, shortest))


func _build_rain() -> void:
	_rain_material = ParticleProcessMaterial.new()
	_rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_material.emission_box_extents = Vector3(14.0, 0.5, 14.0)
	_rain_material.direction = Vector3.DOWN
	_rain_material.spread = 1.5
	_rain_material.initial_velocity_min = RAIN_SPEED * 0.9
	_rain_material.initial_velocity_max = RAIN_SPEED * 1.1
	_rain_material.gravity = Vector3.ZERO
	_rain_material.particle_flag_align_y = true

	var streak := QuadMesh.new()
	streak.size = Vector2(0.014, 0.6)
	_streak_material = ShaderMaterial.new()
	_streak_material.shader = load("res://shaders/rain.gdshader")
	var empty := Image.create_empty(1, 1, false, Image.FORMAT_RF)
	empty.fill(Color(RoofMap.NONE, 0.0, 0.0))
	_streak_material.set_shader_parameter("roof_map", ImageTexture.create_from_image(empty))
	streak.material = _streak_material

	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "Rain"
	_rain_particles.process_material = _rain_material
	_rain_particles.draw_pass_1 = streak
	_rain_particles.amount = RAIN_AMOUNT["high"]
	_rain_particles.lifetime = (RAIN_HEIGHT + 8.0) / RAIN_SPEED
	_rain_particles.preprocess = _rain_particles.lifetime
	_rain_particles.local_coords = false
	_rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_particles.visibility_aabb = AABB(Vector3(-30.0, -20.0, -30.0), Vector3(60.0, 40.0, 60.0))
	_rain_particles.emitting = false
	add_child(_rain_particles)


## Hands the current values to everything that shows them.
func _push() -> void:
	if not is_inside_tree():
		return
	if _sky_dome == null or not is_instance_valid(_sky_dome):
		_sky_dome = get_tree().get_first_node_in_group(SkyDome.GROUP) as SkyDome
	if _grass == null or not is_instance_valid(_grass):
		_grass = get_tree().get_first_node_in_group(GrassField.GROUP) as GrassField
	if _sky_dome:
		_sky_dome.set_weather(overcast, wind)
	if _grass:
		_grass.set_wind(wind)
	if _rain_particles:
		var shown := clampf(rain * (1.0 - cover), 0.0, 1.0)
		_rain_particles.emitting = shown > 0.02
		_rain_particles.amount_ratio = shown
		_rain_material.direction = Vector3(wind * 0.25, -1.0, wind * 0.1).normalized()
		var camera := get_viewport().get_camera_3d()
		if camera:
			_rain_particles.global_position = camera.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0)
