class_name ActiveRagdollStumbleController
extends Node
## Procedural "active ragdoll" hit reaction (GTA IV / Euphoria style).
##
## Light hit -> STAGGER: only the upper body is simulated, layered on top of the running
##              animation. The torso starts limp (so the hit reads), then "muscles" ramp up and a
##              per-bone PD servo pulls it back towards the pose it had when it was hit.
## Heavy hit -> FALL: the whole body goes ragdoll, then gets up once it settles.
## Both end in RECOVER: the simulator's `influence` is blended 1 -> 0 so the pose eases back into
## the AnimationTree instead of snapping.

signal stumble_started()
signal recovery_started()
signal recovered()

enum Phase { IDLE, STAGGER, FALL, RECOVER }

@export_group("References")
@export var actor: CharacterBody3D
@export var ragdoll_skeleton: PhysicalBoneSimulator3D
## Fallback bone that receives the hit impulse when no hit position is known.
@export var stumble_bone: PhysicalBone3D
@export var anim_tree: AnimationTree
@export var collision_shape: CollisionShape3D

@export_group("Bones")
## Kinematic root of the partial ragdoll. Never simulated while staggering.
@export var root_bone_name: StringName = &"pelvis"
## Bones that go limp during a stagger. Legs are left out so they keep animating.
@export var stagger_bones: Array[StringName] = [
	&"spine_01", &"spine_02", &"head", &"arm_l", &"forearm_l", &"arm_r", &"forearm_r"
]

@export_group("Reaction")
## Hit intensity (0..1) at or above which the enemy falls over instead of staggering.
@export_range(0.0, 1.0) var fall_intensity: float = 0.65
## This many hits while staggering also knock the enemy down.
@export var max_stagger_hits: int = 3
## How quickly the root's knockback slides to a stop (m/s^2).
@export var knockback_friction: float = 9.0

@export_group("Stagger")
@export var stagger_duration: float = 0.9
## Muscle strength right after the hit (0 = rag doll, 1 = fully stiff).
@export_range(0.0, 1.0) var limp_strength: float = 0.1
## Seconds for the muscles to reach full strength.
@export var muscle_ramp_time: float = 0.45
## How hard the servo pulls towards the target pose (1/s). Higher = stiffer.
@export var balance_gain: float = 14.0
## How fast the servo's angular velocity follows its goal (1/s).
@export var servo_response: float = 20.0
@export var max_servo_speed: float = 9.0
@export var stagger_recovery_time: float = 0.3

@export_group("Fall")
## Fraction of the force applied to every bone as a velocity change.
@export var fall_velocity_scale: float = 0.9
## Extra velocity change applied to the bone that was hit.
@export var hit_bone_velocity_scale: float = 0.8
@export var upward_kick: float = 0.3
@export var min_fall_time: float = 0.7
@export var max_fall_time: float = 4.0
## Below this pelvis/torso speed (m/s) the body counts as settled.
@export var settle_speed: float = 0.7
@export var settle_time: float = 0.35
@export var getup_blend_time: float = 0.7
## Optional AnimationTree state to travel to when getting up (needs a transition into it).
@export var getup_anim_state: StringName = &""
## World layers used to find the floor under the fallen body.
@export_flags_3d_physics var ground_mask: int = 1

var phase: Phase = Phase.IDLE

var _bones: Array[PhysicalBone3D] = []
var _bones_by_name: Dictionary = {}
var _stagger_set: Array[PhysicalBone3D] = []
var _stagger_names: Array[StringName] = []
var _servo_targets: Array[Basis] = []
var _root_bone: PhysicalBone3D
var _root_rest_in_actor: Basis = Basis.IDENTITY

var _phase_time: float = 0.0
var _muscle_time: float = 0.0
var _settle_timer: float = 0.0
var _stagger_hits: int = 0

var _actor_disabled: bool = false
var _saved_layer: int = 0
var _saved_mask: int = 0
var _blend_tween: Tween


func _ready() -> void:
	set_physics_process(false)
	if not is_instance_valid(ragdoll_skeleton):
		push_warning("ActiveRagdollStumbleController: ragdoll_skeleton is not set.")
		return

	for child in ragdoll_skeleton.get_children():
		if child is PhysicalBone3D:
			var bone: PhysicalBone3D = child as PhysicalBone3D
			_bones.append(bone)
			_bones_by_name[StringName(bone.bone_name)] = bone
			# The bones are children of the actor; stop them from colliding with its capsule.
			if is_instance_valid(actor):
				bone.add_collision_exception_with(actor)

	_root_bone = _bones_by_name.get(root_bone_name) as PhysicalBone3D
	if _root_bone == null and not _bones.is_empty():
		_root_bone = _bones[0]

	for bone_name in stagger_bones:
		var found: PhysicalBone3D = _bones_by_name.get(bone_name) as PhysicalBone3D
		if found:
			_stagger_set.append(found)
			_stagger_names.append(bone_name)


#region Public API

func can_begin() -> bool:
	return phase == Phase.IDLE and _is_configured()


func is_active() -> bool:
	return phase != Phase.IDLE


## `force` is a velocity change in m/s. `intensity` is 0..1 (damage relative to the thresholds).
## `hit_position` is optional (world space); without it the impulse goes to `stumble_bone`.
func begin(direction: Vector3, force: float, intensity: float = 0.5, hit_position: Vector3 = Vector3.INF) -> void:
	if not can_begin():
		return

	direction = _flatten(direction)
	intensity = clampf(intensity, 0.0, 1.0)
	_stagger_hits = 0
	# Remember how the pelvis sits relative to the actor while standing, used to pick a get-up facing.
	_root_rest_in_actor = actor.global_basis.orthonormalized().inverse() * _root_bone.global_basis.orthonormalized()

	set_physics_process(true)
	stumble_started.emit()
	if intensity >= fall_intensity or _stagger_set.is_empty():
		_enter_fall(direction, force, intensity, hit_position)
	else:
		_enter_stagger(direction, force, intensity, hit_position)


## Feed another hit into a reaction that is already running.
func add_hit(direction: Vector3, force: float, intensity: float = 0.5, hit_position: Vector3 = Vector3.INF) -> void:
	direction = _flatten(direction)
	intensity = clampf(intensity, 0.0, 1.0)
	match phase:
		Phase.STAGGER:
			_stagger_hits += 1
			if intensity >= fall_intensity or _stagger_hits >= max_stagger_hits:
				_enter_fall(direction, force, intensity, hit_position)
			else:
				_muscle_time = 0.0 # go limp again
				_phase_time = minf(_phase_time, stagger_duration * 0.5)
				_apply_hit(direction, force, intensity, hit_position, _stagger_set)
				_push_actor(direction, force * lerpf(0.35, 0.7, intensity))
		Phase.FALL:
			_settle_timer = 0.0
			_apply_hit(direction, force * 0.5, intensity, hit_position, _bones)
		_:
			pass


## Hands control over to the death ragdoll. Leaves the simulation running; the dead state
## starts the full simulation itself.
func cancel_for_death() -> void:
	_kill_blend()
	phase = Phase.IDLE
	set_physics_process(false)
	if is_instance_valid(ragdoll_skeleton):
		ragdoll_skeleton.influence = 1.0

#endregion


#region Phases

func _enter_stagger(direction: Vector3, force: float, intensity: float, hit_position: Vector3) -> void:
	phase = Phase.STAGGER
	_phase_time = 0.0
	_muscle_time = 0.0
	_capture_servo_targets()

	ragdoll_skeleton.influence = 1.0
	ragdoll_skeleton.active = true
	ragdoll_skeleton.physical_bones_start_simulation(_stagger_names)

	_apply_hit(direction, force, intensity, hit_position, _stagger_set)
	_push_actor(direction, force * lerpf(0.35, 0.7, intensity))


func _enter_fall(direction: Vector3, force: float, intensity: float, hit_position: Vector3) -> void:
	phase = Phase.FALL
	_phase_time = 0.0
	_settle_timer = 0.0
	_disable_actor()
	if is_instance_valid(anim_tree):
		anim_tree.active = false

	ragdoll_skeleton.influence = 1.0
	ragdoll_skeleton.active = true
	ragdoll_skeleton.physical_bones_start_simulation()
	_apply_hit(direction, force, intensity, hit_position, _bones)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.STAGGER:
			_step_stagger(delta)
		Phase.FALL:
			_step_fall(delta)
		Phase.RECOVER:
			_decay_knockback(delta)


func _step_stagger(delta: float) -> void:
	_phase_time += delta
	_muscle_time += delta
	_decay_knockback(delta)

	var ramp: float = smoothstep(0.0, maxf(muscle_ramp_time, 0.01), _muscle_time)
	_run_balance_servo(delta, lerpf(limp_strength, 1.0, ramp))

	if _phase_time >= stagger_duration:
		_begin_recovery()


func _step_fall(delta: float) -> void:
	_phase_time += delta
	if _phase_time < min_fall_time:
		return

	if _get_settle_speed() < settle_speed:
		_settle_timer += delta
	else:
		_settle_timer = 0.0

	if _settle_timer >= settle_time or _phase_time >= max_fall_time:
		_begin_recovery()


func _begin_recovery() -> void:
	var from_fall: bool = phase == Phase.FALL
	phase = Phase.RECOVER
	recovery_started.emit()

	if from_fall:
		# Put the actor under the body and face it the way the body lies, without dragging the
		# ragdoll along (the bones are children of the actor).
		var pelvis_position: Vector3 = _root_bone.global_position
		_teleport_actor_keep_ragdoll(
			Vector3(pelvis_position.x, _probe_floor_y(pelvis_position), pelvis_position.z),
			_get_getup_yaw()
		)

	if is_instance_valid(anim_tree):
		if not anim_tree.active:
			anim_tree.active = true
			anim_tree.advance(0.0)
		if from_fall and getup_anim_state != &"":
			_travel_anim(getup_anim_state)

	_kill_blend()
	_blend_tween = create_tween()
	_blend_tween.tween_property(
		ragdoll_skeleton, "influence", 0.0,
		getup_blend_time if from_fall else stagger_recovery_time
	)
	_blend_tween.finished.connect(_finish_recovery)


func _finish_recovery() -> void:
	_blend_tween = null
	ragdoll_skeleton.physical_bones_stop_simulation()
	ragdoll_skeleton.active = false
	ragdoll_skeleton.influence = 1.0
	_restore_actor()
	phase = Phase.IDLE
	set_physics_process(false)
	recovered.emit()

#endregion


#region Active balance

func _capture_servo_targets() -> void:
	# Target pose = the pose each bone had (relative to the animated pelvis) at the moment of impact.
	var inverse_root: Basis = _root_bone.global_basis.orthonormalized().inverse()
	_servo_targets.clear()
	for bone in _stagger_set:
		_servo_targets.append(inverse_root * bone.global_basis.orthonormalized())


func _run_balance_servo(delta: float, strength: float) -> void:
	var root_basis: Basis = _root_bone.global_basis.orthonormalized()
	var blend: float = clampf(strength * servo_response * delta, 0.0, 1.0)
	for i in _stagger_set.size():
		var bone: PhysicalBone3D = _stagger_set[i]
		var current: Basis = bone.global_basis.orthonormalized()
		var target: Basis = root_basis * _servo_targets[i]

		var error: Quaternion = (target * current.inverse()).get_rotation_quaternion()
		if error.w < 0.0:
			error = -error # shortest way round
		var desired: Vector3 = error.get_axis() * error.get_angle() * balance_gain * strength
		if desired.length() > max_servo_speed:
			desired = desired.normalized() * max_servo_speed

		var body: RID = bone.get_rid()
		var current_velocity: Vector3 = PhysicsServer3D.body_get_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
		PhysicsServer3D.body_set_state(
			body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, current_velocity.lerp(desired, blend)
		)

#endregion


#region Helpers

func _is_configured() -> bool:
	return is_instance_valid(actor) and is_instance_valid(ragdoll_skeleton) and _root_bone != null


func _flatten(direction: Vector3) -> Vector3:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return -actor.global_basis.z # the model faces +Z, so "behind" is -Z
	return direction.normalized()


func _push_actor(direction: Vector3, speed: float) -> void:
	if _actor_disabled:
		return
	actor.velocity.x += direction.x * speed
	actor.velocity.z += direction.z * speed


func _decay_knockback(delta: float) -> void:
	if _actor_disabled:
		return
	actor.velocity.x = move_toward(actor.velocity.x, 0.0, knockback_friction * delta)
	actor.velocity.z = move_toward(actor.velocity.z, 0.0, knockback_friction * delta)


func _apply_hit(
	direction: Vector3, force: float, intensity: float, hit_position: Vector3,
	candidates: Array[PhysicalBone3D]
) -> void:
	var impulse_direction: Vector3 = (direction + Vector3.UP * upward_kick * intensity).normalized()

	# Whole-body shove (only when everything is simulated). Impulse = velocity * mass.
	if phase == Phase.FALL:
		for bone in _bones:
			bone.apply_central_impulse(impulse_direction * force * fall_velocity_scale * bone.mass)

	# Extra punch where the bullet landed; the offset makes the body spin around the impact point.
	var hit_bone: PhysicalBone3D = _pick_hit_bone(hit_position, candidates)
	if hit_bone:
		var offset: Vector3 = Vector3.ZERO
		if hit_position.is_finite():
			offset = hit_position - hit_bone.global_position
		var speed: float = force * hit_bone_velocity_scale * lerpf(0.6, 1.0, intensity)
		hit_bone.apply_impulse(impulse_direction * speed * hit_bone.mass, offset)


func _pick_hit_bone(hit_position: Vector3, candidates: Array[PhysicalBone3D]) -> PhysicalBone3D:
	var best: PhysicalBone3D = null
	if stumble_bone and candidates.has(stumble_bone):
		best = stumble_bone
	if hit_position.is_finite():
		var best_distance: float = INF
		for bone in candidates:
			var distance: float = bone.global_position.distance_squared_to(hit_position)
			if distance < best_distance:
				best_distance = distance
				best = bone
	if best == null and not candidates.is_empty():
		best = candidates[0]
	return best


func _get_settle_speed() -> float:
	var speed: float = _body_speed(_root_bone)
	if stumble_bone and stumble_bone != _root_bone:
		speed = (speed + _body_speed(stumble_bone)) * 0.5
	return speed


func _body_speed(bone: PhysicalBone3D) -> float:
	var velocity: Vector3 = PhysicsServer3D.body_get_state(bone.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
	return velocity.length()


func _disable_actor() -> void:
	if _actor_disabled:
		return
	_actor_disabled = true
	_saved_layer = actor.collision_layer
	_saved_mask = actor.collision_mask
	actor.set_physics_process(false)
	actor.velocity = Vector3.ZERO
	actor.collision_layer = 0
	actor.collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)


func _restore_actor() -> void:
	if not _actor_disabled:
		return
	_actor_disabled = false
	actor.collision_layer = _saved_layer
	actor.collision_mask = _saved_mask
	actor.velocity = Vector3.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	actor.set_physics_process(true)


## Moves the actor without the simulated bones (its children) being dragged along with it.
func _teleport_actor_keep_ragdoll(new_position: Vector3, new_yaw: float) -> void:
	var saved: Array[Transform3D] = []
	for bone in _bones:
		saved.append(bone.global_transform)
	actor.global_position = new_position
	actor.rotation.y = new_yaw
	for i in _bones.size():
		_bones[i].global_transform = saved[i]


func _get_getup_yaw() -> float:
	# Rebuild "what would the actor's basis be if it had rotated with the pelvis".
	var upright: Basis = _root_bone.global_basis.orthonormalized() * _root_rest_in_actor.inverse()
	var forward: Vector3 = upright * Vector3.BACK
	var flat: Vector2 = Vector2(forward.x, forward.z)
	if flat.length() < 0.35:
		# Lying on the back or front: face along the head direction instead.
		var head: Vector3 = upright * Vector3.UP
		flat = Vector2(head.x, head.z)
	if flat.length() < 0.05:
		return actor.rotation.y
	return atan2(flat.x, flat.y)


func _probe_floor_y(from_position: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_position + Vector3.UP * 0.5,
		from_position + Vector3.DOWN * 3.0,
		ground_mask
	)
	var exclusions: Array[RID] = [actor.get_rid()]
	for bone in _bones:
		exclusions.append(bone.get_rid())
	query.exclude = exclusions
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return actor.global_position.y
	return (hit["position"] as Vector3).y


func _travel_anim(state_name: StringName) -> void:
	var machine: AnimationNodeStateMachine = anim_tree.tree_root as AnimationNodeStateMachine
	var playback: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"] as AnimationNodeStateMachinePlayback
	if machine and playback and machine.has_node(state_name):
		playback.travel(state_name)


func _kill_blend() -> void:
	if _blend_tween:
		_blend_tween.kill()
		_blend_tween = null

#endregion
