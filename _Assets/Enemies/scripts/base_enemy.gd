class_name BaseEnemy
extends CharacterBody3D
## Shared enemy brain: perception, squad-driven movement, cover / flank / shoot behaviour,
## traversal (stairs, vaulting, nav-link jumps) and death handling.
##
## The squad coordinator (EnemySquadCoordinator) decides WHAT each enemy should do through a
## SquadOrder: shoot (holds an attack token), wait in cover, or flank. This script decides HOW:
## path following, arriving, facing, aiming with inaccuracy, bursts, giving up.
##
## Derived enemies only add presentation (animation, ragdoll, hit reactions) by overriding the
## virtual hooks in the "Hooks" region. Expected child nodes: HealthComponent, StateChart,
## NavigationAgent3D, EnemyShootComponent. Optional: TriggerableComponent, BodyKicker.
##
## State chart events used: toIdle, toFollow, toAttack, toAirborne, toDead.
## Follow = move to / hold the squad slot, Attack = stand and shoot.

enum TraversalState {
	GROUND,
	AIRBORNE,
	VAULTING,
}

@export var enemy_groups: Array[String] = ["normal_enemies"]

@export_group("Movement")
@export var follow_speed: float = 5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0
@export var turn_speed_moving: float = 8.0
@export var turn_speed_aiming: float = 14.0
## Horizontal distance at which a slot counts as reached.
@export var arrive_tolerance: float = 1.0
## Slow down inside this distance of the slot.
@export var arrive_slow_radius: float = 2.5
## Seconds of not moving while wanting to move before the slot is considered unreachable.
@export var stuck_time: float = 1.2
@export var gravity: float = 20.0
@export var max_step_up: float = 1.0
@export var max_step_down: float = 1.0
@export var gap_jump_speed: float = 8.0
@export var vault_height: float = 1.5
@export var vault_distance: float = 1.5
@export var vault_duration: float = 0.45
@export var vault_obstacle_check_distance: float = 0.75

@export_group("Perception")
@export var vision_origin: Node3D
@export_range(1.0, 180.0, 1.0) var vision_angle: float = 110.0
@export var vision_range: float = 24.0
## Inside this radius the target is noticed even from behind (still needs a clear line).
@export var awareness_radius: float = 6.0
@export var target_aim_height: float = 1.0
## Seconds without sight before an attacking enemy stops shooting and moves.
@export var lost_target_memory: float = 1.5
## Seconds without sight before an engaged enemy gives up and goes back to idle.
@export var give_up_time: float = 20.0
@export var perception_interval: float = 0.15
@export_flags_3d_physics var vision_collision_mask: int = 3

@export_group("Combat")
@export var attack_range: float = 10.0
## Shooting positions are never closer to the target than this.
@export var min_attack_range: float = 4.0
@export var attack_reach_tolerance: float = 1.5
@export var burst_min_shots: int = 2
@export var burst_max_shots: int = 4
@export var burst_pause_min: float = 0.45
@export var burst_pause_max: float = 1.1
## Aim error in metres at 10 m right after starting to aim...
@export var aim_error_start: float = 0.9
## ...and after aiming for `aim_settle_time` seconds.
@export var aim_error_settled: float = 0.2
@export var aim_settle_time: float = 1.2
## Allies this close are alerted when this enemy first engages.
@export var alert_share_radius: float = 30.0

@export_group("Debug")
## Shows a floating label with the enemy's role, sight, ammo and firing permission.
@export var debug_ai: bool = false

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var enemy_shoot_component: EnemyShootingComponent = $EnemyShootComponent
@onready var triggerable_component: TriggerableComponent = get_node_or_null("TriggerableComponent") as TriggerableComponent
@onready var body_kicker: Area3D = get_node_or_null("BodyKicker") as Area3D

var target: Node3D
var squad_coordinator: EnemySquadCoordinator
var order: SquadOrder = SquadOrder.new()
var _debug_label: Label3D

var is_dead: bool = false
## True once the enemy noticed the player (or was alerted) and until it gives up.
var is_engaged: bool = false
var traversal_state: TraversalState = TraversalState.GROUND

# Perception
var target_visible: bool = false
var time_since_seen: float = INF
var last_known_target_position: Vector3 = Vector3.ZERO
var _perception_timer: float = 0.0
var _target_search_timer: float = 0.0

# Shooting
var burst_shots_remaining: int = 0
var burst_pause_timer: float = 0.0
var aim_time: float = 0.0
var _aim_offset: Vector3 = Vector3.ZERO
var _aim_noise_timer: float = 0.0

# Movement
var previous_velocity: Vector3
var _stuck_timer: float = 0.0
var _last_nav_target: Vector3 = Vector3.INF

# Vaulting
var vault_tween: Tween
var vault_start_position: Vector3
var vault_end_position: Vector3


#region Lifecycle

func _ready() -> void:
	for group in enemy_groups:
		add_to_group(group)

	target = get_tree().get_first_node_in_group("player")
	squad_coordinator = _get_or_create_squad_coordinator()
	squad_coordinator.register_enemy(self)

	health_component.died.connect(_on_died)
	health_component.damage_received.connect(_on_damage_received)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.target_desired_distance = arrive_tolerance * 0.8

	burst_shots_remaining = randi_range(burst_min_shots, burst_max_shots)
	# Spread the work of different enemies over different frames.
	_perception_timer = randf() * perception_interval


func _physics_process(delta: float) -> void:
	_update_perception(delta)
	_reload_if_empty()
	_update_debug_label()

	if traversal_state == TraversalState.VAULTING:
		velocity = Vector3.ZERO
		_update_animation()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# If stair stepping handled the movement, we don't need to move_and_slide
	var handled_stairs: bool = _try_stair_stepping(Vector3(velocity.x, 0.0, velocity.z) * delta)
	if not handled_stairs:
		if not _try_begin_vault():
			move_and_slide()

	_update_animation()


func _exit_tree() -> void:
	if is_instance_valid(squad_coordinator):
		squad_coordinator.unregister_enemy(self)

#endregion


#region Hooks (override in derived enemies)

## True while the enemy cannot act (hit reaction, dead). The squad skips such enemies.
func is_incapacitated() -> bool:
	return is_dead

func _on_idle(_delta: float) -> void:
	pass

## Called every frame in the Follow and Attack states.
func _on_combat_state(_delta: float) -> void:
	pass

func _update_animation() -> void:
	pass

func _on_death_started() -> void:
	pass

## Turn the body into a ragdoll here.
func _on_death_ragdoll() -> void:
	pass

#endregion


#region Perception and alerting

func _update_perception(delta: float) -> void:
	time_since_seen += delta
	if is_dead:
		return

	if not is_instance_valid(target):
		_target_search_timer -= delta
		if _target_search_timer <= 0.0:
			_target_search_timer = 1.0
			target = get_tree().get_first_node_in_group("player")
		target_visible = false
		return

	_perception_timer -= delta
	if _perception_timer > 0.0:
		return
	_perception_timer = perception_interval + randf() * 0.05

	target_visible = _can_see_target()
	if target_visible:
		time_since_seen = 0.0
		last_known_target_position = target.global_position
		engage()


## Starts fighting and wakes up nearby allies.
func engage() -> void:
	if is_dead or is_engaged:
		return
	is_engaged = true
	reset_navigation()
	state_chart.send_event("toFollow")
	if is_instance_valid(squad_coordinator) and is_instance_valid(target):
		squad_coordinator.alert_nearby(self, target.global_position, alert_share_radius)


## An ally spotted the target: start fighting without having seen it ourselves.
func receive_alert(alert_position: Vector3, new_target: Node3D) -> void:
	if is_dead or is_engaged:
		return
	if not is_instance_valid(target):
		target = new_target
	last_known_target_position = alert_position
	time_since_seen = 2.0
	is_engaged = true
	reset_navigation()
	state_chart.send_event("toFollow")


func disengage() -> void:
	is_engaged = false
	target_visible = false
	order.clear()
	burst_pause_timer = 0.0
	aim_time = 0.0
	reset_navigation()
	state_chart.send_event("toIdle")


func _can_see_target() -> bool:
	if not is_instance_valid(target):
		return false

	var origin: Node3D = _get_vision_origin()
	var target_position: Vector3 = _get_target_aim_position()
	var to_target: Vector3 = target_position - origin.global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.001 or distance_to_target > vision_range:
		return false

	# Vision cone uses the body's facing (the model looks along +Z), not the origin's basis, so it
	# also works when the origin is a bone.
	if distance_to_target > awareness_radius:
		var flat_to_target: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
		if flat_to_target.length_squared() > 0.0001:
			var facing: Vector3 = global_basis.z
			facing.y = 0.0
			var direction_dot: float = clampf(facing.normalized().dot(flat_to_target.normalized()), -1.0, 1.0)
			if rad_to_deg(acos(direction_dot)) > vision_angle * 0.5:
				return false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin.global_position,
		target_position,
		vision_collision_mask
	)
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider: Object = result.get("collider") as Object
	return collider == target or (collider is Node3D and target.is_ancestor_of(collider as Node3D))


func _get_vision_origin() -> Node3D:
	if is_instance_valid(vision_origin):
		return vision_origin
	if is_instance_valid(enemy_shoot_component.shoot_position):
		return enemy_shoot_component.shoot_position
	return self


func _get_target_aim_position() -> Vector3:
	return target.global_position + Vector3.UP * target_aim_height


func _on_detection_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_dead:
		target = body
		if _can_see_target():
			time_since_seen = 0.0
			last_known_target_position = target.global_position
			engage()


func on_triggered() -> void:
	if is_dead or not is_instance_valid(target):
		return
	time_since_seen = 0.0
	last_known_target_position = target.global_position
	engage()


## Called by trigger volumes / scripted events.
func on_trigger(player: Node3D) -> void:
	if is_dead:
		return
	target = player
	time_since_seen = 0.0
	last_known_target_position = player.global_position
	if is_engaged:
		state_chart.send_event("toFollow")
	else:
		engage()


func get_targetname() -> String:
	return triggerable_component.targetname if triggerable_component else ""

#endregion


#region Squad queries (used by the coordinator)

## True while the target is visible, or was a moment ago (avoids flickering on partial cover).
func has_recent_sight(max_age: float = 0.5) -> bool:
	return target_visible or time_since_seen <= max_age


func is_reloading() -> bool:
	return enemy_shoot_component != null and enemy_shoot_component.reload_timer > 0.0


func has_ammo() -> bool:
	return enemy_shoot_component == null or enemy_shoot_component.current_ammo > 0

#endregion


#region Follow state: move to / hold the squad slot

func _on_idle_state_state_physics_processing(delta: float) -> void:
	_on_idle(delta)


func _on_follow_state_physics_processing(delta: float) -> void:
	if not _can_act() or not is_instance_valid(target):
		return

	_on_combat_state(delta)

	if not target_visible and time_since_seen >= give_up_time:
		disengage()
		return

	if _should_start_firing():
		state_chart.send_event("toAttack")
		return

	var destination: Vector3 = _get_destination()
	if _at_position(destination):
		_stuck_timer = 0.0
		_stop_moving(delta)
		_turn_towards(_get_look_position() - global_position, turn_speed_aiming, delta)
	else:
		_move_to(destination, delta, order.speed_scale if order.is_fresh() else 1.0)
		_update_stuck(delta)


func _should_start_firing() -> bool:
	if not order.may_fire or not has_recent_sight(0.4):
		return false
	if is_reloading() or not has_ammo():
		return false
	var distance: float = global_position.distance_to(target.global_position)
	if distance > attack_range or distance < min_attack_range * 0.5:
		return false
	# Finish moving to the firing position first.
	if order.has_destination and not _at_position(order.destination):
		return false
	return true


func _get_destination() -> Vector3:
	if order.is_fresh():
		return order.destination
	# No orders (yet): close in on the last place the target was seen.
	if last_known_target_position != Vector3.ZERO:
		return last_known_target_position
	return target.global_position


func _get_look_position() -> Vector3:
	if order.is_fresh():
		return order.aim_position
	return target.global_position


func _at_position(point: Vector3, tolerance: float = -1.0) -> bool:
	var limit: float = arrive_tolerance if tolerance < 0.0 else tolerance
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= limit


func _move_to(destination: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	# Only re-path when the goal really moved; setting target_position every frame is expensive.
	if _last_nav_target.distance_squared_to(destination) > 0.25:
		navigation_agent.target_position = destination
		_last_nav_target = destination

	if navigation_agent.is_navigation_finished():
		_stop_moving(delta)
		return

	var next_position: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		_stop_moving(delta)
		return
	direction = direction.normalized()

	var speed: float = follow_speed * speed_scale
	var remaining: float = Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
	speed *= clampf(remaining / maxf(arrive_slow_radius, 0.01), 0.35, 1.0)
	var desired_velocity: Vector3 = direction * speed

	if navigation_agent.avoidance_enabled:
		# _on_velocity_computed applies the avoidance-corrected velocity.
		navigation_agent.velocity = desired_velocity
	else:
		velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)

	_turn_towards(direction, turn_speed_moving, delta)


func _stop_moving(delta: float) -> void:
	navigation_agent.velocity = Vector3.ZERO
	if not navigation_agent.avoidance_enabled:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)


func _update_stuck(delta: float) -> void:
	if Vector2(velocity.x, velocity.z).length() < 0.3:
		_stuck_timer += delta
		if _stuck_timer >= stuck_time:
			_stuck_timer = 0.0
			_last_nav_target = Vector3.INF
			squad_coordinator.report_stuck(self)
	else:
		_stuck_timer = 0.0


func _turn_towards(direction: Vector3, speed: float, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-speed * delta))


func reset_navigation() -> void:
	_last_nav_target = Vector3.INF
	_stuck_timer = 0.0
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector3.ZERO
		navigation_agent.target_position = global_position


func _on_velocity_computed(suggested_velocity: Vector3) -> void:
	# While reeling or dead, motion is driven by something else (e.g. knockback).
	if is_incapacitated():
		return
	var target_velocity: Vector3 = Vector3(suggested_velocity.x, velocity.y, suggested_velocity.z)
	var rate: float = acceleration if suggested_velocity.length() > 0.01 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * get_physics_process_delta_time())
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * get_physics_process_delta_time())

#endregion


#region Attack state: stand and shoot

func _on_attack_state_physics_processing(delta: float) -> void:
	if not _can_act():
		return
	if not is_instance_valid(target):
		state_chart.send_event("toFollow")
		return

	_on_combat_state(delta)
	burst_pause_timer = maxf(burst_pause_timer - delta, 0.0)

	var distance: float = global_position.distance_to(target.global_position)
	var lost_sight: bool = not target_visible and time_since_seen >= lost_target_memory
	var must_relocate: bool = order.has_destination and not _at_position(order.destination, arrive_tolerance * 2.5)
	if distance > attack_range + attack_reach_tolerance or lost_sight or must_relocate or not order.may_fire:
		aim_time = 0.0
		state_chart.send_event("toFollow")
		return

	_stop_moving(delta)
	aim_time += delta
	_aim_at_target(delta)

	if burst_pause_timer > 0.0:
		return
	if burst_shots_remaining <= 0 or is_reloading() or not has_ammo():
		_finish_burst()
		return

	enemy_shoot_component.fire()
	if enemy_shoot_component.fire_timer > 0.0:
		burst_shots_remaining -= 1


## The burst is over: pause, then hand the attack token to someone else.
func _finish_burst() -> void:
	burst_shots_remaining = randi_range(burst_min_shots, burst_max_shots)
	burst_pause_timer = randf_range(burst_pause_min, burst_pause_max)
	aim_time *= 0.5
	# Empty magazine: poke the weapon so it starts reloading (while we move to cover).
	if not has_ammo() and not is_reloading():
		enemy_shoot_component.fire()
	squad_coordinator.report_burst_finished(self)


func _aim_at_target(delta: float) -> void:
	var flat_direction: Vector3 = target.global_position - global_position
	_turn_towards(flat_direction, turn_speed_aiming, delta)

	if not is_instance_valid(enemy_shoot_component.shoot_position):
		return
	var shoot_pos: Node3D = enemy_shoot_component.shoot_position
	var aim_direction: Vector3 = (_get_noisy_aim_position(delta) - shoot_pos.global_position).normalized()
	if aim_direction.length_squared() <= 0.001:
		return

	var target_basis: Basis = Basis.looking_at(aim_direction, Vector3.UP)
	var current_quat: Quaternion = shoot_pos.global_basis.orthonormalized().get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	shoot_pos.global_basis = Basis(current_quat.slerp(target_quat, 1.0 - exp(-15.0 * delta)))


## Aim point with an error that shrinks the longer the enemy keeps aiming, and grows with distance.
func _get_noisy_aim_position(delta: float) -> Vector3:
	_aim_noise_timer -= delta
	if _aim_noise_timer <= 0.0:
		_aim_noise_timer = 0.35
		var settle: float = clampf(aim_time / maxf(aim_settle_time, 0.01), 0.0, 1.0)
		var error_at_ten_metres: float = lerpf(aim_error_start, aim_error_settled, settle)
		var radius: float = error_at_ten_metres * (global_position.distance_to(target.global_position) / 10.0)
		var random_direction: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0))
		_aim_offset = random_direction.normalized() * radius * randf()
	return _get_target_aim_position() + _aim_offset

#endregion


#region Traversal: stairs, vaulting, jumps

func _can_act() -> bool:
	return traversal_state == TraversalState.GROUND and not is_incapacitated()


func _is_character_blocker(result: PhysicsTestMotionResult3D) -> bool:
	var collider: Object = result.get_collider()
	return collider is CharacterBody3D or collider is PhysicalBone3D


func _try_stair_stepping(motion: Vector3) -> bool:
	if motion.length_squared() == 0 or not is_on_floor():
		return false

	var jt_transform: Transform3D = global_transform
	var params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	params.from = jt_transform
	params.motion = motion
	var result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()

	# 1. Test forward motion. If we don't hit a wall/stair, return false.
	# We let _physics_process handle normal move_and_slide().
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return false
	# Never step up onto other characters.
	if _is_character_blocker(result):
		return false

	# 2. We hit something! Test if we can step up over it.
	var step_up_transform: Transform3D = jt_transform.translated(Vector3(0, max_step_up, 0))
	params.from = step_up_transform
	params.motion = motion

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		# We can move forward up high. Now cast down to find the stair tread.
		var step_down_transform: Transform3D = step_up_transform.translated(result.get_travel())
		params.from = step_down_transform
		params.motion = Vector3(0, -max_step_up * 2.0, 0)

		if PhysicsServer3D.body_test_motion(get_rid(), params, result):
			# We found the stair floor! Move the enemy up and forward cleanly.
			global_position = step_down_transform.origin + result.get_travel()
			return true # We handled the movement, skip move_and_slide!

	return false


func _on_airborne_state_physics_processing(_delta: float) -> void:
	traversal_state = TraversalState.AIRBORNE

	if is_on_floor() and velocity.y < 0.0:
		traversal_state = TraversalState.GROUND
		state_chart.send_event("toFollow")
		reset_navigation()


func _on_navigation_agent_3d_link_reached(details: Dictionary) -> void:
	if is_dead or traversal_state == TraversalState.VAULTING:
		return

	var exit_position: Vector3 = _get_link_position(details, &"link_exit_position")
	var jump_direction: Vector3 = exit_position - global_position
	jump_direction.y = 0.0

	if jump_direction.length_squared() <= 0.001:
		jump_direction = global_basis.z

	jump_direction = jump_direction.normalized()
	velocity.x = jump_direction.x * follow_speed
	velocity.z = jump_direction.z * follow_speed
	velocity.y = gap_jump_speed
	traversal_state = TraversalState.AIRBORNE
	state_chart.send_event("toAirborne")


func _get_link_position(details: Dictionary, key: StringName) -> Vector3:
	var position_variant: Variant = details.get(key, global_position)
	if position_variant is Vector3:
		return position_variant as Vector3
	return global_position


func _try_begin_vault() -> bool:
	if traversal_state != TraversalState.GROUND or not is_on_floor() or not is_engaged:
		return false

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() <= 0.001:
		return false

	var direction: Vector3 = horizontal_velocity.normalized()
	var body_test_parameters: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	var body_test_result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	body_test_parameters.from = global_transform
	body_test_parameters.motion = direction * vault_obstacle_check_distance

	if not PhysicsServer3D.body_test_motion(get_rid(), body_test_parameters, body_test_result):
		return false
	# Do not vault over allies standing in the way.
	if _is_character_blocker(body_test_result):
		return false

	var raised_transform: Transform3D = global_transform.translated(Vector3.UP * vault_height)
	body_test_parameters.from = raised_transform
	body_test_parameters.motion = direction * vault_distance

	if PhysicsServer3D.body_test_motion(get_rid(), body_test_parameters, body_test_result):
		return false

	var landing_transform: Transform3D = raised_transform.translated(direction * vault_distance)
	body_test_parameters.from = landing_transform
	body_test_parameters.motion = Vector3.DOWN * (vault_height + max_step_down)

	if not PhysicsServer3D.body_test_motion(get_rid(), body_test_parameters, body_test_result):
		return false

	var landing_position: Vector3 = landing_transform.origin + body_test_result.get_travel()

	_begin_vault(landing_position, direction)
	return true


func _begin_vault(landing_position: Vector3, direction: Vector3) -> void:
	traversal_state = TraversalState.VAULTING
	velocity = Vector3.ZERO
	navigation_agent.velocity = Vector3.ZERO
	vault_start_position = global_position
	vault_end_position = landing_position

	if vault_tween != null:
		vault_tween.kill()

	var vault_apex: Vector3 = vault_start_position.lerp(vault_end_position, 0.5)
	vault_apex.y = maxf(vault_start_position.y, vault_end_position.y) + vault_height
	vault_tween = create_tween()
	vault_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	vault_tween.tween_method(_set_vault_position, vault_start_position, vault_apex, vault_duration * 0.5)
	vault_tween.tween_method(_set_vault_position, vault_apex, vault_end_position, vault_duration * 0.5)
	vault_tween.finished.connect(_finish_vault)

	rotation.y = atan2(direction.x, direction.z)


func _set_vault_position(new_position: Vector3) -> void:
	global_position = new_position


func _finish_vault() -> void:
	if is_dead:
		return

	vault_tween = null
	global_position = vault_end_position
	traversal_state = TraversalState.GROUND
	reset_navigation()


func _cancel_vault() -> void:
	if vault_tween:
		vault_tween.kill()
		vault_tween = null
	if traversal_state == TraversalState.VAULTING:
		traversal_state = TraversalState.GROUND

#endregion


## The weapon only starts reloading when asked to fire with an empty magazine. Without this an
## enemy that ran dry would never be picked for an attack token again and stop shooting forever.
func _reload_if_empty() -> void:
	if is_dead or not is_engaged or enemy_shoot_component == null:
		return
	if not has_ammo() and not is_reloading():
		enemy_shoot_component.fire()


func _update_debug_label() -> void:
	if not debug_ai:
		if _debug_label:
			_debug_label.queue_free()
			_debug_label = null
		return
	if _debug_label == null:
		_debug_label = Label3D.new()
		_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_debug_label.no_depth_test = true
		_debug_label.pixel_size = 0.004
		_debug_label.font_size = 40
		_debug_label.outline_size = 12
		_debug_label.position = Vector3(0.0, 2.6, 0.0)
		add_child(_debug_label)
	var distance: float = global_position.distance_to(target.global_position) if is_instance_valid(target) else -1.0
	_debug_label.text = "%s  fire:%s  engaged:%s\nsee:%s (%.1fs)  dist:%.1f\nammo:%d  reloading:%s" % [
		order.role, order.may_fire, is_engaged,
		target_visible, minf(time_since_seen, 99.0), distance,
		enemy_shoot_component.current_ammo if enemy_shoot_component else -1, is_reloading()
	]


#region Damage and death

func _on_damage_received(info: DamageInfo, _applied_damage: float) -> void:
	if is_dead:
		return
	# Being shot reveals where the shot came from, and wakes the squad up.
	if info.attacker is Node3D:
		var attacker: Node3D = info.attacker as Node3D
		if not is_instance_valid(target) and attacker.is_in_group("player"):
			target = attacker
		if attacker == target:
			last_known_target_position = attacker.global_position
			time_since_seen = minf(time_since_seen, 0.5)
	engage()


func _on_died() -> void:
	if is_dead:
		return
	# Set immediately so nothing (hit reactions, vaulting, damage) can start after this point.
	is_dead = true
	add_to_group("dead")
	if is_instance_valid(squad_coordinator):
		# Allies near a dead squad mate know there is a fight.
		if is_instance_valid(target):
			squad_coordinator.alert_nearby(self, target.global_position, alert_share_radius)
		squad_coordinator.unregister_enemy(self)
	_cancel_vault()
	_on_death_started()
	state_chart.send_event("toDead")
	# put the enemy into a ragdoll group so the player can kick it around
	add_to_group("ragdoll")
	if is_instance_valid(body_kicker):
		body_kicker.queue_free()
	if is_instance_valid(navigation_agent):
		navigation_agent.queue_free()


func _on_dead_state_entered() -> void:
	# Stop the root body from running gravity / move_and_slide so it can't drag the ragdoll around.
	set_physics_process(false)
	is_dead = true
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector3.ZERO
		navigation_agent.target_position = global_position

	if triggerable_component:
		triggerable_component.queue_free()
		triggerable_component = null

	# Turn the root body into a ghost to prevent collision explosions
	collision_layer = 0
	collision_mask = 0
	_disable_root_collision()

	_on_death_ragdoll()

	# Free the corpse after 5 seconds. Connecting (instead of awaiting) is safe if we're freed earlier.
	get_tree().create_timer(5.0).timeout.connect(queue_free)


## Override to also disable the capsule collision shape.
func _disable_root_collision() -> void:
	pass


# The scene connects DeadState's physics-processing signal here; nothing to do while dead.
func _on_dead_state_physics_processing(_delta: float) -> void:
	pass

#endregion


func _get_or_create_squad_coordinator() -> EnemySquadCoordinator:
	var scene_root: Node = get_tree().root
	if scene_root.has_meta(&"enemy_squad_coordinator"):
		var existing_variant: Variant = scene_root.get_meta(&"enemy_squad_coordinator")
		var existing: EnemySquadCoordinator = existing_variant as EnemySquadCoordinator
		if is_instance_valid(existing):
			return existing

	var created: EnemySquadCoordinator = EnemySquadCoordinator.new()
	created.add_to_group("enemy_squad_coordinator")
	scene_root.set_meta(&"enemy_squad_coordinator", created)
	scene_root.add_child.call_deferred(created)
	return created
