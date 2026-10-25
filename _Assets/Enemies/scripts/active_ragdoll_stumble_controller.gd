class_name ActiveRagdollStumbleController
extends Node

signal stumble_started()
signal recovery_started()
signal recovered()

@export var actor: CharacterBody3D
@export var ragdoll_skeleton: PhysicalBoneSimulator3D
@export var stumble_bone: PhysicalBone3D
@export var anim_tree: AnimationTree
@export var collision_shape: CollisionShape3D
@export var stumble_duration: float = 0.4
@export var recovery_duration: float = 0.28

var is_active: bool = false
var _collision_layer: int = 0
var _collision_mask: int = 0
var _token: int = 0
var _rest_rotation: Vector3 = Vector3.ZERO

func begin(impact_direction: Vector3, force: float) -> void:
	if is_active or not _is_configured():
		return

	is_active = true
	_token += 1
	var current_token: int = _token
	_collision_layer = actor.collision_layer
	_collision_mask = actor.collision_mask
	_rest_rotation = actor.rotation

	actor.set_physics_process(false)
	actor.velocity = Vector3.ZERO
	actor.collision_layer = 0
	actor.collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if anim_tree:
		anim_tree.active = false

	ragdoll_skeleton.active = true
	ragdoll_skeleton.physical_bones_start_simulation()
	var direction: Vector3 = impact_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = actor.global_transform.basis.z
	if stumble_bone:
		stumble_bone.apply_central_impulse(direction * force)

	stumble_started.emit()
	await get_tree().create_timer(stumble_duration).timeout
	if current_token != _token or not is_active:
		return
	print("begin recovery")
	_begin_recovery(current_token)

func cancel_for_death() -> void:
	_token += 1
	is_active = false
	if ragdoll_skeleton:
		ragdoll_skeleton.physical_bones_stop_simulation()
		ragdoll_skeleton.active = false

func _begin_recovery(current_token: int) -> void:
	recovery_started.emit()
	ragdoll_skeleton.physical_bones_stop_simulation()
	ragdoll_skeleton.active = false
	if anim_tree:
		anim_tree.active = true
		anim_tree.advance(0.0)

	var recovery_tween: Tween = create_tween()
	recovery_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recovery_tween.tween_property(actor, "rotation", _rest_rotation, recovery_duration)
	await recovery_tween.finished
	if current_token != _token:
		return

	actor.collision_layer = _collision_layer
	actor.collision_mask = _collision_mask
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	actor.set_physics_process(true)
	is_active = false
	recovered.emit()

func _is_configured() -> bool:
	return is_instance_valid(actor) and is_instance_valid(ragdoll_skeleton)

func can_begin() -> bool:
	return not is_active and _is_configured()
