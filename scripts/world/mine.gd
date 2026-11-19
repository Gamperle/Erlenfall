class_name Mine
extends Node3D
## The buried mine's entrance: a cliff face, a collapsed timber frame, a rubble heap that blocks the
## way in, a tilted cart, rails, and a tall timber headframe with a winch shed that can be seen from afar. It is built from
## code-made shapes. The ground in front of it is flattened by Terrain, and the inside is not built.
## The entrance faces +z, so the node's rotation turns it toward the road.

const ROCK_COLOR := Color(0.36, 0.34, 0.32)
const DARK_ROCK_COLOR := Color(0.28, 0.26, 0.25)
const RUBBLE_TINT := Color(0.34, 0.31, 0.28)
const TIMBER := Color(0.24, 0.16, 0.1)
const OLD_TIMBER := Color(0.3, 0.22, 0.15)
const IRON := Color(0.18, 0.16, 0.15)
const SACK := Color(0.42, 0.35, 0.24)
const OPENING := Color(0.02, 0.02, 0.025)
const BEAM := 0.5
const RUBBLE_COUNT := 22
const RUBBLE_LUMPINESS := 0.3
const HEADFRAME_HEIGHT := 11.0
## How far below the ground the cliff's parts reach, so that none float over the slope behind.
const SINK := 3.0
## Where the plaza ends in front of the opening, and so where the path in is planned to.
const FRONT_DISTANCE := 7.0
## The sculpted face: where its front plane lies, the size of its cells, how tall its ledges are,
## how far it reaches beyond the cliff's width and above its top, to blend into the hill.
const FACE_FRONT := 0.8
const FACE_CELL := 0.5
const FACE_LEDGE := 1.8
const FACE_MARGIN := 4.0
const FACE_CREST := 3.0
const ROOT_COLOR := Color(0.2, 0.14, 0.09)
## How much each 2 m piece of the track in front of the opening bends, in radians (positive is left).
const RAIL_TURNS: Array[float] = [0.0, 0.0, 0.3]

var mine_id := ""
var landmark := false

var _data: Dictionary


func setup(data: Dictionary) -> void:
	_data = data
	mine_id = data["id"]
	name = mine_id
	landmark = data.get("compass", false)


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(_data["seed"])
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	var look := Node3D.new()
	look.name = "Look"
	_build_cliff(look, body)
	_build_cliff_rocks(look, body, random)
	_build_base_details(look, body, random)
	if _data.get("intact_frame", false):
		# For a mine that has been cleared: a standing timbered entrance that fits the opening (#436).
		var entrance := StructureBuilder.mine_timber_entrance(float(_data["opening_width"]), float(_data["opening_height"]))
		entrance.name = "TimberEntrance"
		entrance.position = Vector3(0.0, 0.0, 0.5)
		add_child(entrance)
	else:
		_build_frame(look, body)
	_build_rubble(look, body, random)
	_build_headframe(look, body)
	_build_mouth_details(look, random)
	_build_cart_and_rails(look, body)
	add_child(ModelBuilder.merged(look))


## Where the player stands to look at the entrance, in the world.
func front_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, FRONT_DISTANCE)


## Where the collapsed frame and the cliff's brow keep the rain off the mouth, for the rain map (see
## RoofMap). It is flat at the lintel and reaches out as far as the broken beams do. Call it once the
## mine has its place in the world.
func roof_cover() -> Dictionary:
	var opening: float = _data["opening_width"]
	var reach := 3.0
	var middle := Basis(Vector3.UP, rotation.y) * Vector3(0.0, 0.0, FACE_FRONT + reach / 2.0)
	return {
		"center": Vector2(position.x + middle.x, position.z + middle.z),
		"half": Vector2(opening / 2.0 + 0.8, reach / 2.0),
		"yaw": rotation.y, "base": position.y + float(_data["opening_height"]), "rise": 0.0,
		"shape": "ridge", "active": true,
	}


## The ground around the entrance that the layout asks Terrain to level.
static func plaza_of(data: Dictionary) -> Dictionary:
	return { "x": data["x"], "z": data["z"], "radius": data["plaza_radius"], "blend": data["plaza_blend"] }


func _build_cliff(look: Node3D, body: StaticBody3D) -> void:
	var width: float = _data["width"]
	var height: float = _data["height"]
	var opening: float = _data["opening_width"]
	var opening_height: float = _data["opening_height"]
	var side := (width - opening) / 2.0
	var side_x := opening / 2.0 + side / 2.0
	# Two buttresses either side of the opening, a slab over it, and a mass behind that fills the hill.
	# These only block the way. What is seen is the sculpted face below.
	_add_block(body, Vector3(side, height + SINK, 4.0), Vector3(-side_x, (height - SINK) / 2.0, -1.2), -3.0)
	_add_block(body, Vector3(side, height * 0.8 + SINK, 4.4), Vector3(side_x, (height * 0.8 - SINK) / 2.0, -1.4), 4.0)
	_add_block(body, Vector3(opening + 1.6, height - opening_height - 0.4, 3.2), Vector3(0.0, opening_height + 0.4 + (height - opening_height - 0.4) / 2.0, -1.0), 0.0)
	_add_block(body, Vector3(width + 6.0, height + 4.0 + SINK, 6.0), Vector3(0.0, (height + 4.0 - SINK) / 2.0, -5.0), 0.0)
	_build_cliff_face(look)
	# The dark of the tunnel, seen above the rubble.
	var dark := ModelBuilder.box(Vector3(opening, opening_height, 0.2), Surfaces.Pattern.BOULDER, OPENING, Vector3(0.0, opening_height / 2.0, -0.5))
	look.add_child(dark)


## The height of the cliff's face at (x, y) across its plane: ledges that step back as it rises, with
## rough noise on them, and a crest and sides that curl back so that the face melts into the hill.
func _face_z(x: float, y: float, top: float, noise: FastNoiseLite) -> float:
	var width: float = _data["width"]
	var ledge := y / FACE_LEDGE
	var steps := floorf(ledge) + smoothstep(0.65, 1.0, ledge - floorf(ledge))
	var z := FACE_FRONT - steps * 0.3 + noise.get_noise_2d(x * 2.0, y * 2.0) * 0.18 + noise.get_noise_2d(x * 0.7 + 50.0, y * 0.7) * 0.5
	var over := maxf(0.0, y - top)
	var out := maxf(0.0, absf(x) - width / 2.0)
	return z - over * 1.2 - out * out * 0.35


func _build_cliff_face(look: Node3D) -> void:
	var width: float = _data["width"]
	var height: float = _data["height"]
	var opening: float = _data["opening_width"]
	var opening_height: float = _data["opening_height"]
	var noise := FastNoiseLite.new()
	noise.seed = int(_data["seed"]) + 2
	noise.frequency = 0.5
	var half := width / 2.0 + FACE_MARGIN
	var columns := int(ceilf(half * 2.0 / FACE_CELL))
	var rows := int(ceilf((height + FACE_CREST + SINK) / FACE_CELL))
	var tops: PackedFloat32Array = []
	for column in columns + 1:
		var x := -half + column * FACE_CELL
		var fade := maxf(0.0, absf(x) - width / 2.0)
		tops.append(height + noise.get_noise_1d(x * 3.0 + 9.0) * 1.6 - fade * 0.9)
	var points: Array[Vector3] = []
	for row in rows + 1:
		for column in columns + 1:
			var x := -half + column * FACE_CELL
			var y := -SINK + row * FACE_CELL
			points.append(Vector3(x, y, _face_z(x, y, tops[column], noise)))
	var tools: Array[SurfaceTool] = []
	var materials: Array[Material] = [Surfaces.get_material(Surfaces.Pattern.BOULDER, ROCK_COLOR), Surfaces.get_material(Surfaces.Pattern.BOULDER, DARK_ROCK_COLOR)]
	for i in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(tool)
	for row in rows:
		for column in columns:
			var centre_x := -half + (column + 0.5) * FACE_CELL
			var centre_y := -SINK + (row + 0.5) * FACE_CELL
			if absf(centre_x) < opening / 2.0 and centre_y > 0.0 and centre_y < opening_height:
				continue
			var a := points[row * (columns + 1) + column]
			var b := points[row * (columns + 1) + column + 1]
			var c := points[(row + 1) * (columns + 1) + column + 1]
			var d := points[(row + 1) * (columns + 1) + column]
			# Strata of two shades, banded by ledge and broken up by noise.
			var strata := 1 if int(floorf(centre_y / FACE_LEDGE + noise.get_noise_2d(centre_x * 1.5, 7.0) * 0.8)) % 2 != 0 else 0
			var tool := tools[strata]
			for corner in [a, c, b, a, d, c]:
				tool.add_vertex(corner)
	var mesh := ArrayMesh.new()
	for i in 2:
		tools[i].generate_normals()
		tools[i].commit(mesh)
		mesh.surface_set_material(i, materials[i])
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = mesh
	look.add_child(face)


## Lumpy rocks along the cliff's top and feet, so that its outline is not a straight edge.
func _build_cliff_rocks(look: Node3D, body: StaticBody3D, random: RandomNumberGenerator) -> void:
	var width: float = _data["width"]
	var height: float = _data["height"]
	var mesh := _rock_mesh(int(_data["seed"]) + 1)
	mesh.surface_set_material(0, Surfaces.get_material(Surfaces.Pattern.BOULDER, ROCK_COLOR))
	for i in 14:
		var along := random.randf_range(-1.0, 1.0)
		var up := random.randf_range(0.0, 0.7)
		var at := Vector3(along * (width / 2.0 + 1.0), lerpf(0.5, height - 1.0, up * up), random.randf_range(-1.5, 0.2))
		_add_rock(look, body, mesh, at, random.randf_range(1.2, 2.6), random)


## Fallen rocks along the cliff's foot and roots reaching down its face, so that it meets the ground
## with a ragged edge. They keep clear of the opening, the plaza and the trail.
func _build_base_details(look: Node3D, body: StaticBody3D, random: RandomNumberGenerator) -> void:
	var width: float = _data["width"]
	var opening: float = _data["opening_width"]
	var mesh := _rock_mesh(int(_data["seed"]) + 3)
	mesh.surface_set_material(0, Surfaces.get_material(Surfaces.Pattern.BOULDER, DARK_ROCK_COLOR))
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * random.randf_range(opening / 2.0 + 2.4, width / 2.0 + 2.5)
		var size := random.randf_range(0.5, 1.3)
		_add_rock(look, body, mesh, Vector3(x, size * 0.3, random.randf_range(0.0, 1.0)), size, random)
	for i in 7:
		var x := random.randf_range(-width / 2.0, width / 2.0)
		if absf(x) < opening / 2.0 + 0.8:
			x += signf(x + 0.01) * (opening / 2.0 + 0.8)
		var length := random.randf_range(1.0, 2.2)
		var y := random.randf_range(0.6, 0.6 + length)
		_add_timber(look, Vector3(0.14, length, 0.14), Vector3(x, y, FACE_FRONT + 0.1), Vector3(random.randf_range(-0.2, 0.2), random.randf(), random.randf_range(-0.35, 0.35)), ROOT_COLOR)


func _build_frame(look: Node3D, body: StaticBody3D) -> void:
	var opening: float = _data["opening_width"]
	var opening_height: float = _data["opening_height"]
	var half := opening / 2.0
	# The left post still stands. The right one has been knocked sideways, and the beam sags onto it.
	_add_timber(look, Vector3(BEAM, opening_height, BEAM), Vector3(-half, opening_height / 2.0, 0.3), Vector3(0.0, 0.0, 0.03), OLD_TIMBER)
	_add_timber(look, Vector3(BEAM, opening_height * 0.8, BEAM), Vector3(half - 0.2, opening_height * 0.38, 0.5), Vector3(0.1, 0.0, -0.42), OLD_TIMBER)
	_add_timber(look, Vector3(opening + 1.2, BEAM, BEAM), Vector3(0.0, opening_height - 0.1, 0.3), Vector3(0.0, 0.0, -0.17), TIMBER)
	_add_timber(look, Vector3(BEAM * 0.7, BEAM * 0.7, 3.2), Vector3(-0.6, opening_height - 0.9, 1.3), Vector3(0.0, 0.3, 0.0), TIMBER)
	var post := BoxShape3D.new()
	post.size = Vector3(BEAM, opening_height, BEAM)
	var shape := CollisionShape3D.new()
	shape.shape = post
	shape.position = Vector3(-half, opening_height / 2.0, 0.3)
	body.add_child(shape)


func _build_rubble(look: Node3D, body: StaticBody3D, random: RandomNumberGenerator) -> void:
	var opening: float = _data["opening_width"]
	var opening_height: float = _data["opening_height"]
	var mesh := _rock_mesh(int(_data["seed"]))
	var material := Surfaces.get_material(Surfaces.Pattern.BOULDER, RUBBLE_TINT)
	mesh.surface_set_material(0, material)
	# A heap that rises toward the opening and covers it to nearly the lintel.
	for i in RUBBLE_COUNT:
		var across := random.randf_range(-1.0, 1.0)
		var depth := random.randf_range(0.0, 1.0)
		var size := lerpf(2.6, 1.1, depth) * random.randf_range(0.85, 1.25)
		var x := across * (opening / 2.0 + 1.6)
		var z := 0.4 + depth * 3.4
		var y := size * 0.45 + (1.0 - depth) * opening_height * 0.45 * (1.0 - absf(across) * 0.5)
		_add_rock(look, body, mesh, Vector3(x, y, z), size, random)
	# A few of the frame's broken beams stick out of the heap.
	_add_timber(look, Vector3(0.3, 0.3, 3.0), Vector3(0.8, opening_height * 0.6, 1.4), Vector3(-0.35, 0.5, 0.1), TIMBER)
	_add_timber(look, Vector3(0.28, 0.28, 2.4), Vector3(-1.2, opening_height * 0.5, 1.8), Vector3(-0.2, -0.6, 0.15), OLD_TIMBER)


## A timber headframe that can be seen from afar: four legs leaning together, rings and cross braces
## between them, a sheave wheel on an axle at the top, a rope down to a winch shed beside it, and a
## small deck at its foot. The people who left it took nothing, so planks are missing and a brace hangs.
func _build_headframe(look: Node3D, body: StaticBody3D) -> void:
	var base_x: float = _data["width"] / 2.0 + 3.5
	var centre := Vector3(base_x, 0.0, 3.0)
	var height := HEADFRAME_HEIGHT
	# The legs: a square at the foot that narrows toward the top.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_strut(look, _frame_point(centre, sx, sz, -0.4), _frame_point(centre, sx, sz, height), 0.55, TIMBER)
	var levels := [-0.1, 2.6, 5.4, 8.2, height - 0.9]
	for level in levels.size():
		if level == 0:
			continue
		var y: float = levels[level]
		for s in [-1.0, 1.0]:
			_add_strut(look, _frame_point(centre, -1.0, s, y), _frame_point(centre, 1.0, s, y), 0.3, OLD_TIMBER)
			_add_strut(look, _frame_point(centre, s, -1.0, y), _frame_point(centre, s, 1.0, y), 0.3, OLD_TIMBER)
	# Diagonal braces on every face, one in each bay, running the other way in the next bay.
	for bay in levels.size() - 1:
		var low: float = levels[bay]
		var high: float = levels[bay + 1]
		var flip := -1.0 if bay % 2 == 0 else 1.0
		for s in [-1.0, 1.0]:
			if bay == 2 and s > 0.0:
				continue
			_add_strut(look, _frame_point(centre, s, -flip, low), _frame_point(centre, s, flip, high), 0.2, OLD_TIMBER)
			_add_strut(look, _frame_point(centre, -flip, s, low), _frame_point(centre, flip, s, high), 0.2, OLD_TIMBER)
	# One brace has come loose and hangs from its upper end.
	var loose_top := _frame_point(centre, 1.0, 1.0, levels[3])
	_add_strut(look, loose_top, loose_top + Vector3(0.9, -1.9, 0.5), 0.2, OLD_TIMBER)
	# The cap, and the axle the wheel turns on.
	for s in [-1.0, 1.0]:
		_add_strut(look, _frame_point(centre, -1.0, s, height) + Vector3(-0.2, 0.15, 0.0), _frame_point(centre, 1.0, s, height) + Vector3(0.2, 0.15, 0.0), 0.35, TIMBER)
	var axle_y := height - 0.9
	_add_strut(look, centre + Vector3(0.0, axle_y, -1.0), centre + Vector3(0.0, axle_y, 1.0), 0.18, IRON)
	_build_sheave(look, centre + Vector3(0.0, axle_y, 0.0))
	# The foot: a deck of planks over sleepers, with two planks gone.
	for sleeper in [-1.0, 1.0]:
		_add_strut(look, centre + Vector3(-2.0, 0.22, sleeper * 1.3), centre + Vector3(2.0, 0.22, sleeper * 1.3), 0.25, OLD_TIMBER)
	for plank in 7:
		if plank == 3 or plank == 5:
			continue
		var z := -1.5 + plank * 0.5
		_add_timber(look, Vector3(3.9, 0.08, 0.46), centre + Vector3(0.0, 0.38, z), Vector3.ZERO, TIMBER)
	_build_winch_shed(look, body, centre + Vector3(-3.6, 0.0, 0.0), centre + Vector3(0.0, axle_y, 0.0))
	var feet := BoxShape3D.new()
	feet.size = Vector3(3.4, height, 3.6)
	var shape := CollisionShape3D.new()
	shape.shape = feet
	shape.position = centre + Vector3(0.0, height / 2.0, 0.0)
	body.add_child(shape)


## A point on the headframe at height y, at a corner (sx, sz are -1 or 1) or along a face.
func _frame_point(centre: Vector3, sx: float, sz: float, y: float) -> Vector3:
	var fraction := clampf((y + 0.4) / (HEADFRAME_HEIGHT + 0.4), 0.0, 1.0)
	var half := Vector2(1.5, 1.6).lerp(Vector2(0.6, 0.7), fraction)
	return centre + Vector3(sx * half.x, y, sz * half.y)


## The sheave: an iron rim, a hub and spokes, standing in the x-y plane around the axle.
func _build_sheave(look: Node3D, at: Vector3) -> void:
	var material := Surfaces.get_material(Surfaces.Pattern.BOULDER, IRON)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.96
	rim.outer_radius = 1.12
	rim.rings = 16
	rim.ring_segments = 5
	rim.material = material
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.position = at
	rim_node.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	look.add_child(rim_node)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.2
	hub.bottom_radius = 0.2
	hub.height = 0.3
	hub.radial_segments = 8
	hub.material = material
	var hub_node := MeshInstance3D.new()
	hub_node.mesh = hub
	hub_node.position = at
	hub_node.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	look.add_child(hub_node)
	for spoke in 4:
		var node := ModelBuilder.box(Vector3(2.05, 0.09, 0.09), Surfaces.Pattern.BOULDER, IRON, at)
		node.rotation = Vector3(0.0, 0.0, spoke * PI / 4.0 + 0.2)
		look.add_child(node)


## A hoist house with the winch drum inside. It stands open toward the headframe, with a lean-to roof
## that slopes away, gaps in its plank walls, and the rope running from the wheel to the drum.
func _build_winch_shed(look: Node3D, body: StaticBody3D, at: Vector3, wheel: Vector3) -> void:
	for sx in [-1.5, 1.5]:
		for sz in [-1.4, 1.4]:
			var tall := 2.9 if sx > 0.0 else 2.3
			_add_timber(look, Vector3(0.22, tall + 0.6, 0.22), at + Vector3(sx, (tall - 0.6) / 2.0, sz), Vector3.ZERO, TIMBER)
	# Back wall planks (away from the frame), with two missing, and half of the side walls.
	for plank in 9:
		if plank == 2 or plank == 6:
			continue
		var plank_height := 2.1 - (0.5 if plank == 7 else 0.0)
		_add_timber(look, Vector3(0.06, plank_height, 0.3), at + Vector3(-1.5, plank_height / 2.0, -1.4 + plank * 0.35), Vector3.ZERO, OLD_TIMBER)
	for side in [-1.0, 1.0]:
		for plank in 5:
			if side > 0.0 and plank == 3:
				continue
			_add_timber(look, Vector3(0.3, 2.0 - plank * 0.1, 0.06), at + Vector3(-1.2 + plank * 0.35, (2.0 - plank * 0.1) / 2.0, side * 1.4), Vector3.ZERO, OLD_TIMBER)
	# The roof: a slab sloping down toward the back, with ribs under it and a plank torn off the edge.
	var roof := ModelBuilder.box(Vector3(3.7, 0.12, 3.5), Surfaces.Pattern.WOOD, TIMBER, at + Vector3(0.0, 2.75, 0.0))
	roof.rotation = Vector3(0.0, 0.0, 0.14)
	look.add_child(roof)
	for rib in 4:
		_add_timber(look, Vector3(3.5, 0.14, 0.14), at + Vector3(0.0, 2.6, -1.3 + rib * 0.87), Vector3(0.0, 0.0, 0.14), OLD_TIMBER)
	_add_timber(look, Vector3(1.5, 0.06, 0.4), at + Vector3(1.0, 2.2, 1.9), Vector3(0.6, 0.2, 0.9), OLD_TIMBER)
	# The drum, with flanges, and a crank.
	var drum := CylinderMesh.new()
	drum.top_radius = 0.42
	drum.bottom_radius = 0.42
	drum.height = 1.7
	drum.radial_segments = 10
	drum.material = Surfaces.get_material(Surfaces.Pattern.BOULDER, IRON)
	var drum_node := MeshInstance3D.new()
	drum_node.mesh = drum
	drum_node.position = at + Vector3(-0.3, 0.9, 0.0)
	drum_node.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	look.add_child(drum_node)
	for flange in [-0.9, 0.9]:
		_add_timber(look, Vector3(1.0, 1.0, 0.1), at + Vector3(-0.3, 0.9, flange), Vector3(0.0, 0.0, 0.4), TIMBER)
	_add_strut(look, at + Vector3(-0.3, 0.9, 1.0), at + Vector3(0.2, 1.5, 1.35), 0.1, IRON)
	_add_timber(look, Vector3(1.6, 0.25, 1.9), at + Vector3(-0.3, 0.25, 0.0), Vector3.ZERO, OLD_TIMBER)
	# The rope, from the wheel's side to the drum.
	_add_strut(look, wheel + Vector3(-1.1, 0.0, 0.0), at + Vector3(-0.3, 1.32, 0.0), 0.07, ROOT_COLOR)
	var shed := BoxShape3D.new()
	shed.size = Vector3(3.2, 2.8, 3.0)
	var shape := CollisionShape3D.new()
	shape.shape = shed
	shape.position = at + Vector3(0.0, 1.4, 0.0)
	body.add_child(shape)


## Props and planks around the mouth, sacks and spilled ore beside the track, and loose rails.
func _build_mouth_details(look: Node3D, random: RandomNumberGenerator) -> void:
	var opening: float = _data["opening_width"]
	var opening_height: float = _data["opening_height"]
	var half := opening / 2.0
	# Bracing on the standing post, a footing under it, and a brace hanging from the sagging beam.
	_add_strut(look, Vector3(-half + 0.2, 0.5, 0.62), Vector3(-half + 1.25, opening_height - 0.45, 0.62), 0.2, OLD_TIMBER)
	_add_timber(look, Vector3(1.1, 0.3, 0.9), Vector3(-half, 0.15, 0.3), Vector3.ZERO, OLD_TIMBER)
	_add_strut(look, Vector3(half - 1.0, opening_height - 0.35, 0.62), Vector3(half - 0.2, opening_height - 1.5, 0.7), 0.2, TIMBER)
	# Props that held the roof, snapped and leaning on the heap.
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * random.randf_range(half + 0.2, half + 2.4)
		var z := random.randf_range(3.0, 4.6)
		var lean := Vector3(-side * random.randf_range(0.2, 0.9), random.randf_range(1.0, 1.9), -random.randf_range(0.8, 1.5))
		_add_strut(look, Vector3(x, 0.1, z), Vector3(x, 0.1, z) + lean, 0.22, TIMBER if i % 3 == 0 else OLD_TIMBER)
	# Planks lying about, and a few leaning against the heap.
	for i in 11:
		var at := Vector3(random.randf_range(-6.0, 6.0), 0.06 + (0.07 if i % 4 == 0 else 0.0), random.randf_range(4.0, 8.0))
		if absf(at.x) < 1.4 and at.z > 4.0:
			at.x += signf(at.x + 0.01) * 1.6
		_add_timber(look, Vector3(random.randf_range(1.2, 2.6), 0.06, 0.24), at, Vector3(0.0, random.randf() * PI, random.randf_range(-0.05, 0.05)), OLD_TIMBER)
	for i in 3:
		var x := -half - 0.6 + i * 1.5 + random.randf_range(-0.3, 0.3)
		_add_strut(look, Vector3(x, 0.1, 4.3), Vector3(x + random.randf_range(-0.3, 0.3), 2.0, 3.2), 0.24, OLD_TIMBER)
	_build_sacks(look, random)
	# Rails: a bent one sticking out of the heap, and a loose piece beside the cart.
	_add_strut(look, Vector3(-0.7, 0.3, 4.0), Vector3(-0.2, 1.6, 3.3), 0.1, IRON)
	_add_strut(look, Vector3(1.7, 0.1, 6.0), Vector3(2.4, 0.2, 9.2), 0.1, IRON)


## Sacks of ore stacked beside the winch shed, one fallen, with ore spilled on the ground.
func _build_sacks(look: Node3D, random: RandomNumberGenerator) -> void:
	var base := Vector3(5.2, 0.0, 5.2)
	var rows: Array = [[0.0, 0.0], [0.55, 0.05], [1.1, 0.0], [0.27, 0.45], [0.82, 0.5]]
	for i in rows.size():
		var level := 0.19 if i < 3 else 0.54
		var sack := ModelBuilder.box(Vector3(0.55, 0.38, 0.38), Surfaces.Pattern.PLASTER, SACK, base + Vector3(rows[i][0], level, rows[i][1]))
		sack.rotation = Vector3(0.0, random.randf_range(-0.25, 0.25), random.randf_range(-0.08, 0.08))
		look.add_child(sack)
	var fallen := ModelBuilder.box(Vector3(0.55, 0.38, 0.38), Surfaces.Pattern.PLASTER, SACK, base + Vector3(1.6, 0.17, 0.9))
	fallen.rotation = Vector3(0.0, 0.8, 0.5)
	look.add_child(fallen)
	var ore := _rock_mesh(int(_data["seed"]) + 4)
	ore.surface_set_material(0, Surfaces.get_material(Surfaces.Pattern.IRON_ORE, Color(0.5, 0.4, 0.34)))
	for i in 7:
		var piece := MeshInstance3D.new()
		piece.mesh = ore
		var size := random.randf_range(0.08, 0.2)
		piece.transform = Transform3D(Basis.from_euler(Vector3(random.randf(), random.randf() * TAU, random.randf())).scaled(Vector3.ONE * size), base + Vector3(1.5 + random.randf_range(-0.2, 1.1), size * 0.5, 0.9 + random.randf_range(-0.2, 0.9)))
		look.add_child(piece)


func _build_cart_and_rails(look: Node3D, body: StaticBody3D) -> void:
	# Rails run out of the opening and disappear under the rubble: two straight pieces and then one that
	# bends away to the left, joined end to end (#436).
	var track := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 4.2))
	for turn: float in RAIL_TURNS:
		var piece := StructureBuilder.rail_track(turn, OLD_TIMBER)
		piece.transform = track
		look.add_child(piece)
		track *= StructureBuilder.rail_end(turn)
	# A cart that tipped over beside the track.
	var cart := Vector3(2.9, 0.5, 8.0)
	_add_timber(look, Vector3(1.5, 0.9, 1.1), cart, Vector3(0.0, 0.5, 0.9), IRON)
	_add_timber(look, Vector3(0.1, 1.0, 1.0), cart + Vector3(0.75, 0.0, 0.6), Vector3(0.0, 0.5, 0.0), IRON)
	for wheel in [Vector3(-0.35, 0.0, 0.6), Vector3(0.45, 0.0, -0.7)]:
		var disk := CylinderMesh.new()
		disk.top_radius = 0.25
		disk.bottom_radius = 0.25
		disk.height = 0.06
		disk.radial_segments = 8
		disk.material = Surfaces.get_material(Surfaces.Pattern.BOULDER, IRON)
		var wheel_node := MeshInstance3D.new()
		wheel_node.mesh = disk
		wheel_node.position = cart + wheel + Vector3(0.0, 0.4, 0.0)
		wheel_node.rotation = Vector3(0.4, 0.5, PI / 2.0 - 0.3)
		look.add_child(wheel_node)
	var tipped := BoxShape3D.new()
	tipped.size = Vector3(1.5, 1.0, 1.4)
	var shape := CollisionShape3D.new()
	shape.shape = tipped
	shape.position = cart
	shape.rotation = Vector3(0.0, 0.5, 0.9)
	body.add_child(shape)


func _add_rock(look: Node3D, body: StaticBody3D, mesh: ArrayMesh, at: Vector3, size: float, random: RandomNumberGenerator) -> void:
	var basis := Basis.from_euler(Vector3(random.randf(), random.randf() * TAU, random.randf())).scaled(Vector3(random.randf_range(0.9, 1.4), random.randf_range(0.7, 1.0), random.randf_range(0.9, 1.4)) * size)
	var rock := MeshInstance3D.new()
	rock.mesh = mesh
	rock.transform = Transform3D(basis, at)
	look.add_child(rock)
	var shape := CollisionShape3D.new()
	var convex := mesh.create_convex_shape()
	convex.points = Transform3D(basis, at) * convex.points
	shape.shape = convex
	body.add_child(shape)


func _add_block(body: StaticBody3D, size: Vector3, at: Vector3, yaw_degrees: float) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = at
	shape.rotation.y = deg_to_rad(yaw_degrees)
	body.add_child(shape)


## A beam of the given thickness running from one point to another.
func _add_strut(look: Node3D, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var along := to - from
	var pattern := Surfaces.Pattern.BOULDER if color == IRON else Surfaces.Pattern.WOOD
	var strut := ModelBuilder.box(Vector3(thickness, thickness, along.length()), pattern, color)
	var up := Vector3.RIGHT if absf(along.normalized().y) > 0.99 else Vector3.UP
	strut.transform = Transform3D(Basis.looking_at(along.normalized(), up), (from + to) / 2.0)
	look.add_child(strut)


func _add_timber(look: Node3D, size: Vector3, at: Vector3, tilt: Vector3, color: Color) -> void:
	var timber := ModelBuilder.box(size, Surfaces.Pattern.WOOD, color, at)
	timber.rotation = tilt
	look.add_child(timber)


## A sphere with lumps pushed in and out, flat-shaded so it reads as broken rock.
static func _rock_mesh(seed_value: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lumps := FastNoiseLite.new()
	lumps.seed = seed_value
	lumps.frequency = 1.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for offset in 3:
			var vertex := source[indices[i + offset]]
			corners.append(vertex * (1.0 + lumps.get_noise_3dv(vertex) * RUBBLE_LUMPINESS))
		surface.set_normal((corners[2] - corners[0]).cross(corners[1] - corners[0]).normalized())
		for corner in corners:
			surface.add_vertex(corner)
	return surface.commit()
