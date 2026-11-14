class_name Projectile
extends Node3D
## A flying arrow or thrown flask. It falls under gravity, and ends on the first enemy or piece of ground it touches.
## What it does comes from `data/projectiles.json`. Splash projectiles hurt every enemy near where they land.

const DATA_PATH := "res://data/projectiles.json"
const GROUP := "projectile"
## How long a stuck arrow stays before it disappears, in seconds.
const STUCK_SECONDS := 3.0

static var _data: Dictionary = {}

var velocity := Vector3.ZERO
## Seconds left before it vanishes if it hits nothing.
var time_left := 0.0
var damage := 0.0
var radius := 0.1
var splash_radius := 0.0
var gravity := 9.8
var hit_something := false
var _shooter: CollisionObject3D


static func type_ids() -> Array:
	return _get_data().keys()


static func stats(projectile_id: String) -> Dictionary:
	return _get_data()[projectile_id]


## Creates a projectile of this type at `origin` flying along `direction`. The shooter's own body is ignored. The damage is scaled by `damage_multiplier`, which comes from the bow and ammunition used.
static func launch(projectile_id: String, origin: Vector3, direction: Vector3, shooter: CollisionObject3D = null, damage_multiplier: float = 1.0) -> Projectile:
	var type: Dictionary = _get_data()[projectile_id]
	var projectile := Projectile.new()
	projectile.damage = float(type["damage"]) * damage_multiplier
	projectile.radius = type["radius"]
	projectile.splash_radius = type["splash_radius"]
	projectile.gravity = type["gravity"]
	projectile.time_left = type["lifetime"]
	projectile.velocity = direction.normalized() * float(type["speed"])
	projectile._shooter = shooter
	projectile.position = origin
	projectile._build(type)
	return projectile


func _enter_tree() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if hit_something:
		return
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var ground := _ground_hit(from, to)
	var target := _enemy_hit(from, to)
	# Whatever is closer along the path is what the projectile meets first.
	var end := to
	if not ground.is_empty():
		end = ground["position"]
	if target != null:
		var middle := target.global_position + Vector3.UP * target.body_height() * 0.5
		var on_path := _closest_on_segment(middle, from, to)
		if ground.is_empty() or from.distance_to(on_path) <= from.distance_to(end):
			end = on_path
		else:
			target = null
	global_position = end
	if velocity.length() > 0.01 and not end.is_equal_approx(end + velocity):
		# Straight up or down has no sideways direction to turn towards, so another up vector is used.
		var up := Vector3.UP if absf(velocity.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		look_at(end + velocity, up)
	if target != null or not ground.is_empty():
		_land(target)


func _ground_hit(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if _shooter != null:
		query.exclude = [_shooter.get_rid()]
	# Enemies are found by their own size below, so the ray only has to find scenery.
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit["collider"] is Enemy:
		query.exclude = query.exclude + [hit["rid"]]
		hit = space.intersect_ray(query)
	return hit


## The living enemy that the path passes through, nearest to its start, or null.
func _enemy_hit(from: Vector3, to: Vector3) -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy.health == null or not enemy.health.is_alive() or not enemy.visible:
			continue
		var height := enemy.body_height()
		var center := enemy.global_position + Vector3.UP * height * 0.5
		var near := _closest_on_segment(center, from, to)
		var offset := near - center
		var across := Vector2(offset.x, offset.z).length()
		if across <= enemy.body_radius() + radius and absf(offset.y) <= height * 0.5 + radius:
			var distance := from.distance_to(near)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best


func _land(target: Enemy) -> void:
	hit_something = true
	if splash_radius > 0.0:
		for node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var enemy := node as Enemy
			if enemy.health != null and enemy.health.is_alive() and enemy.global_position.distance_to(global_position) <= splash_radius:
				enemy.take_hit(damage, global_position)
		queue_free()
		return
	if target != null:
		target.take_hit(damage, global_position - velocity.normalized())
		queue_free()
		return
	# An arrow that hits the ground stays stuck for a moment.
	get_tree().create_timer(STUCK_SECONDS).timeout.connect(queue_free)


func _build(type: Dictionary) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(type["size"][0], type["size"][1], type["size"][2])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(type["color"])
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


static func _closest_on_segment(point: Vector3, from: Vector3, to: Vector3) -> Vector3:
	var along := to - from
	var length_squared := along.length_squared()
	if length_squared == 0.0:
		return from
	return from + along * clampf((point - from).dot(along) / length_squared, 0.0, 1.0)


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
