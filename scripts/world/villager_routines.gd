class_name VillagerRoutines
extends Node
## Sends villagers to the places their daily routines name, as the hours pass.
##
## The routines are in data/villager_routines.json: for each villager, a list of stops. A stop
## starts at an hour ("from", 0 to 24) and lasts until the next one starts, wrapping past
## midnight. It names a place ("x", "z") and which way to face there ("facing", degrees around
## the vertical axis, as for a building's rotation). A stop with no place is the villager's home,
## where the layout file puts them. A stop can also list "via" places ([x, z] pairs) to walk through
## on the way to it, so the walk goes around buildings and water rather than straight at it (#222).
##
## To keep it cheap, this checks the clock a couple of times a second, and a villager only does
## any work while walking.

const PATH := "res://data/villager_routines.json"
## A jump in the time of day bigger than this, such as sleeping through the night, puts everyone
## straight at their places instead of making them walk all the way.
const JUMP_HOURS := 2.0

var _routines: Dictionary = {}
var _villagers: Dictionary = {}
var _day_night: DayNight
var _last_hour := -1.0
var _tick_left := 0.0


func _ready() -> void:
	set_process(FeatureFlags.enabled("villager_routines"))
	_routines = load_routines()


## The places to walk through on the way to a stop.
static func route_of(stop: Dictionary) -> Array[Vector2]:
	var route: Array[Vector2] = []
	for point: Array in stop.get("via", []):
		route.append(Vector2(point[0], point[1]))
	return route


static func load_routines(path := PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Returns the stop that is on at this hour, or an empty dictionary if there are none.
static func active_stop(stops: Array, hour: float) -> Dictionary:
	var result := {}
	var latest := -1.0
	var last := {}
	var last_from := -1.0
	for stop: Dictionary in stops:
		var from: float = stop["from"]
		if from <= hour and from > latest:
			latest = from
			result = stop
		if from > last_from:
			last_from = from
			last = stop
	return result if not result.is_empty() else last


## Returns what is wrong with the routines, or an empty list.
static func problems(routines: Dictionary, npc_ids: Array) -> Array[String]:
	var found: Array[String] = []
	for id: String in routines:
		if not npc_ids.has(id):
			found.append("%s has a routine but is not in the village" % id)
		var previous := -1.0
		for stop: Dictionary in routines[id]:
			var from: float = stop.get("from", -1.0)
			if from < 0.0 or from >= 24.0 or from <= previous:
				found.append("%s: stops must start at increasing hours from 0 to 24" % id)
			previous = from
			if stop.has("x") != stop.has("z"):
				found.append("%s: a stop needs both x and z, or neither" % id)
			for point: Variant in stop.get("via", []) as Array:
				if not (point is Array and point.size() == 2):
					found.append("%s: via places must be [x, z] pairs" % id)
	return found


func add_villager(npc: Npc) -> void:
	_villagers[npc.npc_id] = npc


func _process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = FeatureFlags.value("villager_routine_tick_seconds", 0.5)
	if _day_night == null:
		_day_night = get_tree().get_first_node_in_group(DayNight.GROUP)
		if _day_night == null:
			return
	update(_day_night.hour)


## Sends each villager to their stop for this hour, or puts them there if the time jumped.
func update(hour: float) -> void:
	var change := absf(hour - _last_hour)
	var jumped := _last_hour < 0.0 or (change > JUMP_HOURS and change < 24.0 - JUMP_HOURS)
	_last_hour = hour
	for id: String in _routines:
		if not _villagers.has(id):
			continue
		var npc: Npc = _villagers[id]
		# Someone who has not arrived yet does not walk.
		if not npc.is_available():
			continue
		var stop := active_stop(_routines[id], hour)
		if stop.is_empty():
			continue
		var spot := Vector2(stop["x"], stop["z"]) if stop.has("x") else npc.home
		var facing := deg_to_rad(stop["facing"]) if stop.has("facing") else NAN
		if jumped:
			npc.place_at(spot, facing)
		else:
			npc.go_to(spot, facing, route_of(stop))
