class_name MapController
extends Node
## Builds the map picture once, in the background, and feeds the minimap and the full map with the
## player's place and the objectives. See the `world_map` and `minimap` flags.

const LAYOUT_PATH := "res://data/village_layout.json"
const MINIMAP_NAME := "Minimap"

var data := MapData.new()
var minimap: Minimap
var world_map: WorldMap

var _terrain: Terrain
var _village: Village
var _player: Player
var _hud: HudLayout
var _task := -1
var _ready_to_show := false


## `hud` is the layer the minimap goes on.
func setup(terrain: Terrain, village: Village, player: Player, hud: HudLayout) -> void:
	name = "MapController"
	_terrain = terrain
	_village = village
	_player = player
	_hud = hud
	if not FeatureFlags.enabled("world_map") and not FeatureFlags.enabled("minimap"):
		set_process(false)
		return
	if FeatureFlags.enabled("minimap"):
		minimap = Minimap.new()
		minimap.radius = float(FeatureFlags.value("minimap_radius", Minimap.DEFAULT_RADIUS))
		minimap.map = data
		hud.add_child(minimap)
		hud.minimap = minimap
		hud.arrange()
	if FeatureFlags.enabled("world_map"):
		world_map = WorldMap.new()
		world_map.map = data
		world_map.can_open = func() -> bool: return _hud.visible and not _player.is_busy()
		add_child(world_map)
		world_map.setup(player)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_task = WorkerThreadPool.add_task(data.render.bind(terrain, layout), false, "Draw the map")


## Waits for the picture, for tests and for anything that needs the map at once.
func finish_now() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_show_picture()


func is_picture_ready() -> bool:
	return _ready_to_show


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		finish_now()
	var place := Vector2(_player.position.x, _player.position.z)
	var heading := _player.heading_degrees()
	var objectives := _objective_places()
	if data.discover_near(place, float(FeatureFlags.value("map_discover_radius", 60.0))):
		if minimap != null:
			minimap.queue_redraw()
		if world_map != null:
			world_map.refresh()
	if minimap != null:
		minimap.player_position = place
		minimap.heading = heading
		minimap.objectives = objectives
	if world_map != null:
		world_map.player_position = place
		world_map.heading = heading
		world_map.objectives = objectives


func _show_picture() -> void:
	data.make_texture()
	_ready_to_show = true
	if minimap != null:
		minimap.queue_redraw()
	if world_map != null:
		world_map.refresh()


func _objective_places() -> Array[Vector2]:
	var places: Array[Vector2] = []
	if FeatureFlags.enabled("compass_objectives"):
		for marker in _player.quests.objective_markers(_player.inventory):
			places.append(_village.marker_position(marker))
	return places
