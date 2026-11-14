class_name MapData
extends RefCounted
## The picture of the whole world for the map and minimap, drawn once from the terrain and the layout
## file, and the places on it. Nothing here runs per frame.

const IMAGE_SIZE := 512
const SHADE_STRENGTH := 0.55
const LOW_COLOR := Color(0.2, 0.28, 0.14)
const MID_COLOR := Color(0.36, 0.38, 0.2)
const ROCK_COLOR := Color(0.45, 0.43, 0.4)
const SNOW_COLOR := Color(0.92, 0.93, 0.95)
const WATER_COLOR := Color(0.16, 0.34, 0.45)
const ROAD_COLOR := Color(0.74, 0.62, 0.42)
const FIELD_COLOR := Color(0.6, 0.55, 0.25)
const BUILDING_COLOR := Color(0.28, 0.2, 0.15)
const SNOW_LINE := 0.85
const ROCK_LINE := 0.45
const IRON_ITEM := "iron_ore"

## Each place is a Dictionary with "id", "position" (x and z), "name" (a translation key), and "discovered".
var places: Array[Dictionary] = []
var texture: ImageTexture

var _image: Image


## Meters from the world's center to its edge.
static func half_extent() -> float:
	return Terrain.SIZE / 2.0


## Where a world position (x and z) lies on the picture, from 0 to 1 on each side. North is up.
static func world_to_uv(world: Vector2) -> Vector2:
	return (world + Vector2.ONE * half_extent()) / Terrain.SIZE


static func uv_to_world(uv: Vector2) -> Vector2:
	return uv * Terrain.SIZE - Vector2.ONE * half_extent()


## Draws the picture. Safe to call from a worker thread: it only reads. `terrain` must have its roads and river.
func render(terrain: Terrain, layout: Dictionary) -> void:
	var grid := _grid_of(terrain)
	var count := int(roundf(sqrt(grid.size())))
	var low := INF
	var high := -INF
	for height in grid:
		low = minf(low, height)
		high = maxf(high, height)
	var bytes := PackedByteArray()
	bytes.resize(IMAGE_SIZE * IMAGE_SIZE * 3)
	var meters := Terrain.SIZE / IMAGE_SIZE
	var cell := Terrain.SIZE / (count - 1)
	for py in IMAGE_SIZE:
		for px in IMAGE_SIZE:
			var world := uv_to_world(Vector2(px + 0.5, py + 0.5) / IMAGE_SIZE)
			var color := _land_color(grid, count, cell, world, low, high)
			if terrain.river_clearance(world.x, world.y) < 0.0:
				color = WATER_COLOR
			else:
				for road in terrain.roads:
					var found := road.nearest(world.x, world.y)
					if found.x < found.z + meters * 0.5:
						color = ROAD_COLOR
						break
			var at := (py * IMAGE_SIZE + px) * 3
			bytes[at] = color.r8
			bytes[at + 1] = color.g8
			bytes[at + 2] = color.b8
	_image = Image.create_from_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGB8, bytes)
	for field: Dictionary in layout.get("fields", []):
		_fill_box(field, FIELD_COLOR)
	for building: Dictionary in layout.get("buildings", []):
		_fill_box(building, BUILDING_COLOR, 1.6 * Terrain.SIZE / IMAGE_SIZE)
	_collect_places(layout)


## Turns the drawn picture into a texture. Call it on the main thread once `render` is done.
func make_texture() -> void:
	texture = ImageTexture.create_from_image(_image)


## Marks the places within `radius` of the player as discovered. Returns whether any was new.
func discover_near(position: Vector2, radius: float) -> bool:
	var found := false
	for place in places:
		if not place["discovered"] and position.distance_to(place["position"]) <= radius:
			place["discovered"] = true
			found = true
	return found


func discovered_count() -> int:
	return places.filter(func(place: Dictionary) -> bool: return place["discovered"]).size()


func image() -> Image:
	return _image


func _grid_of(terrain: Terrain) -> PackedFloat32Array:
	if not terrain.height_grid.is_empty():
		return terrain.height_grid
	# The terrain hasn't built its mesh yet, so sample the same grid.
	var count := int(Terrain.SIZE / Terrain.STEP) + 1
	var grid := PackedFloat32Array()
	grid.resize(count * count)
	for j in count:
		for i in count:
			grid[j * count + i] = terrain.height_at(i * Terrain.STEP - half_extent(), j * Terrain.STEP - half_extent())
	return grid


func _height_in(grid: PackedFloat32Array, count: int, cell: float, world: Vector2) -> float:
	var at := (world + Vector2.ONE * half_extent()) / cell
	var x0 := clampi(floori(at.x), 0, count - 2)
	var z0 := clampi(floori(at.y), 0, count - 2)
	var fx := clampf(at.x - x0, 0.0, 1.0)
	var fz := clampf(at.y - z0, 0.0, 1.0)
	var top := lerpf(grid[z0 * count + x0], grid[z0 * count + x0 + 1], fx)
	var bottom := lerpf(grid[(z0 + 1) * count + x0], grid[(z0 + 1) * count + x0 + 1], fx)
	return lerpf(top, bottom, fz)


func _land_color(grid: PackedFloat32Array, count: int, cell: float, world: Vector2, low: float, high: float) -> Color:
	var height := _height_in(grid, count, cell, world)
	var level := inverse_lerp(low, high, height)
	var color := LOW_COLOR.lerp(MID_COLOR, smoothstep(0.0, ROCK_LINE * 0.6, level))
	color = color.lerp(ROCK_COLOR, smoothstep(ROCK_LINE * 0.6, ROCK_LINE + 0.15, level))
	color = color.lerp(SNOW_COLOR, smoothstep(SNOW_LINE - 0.1, SNOW_LINE + 0.1, level))
	# Light from the north-west: ground falling away from it is dark, ground rising towards it is bright.
	var slope_x := _height_in(grid, count, cell, world + Vector2(cell, 0.0)) - _height_in(grid, count, cell, world - Vector2(cell, 0.0))
	var slope_z := _height_in(grid, count, cell, world + Vector2(0.0, cell)) - _height_in(grid, count, cell, world - Vector2(0.0, cell))
	var shade := clampf((slope_x + slope_z) / (cell * 2.0) * 0.5, -1.0, 1.0)
	return color.darkened(shade * SHADE_STRENGTH) if shade > 0.0 else color.lightened(-shade * SHADE_STRENGTH)


## Paints a layout box (a field or building), turned about its center, at least `minimum` meters on each side.
func _fill_box(data: Dictionary, color: Color, minimum := 0.0) -> void:
	var center := Vector2(data["x"], data["z"])
	var half := Vector2(maxf(float(data["width"]), minimum), maxf(float(data["depth"]), minimum)) / 2.0
	var angle := deg_to_rad(float(data.get("rotation", 0.0)))
	var reach := half.length()
	var low := (world_to_uv(center - Vector2.ONE * reach) * IMAGE_SIZE).floor()
	var high := (world_to_uv(center + Vector2.ONE * reach) * IMAGE_SIZE).ceil()
	for py in range(maxi(int(low.y), 0), mini(int(high.y), IMAGE_SIZE - 1) + 1):
		for px in range(maxi(int(low.x), 0), mini(int(high.x), IMAGE_SIZE - 1) + 1):
			var offset := uv_to_world(Vector2(px + 0.5, py + 0.5) / IMAGE_SIZE) - center
			# The inverse of the box's turn about the vertical axis.
			var local := Vector2(offset.x * cos(angle) - offset.y * sin(angle), offset.x * sin(angle) + offset.y * cos(angle))
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				_image.set_pixel(px, py, color)


func _collect_places(layout: Dictionary) -> void:
	places.clear()
	for building: Dictionary in layout.get("buildings", []):
		_add_place(building["id"], Vector2(building["x"], building["z"]), "MAP_" + String(building["id"]).to_upper())
	var ore := Vector2.ZERO
	var ore_count := 0
	for resource: Dictionary in layout.get("resources", []):
		if resource.get("item", "") == IRON_ITEM:
			ore += Vector2(resource["x"], resource["z"])
			ore_count += 1
	if ore_count > 0:
		_add_place("iron_ore", ore / ore_count, "MAP_IRON_ORE")


func _add_place(id: String, position: Vector2, name_key: String) -> void:
	places.append({ "id": id, "position": position, "name": name_key, "discovered": false })
