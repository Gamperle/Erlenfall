class_name RoofMap
extends RefCounted
## A coarse top-down height field of everything the rain should not fall through: house roofs and
## bridge decks. It is built once from the footprints the village placed (no physics, no per-drop
## work), read back by the rain shader as a small texture, and by code through height_at().

const CELL := 1.0
const MARGIN := 3.0
## What a cell holds where nothing covers it: far below any drop.
const NONE := -1000.0

var origin := Vector2.ZERO
var size := Vector2.ONE
var image: Image


## Each cover is a dictionary with "center" (Vector2), "half" (Vector2, half the footprint across x and
## z), "yaw" (radians, as the node's rotation.y), "base" (the y where the profile starts), "rise" (how
## far the top climbs above it) and "shape": "ridge" peaks along local z, "arch" peaks in the middle of
## local z. Covers with "active": false are skipped.
static func build(covers: Array) -> RoofMap:
	var map := RoofMap.new()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var active: Array[Dictionary] = []
	for cover: Dictionary in covers:
		if not cover.get("active", true):
			continue
		active.append(cover)
		var reach: float = (cover["half"] as Vector2).length()
		low = low.min(cover["center"] - Vector2(reach, reach))
		high = high.max(cover["center"] + Vector2(reach, reach))
	if active.is_empty():
		map.image = Image.create_empty(1, 1, false, Image.FORMAT_RF)
		map.image.fill(Color(NONE, 0.0, 0.0))
		return map
	map.origin = (low - Vector2(MARGIN, MARGIN)).floor()
	map.size = ((high + Vector2(MARGIN, MARGIN)).ceil() - map.origin)
	var width := ceili(map.size.x / CELL)
	var height := ceili(map.size.y / CELL)
	map.image = Image.create_empty(width, height, false, Image.FORMAT_RF)
	map.image.fill(Color(NONE, 0.0, 0.0))
	for cover in active:
		map._stamp(cover)
	return map


## The height of the roof or deck above this x and z, or NONE when open sky is overhead.
func height_at(x: float, z: float) -> float:
	var cell := Vector2i(floori((x - origin.x) / CELL), floori((z - origin.y) / CELL))
	if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height():
		return NONE
	return image.get_pixelv(cell).r


func _stamp(cover: Dictionary) -> void:
	var center: Vector2 = cover["center"]
	var half: Vector2 = cover["half"]
	var yaw: float = cover["yaw"]
	var reach := half.length()
	var first := Vector2i(floori((center.x - reach - origin.x) / CELL), floori((center.y - reach - origin.y) / CELL))
	var last := Vector2i(floori((center.x + reach - origin.x) / CELL), floori((center.y + reach - origin.y) / CELL))
	var cosine := cos(yaw)
	var sine := sin(yaw)
	for cy in range(maxi(first.y, 0), mini(last.y, image.get_height() - 1) + 1):
		for cx in range(maxi(first.x, 0), mini(last.x, image.get_width() - 1) + 1):
			var offset := Vector2(origin.x + (cx + 0.5) * CELL, origin.y + (cy + 0.5) * CELL) - center
			var local := Vector2(offset.x * cosine - offset.y * sine, offset.x * sine + offset.y * cosine)
			if absf(local.x) > half.x or absf(local.y) > half.y:
				continue
			var top: float = cover["base"] + cover["rise"] * _profile(cover["shape"], local, half)
			if top > image.get_pixel(cx, cy).r:
				image.set_pixel(cx, cy, Color(top, 0.0, 0.0))


## 1 at the highest line of the cover and 0 at its lowest edge.
static func _profile(shape: String, local: Vector2, half: Vector2) -> float:
	if shape == "arch":
		var across := local.y / half.y
		return 1.0 - across * across
	return 1.0 - absf(local.x) / half.x
