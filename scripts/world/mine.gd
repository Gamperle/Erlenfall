class_name Mine
extends Node3D
## The buried mine's entrance: a cliff face, a collapsed timber frame, a rubble heap that blocks the
## way in, a tilted cart, rails, and a tall headframe that can be seen from afar. It is built from
## code-made shapes. The ground in front of it is flattened by Terrain, and the inside is not built.
## The entrance faces +z, so the node's rotation turns it toward the road.

const ROCK_COLOR := Color(0.36, 0.34, 0.32)
const DARK_ROCK_COLOR := Color(0.28, 0.26, 0.25)
const RUBBLE_TINT := Color(0.34, 0.31, 0.28)
const TIMBER := Color(0.24, 0.16, 0.1)
const OLD_TIMBER := Color(0.3, 0.22, 0.15)
const IRON := Color(0.18, 0.16, 0.15)
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
	_build_frame(look, body)
	_build_rubble(look, body, random)
	_build_headframe(look, body)
	_build_cart_and_rails(look, body)
	add_child(ModelBuilder.merged(look))


## Where the player stands to look at the entrance, in the world.
func front_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, FRONT_DISTANCE)


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


func _build_headframe(look: Node3D, body: StaticBody3D) -> void:
	# Two leaning legs and a cross beam, so that the mine can be told from far off.
	var base_x: float = _data["width"] / 2.0 + 3.5
	var lean := 0.22
	for leg in [[-0.9, lean], [0.9, -lean]]:
		_add_timber(look, Vector3(0.6, HEADFRAME_HEIGHT, 0.6), Vector3(base_x + leg[1] * HEADFRAME_HEIGHT / 2.0, HEADFRAME_HEIGHT / 2.0 - 0.3, 3.0 + leg[0] * 1.0), Vector3(0.0, 0.0, -leg[1]), TIMBER)
	_add_timber(look, Vector3(0.5, 0.5, 3.0), Vector3(base_x, HEADFRAME_HEIGHT - 1.0, 3.0), Vector3.ZERO, OLD_TIMBER)
	_add_timber(look, Vector3(2.4, 0.4, 0.4), Vector3(base_x, HEADFRAME_HEIGHT * 0.5, 3.0), Vector3(0.0, 0.0, 0.0), OLD_TIMBER)
	# A rusted wheel hangs from the top.
	var wheel := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 0.25
	disk.radial_segments = 12
	disk.material = Surfaces.get_material(Surfaces.Pattern.BOULDER, IRON)
	wheel.mesh = disk
	wheel.position = Vector3(base_x, HEADFRAME_HEIGHT - 2.2, 3.0)
	wheel.rotation = Vector3(0.0, PI / 2.0, PI / 2.0)
	look.add_child(wheel)
	var feet := BoxShape3D.new()
	feet.size = Vector3(5.0, HEADFRAME_HEIGHT, 3.0)
	var shape := CollisionShape3D.new()
	shape.shape = feet
	shape.position = Vector3(base_x, HEADFRAME_HEIGHT / 2.0, 3.0)
	body.add_child(shape)


func _build_cart_and_rails(look: Node3D, body: StaticBody3D) -> void:
	# Rails run out of the opening and disappear under the rubble. Sleepers every meter.
	for i in 6:
		var z := 4.2 + i * 1.1
		_add_timber(look, Vector3(2.0, 0.12, 0.25), Vector3(0.0, 0.06, z), Vector3.ZERO, OLD_TIMBER)
	for side in [-0.7, 0.7]:
		_add_timber(look, Vector3(0.1, 0.12, 6.4), Vector3(side, 0.16, 6.9), Vector3.ZERO, IRON)
	# A cart that tipped over beside the track.
	var cart := Vector3(2.9, 0.5, 8.0)
	_add_timber(look, Vector3(1.5, 0.9, 1.1), cart, Vector3(0.0, 0.5, 0.9), IRON)
	_add_timber(look, Vector3(0.1, 1.0, 1.0), cart + Vector3(0.75, 0.0, 0.6), Vector3(0.0, 0.5, 0.0), IRON)
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
