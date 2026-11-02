class_name TerrainPath
extends RefCounted
## A smooth line across the map, such as a road or a river, that can quickly say how near a point is.

const CELL_SIZE := 32.0

## Each sample's position, its height, and how far the line's width reaches on either side.
var positions := PackedVector2Array()
var heights := PackedFloat32Array()
var half_widths := PackedFloat32Array()

var _cells: Dictionary = {}


## Each point is [x, z, height, half width]. The reach is how far from the line `nearest` still answers.
func _init(points: Array, spacing: float, reach: float) -> void:
	for i in points.size() - 1:
		var from: Array = points[i]
		var to: Array = points[i + 1]
		var start := Vector2(from[0], from[1])
		var end := Vector2(to[0], to[1])
		var before: Array = points[maxi(i - 1, 0)]
		var after: Array = points[mini(i + 2, points.size() - 1)]
		var steps := ceili(start.distance_to(end) / spacing)
		for step in steps:
			var progress := float(step) / steps
			positions.append(start.cubic_interpolate(end, Vector2(before[0], before[1]), Vector2(after[0], after[1]), progress))
			heights.append(lerpf(from[2], to[2], progress))
			half_widths.append(lerpf(from[3], to[3], progress))
	var last: Array = points[points.size() - 1]
	positions.append(Vector2(last[0], last[1]))
	heights.append(last[2])
	half_widths.append(last[3])
	_index_segments(reach)


## The distance to the line, and the height and half width there. The distance is INF beyond the reach.
func nearest(x: float, z: float) -> Vector3:
	var segments: Variant = _cells.get(_cell_key(floori(x / CELL_SIZE), floori(z / CELL_SIZE)))
	if segments == null:
		return Vector3(INF, 0.0, 0.0)
	var point := Vector2(x, z)
	var best := INF
	var best_segment := 0
	var best_progress := 0.0
	for segment: int in segments:
		var start := positions[segment]
		var along := positions[segment + 1] - start
		var progress := clampf((point - start).dot(along) / along.length_squared(), 0.0, 1.0)
		var distance := point.distance_squared_to(start + along * progress)
		if distance < best:
			best = distance
			best_segment = segment
			best_progress = progress
	return Vector3(
		sqrt(best),
		lerpf(heights[best_segment], heights[best_segment + 1], best_progress),
		lerpf(half_widths[best_segment], half_widths[best_segment + 1], best_progress))


func _index_segments(reach: float) -> void:
	for segment in positions.size() - 1:
		var low := Vector2(minf(positions[segment].x, positions[segment + 1].x), minf(positions[segment].y, positions[segment + 1].y)) - Vector2.ONE * reach
		var high := Vector2(maxf(positions[segment].x, positions[segment + 1].x), maxf(positions[segment].y, positions[segment + 1].y)) + Vector2.ONE * reach
		for cell_z in range(floori(low.y / CELL_SIZE), floori(high.y / CELL_SIZE) + 1):
			for cell_x in range(floori(low.x / CELL_SIZE), floori(high.x / CELL_SIZE) + 1):
				var key := _cell_key(cell_x, cell_z)
				if not _cells.has(key):
					_cells[key] = PackedInt32Array()
				_cells[key].append(segment)


func _cell_key(cell_x: int, cell_z: int) -> int:
	return (cell_x + 1024) * 4096 + cell_z + 1024
