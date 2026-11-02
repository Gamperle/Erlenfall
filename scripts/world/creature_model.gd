class_name CreatureModel
extends CharacterModel
## A rigged creature posed in code, for bodies too unlike a human to share the human animations.

const ARM_DROP := deg_to_rad(72.0)
const LEG_SWING := 0.6
const ARM_SWING := 0.5
const STRIDE_PER_METER := 3.2
const PUNCH_SECONDS := 0.7
const PUNCH_REACH := deg_to_rad(-100.0)
const FULL_STRIDE_SPEED := 3.0

var _punch_left := 0.0


func load_model(path: String) -> void:
	_model = (load(path) as PackedScene).instantiate()
	_model.name = "Model"
	# Models face +Z, and the game's characters face -Z.
	_model.rotation.y = PI
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false)
	_copy_materials()
	animate(0.0, 0.0)


func play_action(_animation_name: StringName, _duration := 0.0, _start := 0.0) -> void:
	_punch_left = PUNCH_SECONDS


func animate(speed: float, delta: float) -> void:
	_phase += delta * STRIDE_PER_METER * speed
	_punch_left = maxf(_punch_left - delta, 0.0)
	var stride := sin(_phase) * minf(speed / FULL_STRIDE_SPEED, 1.0)
	var punch := sin(_punch_left / PUNCH_SECONDS * PI) * PUNCH_REACH
	_pose(&"UpperLeg.L", Quaternion(Vector3.RIGHT, stride * LEG_SWING))
	_pose(&"UpperLeg.R", Quaternion(Vector3.RIGHT, -stride * LEG_SWING))
	_pose(&"UpperArm.L", Quaternion(Vector3.RIGHT, -stride * ARM_SWING) * Quaternion(Vector3.BACK, -ARM_DROP))
	_pose(&"UpperArm.R", Quaternion(Vector3.RIGHT, stride * ARM_SWING + punch) * Quaternion(Vector3.BACK, ARM_DROP))


## Applies a rotation given in the skeleton's axes to a bone with its own axes.
func _pose(bone_name: StringName, rotation_in_skeleton: Quaternion) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var rest := _skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var local := rest.inverse() * rotation_in_skeleton * rest
	_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * local)
