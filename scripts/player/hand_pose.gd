class_name HandPose
extends SkeletonModifier3D
## Closes the hands around what they hold and raises the sword arm to guard, over the animations.
## Directions are in the skeleton's axes, where +Z is ahead and -X is the character's right.

const GUARD_SPEED := 10.0
const UPPER_ARM_GUARD := Vector3(-0.35, -0.65, 0.65)
const LOWER_ARM_GUARD := Vector3(0.4, 0.2, 0.9)
const BLADE_GUARD := Vector3(0.55, 0.8, 0.2)
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
const FINGER_CURL: Array[float] = [1.3, 1.5, 1.1]
const THUMB_CURL: Array[float] = [0.35, 0.6, 0.7]
## Which way the fingers bend around the line across the knuckles, on each hand.
const RIGHT_BEND := -1.0
const LEFT_BEND := 1.0

var grip_right := true
var grip_left := false
var guarding := false
## The direction of the held blade, in the hand bone's axes.
var blade_in_hand := Vector3.UP

var _guard := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	_guard = move_toward(_guard, 1.0 if guarding else 0.0, GUARD_SPEED * delta)
	if _guard > 0.0:
		_aim_bone(skeleton, skeleton.find_bone(&"RightUpperArm"), skeleton.find_bone(&"RightLowerArm"), UPPER_ARM_GUARD)
		_aim_bone(skeleton, skeleton.find_bone(&"RightLowerArm"), skeleton.find_bone(&"RightHand"), LOWER_ARM_GUARD)
		_aim_blade(skeleton)
	if grip_right:
		_close_hand(skeleton, "r", RIGHT_BEND)
	if grip_left:
		_close_hand(skeleton, "l", LEFT_BEND)


func _aim_bone(skeleton: Skeleton3D, bone: int, child: int, direction: Vector3) -> void:
	var current := skeleton.get_bone_global_pose(child).origin - skeleton.get_bone_global_pose(bone).origin
	_turn_bone(skeleton, bone, Quaternion(current.normalized(), direction.normalized()))


func _aim_blade(skeleton: Skeleton3D) -> void:
	var hand := skeleton.find_bone(&"RightHand")
	var current := skeleton.get_bone_global_pose(hand).basis.get_rotation_quaternion() * blade_in_hand
	_turn_bone(skeleton, hand, Quaternion(current.normalized(), BLADE_GUARD.normalized()))


func _turn_bone(skeleton: Skeleton3D, bone: int, turn: Quaternion) -> void:
	var rotation_now := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var wanted := Quaternion.IDENTITY.slerp(turn, _guard) * rotation_now
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, (parent.inverse() * wanted).normalized())


func _close_hand(skeleton: Skeleton3D, side: String, bend: float) -> void:
	var first := skeleton.get_bone_global_pose(skeleton.find_bone("index_01_" + side)).origin
	var last := skeleton.get_bone_global_pose(skeleton.find_bone("pinky_01_" + side)).origin
	var across := (last - first).normalized()
	for finger in FINGERS:
		_curl(skeleton, finger, side, across, bend, FINGER_CURL)
	_curl(skeleton, "thumb", side, across, bend, THUMB_CURL)


func _curl(skeleton: Skeleton3D, finger: String, side: String, across: Vector3, bend: float, angles: Array[float]) -> void:
	for joint in angles.size():
		var bone := skeleton.find_bone("%s_0%d_%s" % [finger, joint + 1, side])
		var rotation_now := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		var wanted := Quaternion(across, angles[joint] * bend) * rotation_now
		var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone, (parent.inverse() * wanted).normalized())
