class_name StructureBuilder
extends RefCounted
## The small buildings and work pieces of the forge, the lumber yard, the carpenter, the farms and the
## mine, built in code from boxes like the houses (#436, see docs/WALLS_AND_BUILDINGS.md). Each one is
## sized exactly, stands on its footprint's middle with its front toward +z, and joins into one mesh.
## `build` returns a StaticBody3D with the collision people bump into. A roofed one also carries a
## "cover" meta: where it keeps the rain off (see RoofMap).

## Every kind that `build` knows, for the data validator.
const KINDS: Array[String] = ["smithy_forge_shed", "lumber_shed", "sawmill_lean_to", "carpenter_workshop", "small_barn", "granary", "tool_shed", "ore_chute"]

const WOOD := Color(0.42, 0.28, 0.16)
const DARK_WOOD := Color(0.2, 0.13, 0.08)
const PLANK := Color(0.5, 0.38, 0.25)
const STONE := Color(0.42, 0.4, 0.37)
const ROOF := Color(0.36, 0.24, 0.18)
const IRON := Color(0.16, 0.17, 0.19)
const SOOT := Color(0.12, 0.11, 0.1)
const POST := 0.24
## How far under the ground the footings reach, so that nothing floats over a slope.
const SINK := 1.5
const ROOF_THICKNESS := 0.14
const OVERHANG := 0.5
## Rail pieces are this long, and the rails are this far apart (the gauge).
const RAIL_PIECE := 2.0
const RAIL_GAUGE := 0.9
const RAIL_STEPS := 4


## Builds the named kind. `variant` picks one of a kind's looks (barns and sheds have several).
static func build(kind: String, width: float, depth: float, height: float, color: Color, variant := 0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var look := Node3D.new()
	look.name = "Look"
	body.add_child(look)
	match kind:
		"smithy_forge_shed":
			_forge_shed(body, look, width, depth, height)
		"lumber_shed":
			_lumber_shed(body, look, width, depth, height)
		"sawmill_lean_to":
			_sawmill(body, look, width, depth, height, variant)
		"carpenter_workshop":
			_workshop(body, look, width, depth, height, color)
		"small_barn":
			_barn(body, look, width, depth, height, color, variant)
		"granary":
			_granary(body, look, width, depth, height, color)
		"tool_shed":
			_tool_shed(body, look, width, depth, height, color, variant)
		"ore_chute":
			_ore_chute(body, look, width, depth, height)
		_:
			push_error("StructureBuilder: unknown kind %s" % kind)
	ModelBuilder.merged(look)
	return body


## Straight (turn 0) or curved rail piece, 2 m long along +z, starting at its origin. `turn` is the
## angle the track bends over the piece, in radians, positive to the left (toward -x). Sleepers
## and two iron rails, no collision: they are only a few centimeters high.
static func rail_track(turn := 0.0, sleeper_color := Color(0.3, 0.22, 0.15)) -> Node3D:
	var piece := Node3D.new()
	var step := RAIL_PIECE / RAIL_STEPS
	var at := Vector3.ZERO
	for i in RAIL_STEPS:
		var heading := turn * (i + 0.5) / RAIL_STEPS
		var along := Vector3(-sin(heading), 0.0, cos(heading))
		var segment := Node3D.new()
		segment.position = at + along * step / 2.0
		segment.rotation.y = heading
		piece.add_child(segment)
		segment.add_child(ModelBuilder.box(Vector3(RAIL_GAUGE + 0.5, 0.1, 0.2), Surfaces.Pattern.WOOD, sleeper_color, Vector3(0.0, 0.05, 0.0)))
		for side: float in [-1.0, 1.0]:
			# A touch longer than the step, so the rails of a curve close their corners.
			segment.add_child(ModelBuilder.box(Vector3(0.08, 0.1, step + 0.04), Surfaces.Pattern.BOULDER, IRON, Vector3(side * RAIL_GAUGE / 2.0, 0.15, 0.0)))
		at += along * step
	return piece


## Where a rail piece with this turn ends, in the piece's own space: its position and heading.
static func rail_end(turn: float) -> Transform3D:
	var at := Vector3.ZERO
	var step := RAIL_PIECE / RAIL_STEPS
	for i in RAIL_STEPS:
		var heading := turn * (i + 0.5) / RAIL_STEPS
		at += Vector3(-sin(heading), 0.0, cos(heading)) * step
	return Transform3D(Basis(Vector3.UP, turn), at)


## A timbered frame for a mine mouth: two posts, a lintel, corner braces, and a plank header
## over the opening. The opening it frames is `opening_width` by `opening_height`; the frame
## stands around it, with its front at z = 0.
static func mine_timber_entrance(opening_width: float, opening_height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var look := Node3D.new()
	look.name = "Look"
	body.add_child(look)
	var half := opening_width / 2.0
	var beam := 0.5
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (half + beam / 2.0), opening_height / 2.0, 0.0)
		look.add_child(ModelBuilder.box(Vector3(beam, opening_height, beam), Surfaces.Pattern.UPRIGHT_WOOD, DARK_WOOD, at))
		_collider(body, Vector3(beam, opening_height, beam), at)
		look.add_child(ModelBuilder.box(Vector3(beam + 0.3, 0.3, beam + 0.3), Surfaces.Pattern.BOULDER, STONE, Vector3(side * (half + beam / 2.0), 0.15, 0.0)))
		_strut(look, Vector3(side * half, opening_height - 1.1, 0.0), Vector3(side * (half - 1.0), opening_height - 0.05, 0.0), 0.28, DARK_WOOD)
	look.add_child(ModelBuilder.box(Vector3(opening_width + beam * 2.0 + 0.6, beam, beam + 0.1), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, opening_height + beam / 2.0, 0.0)))
	_collider(body, Vector3(opening_width + beam * 2.0, beam, beam), Vector3(0.0, opening_height + beam / 2.0, 0.0))
	# Planks nailed over the lintel, and two cap beams running back into the rock.
	look.add_child(ModelBuilder.box(Vector3(opening_width + beam * 2.0, 0.9, 0.18), Surfaces.Pattern.UPRIGHT_WOOD, WOOD, Vector3(0.0, opening_height + beam + 0.45, 0.2)))
	for side: float in [-1.0, 1.0]:
		look.add_child(ModelBuilder.box(Vector3(0.3, 0.3, 2.4), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(side * (half - 0.1), opening_height + beam + 0.15, -1.1)))
	ModelBuilder.merged(look)
	return body


# -- A lean-to by the forge: an open roof on posts with a hearth and a chimney ---------------------

static func _forge_shed(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float) -> void:
	# The back is the forge's wall, so the roof slopes down toward the front.
	var low := height - 0.8
	_floor(look, width, depth, STONE)
	for x: float in [-1.0, 1.0]:
		_post(body, look, Vector3(x * (width / 2.0 - POST / 2.0), 0.0, depth / 2.0 - POST / 2.0), low)
		_post(body, look, Vector3(x * (width / 2.0 - POST / 2.0), 0.0, -depth / 2.0 + POST / 2.0), height)
	_shed_roof(look, width, depth, height, low, OVERHANG, ROOF)
	# A stone hearth in the left back corner with a chimney stack through the roof.
	var hearth := Vector3(1.6, 1.0, 1.2)
	var hearth_at := Vector3(-width / 2.0 + 1.3, 0.5, -depth / 2.0 + 0.8)
	look.add_child(ModelBuilder.box(hearth, Surfaces.Pattern.STONE, STONE, hearth_at))
	look.add_child(ModelBuilder.box(Vector3(1.0, 0.1, 0.7), Surfaces.Pattern.BOULDER, SOOT, hearth_at + Vector3(0.0, 0.5, 0.05)))
	_collider(body, hearth, hearth_at)
	var stack_height := height + 1.8
	var stack_at := Vector3(hearth_at.x, stack_height / 2.0, hearth_at.z)
	look.add_child(ModelBuilder.box(Vector3(0.8, stack_height, 0.8), Surfaces.Pattern.STONE, STONE, stack_at))
	look.add_child(ModelBuilder.box(Vector3(1.0, 0.18, 1.0), Surfaces.Pattern.STONE, STONE, Vector3(stack_at.x, stack_height, stack_at.z)))
	# A rail on the back posts for hanging tools.
	look.add_child(ModelBuilder.box(Vector3(1.8, 0.1, 0.3), Surfaces.Pattern.WOOD, WOOD, Vector3(width / 2.0 - 1.2, 1.5, -depth / 2.0 + 0.2)))
	_set_cover(body, Vector2(0.0, OVERHANG / 2.0), Vector2(width + OVERHANG * 2.0, depth + OVERHANG) / 2.0, low, 0.0)


# -- Lumber yard: a shed open at the front for drying planks and logs ------------------------------

static func _lumber_shed(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float) -> void:
	var low := height - 0.7
	_floor(look, width, depth, WOOD.darkened(0.2))
	# Plank walls at the back and sides, shoulder high on the sides.
	var back := Vector3(width, height, 0.16)
	var back_at := Vector3(0.0, height / 2.0, -depth / 2.0 + 0.08)
	look.add_child(ModelBuilder.box(back, Surfaces.Pattern.UPRIGHT_WOOD, PLANK.darkened(0.15), back_at))
	_collider(body, back, back_at)
	for side: float in [-1.0, 1.0]:
		var wall := Vector3(0.14, 1.3, depth - 0.3)
		var wall_at := Vector3(side * (width / 2.0 - 0.07), 0.65, -0.1)
		look.add_child(ModelBuilder.box(wall, Surfaces.Pattern.UPRIGHT_WOOD, PLANK.darkened(0.15), wall_at))
		_collider(body, wall, wall_at)
	var posts := maxi(2, roundi(width / 3.0) + 1)
	for i in posts:
		var x := lerpf(-width / 2.0 + POST / 2.0, width / 2.0 - POST / 2.0, float(i) / (posts - 1))
		_post(body, look, Vector3(x, 0.0, depth / 2.0 - POST / 2.0), low)
	for x: float in [-1.0, 1.0]:
		_post(body, look, Vector3(x * (width / 2.0 - POST / 2.0), 0.0, -depth / 2.0 + POST / 2.0), height)
	_shed_roof(look, width, depth, height, low, OVERHANG, ROOF)
	# Plank stacks, spaced with sticks, standing against the back.
	var stacks := maxi(2, floori(width / 2.2))
	for i in stacks:
		var x := lerpf(-width / 2.0 + 1.3, width / 2.0 - 1.3, float(i) / (stacks - 1))
		var stack_height := 0.9 + 0.35 * (i % 2)
		var stack_at := Vector3(x, stack_height / 2.0 + 0.1, -depth / 2.0 + 0.9)
		look.add_child(ModelBuilder.box(Vector3(1.5, stack_height, 1.0), Surfaces.Pattern.WOOD, PLANK, stack_at))
		for course in floori(stack_height / 0.3):
			look.add_child(ModelBuilder.box(Vector3(1.56, 0.06, 1.06), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(x, 0.4 + course * 0.3, stack_at.z)))
		_collider(body, Vector3(1.5, stack_height, 1.0), stack_at)
	_set_cover(body, Vector2(0.0, OVERHANG / 2.0), Vector2(width + OVERHANG * 2.0, depth + OVERHANG) / 2.0, low, 0.0)


# -- Sawmill: a roofed frame over the work place, open on three sides ------------------------------

## Variant 1 leaves the log and trestles out: the layout places the generated `sawpit_frame_1` there (#468).
static func _sawmill(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float, variant := 0) -> void:
	# A gable roof on a frame of six posts, with a plank back and a log lying on trestles.
	_floor(look, width, depth, Color(0.36, 0.28, 0.2))
	var posts := 3
	for i in posts:
		var x := lerpf(-width / 2.0 + POST / 2.0, width / 2.0 - POST / 2.0, float(i) / (posts - 1))
		_post(body, look, Vector3(x, 0.0, depth / 2.0 - POST / 2.0), height)
		_post(body, look, Vector3(x, 0.0, -depth / 2.0 + POST / 2.0), height)
	for z: float in [-1.0, 1.0]:
		look.add_child(ModelBuilder.box(Vector3(width, 0.22, 0.22), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, height - 0.11, z * (depth / 2.0 - POST / 2.0))))
	for x: float in [-1.0, 1.0]:
		look.add_child(ModelBuilder.box(Vector3(0.2, 0.2, depth), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(x * (width / 2.0 - POST / 2.0), height - 0.5, 0.0)))
	var back := Vector3(width, height * 0.55, 0.12)
	var back_at := Vector3(0.0, height * 0.275, -depth / 2.0 + 0.06)
	look.add_child(ModelBuilder.box(back, Surfaces.Pattern.UPRIGHT_WOOD, PLANK.darkened(0.2), back_at))
	_collider(body, back, back_at)
	_gable_roof(look, width, depth, height, 1.4)
	var log_length := minf(width - 1.0, 4.2)
	if variant == 1:
		# Sawdust only, under the generated log on trestles.
		look.add_child(ModelBuilder.box(Vector3(3.2, 0.05, 1.5), Surfaces.Pattern.PLASTER, Color(0.62, 0.5, 0.34), Vector3(0.0, 0.1, 0.2)))
	else:
		# A long log on two A-shaped trestles, with sawdust under it.
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.28
		log_mesh.bottom_radius = 0.31
		log_mesh.height = log_length
		log_mesh.radial_segments = 8
		log_mesh.material = Surfaces.get_material(Surfaces.Pattern.UPRIGHT_WOOD, Color(0.36, 0.26, 0.17))
		var log_node := MeshInstance3D.new()
		log_node.mesh = log_mesh
		log_node.position = Vector3(0.0, 0.95, 0.2)
		log_node.rotation.z = PI / 2.0
		look.add_child(log_node)
		for x: float in [-1.0, 1.0]:
			var trestle_x := x * log_length * 0.32
			for lean: float in [-1.0, 1.0]:
				_strut(look, Vector3(trestle_x, 0.0, 0.2 + lean * 0.5), Vector3(trestle_x, 0.78, 0.2 + lean * 0.12), 0.12, WOOD)
			look.add_child(ModelBuilder.box(Vector3(0.12, 0.12, 0.9), Surfaces.Pattern.WOOD, WOOD, Vector3(trestle_x, 0.72, 0.2)))
		look.add_child(ModelBuilder.box(Vector3(log_length + 0.2, 0.05, 1.5), Surfaces.Pattern.PLASTER, Color(0.62, 0.5, 0.34), Vector3(0.0, 0.1, 0.2)))
		_collider(body, Vector3(log_length, 1.3, 0.7), Vector3(0.0, 0.65, 0.2))
	_set_cover(body, Vector2.ZERO, Vector2(width + OVERHANG * 2.0, depth + OVERHANG * 2.0) / 2.0, height, 1.4)


# -- Carpenter's workshop: plastered timber walls, wide doors, and a loft ------------------------

static func _workshop(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float, color: Color) -> void:
	look.add_child(ModelBuilder.house_walls(Vector3(width, height, depth), color, false, true))
	_box_collider(body, width, depth, height)
	var half := depth / 2.0
	# Wide double doors over the house door, with a frame and cross braces.
	var door := Vector3(2.8, 2.5, 0.1)
	var door_at := Vector3(0.0, ModelBuilder.FOUNDATION_HEIGHT + door.y / 2.0 - 0.3, half + 0.1)
	look.add_child(ModelBuilder.box(door + Vector3(0.4, 0.3, 0.04), Surfaces.Pattern.WOOD, DARK_WOOD, door_at))
	look.add_child(ModelBuilder.box(door, Surfaces.Pattern.UPRIGHT_WOOD, WOOD, door_at + Vector3(0.0, 0.0, 0.04)))
	look.add_child(ModelBuilder.box(Vector3(0.06, door.y, 0.04), Surfaces.Pattern.WOOD, DARK_WOOD, door_at + Vector3(0.0, 0.0, 0.09)))
	for y: float in [-0.7, 0.7]:
		look.add_child(ModelBuilder.box(Vector3(door.x - 0.1, 0.14, 0.04), Surfaces.Pattern.WOOD, DARK_WOOD, door_at + Vector3(0.0, y, 0.1)))
	# The loft door high in the gable, with a hoist beam above it.
	# The roof's gable face stands half a meter in front of the wall, so the door sits on that.
	var gable := half + ModelBuilder.ROOF_OVERHANG / 2.0
	var loft_y := height + 0.8
	look.add_child(ModelBuilder.box(Vector3(1.0, 1.1, 0.08), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, loft_y, gable + 0.04)))
	look.add_child(ModelBuilder.box(Vector3(0.8, 0.9, 0.06), Surfaces.Pattern.UPRIGHT_WOOD, WOOD, Vector3(0.0, loft_y, gable + 0.09)))
	look.add_child(ModelBuilder.box(Vector3(0.16, 0.16, 1.1), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, loft_y + 0.95, gable + 0.45)))
	look.add_child(ModelBuilder.house_roof(width, depth, height))
	look.add_child(ModelBuilder.chimney(width, depth, height))
	_set_cover(body, Vector2.ZERO, Vector2(width + ModelBuilder.ROOF_OVERHANG, depth + ModelBuilder.ROOF_OVERHANG) / 2.0, height, ModelBuilder.ROOF_HEIGHT)


# -- Small barns: three looks for the farms ---------------------------------------------------------

## Variant 0 is a plain barn, 1 has an open lean-to along its side, and 2 has a porch roof over the doors.
static func _barn(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float, color: Color, variant: int) -> void:
	var rise := 2.0
	look.add_child(ModelBuilder.box(Vector3(width + 0.2, ModelBuilder.FOUNDATION_HEIGHT + SINK, depth + 0.2), Surfaces.Pattern.STONE, STONE, Vector3(0.0, (ModelBuilder.FOUNDATION_HEIGHT - SINK) / 2.0, 0.0)))
	look.add_child(ModelBuilder.box(Vector3(width, height + SINK, depth), Surfaces.Pattern.UPRIGHT_WOOD, color, Vector3(0.0, (height - SINK) / 2.0, 0.0)))
	_box_collider(body, width, depth, height)
	var half := Vector2(width, depth) / 2.0
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		look.add_child(ModelBuilder.box(Vector3(0.2, height, 0.2), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(corner.x * half.x, height / 2.0, corner.y * half.y)))
	# Large double doors in the gable end, braced with a cross, and a hay loft door over them.
	var door := Vector3(2.8, 2.7, 0.1)
	var door_at := Vector3(0.0, ModelBuilder.FOUNDATION_HEIGHT + door.y / 2.0 - 0.3, half.y + 0.06)
	look.add_child(ModelBuilder.box(door + Vector3(0.4, 0.3, 0.04), Surfaces.Pattern.WOOD, DARK_WOOD, door_at))
	for side: float in [-1.0, 1.0]:
		var middle := door_at + Vector3(side * door.x / 4.0, 0.0, 0.07)
		look.add_child(ModelBuilder.box(Vector3(door.x / 2.0 - 0.05, door.y, 0.06), Surfaces.Pattern.UPRIGHT_WOOD, WOOD, middle))
		_strut(look, middle + Vector3(-0.6, -door.y / 2.0 + 0.1, 0.05), middle + Vector3(0.6, door.y / 2.0 - 0.1, 0.05), 0.1, DARK_WOOD)
	var gable := half.y + OVERHANG
	var loft_y := height + 0.7
	look.add_child(ModelBuilder.box(Vector3(1.1, 1.1, 0.08), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, loft_y, gable + 0.04)))
	look.add_child(ModelBuilder.box(Vector3(0.9, 0.9, 0.06), Surfaces.Pattern.UPRIGHT_WOOD, WOOD.darkened(0.1), Vector3(0.0, loft_y, gable + 0.09)))
	look.add_child(ModelBuilder.box(Vector3(0.16, 0.16, 1.2), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, loft_y + 0.8, gable + 0.5)))
	_gable_roof(look, width, depth, height, rise)
	match variant:
		1:
			# An open lean-to for carts and hay on the +x side, roof sloping down from the barn's eave.
			var shed_depth := 2.4
			var shed_low := 2.1
			for z: float in [-1.0, 1.0]:
				_post(body, look, Vector3(width / 2.0 + shed_depth - POST / 2.0, 0.0, z * (depth / 2.0 - 0.5)), shed_low)
			var drop := height - 0.4 - shed_low
			var slab := ModelBuilder.box(Vector3(sqrt(shed_depth * shed_depth + drop * drop) + 0.3, ROOF_THICKNESS, depth - 0.6), Surfaces.Pattern.SHINGLES, ROOF)
			slab.position = Vector3(width / 2.0 + shed_depth / 2.0, (height - 0.4 + shed_low) / 2.0 + 0.05, 0.0)
			slab.rotation.z = -atan2(drop, shed_depth)
			look.add_child(slab)
			look.add_child(ModelBuilder.box(Vector3(shed_depth, 0.12, depth - 0.6), Surfaces.Pattern.WOOD, WOOD.darkened(0.2), Vector3(width / 2.0 + shed_depth / 2.0, 0.06, 0.0)))
		2:
			# A porch roof on two posts over the doors.
			var porch := 2.0
			for x: float in [-1.0, 1.0]:
				_post(body, look, Vector3(x * 1.8, 0.0, half.y + porch - POST / 2.0), 2.7)
			var slab := ModelBuilder.box(Vector3(4.4, ROOF_THICKNESS, porch + 0.5), Surfaces.Pattern.SHINGLES, ROOF)
			slab.position = Vector3(0.0, 3.0, half.y + porch / 2.0 - 0.05)
			slab.rotation.x = 0.16
			look.add_child(slab)
	_set_cover(body, Vector2.ZERO, Vector2(width + ModelBuilder.ROOF_OVERHANG, depth + ModelBuilder.ROOF_OVERHANG) / 2.0, height, rise)


# -- Granary: a timber store on stone mushrooms, with a stair outside ------------------------------

static func _granary(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float, color: Color) -> void:
	var lift := 0.8
	var walls_height := height - lift
	# Staddle stones: a stem and a wide flat cap, six of them under the floor.
	for x: float in [-1.0, 0.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var at := Vector3(x * (width / 2.0 - 0.35), 0.0, z * (depth / 2.0 - 0.35))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.17
			stem.bottom_radius = 0.24
			stem.height = lift - 0.1 + SINK
			stem.radial_segments = 7
			stem.material = Surfaces.get_material(Surfaces.Pattern.STONE, STONE)
			var stem_node := MeshInstance3D.new()
			stem_node.mesh = stem
			stem_node.position = at + Vector3(0.0, (lift - 0.1 - SINK) / 2.0, 0.0)
			look.add_child(stem_node)
			var cap := CylinderMesh.new()
			cap.top_radius = 0.42
			cap.bottom_radius = 0.2
			cap.height = 0.14
			cap.radial_segments = 8
			cap.material = Surfaces.get_material(Surfaces.Pattern.STONE, STONE.lightened(0.08))
			var cap_node := MeshInstance3D.new()
			cap_node.mesh = cap
			cap_node.position = at + Vector3(0.0, lift - 0.17, 0.0)
			look.add_child(cap_node)
	# Joists, then plank walls with corner posts, and a door.
	look.add_child(ModelBuilder.box(Vector3(width + 0.1, 0.2, depth + 0.1), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, lift - 0.1, 0.0)))
	look.add_child(ModelBuilder.box(Vector3(width, walls_height, depth), Surfaces.Pattern.UPRIGHT_WOOD, color, Vector3(0.0, lift + walls_height / 2.0, 0.0)))
	_collider(body, Vector3(width, height + SINK, depth), Vector3(0.0, (height - SINK) / 2.0, 0.0))
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		look.add_child(ModelBuilder.box(Vector3(0.18, walls_height, 0.18), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(corner.x * width / 2.0, lift + walls_height / 2.0, corner.y * depth / 2.0)))
	var front := depth / 2.0
	look.add_child(ModelBuilder.box(Vector3(1.1, 1.7, 0.1), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, lift + 0.85, front + 0.03)))
	look.add_child(ModelBuilder.box(Vector3(0.9, 1.55, 0.06), Surfaces.Pattern.UPRIGHT_WOOD, WOOD, Vector3(0.0, lift + 0.8, front + 0.08)))
	# A vent slit on each side, so the store breathes.
	for side: float in [-1.0, 1.0]:
		look.add_child(ModelBuilder.box(Vector3(0.06, 0.5, 0.18), Surfaces.Pattern.PLASTER, Color(0.04, 0.03, 0.03), Vector3(side * (width / 2.0 + 0.01), lift + walls_height * 0.55, -depth * 0.2)))
	# The stair: four solid steps rise toward the door, ending at a landing.
	var steps := 4
	var rise := lift / steps
	for i in steps:
		var step_height := rise * (i + 1)
		var step := Vector3(1.2, step_height + SINK, 0.4)
		var at := Vector3(0.0, (step_height - SINK) / 2.0, front + 0.25 + (steps - 1 - i) * 0.4 + 0.2)
		look.add_child(ModelBuilder.box(step, Surfaces.Pattern.WOOD, PLANK, at))
		_collider(body, step, at)
	var roof_rise := 1.4
	_gable_roof(look, width, depth, height, roof_rise)
	_set_cover(body, Vector2.ZERO, Vector2(width + OVERHANG * 2.0, depth + OVERHANG * 2.0) / 2.0, height, roof_rise)


# -- Tool shed: tiny, one door and one window ------------------------------------------------------

static func _tool_shed(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float, color: Color, variant: int) -> void:
	look.add_child(ModelBuilder.box(Vector3(width + 0.1, 0.4 + SINK, depth + 0.1), Surfaces.Pattern.STONE, STONE, Vector3(0.0, (0.4 - SINK) / 2.0, 0.0)))
	look.add_child(ModelBuilder.box(Vector3(width, height + SINK, depth), Surfaces.Pattern.UPRIGHT_WOOD, color, Vector3(0.0, (height - SINK) / 2.0, 0.0)))
	_box_collider(body, width, depth, height)
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		look.add_child(ModelBuilder.box(Vector3(0.12, height, 0.12), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(corner.x * width / 2.0, height / 2.0, corner.y * depth / 2.0)))
	var front := depth / 2.0
	var door_x := -width * 0.2
	look.add_child(ModelBuilder.box(Vector3(0.9, 1.75, 0.08), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(door_x, 0.4 + 0.85, front + 0.03)))
	look.add_child(ModelBuilder.box(Vector3(0.74, 1.6, 0.06), Surfaces.Pattern.UPRIGHT_WOOD, WOOD, Vector3(door_x, 0.4 + 0.8, front + 0.07)))
	look.add_child(ModelBuilder.box(Vector3(0.1, 0.1, 0.06), Surfaces.Pattern.BOULDER, IRON, Vector3(door_x + 0.27, 1.2, front + 0.12)))
	var window_x := width * 0.28
	look.add_child(ModelBuilder.box(Vector3(0.6, 0.6, 0.08), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(window_x, 1.25, front + 0.03)))
	look.add_child(ModelBuilder.box(Vector3(0.44, 0.44, 0.1), Surfaces.Pattern.PLASTER, Color(0.05, 0.04, 0.04), Vector3(window_x, 1.25, front + 0.04)))
	# Variant 0 has a low roof, variant 1 a steeper one with firewood stacked at the side.
	if variant == 0:
		_gable_roof(look, width, depth, height, 0.6)
		_set_cover(body, Vector2.ZERO, Vector2(width + OVERHANG * 2.0, depth + OVERHANG * 2.0) / 2.0, height, 0.6)
	else:
		_gable_roof(look, width, depth, height, 1.0)
		var stack := Vector3(0.45, 0.9, depth - 0.3)
		var stack_at := Vector3(width / 2.0 + stack.x / 2.0 + 0.05, 0.45, 0.0)
		look.add_child(ModelBuilder.box(stack, Surfaces.Pattern.UPRIGHT_WOOD, Color(0.36, 0.25, 0.15), stack_at))
		_collider(body, stack, stack_at)
		_set_cover(body, Vector2.ZERO, Vector2(width + OVERHANG * 2.0, depth + OVERHANG * 2.0) / 2.0, height, 1.0)


# -- Ore chute: a hopper on legs with a sloping trough ---------------------------------------------

## The hopper stands at the back (-z) and the trough runs toward the front (+z), ending over a cart's place.
static func _ore_chute(body: StaticBody3D, look: Node3D, width: float, depth: float, height: float) -> void:
	var hopper := minf(width, 2.0)
	var hopper_z := -depth / 2.0 + hopper / 2.0
	var top := height * 0.55
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_post(body, look, Vector3(x * (hopper / 2.0 - 0.15), 0.0, hopper_z + z * (hopper / 2.0 - 0.15)), top)
	# The hopper: four boards leaning outward, and a heap of rust-brown ore in it.
	var wall_height := 1.0
	for side: float in [-1.0, 1.0]:
		var board := ModelBuilder.box(Vector3(0.1, wall_height, hopper), Surfaces.Pattern.WOOD, WOOD, Vector3(side * (hopper / 2.0 - 0.05), top + wall_height / 2.0 - 0.1, hopper_z))
		board.rotation.z = -side * 0.3
		look.add_child(board)
		var end := ModelBuilder.box(Vector3(hopper - 0.1, wall_height, 0.1), Surfaces.Pattern.WOOD, WOOD, Vector3(0.0, top + wall_height / 2.0 - 0.1, hopper_z + side * (hopper / 2.0 - 0.05)))
		end.rotation.x = side * 0.3
		look.add_child(end)
	_collider(body, Vector3(hopper, top + wall_height, hopper), Vector3(0.0, (top + wall_height) / 2.0, hopper_z))
	look.add_child(ModelBuilder.box(Vector3(hopper * 0.7, 0.4, hopper * 0.7), Surfaces.Pattern.IRON_ORE, Color(0.5, 0.36, 0.28), Vector3(0.0, top + wall_height - 0.35, hopper_z)))
	# The trough slopes down from the hopper's foot to a low lip over the cart, held by two legs.
	var start := Vector3(0.0, top - 0.05, hopper_z + hopper / 2.0 - 0.1)
	var finish := Vector3(0.0, height * 0.3, depth / 2.0 - 0.2)
	var along := finish - start
	var trough := Node3D.new()
	trough.transform = Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), (start + finish) / 2.0)
	look.add_child(trough)
	trough.add_child(ModelBuilder.box(Vector3(0.7, 0.08, along.length()), Surfaces.Pattern.WOOD, DARK_WOOD))
	for side: float in [-1.0, 1.0]:
		trough.add_child(ModelBuilder.box(Vector3(0.08, 0.25, along.length()), Surfaces.Pattern.WOOD, WOOD, Vector3(side * 0.34, 0.13, 0.0)))
		_post(body, look, Vector3(side * 0.45, 0.0, depth / 2.0 - 0.3), height * 0.3 - 0.1)
	trough.add_child(ModelBuilder.box(Vector3(0.9, 0.06, 0.1), Surfaces.Pattern.BOULDER, IRON, Vector3(0.0, 0.1, 0.0)))


# -- Shared parts ----------------------------------------------------------------------------------

## A square post from under the ground up to `top`, with a collider.
static func _post(body: StaticBody3D, look: Node3D, at: Vector3, top: float) -> void:
	var size := Vector3(POST, top + SINK, POST)
	var middle := Vector3(at.x, (top - SINK) / 2.0, at.z)
	look.add_child(ModelBuilder.box(size, Surfaces.Pattern.WOOD, DARK_WOOD, middle))
	_collider(body, size, middle)


## A floor of boards or flagstones lying just above the ground.
static func _floor(look: Node3D, width: float, depth: float, color: Color) -> void:
	var pattern := Surfaces.Pattern.STONE if color == STONE else Surfaces.Pattern.WOOD
	look.add_child(ModelBuilder.box(Vector3(width, 0.15 + SINK, depth), pattern, color, Vector3(0.0, (0.15 - SINK) / 2.0, 0.0)))


## A mono-pitch roof, high at the back (-z, where a wall or the forge stands) and low at the front.
static func _shed_roof(look: Node3D, width: float, depth: float, high: float, low: float, overhang: float, color: Color) -> void:
	var run := depth + overhang
	var drop := high - low
	var slab := ModelBuilder.box(Vector3(width + overhang * 2.0, ROOF_THICKNESS, sqrt(run * run + drop * drop)), Surfaces.Pattern.SHINGLES, color)
	slab.position = Vector3(0.0, (high + low) / 2.0 + 0.05, -depth / 2.0 + run / 2.0)
	slab.rotation.x = atan2(drop, run)
	look.add_child(slab)
	# A beam under the front edge, holding it up.
	look.add_child(ModelBuilder.box(Vector3(width, 0.2, 0.2), Surfaces.Pattern.WOOD, DARK_WOOD, Vector3(0.0, low - 0.1, depth / 2.0 - POST / 2.0)))


## A gable roof with its ridge along z, `rise` high.
static func _gable_roof(look: Node3D, width: float, depth: float, wall_height: float, rise: float) -> void:
	var prism := PrismMesh.new()
	prism.size = Vector3(width + OVERHANG * 2.0, rise, depth + OVERHANG * 2.0)
	prism.material = Surfaces.get_material(Surfaces.Pattern.SHINGLES, ROOF)
	var roof := MeshInstance3D.new()
	roof.mesh = prism
	roof.position = Vector3(0.0, wall_height + rise / 2.0, 0.0)
	look.add_child(roof)


static func _collider(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = at
	body.add_child(shape)


## One box collider for a closed building, reaching below the ground.
static func _box_collider(body: StaticBody3D, width: float, depth: float, height: float) -> void:
	_collider(body, Vector3(width, height + SINK, depth), Vector3(0.0, (height - SINK) / 2.0, 0.0))


## A beam of the given thickness from one point to another.
static func _strut(look: Node3D, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var along := to - from
	var up := Vector3.RIGHT if absf(along.normalized().y) > 0.99 else Vector3.UP
	var strut := ModelBuilder.box(Vector3(thickness, thickness, along.length()), Surfaces.Pattern.WOOD, color)
	strut.transform = Transform3D(Basis.looking_at(along.normalized(), up), (from + to) / 2.0)
	look.add_child(strut)


## Notes where this structure keeps the rain off, in its own space: a ridge of `rise` over `base`.
static func _set_cover(body: StaticBody3D, offset: Vector2, half: Vector2, base: float, rise: float) -> void:
	body.set_meta("cover", { "offset": offset, "half": half, "base": base, "rise": rise })
