class_name MapMarkers
extends RefCounted
## The little shapes the map and minimap share, drawn onto any canvas item.

const PLAYER_COLOR := Color(0.95, 0.35, 0.2)
const OBJECTIVE_COLOR := Color(1.0, 0.85, 0.3)
const PLACE_COLOR := Color(0.95, 0.92, 0.85)
const OUTLINE_COLOR := Color(0.1, 0.06, 0.03)
const OUTLINE_WIDTH := 1.5


## An arrow at `at` pointing in a direction given in degrees clockwise from north, with north up.
static func draw_player(canvas: CanvasItem, at: Vector2, heading: float, size: float) -> void:
	var angle := deg_to_rad(heading)
	var forward := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([at + forward * size, at - forward * size * 0.7 + side * size * 0.7, at - forward * size * 0.3, at - forward * size * 0.7 - side * size * 0.7])
	canvas.draw_colored_polygon(points, PLAYER_COLOR)
	points.append(points[0])
	canvas.draw_polyline(points, OUTLINE_COLOR, OUTLINE_WIDTH, true)


## The diamond the compass uses for an objective.
static func draw_objective(canvas: CanvasItem, at: Vector2, size: float) -> void:
	var diamond := PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size, 0.0), at + Vector2(0.0, size), at + Vector2(-size, 0.0)])
	canvas.draw_colored_polygon(diamond, OBJECTIVE_COLOR)
	diamond.append(diamond[0])
	canvas.draw_polyline(diamond, OUTLINE_COLOR, OUTLINE_WIDTH, true)


static func draw_place(canvas: CanvasItem, at: Vector2, size: float) -> void:
	canvas.draw_circle(at, size + OUTLINE_WIDTH, OUTLINE_COLOR)
	canvas.draw_circle(at, size, PLACE_COLOR)


## Pulls a point that lies outside the rectangle back to its edge, along the line from the center, so a
## target out of view stays at the edge towards it.
static func clamp_to_rect(point: Vector2, rect: Rect2, inset: float) -> Vector2:
	var inner := rect.grow(-inset)
	var center := rect.get_center()
	var offset := point - center
	if inner.has_point(point) or offset == Vector2.ZERO:
		return point
	var shrink := minf(inner.size.x * 0.5 / maxf(absf(offset.x), 0.0001), inner.size.y * 0.5 / maxf(absf(offset.y), 0.0001))
	return center + offset * shrink
