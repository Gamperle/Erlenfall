class_name Npc
extends Interactable
## A villager the player can talk to.

const UI_GROUP := "dialogue_ui"
const BODY_RADIUS := 0.35
const BODY_HEIGHT := 1.75

var npc_id := ""


func setup(data: Dictionary) -> void:
	npc_id = data["id"]
	prompt_key = data["name"]
	name = npc_id

	var mesh := CapsuleMesh.new()
	mesh.radius = BODY_RADIUS
	mesh.height = BODY_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(data["color"])
	mesh.material = material
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = BODY_HEIGHT / 2.0
	add_child(body)

	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = BODY_HEIGHT / 2.0
	add_child(collision)

	var label := Label3D.new()
	label.text = tr(prompt_key)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = BODY_HEIGHT + 0.3
	label.pixel_size = 0.006
	label.outline_size = 8
	add_child(label)


func prompt() -> String:
	return tr("PROMPT_TALK") % tr(prompt_key)


func interact(player: Player) -> void:
	get_tree().call_group(UI_GROUP, "open_conversation", npc_id, tr(prompt_key), player)
