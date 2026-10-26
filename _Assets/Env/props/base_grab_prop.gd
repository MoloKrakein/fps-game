class_name BaseGrabProp extends RigidBody3D

signal force_dropped

@export var pull_power: float = 15.0
@export var throw_power: float = 15.0
@export var disable_collision_while_held: bool = true

var is_held: bool = false
var hold_target: Marker3D = null
var weight: float = 1.0
var _saved_collision_state: Array[Dictionary] = []


func _physics_process(delta: float) -> void:
	if not is_held:
		return
	if not is_instance_valid(hold_target):
		_force_drop()
		return

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, hold_target.global_position
	)
	query.exclude = [get_rid()]

	if not space_state.intersect_ray(query).is_empty():
		_force_drop()
		return

	var distance: float = global_position.distance_to(hold_target.global_position)
	if distance > 5.0:
		_force_drop()
		return

	var direction: Vector3 = global_position.direction_to(hold_target.global_position)
	var spring_velocity: Vector3 = direction * (distance * pull_power)
	linear_velocity = linear_velocity.lerp(spring_velocity, 10.0 * delta)


func grab(target_marker: Marker3D) -> void:
	if not is_instance_valid(target_marker):
		return
	if is_held:
		_restore_collision_state()

	is_held = true
	hold_target = target_marker
	gravity_scale = 0.0
	angular_damp = 5.0
	sleeping = false
	weight = get_weight()
	if disable_collision_while_held:
		_disable_collision_state()


func drop() -> void:
	if not is_held and _saved_collision_state.is_empty():
		return
	is_held = false
	hold_target = null
	gravity_scale = 1.0
	angular_damp = 0.0
	weight = get_weight()
	_restore_collision_state()


func throw(throw_direction: Vector3) -> void:
	var direction: Vector3 = throw_direction.normalized()
	drop()
	apply_central_impulse(direction * throw_power)


func get_weight() -> float:
	return mass


func _force_drop() -> void:
	if not is_held:
		return
	drop()
	force_dropped.emit()


func _disable_collision_state() -> void:
	_saved_collision_state.clear()
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		var collision_object: CollisionObject3D = node as CollisionObject3D
		if collision_object == null:
			continue
		_saved_collision_state.append({
			"object": collision_object,
			"layer": collision_object.collision_layer,
			"mask": collision_object.collision_mask
		})
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	# The rigid body itself is not returned by find_children().
	_saved_collision_state.append({
		"object": self,
		"layer": collision_layer,
		"mask": collision_mask
	})
	collision_layer = 0
	collision_mask = 0


func _restore_collision_state() -> void:
	for state: Dictionary in _saved_collision_state:
		var collision_object: CollisionObject3D = state.get("object") as CollisionObject3D
		if not is_instance_valid(collision_object):
			continue
		collision_object.collision_layer = int(state.get("layer", 0))
		collision_object.collision_mask = int(state.get("mask", 0))
	_saved_collision_state.clear()