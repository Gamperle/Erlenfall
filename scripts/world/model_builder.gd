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


static func box(size: Vector3, pattern: Surfaces.Pattern, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Surfaces.get_material(pattern, color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


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
			return _furnace(size)
		"anvil":
			return _anvil(size)
		"ladder":
			return _ladder(size)
		"bed":
			return _bed(size)
	return box(size, Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * size.y / 2.0)


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
	return pile


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


static func _ladder(size: Vector3) -> Node3D:
	var ladder := Node3D.new()
	for side: float in [-1.0, 1.0]:
		ladder.add_child(box(Vector3(0.08, size.y, 0.08), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(side * size.x / 2.0, size.y / 2.0, 0.0)))
	var rung_count := int(size.y / 0.4)
	for rung in rung_count:
		ladder.add_child(box(Vector3(size.x, 0.05, 0.05), Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3(0.0, 0.3 + rung * 0.4, 0.0)))
	ladder.rotation.z = -0.15
	return ladder


static func _bed(size: Vector3) -> Node3D:
	var bed := Node3D.new()
	bed.add_child(box(size, Surfaces.Pattern.WOOD, WOOD_COLOR, Vector3.UP * size.y / 2.0))
	var blanket := Vector3(size.x * 0.7, 0.12, size.z * 0.95)
	bed.add_child(box(blanket, Surfaces.Pattern.PLASTER, CLOTH_COLOR, Vector3(size.x * -0.12, size.y + 0.06, 0.0)))
	var pillow := Vector3(size.x * 0.2, 0.14, size.z * 0.7)
	bed.add_child(box(pillow, Surfaces.Pattern.PLASTER, Color(0.75, 0.72, 0.65), Vector3(size.x * 0.36, size.y + 0.07, 0.0)))
	return bed
