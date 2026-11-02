class_name Humanoid
extends Node3D
## A simple jointed figure with a walking animation. Its feet are at its origin, and it faces -Z.

const DEFAULT_SKIN := Color(0.78, 0.6, 0.48)
const DEFAULT_HAIR := Color(0.25, 0.17, 0.1)
const STRIDE_RATE := 2.6
const MAX_STRIDE := 0.7
const WALK_SPEED_FOR_FULL_STRIDE := 4.0

## How far the left arm is raised to the front, for holding a torch. 0 lets it swing.
var left_arm_raise := 0.0

var _phase := 0.0
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _materials: Array[StandardMaterial3D] = []


## Builds the figure. Hair is left out for creatures, which get ears if asked for.
func setup(cloth: Color, skin := DEFAULT_SKIN, hair := DEFAULT_HAIR, has_hair := true, has_ears := false) -> void:
	var cloth_material := _new_material(cloth)
	var legs_material := _new_material(cloth.darkened(0.45))
	var skin_material := _new_material(skin)

	_add_part(self, _capsule(0.2, 0.68), cloth_material, Vector3(0.0, 1.14, 0.0))
	_add_part(self, _sphere(0.13), skin_material, Vector3(0.0, 1.62, 0.0))
	if has_hair:
		# Sits slightly behind and above the head, leaving the face (-Z) uncovered.
		_add_part(self, _sphere(0.14), _new_material(hair), Vector3(0.0, 1.65, 0.035))
	if has_ears:
		for side: float in [-1.0, 1.0]:
			var ear := _add_part(self, _capsule(0.04, 0.24), skin_material, Vector3(side * 0.19, 1.66, 0.0))
			ear.rotation.z = side * -1.1

	_left_leg = _add_limb(Vector3(-0.1, 0.82, 0.0), _capsule(0.08, 0.84), legs_material)
	_right_leg = _add_limb(Vector3(0.1, 0.82, 0.0), _capsule(0.08, 0.84), legs_material)
	_left_arm = _add_limb(Vector3(-0.27, 1.42, 0.0), _capsule(0.06, 0.62), cloth_material)
	_right_arm = _add_limb(Vector3(0.27, 1.42, 0.0), _capsule(0.06, 0.62), cloth_material)


## Returns the node that a held item should attach to.
func right_hand() -> Node3D:
	return _right_arm


func left_hand() -> Node3D:
	return _left_arm


## Plays a one-off animation, on figures that have them.
func play_action(_animation_name: StringName) -> void:
	pass


## Swings the limbs to match a walking speed.
func animate(speed: float, delta: float) -> void:
	_phase += delta * STRIDE_RATE * speed
	var stride := sin(_phase) * MAX_STRIDE * minf(speed / WALK_SPEED_FOR_FULL_STRIDE, 1.0)
	_left_leg.rotation.x = stride
	_right_leg.rotation.x = -stride
	_left_arm.rotation.x = left_arm_raise if left_arm_raise != 0.0 else -stride * 0.7
	_right_arm.rotation.x = stride * 0.7


## Makes the figure glow, for attack warnings and hit flashes. An amount of 0 clears it.
func set_glow(color: Color, amount: float) -> void:
	for material in _materials:
		material.emission_enabled = amount > 0.0
		material.emission = color
		material.emission_energy_multiplier = amount


func _new_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	_materials.append(material)
	return material


func _add_part(parent: Node3D, mesh: PrimitiveMesh, material: Material, at: Vector3) -> MeshInstance3D:
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	parent.add_child(part)
	return part


## Adds a limb that pivots at its top joint.
func _add_limb(joint: Vector3, mesh: CapsuleMesh, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	add_child(pivot)
	_add_part(pivot, mesh, material, Vector3.DOWN * mesh.height / 2.0)
	return pivot


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 3
	return mesh


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh
