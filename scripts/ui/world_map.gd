class_name WorldMap
extends CanvasLayer
## The full-screen map, opened with the map key. It pauses the game like the inventory. The picture is
## drawn once (see MapData), so opening it costs one textured rectangle and a few markers.

const MARGIN := 24.0
const FRAME_COLOR := Color(0.1, 0.06, 0.03)
const DIM_COLOR := Color(0.03, 0.03, 0.02, 0.88)
const TEXT_COLOR := Color(0.95, 0.92, 0.85)
const TITLE_FONT_SIZE := 24
const LABEL_FONT_SIZE := 15
const HINT_FONT_SIZE := 14
const MIN_ZOOM := 1.0
const MAX_ZOOM := 8.0
const START_ZOOM := 3.0
const ZOOM_STEP := 1.4
const LABEL_ZOOM := 2.0
const PAN_PER_SECOND := 0.6
const PLAYER_SIZE := 9.0
const OBJECTIVE_SIZE := 8.0
const PLACE_SIZE := 4.5

var map: MapData
var player_position := Vector2.ZERO
var heading := 0.0
var objectives: Array[Vector2] = []
## Says whether the map may open now, such as not during a menu or dialogue.
var can_open := func() -> bool: return true

var _player: Player
var _canvas: Control
var _center := Vector2.ZERO
var _zoom := START_ZOOM
var _dragging := false


func _init() -> void:
	name = "WorldMap"
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)


func setup(player: Player) -> void:
	_player = player


## Draws the map again, after a change in what it shows.
func refresh() -> void:
	if _canvas != null and visible:
		_canvas.queue_redraw()


func is_open() -> bool:
	return visible


func open() -> void:
	_center = player_position
	_zoom = START_ZOOM
	visible = true
	if _player != null:
		_player.set_busy(true)
	_clamp_center()
	_canvas.queue_redraw()


func close() -> void:
	visible = false
	_dragging = false
	if _player != null:
		_player.set_busy(false)


## The meters across the map's square at the current zoom.
func span() -> float:
	return Terrain.SIZE / _zoom


func zoom_by(factor: float) -> void:
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_clamp_center()
	_canvas.queue_redraw()


func zoom_level() -> float:
	return _zoom


func pan(world_offset: Vector2) -> void:
	_center += world_offset
	_clamp_center()
	_canvas.queue_redraw()


func view_center() -> Vector2:
	return _center


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _canvas != null:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("map") and can_open.call():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("map_zoom_in"):
		zoom_by(ZOOM_STEP)
	elif event.is_action_pressed("map_zoom_out"):
		zoom_by(1.0 / ZOOM_STEP)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		pan(-event.relative / _map_rect().size.x * span())
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if direction != Vector2.ZERO:
		pan(direction * span() * PAN_PER_SECOND * delta)


func _clamp_center() -> void:
	var limit := MapData.half_extent() - span() / 2.0
	_center = _center.clamp(Vector2.ONE * -limit, Vector2.ONE * limit)


## The square the picture fills, leaving room for the title above and the keys below.
func _map_rect() -> Rect2:
	var size := _canvas.size
	var top := MARGIN + Settings.scaled_font_size(TITLE_FONT_SIZE) * 1.4
	var bottom := _footer_height(size.x)
	var side := maxf(minf(size.x - MARGIN * 2.0, size.y - top - bottom - MARGIN), 64.0)
	return Rect2(Vector2((size.x - side) / 2.0, top), Vector2(side, side))


func _footer_height(width: float) -> float:
	var font := _canvas.get_theme_default_font()
	var hint := font.get_multiline_string_size(tr("UI_MAP_HINT"), HORIZONTAL_ALIGNMENT_CENTER, width - MARGIN * 2.0, Settings.scaled_font_size(HINT_FONT_SIZE))
	return hint.y + Settings.scaled_font_size(LABEL_FONT_SIZE) * 1.6 + MARGIN * 0.5


## Where a world position (x and z) lands on the screen.
func to_screen(world: Vector2, rect: Rect2) -> Vector2:
	return rect.position + (world - _center + Vector2.ONE * span() / 2.0) / span() * rect.size


func _draw_map() -> void:
	var canvas_size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), DIM_COLOR)
	var font := _canvas.get_theme_default_font()
	var title := tr("UI_MAP")
	var title_size := Settings.scaled_font_size(TITLE_FONT_SIZE)
	_text(font, Vector2(canvas_size.x / 2.0, MARGIN + title_size), title, title_size, true)
	var rect := _map_rect()
	if map != null and map.texture != null:
		var half := Vector2.ONE * span() / 2.0
		var region := Rect2((MapData.world_to_uv(_center - half) * MapData.IMAGE_SIZE), Vector2.ONE * span() / Terrain.SIZE * MapData.IMAGE_SIZE)
		_canvas.draw_texture_rect_region(map.texture, rect, region)
	else:
		_canvas.draw_rect(rect, Color(0.07, 0.07, 0.06))
		_text(font, rect.get_center(), tr("UI_MAP_LOADING"), Settings.scaled_font_size(LABEL_FONT_SIZE), true)
	_draw_places(font, rect)
	for objective in objectives:
		MapMarkers.draw_objective(_canvas, MapMarkers.clamp_to_rect(to_screen(objective, rect), rect, OBJECTIVE_SIZE + 2.0), OBJECTIVE_SIZE)
	var player_at := to_screen(player_position, rect)
	if rect.has_point(player_at):
		MapMarkers.draw_player(_canvas, player_at, heading, PLAYER_SIZE)
	_canvas.draw_rect(rect, FRAME_COLOR, false, 3.0)
	_draw_compass_letters(font, rect)
	_draw_footer(font, canvas_size, rect)


func _draw_places(font: Font, rect: Rect2) -> void:
	if map == null:
		return
	var label_size := Settings.scaled_font_size(LABEL_FONT_SIZE)
	var taken: Array[Rect2] = []
	for place in map.places:
		if not place["discovered"]:
			continue
		var at := to_screen(place["position"], rect)
		if not rect.grow(-4.0).has_point(at):
			continue
		MapMarkers.draw_place(_canvas, at, PLACE_SIZE)
		if _zoom < LABEL_ZOOM:
			continue
		var text := tr(place["name"])
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
		var box := Rect2(at + Vector2(PLACE_SIZE + 4.0, -text_size.y / 2.0), text_size)
		if not rect.encloses(box) or taken.any(func(other: Rect2) -> bool: return other.intersects(box)):
			continue
		taken.append(box)
		_text(font, Vector2(box.position.x, box.position.y + font.get_ascent(label_size)), text, label_size, false)


func _draw_compass_letters(font: Font, rect: Rect2) -> void:
	var size := Settings.scaled_font_size(LABEL_FONT_SIZE)
	_text(font, Vector2(rect.get_center().x, rect.position.y + size + 4.0), tr("UI_COMPASS_N"), size, true, MapMarkers.PLAYER_COLOR)


func _draw_footer(font: Font, canvas_size: Vector2, rect: Rect2) -> void:
	var label_size := Settings.scaled_font_size(LABEL_FONT_SIZE)
	var y := rect.end.y + MARGIN * 0.5 + label_size
	var x := rect.position.x
	MapMarkers.draw_player(_canvas, Vector2(x + 8.0, y - label_size * 0.35), 0.0, 7.0)
	x += 22.0
	x = _legend_text(font, Vector2(x, y), tr("UI_MAP_YOU"), label_size) + 18.0
	MapMarkers.draw_objective(_canvas, Vector2(x + 7.0, y - label_size * 0.35), 6.0)
	x += 20.0
	x = _legend_text(font, Vector2(x, y), tr("UI_MAP_OBJECTIVE"), label_size) + 18.0
	MapMarkers.draw_place(_canvas, Vector2(x + 5.0, y - label_size * 0.35), 4.0)
	x += 16.0
	_legend_text(font, Vector2(x, y), tr("UI_MAP_PLACE"), label_size)
	var hint_size := Settings.scaled_font_size(HINT_FONT_SIZE)
	var hint_top := y + label_size * 0.6
	_canvas.draw_multiline_string(font, Vector2(MARGIN, hint_top + hint_size), tr("UI_MAP_HINT"), HORIZONTAL_ALIGNMENT_CENTER, canvas_size.x - MARGIN * 2.0, hint_size, -1, TEXT_COLOR)


## Draws a legend entry and returns where it ends.
func _legend_text(font: Font, at: Vector2, text: String, font_size: int) -> float:
	_canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.8))
	_canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
	return at.x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Draws text with a dark outline. Centered on `at.x` when `centered`, otherwise starting there.
func _text(font: Font, at: Vector2, text: String, font_size: int, centered: bool, color := TEXT_COLOR) -> void:
	var start := at
	if centered:
		start.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	_canvas.draw_string_outline(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.0, 0.0, 0.0, 0.8))
	_canvas.draw_string(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
