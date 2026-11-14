class_name ModelBuilder
extends RefCounted
## Builds the world's objects from simple shapes and procedural materials.

const TIMBER_COLOR := Color(0.2, 0.13, 0.08)
const STONE_COLOR := Color(0.42, 0.4, 0.37)
const ROOF_COLOR := Color(0.36, 0.24, 0.18)
const OPENING_COLOR := Color(0.05, 0.04, 0.04)
const WOOD_COLOR := Color(0.42, 0.28, 0.16)
const IRON_COLOR := Color(0.16, 0.17, 0.19)
const CLOTH_COLOR := Color(0.45, 0.22, 0.18)
const FIRE_COLOR := Color(1.0, 0.45, 0.1)
const FOUNDATION_HEIGHT := 0.6
const BEAM := 0.22
const OPENING_DEPTH := 0.08
const DOOR_SIZE := Vector2(1.1, 2.1)
const WINDOW_SIZE := Vector2(0.9, 0.9)
const ROOF_HEIGHT := 2.5
const ROOF_OVERHANG := 1.0
const TORCH_FLAME_HEIGHT := 0.62
const WALL_COURSE_HEIGHT := 0.4
const WALL_BLOCK_LENGTH := Vector2(0.45, 0.9)
const WALL_GAP := 0.03
## Blocks and logs take one of a few tints, since each color is a material of its own.
const WALL_TINTS: Array[float] = [-0.1, 0.0, 0.1]
const PALISADE_POST_WIDTH := 0.28
const BRIDGE_SEGMENTS := 8
const BRIDGE_DECK_THICKNESS := 0.25
const BRIDGE_RAIL_HEIGHT := 1.0
const BRIDGE_RAIL_THICKNESS := 0.12
const BRIDGE_PIER_DEPTH := 3.0


static func box(size: Vector3, pattern: Surfaces.Pattern, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Surfaces.get_material(pattern, color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


## Joins the model's parts into one mesh with a surface for each material, since each part
## is a draw call of its own, and once more for every shadow it casts. The materials are
## mapped to the world, so the joined mesh looks the same. Parts that aren't meshes, or that
## don't cast shadows, stay as they are.
static func merged(model: Node3D) -> Node3D:
	var surfaces: Dictionary = {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			continue
		var to_model := _transform_in(model, part)
		for i in part.mesh.get_surface_count():
			var material: Material = part.get_active_material(i)
			if not surfaces.has(material):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[material] = surface
			surfaces[material].append_from(part.mesh, i, to_model)
		part.get_parent().remove_child(part)
		part.free()
	var mesh := ArrayMesh.new()
	for material: Material in surfaces:
		surfaces[material].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	model.add_child(instance)
	return model


## Where the part sits relative to the model, which may not be in the scene tree yet.
static func _transform_in(model: Node3D, part: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node: Node = part
	while node != model:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


## Plastered walls with a timber frame, a stone base, a door, and windows.
static func house_walls(size: Vector3, wall_color: Color, ruined: bool) -> Node3D:
	var house := Node3D.new()
	var plaster := wall_color.lightened(0.25) if not ruined else wall_color
	house.add_child(box(Vector3(size.x, size.y + 3.0, size.z), Surfaces.Pattern.PLASTER, plaster, Vector3.UP * (size.y - 3.0) / 2.0))

	var base_size := Vector3(size.x + 0.2, FOUNDATION_HEIGHT + 3.0, size.z + 0.2)
	house.add_child(box(base_size, Surfaces.Pattern.STONE, STONE_COLOR, Vector3.UP * (FOUNDATION_HEIGHT - 3.0) / 2.0))

	var half := Vector3(size.x, 0.0, size.z) / 2.0
	if not ruined:
		for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var at := Vector3(corner.x * half.x, size.y / 2.0, corner.y * half.z)
			house.add_child(box(Vector3(BEAM, size.y, BEAM), Surfaces.Pattern.WOOD, TIMBER_COLOR, at))
		for height: float in [FOUNDATION_HEIGHT + 0.1, size.y * 0.62, size.y - BEAM / 2.0]:
			for side: float in [1.0, -1.0]:
				var front := Vector3(0.0, height, side * (half.z + 0.03))
				house.add_child(box(Vector3(size.x, BEAM, 0.06), Surfaces.Pattern.WOOD, TIMBER_COLOR, front))
				var flank := Vector3(side * (half.x + 0.03), height, 0.0)
				house.add_child(box(Vector3(0.06, BEAM, size.z), Surfaces.Pattern.WOOD, TIMBER_COLOR, flank))

	# The door faces +z, and windows sit on either side of it and on the back.
	var door_at := Vector3(0.0, FOUNDATION_HEIGHT + DOOR_SIZE.y / 2.0 - 0.3, half.z + OPENING_DEPTH / 2.0)
	var door_color := OPENING_COLOR if ruined else WOOD_COLOR
	house.add_child(box(Vector3(DOOR_SIZE.x, DOOR_SIZE.y, OPENING_DEPTH), Surfaces.Pattern.WOOD, door_color, door_at))
	var window_height := minf(size.y * 0.42 + 0.5, size.y - 0.9)
	for side: float in [1.0, -1.0]:
		house.add_child(_window(Vector3(side * size.x * 0.3, window_height, half.z)))
		house.add_child(_window(Vector3(side * size.x * 0.3, window_height, -half.z)))
	return house


## A free-standing wall of rough stone blocks laid in courses, with every other course offset
## and each block a little off in size and tilt. Like the houses, it joins into one mesh.
## The same seed always gives the same wall. Blocks stick out of the front and back by a few
## centimeters, so the wall is a bit thicker than `thickness`.
static func stone_wall(length: float, height: float, thickness: float, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wall := Node3D.new()
	var course_count := maxi(1, roundi(height / WALL_COURSE_HEIGHT))
	var course_height := height / course_count
	for course in course_count:
		var x := -length / 2.0
		if course % 2 == 1:
			x -= rng.randf_range(0.1, WALL_BLOCK_LENGTH.x)
		while x < length / 2.0 - 0.01:
			var block_length := rng.randf_range(WALL_BLOCK_LENGTH.x, WALL_BLOCK_LENGTH.y)
			var left := maxf(x, -length / 2.0)
			var right := minf(x + block_length, length / 2.0)
			x += block_length
			if right - left < 0.15:
				continue
			var size := Vector3(right - left - WALL_GAP, course_height - WALL_GAP, thickness + rng.randf_range(-0.04, 0.04))
			var at := Vector3((left + right) / 2.0, (course + 0.5) * course_height, 0.0)
			var block := box(size, Surfaces.Pattern.STONE, STONE_COLOR.lightened(WALL_TINTS[rng.randi() % WALL_TINTS.size()]), at)
			block.rotation = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.02, 0.02))
			wall.add_child(block)
	merged(wall)
	return _solid(wall, Vector3(length, height, thickness))


## A fence of upright logs with a rail across them, for forts and enclosures. The
## logs are close together and differ a little in height.
static func palisade(length: float, height: float, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fence := Node3D.new()
	var count := maxi(1, ceili(length / PALISADE_POST_WIDTH))
	var step := length / count
	for i in count:
		var post_height := height * rng.randf_range(0.9, 1.0)
		var at := Vector3(-length / 2.0 + (i + 0.5) * step, post_height / 2.0, 0.0)
		fence.add_child(box(Vector3(step - 0.02, post_height, PALISADE_POST_WIDTH), Surfaces.Pattern.WOOD, TIMBER_COLOR.lightened(WALL_TINTS[rng.randi() % WALL_TINTS.size()]), at))
	fence.add_child(box(Vector3(length, BEAM, 0.1), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, height * 0.6, PALISADE_POST_WIDTH / 2.0 + 0.04)))
	merged(fence)
	return _solid(fence, Vector3(length, height, PALISADE_POST_WIDTH))


## The model on a body that stops people with a box the size of the wall.
static func _solid(model: Node3D, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(model)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = Vector3.UP * size.y / 2.0
	body.add_child(shape)
	return body


static func house_roof(width: float, depth: float, wall_height: float) -> MeshInstance3D:
	var roof := PrismMesh.new()
	roof.size = Vector3(width + ROOF_OVERHANG, ROOF_HEIGHT, depth + ROOF_OVERHANG)
	roof.material = Surfaces.get_material(Surfaces.Pattern.SHINGLES, ROOF_COLOR)
	var instance := MeshInstance3D.new()
	instance.mesh = roof
	instance.position = Vector3.UP * (wall_height + ROOF_HEIGHT / 2.0)
	return instance


static func chimney(width: float, depth: float, wall_height: float) -> MeshInstance3D:
	var at := Vector3(width * 0.25, wall_height + ROOF_HEIGHT * 0.65, depth * 0.2)
	return box(Vector3(0.7, 2.2, 0.7), Surfaces.Pattern.STONE, STONE_COLOR, at)


## A few bare rafters and loose planks where the roof should be.
static func damaged_roof(width: float, depth: float, wall_height: float) -> Node3D:
	var damaged := Node3D.new()
	damaged.name = "DamagedRoof"
	for offset: float in [-0.4, -0.05, 0.3]:
		var at := Vector3(width * -0.2, wall_height + 1.0, depth * offset)
		var rafter := box(Vector3(width * 0.65, 0.2, 0.3), Surfaces.Pattern.WOOD, TIMBER_COLOR, at)
		rafter.rotation.z = 0.4
		damaged.add_child(rafter)
	var plank_at := Vector3(width * 0.2, wall_height + 0.6, depth * 0.25)
	var plank := box(Vector3(width * 0.45, 0.1, depth * 0.4), Surfaces.Pattern.WOOD, WOOD_COLOR, plank_at)
	plank.rotation.z = -0.35
	damaged.add_child(plank)
	return damaged


## Returns the visual model for a named prop, sized to fit the given box.
static func prop(model: String, size: Vector3) -> Node3D:
	match model:
		"furnace":
			return merged(_furnace(size))
		"anvil":
			return merged(_anvil(size))
		"campfire":
			var campfire := merged(_campfire(size))
			campfire.add_child(CampfireFire.new())
			return campfire
		"ladder":
			return merged(_ladder(size))
		"bed":
			return merged(_bed(size))
	return box(size, Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * size.y / 2.0)


## A low wooden arch along its local z axis, with railings, resting on stone piers.
static func bridge(length: float, width: float, rise: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	for i in BRIDGE_SEGMENTS:
		var from := _arch_point(float(i) / BRIDGE_SEGMENTS, length, rise)
		var to := _arch_point(float(i + 1) / BRIDGE_SEGMENTS, length, rise)
		var segment := Node3D.new()
		segment.position = (from + to) / 2.0
		segment.rotation.x = atan2(from.y - to.y, to.z - from.z)
		body.add_child(segment)
		var run := from.distance_to(to) + 0.02
		_add_bridge_part(body, segment, Vector3(width, BRIDGE_DECK_THICKNESS, run), Vector3.DOWN * BRIDGE_DECK_THICKNESS / 2.0, TIMBER_COLOR.lightened(0.15))
		for side: float in [-1.0, 1.0]:
			var rail_at := Vector3(side * (width - BRIDGE_RAIL_THICKNESS) / 2.0, BRIDGE_RAIL_HEIGHT, 0.0)
			_add_bridge_part(body, segment, Vector3(BRIDGE_RAIL_THICKNESS, BRIDGE_RAIL_THICKNESS, run), rail_at, TIMBER_COLOR)
			var post := box(Vector3(BRIDGE_RAIL_THICKNESS, BRIDGE_RAIL_HEIGHT, BRIDGE_RAIL_THICKNESS), Surfaces.Pattern.WOOD, TIMBER_COLOR, rail_at + Vector3.DOWN * BRIDGE_RAIL_HEIGHT / 2.0)
			segment.add_child(post)
			var guard := CollisionShape3D.new()
			var guard_shape := BoxShape3D.new()
			guard_shape.size = Vector3(BRIDGE_RAIL_THICKNESS, BRIDGE_RAIL_HEIGHT, run)
			guard.shape = guard_shape
			guard.transform = segment.transform * Transform3D(Basis.IDENTITY, Vector3(rail_at.x, BRIDGE_RAIL_HEIGHT / 2.0, 0.0))
			body.add_child(guard)
	for progress: float in [0.3, 0.7]:
		var at := _arch_point(progress, length, rise)
		var pier_height := at.y + BRIDGE_PIER_DEPTH - BRIDGE_DECK_THICKNESS
		body.add_child(box(Vector3(width, pier_height, 0.8), Surfaces.Pattern.STONE, STONE_COLOR, Vector3(0.0, at.y - BRIDGE_DECK_THICKNESS - pier_height / 2.0, at.z)))
	return merged(body)


## The top of the deck, from one end at 0 to the other at 1. Both ends are at height 0.
static func _arch_point(progress: float, length: float, rise: float) -> Vector3:
	var across := progress * 2.0 - 1.0
	return Vector3(0.0, rise * (1.0 - across * across), across * length / 2.0)


static func _add_bridge_part(body: StaticBody3D, segment: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	segment.add_child(box(size, Surfaces.Pattern.WOOD, color, at))
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = segment.transform * Transform3D(Basis.IDENTITY, at)
	body.add_child(collision)


## A stack of logs for the wood gathering spots.
static func wood_pile(size: float) -> Node3D:
	var pile := Node3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16 * size
	mesh.bottom_radius = 0.16 * size
	mesh.height = 1.5 * size
	mesh.radial_segments = 8
	mesh.material = Surfaces.get_material(Surfaces.Pattern.WOOD, WOOD_COLOR)
	var spacing := 0.34 * size
	var rows := [[-1.0, 0.0, 1.0], [-0.5, 0.5], [0.0]]
	for row in rows.size():
		for column: float in rows[row]:
			var log_mesh := MeshInstance3D.new()
			log_mesh.mesh = mesh
			log_mesh.position = Vector3(column * spacing, 0.16 * size + row * spacing * 0.85, 0.0)
			log_mesh.rotation.x = PI / 2.0
			pile.add_child(log_mesh)
	return merged(pile)


## A stick with a wrapped head and a flame. Its origin is where the hand grips it.
static func torch() -> Node3D:
	var model := Node3D.new()
	model.add_child(box(Vector3(0.04, 0.6, 0.04), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * 0.2))
	model.add_child(box(Vector3(0.08, 0.14, 0.08), Surfaces.Pattern.PLASTER, IRON_COLOR, Vector3.UP * 0.5))
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.07
	flame_mesh.height = 0.26
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	flame_mesh.material = _fire_material(2.5)
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.name = "Flame"
	flame.position = Vector3.UP * TORCH_FLAME_HEIGHT
	model.add_child(flame)
	return model


static func _fire_material(energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = FIRE_COLOR
	material.emission_enabled = true
	material.emission = FIRE_COLOR
	material.emission_energy_multiplier = energy
	return material


static func _window(at: Vector3) -> Node3D:
	var window := Node3D.new()
	window.position = at
	var frame_size := Vector3(WINDOW_SIZE.x + 0.2, WINDOW_SIZE.y + 0.2, OPENING_DEPTH)
	window.add_child(box(frame_size, Surfaces.Pattern.WOOD, TIMBER_COLOR))
	var pane := Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, OPENING_DEPTH * 2.0)
	window.add_child(box(pane, Surfaces.Pattern.PLASTER, OPENING_COLOR))
	return window


static func _furnace(size: Vector3) -> Node3D:
	var furnace := Node3D.new()
	furnace.add_child(box(size, Surfaces.Pattern.STONE, STONE_COLOR.darkened(0.15), Vector3.UP * size.y / 2.0))
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(size.x * 0.5, size.y * 0.25, 0.05)
	mouth_mesh.material = _fire_material(0.9)
	var mouth := MeshInstance3D.new()
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(0.0, size.y * 0.3, size.z / 2.0 + 0.03)
	furnace.add_child(mouth)
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position = Vector3(0.0, size.y * 0.3, size.z / 2.0 + 0.5)
	furnace.add_child(light)
	furnace.add_child(box(Vector3(0.6, 1.2, 0.6), Surfaces.Pattern.STONE, STONE_COLOR.darkened(0.15), Vector3.UP * (size.y + 0.6)))
	return furnace


static func _anvil(size: Vector3) -> Node3D:
	var anvil := Node3D.new()
	var base_height := size.y * 0.55
	anvil.add_child(box(Vector3(size.x * 0.5, base_height, size.z), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * base_height / 2.0))
	var waist_at := Vector3.UP * (base_height + size.y * 0.12)
	anvil.add_child(box(Vector3(size.x * 0.35, size.y * 0.25, size.z * 0.5), Surfaces.Pattern.PLASTER, IRON_COLOR, waist_at))
	var top_at := Vector3.UP * (size.y - size.y * 0.1)
	anvil.add_child(box(Vector3(size.x, size.y * 0.2, size.z * 0.7), Surfaces.Pattern.PLASTER, IRON_COLOR, top_at))
	return anvil


## A ring of stones around a few crossed logs. The flame and light come from CampfireFire.
static func _campfire(size: Vector3) -> Node3D:
	var campfire := Node3D.new()
	var radius := minf(size.x, size.z) / 2.0
	var stones := 8
	for i in stones:
		var angle := TAU * i / stones
		var stone_size := Vector3(0.22, 0.16 + 0.04 * (i % 2), 0.18)
		var stone := box(stone_size, Surfaces.Pattern.STONE, STONE_COLOR.lightened(WALL_TINTS[i % WALL_TINTS.size()]), Vector3(cos(angle) * radius, stone_size.y / 2.0, sin(angle) * radius))
		stone.rotation.y = -angle
		campfire.add_child(stone)
	for i in 3:
		var log_mesh := box(Vector3(radius * 1.5, 0.1, 0.1), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * (0.08 + 0.07 * (i % 2)))
		log_mesh.rotation.y = PI * i / 3.0 + 0.3
		campfire.add_child(log_mesh)
	return campfire


static func _ladder(size: Vector3) -> Node3D:
	var ladder := Node3D.new()
	for side: float in [-1.0, 1.0]:
		ladder.add_child(box(Vector3(0.08, size.y, 0.08), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(side * size.x / 2.0, size.y / 2.0, 0.0)))
	var rung_count := int(size.y / 0.4)
	for rung in rung_count:
		ladder.add_child(box(Vector3(size.x, 0.05, 0.05), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, 0.3 + rung * 0.4, 0.0)))
	ladder.rotation.x = -0.15
	return ladder


const PAPER_COLOR := Color(0.82, 0.76, 0.6)
const READABLE_MODELS: Array[String] = ["signpost", "board", "note", "book"]


## A readable thing built from boxes, facing +z: a "signpost" (a post with a plank and a pointing arm),
## a "board" (a notice board on two posts with pinned papers), a "note" (a paper on a small stand), or
## a "book" (an open book on a lectern). The size is the box it fills.
static func readable(model: String, size: Vector3) -> Node3D:
	var root := Node3D.new()
	match model:
		"board":
			for side: float in [-1.0, 1.0]:
				root.add_child(box(Vector3(0.14, size.y, 0.14), Surfaces.Pattern.WOOD, TIMBER_COLOR, Vector3(side * (size.x / 2.0 - 0.07), size.y / 2.0, 0.0)))
			root.add_child(box(Vector3(size.x, size.y * 0.5, 0.08), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, size.y * 0.68, 0.0)))
			root.add_child(box(Vector3(size.x, 0.12, 0.2), Surfaces.Pattern.WOOD, TIMBER_COLOR, Vector3(0.0, size.y * 0.95, 0.0)))
			for paper: Array in [[-0.3, 0.72, 0.3, 0.4], [0.15, 0.66, 0.28, 0.34], [0.45, 0.76, 0.2, 0.26]]:
				root.add_child(box(Vector3(size.x * paper[2], size.y * paper[3] * 0.6, 0.02), Surfaces.Pattern.PLASTER, PAPER_COLOR, Vector3(size.x * paper[0], size.y * paper[1], 0.05)))
		"note":
			root.add_child(box(Vector3(0.1, size.y * 0.75, 0.1), Surfaces.Pattern.WOOD, TIMBER_COLOR, Vector3(0.0, size.y * 0.375, 0.0)))
			var top := box(Vector3(size.x, 0.06, size.z), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, size.y * 0.78, 0.0))
			top.rotation.x = -0.35
			root.add_child(top)
			var paper := box(Vector3(size.x * 0.7, 0.02, size.z * 0.7), Surfaces.Pattern.PLASTER, PAPER_COLOR, Vector3(0.0, size.y * 0.78 + 0.05, 0.0))
			paper.rotation.x = -0.35
			root.add_child(paper)
		"book":
			root.add_child(box(Vector3(0.12, size.y * 0.75, 0.12), Surfaces.Pattern.WOOD, TIMBER_COLOR, Vector3(0.0, size.y * 0.375, 0.0)))
			var slope := box(Vector3(size.x, 0.07, size.z), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, size.y * 0.8, 0.0))
			slope.rotation.x = -0.5
			root.add_child(slope)
			for side: float in [-1.0, 1.0]:
				var page := box(Vector3(size.x * 0.4, 0.04, size.z * 0.8), Surfaces.Pattern.PLASTER, PAPER_COLOR, Vector3(side * size.x * 0.21, size.y * 0.8 + 0.06, 0.0))
				page.rotation.x = -0.5
				root.add_child(page)
			var spine := box(Vector3(size.x * 0.06, 0.06, size.z * 0.85), Surfaces.Pattern.WOOD, CLOTH_COLOR, Vector3(0.0, size.y * 0.8 + 0.05, 0.0))
			spine.rotation.x = -0.5
			root.add_child(spine)
		_:
			root.add_child(box(Vector3(0.16, size.y, 0.16), Surfaces.Pattern.WOOD, TIMBER_COLOR, Vector3(0.0, size.y / 2.0, 0.0)))
			root.add_child(box(Vector3(size.x, size.y * 0.28, 0.07), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, size.y * 0.8, 0.11)))
			root.add_child(box(Vector3(size.x * 0.7, size.y * 0.2, 0.07), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(size.x * 0.12, size.y * 0.5, 0.11)))
	return merged(root)


static func _bed(size: Vector3) -> Node3D:
	var bed := Node3D.new()
	bed.add_child(box(size, Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * size.y / 2.0))
	var blanket := Vector3(size.x * 0.7, 0.12, size.z * 0.95)
	bed.add_child(box(blanket, Surfaces.Pattern.PLASTER, CLOTH_COLOR, Vector3(size.x * -0.12, size.y + 0.06, 0.0)))
	var pillow := Vector3(size.x * 0.2, 0.14, size.z * 0.7)
	bed.add_child(box(pillow, Surfaces.Pattern.PLASTER, Color(0.75, 0.72, 0.65), Vector3(size.x * 0.36, size.y + 0.07, 0.0)))
	return bed
