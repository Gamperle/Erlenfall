class_name Minimap
extends Control
## A small square of the map around the player, in the corner of the HUD. It draws one texture region
## and a few markers, and only redraws when the player has moved or turned.

const BASE_SIZE := 150.0
const DEFAULT_RADIUS := 120.0
const MOVE_THRESHOLD := 0.5
const TURN_THRESHOLD := 1.0
const FRAME_COLOR := Color(0.1, 0.06, 0.03)
const BACKDROP_COLOR := Color(0.07, 0.07, 0.06)
const FRAME_WIDTH := 2.0
const PLAYER_SIZE := 6.0
const OBJECTIVE_SIZE := 5.0
const EDGE_INSET := 6.0
const NORTH_FONT_SIZE := 13
const NORTH_COLOR := Color(0.95, 0.55, 0.15)

var map: MapData:
	set(new_map):
		map = new_map
		queue_redraw()

## Half the width of the area shown, in meters.
var radius := DEFAULT_RADIUS:
	set(new_radius):
		radius = maxf(new_radius, 1.0)
		queue_redraw()

var player_position := Vector2.ZERO:
	set(new_position):
		if new_position.distance_to(player_position) >= MOVE_THRESHOLD:
			player_position = new_position
			queue_redraw()

var heading := 0.0:
	set(new_heading):
		if absf(wrapf(new_heading - heading, -180.0, 180.0)) >= TURN_THRESHOLD:
			heading = new_heading
			queue_redraw()

## The places of the current objectives, as x and z.
var objectives: Array[Vector2] = []:
	set(new_objectives):
		if new_objectives != objectives:
			objectives = new_objectives
			queue_redraw()


func _init() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## The side of the square for the current text size.
static func side_for_text_size() -> float:
	return roundf(BASE_SIZE * Settings.text_size)


## Puts the square's top left corner at `top_left`, and sizes it for the text size.
func place(top_left: Vector2) -> void:
	var side := side_for_text_size()
	offset_left = top_left.x
	offset_top = top_left.y
	offset_right = top_left.x + side
	offset_bottom = top_left.y + side
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


## Returns where a world position (x and z) lands inside the square, and the texture area shown.
func to_local_position(world: Vector2, region: Rect2) -> Vector2:
	var texel := MapData.world_to_uv(world) * MapData.IMAGE_SIZE
	return (texel - region.position) / region.size * size


## The area of the map picture shown, in its pixels, kept inside the picture.
func visible_region() -> Rect2:
	var span := 2.0 * radius * MapData.IMAGE_SIZE / Terrain.SIZE
	var center := MapData.world_to_uv(player_position) * MapData.IMAGE_SIZE
	var origin := (center - Vector2.ONE * span / 2.0).clamp(Vector2.ZERO, Vector2.ONE * (MapData.IMAGE_SIZE - span))
	return Rect2(origin, Vector2.ONE * span)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, BACKDROP_COLOR)
	if map == null or map.texture == null:
		draw_rect(box, FRAME_COLOR, false, FRAME_WIDTH * 2.0)
		return
	var region := visible_region()
	draw_texture_rect_region(map.texture, box, region)
	for place in map.places:
		if place["discovered"] and region.has_point(MapData.world_to_uv(place["position"]) * MapData.IMAGE_SIZE):
			MapMarkers.draw_place(self, to_local_position(place["position"], region), 3.0)
	for objective in objectives:
		MapMarkers.draw_objective(self, MapMarkers.clamp_to_rect(to_local_position(objective, region), box, EDGE_INSET), OBJECTIVE_SIZE)
	MapMarkers.draw_player(self, to_local_position(player_position, region), heading, PLAYER_SIZE)
	var font := get_theme_default_font()
	var north := tr("UI_COMPASS_N")
	var font_size := Settings.scaled_font_size(NORTH_FONT_SIZE)
	var at := Vector2(size.x / 2.0 - font.get_string_size(north, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0, font_size + 3.0)
	draw_string_outline(font, at, north, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.8))
	draw_string(font, at, north, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, NORTH_COLOR)
	draw_rect(box, FRAME_COLOR, false, FRAME_WIDTH * 2.0)
