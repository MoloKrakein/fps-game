class_name NormalEnemy
extends BaseEnemy

@export var follow_speed: float = 5.0
@export var max_step_up: float = 1.0
@export var max_step_down: float = 1.0
@export var gap_jump_speed: float = 8.0
@export var gravity: float = 20.0
@export var vault_height: float = 1.5
@export var vault_distance: float = 1.5
@export var vault_duration: float = 0.45
@export var vault_obstacle_check_distance: float = 0.75
@export_category("Perception")
@export var vision_origin: Node3D
@export_range(1.0, 180.0, 1.0) var vision_angle: float = 110.0
@export var vision_range: float = 24.0
@export var target_aim_height: float = 1.0
@export var lost_target_memory: float = 1.5
@export var vision_collision_mask: int = 3
@export_category("Combat")
@export var attack_range: float = 10.0
@export var attack_reach_tolerance: float = 1.5
@export var cover_reposition_distance: float = 2.0
@export var burst_min_shots: int = 2
@export var burst_max_shots: int = 4
@export var burst_pause_min: float = 0.45
@export var burst_pause_max: float = 1.1
@export var flank_reposition_interval: float = 3.0

@export var animation_player: AnimationPlayer
@export var anim_tree: AnimationTree
@export var ledge_raycast: RayCast3D
@export var ragdoll_skeleton: PhysicalBoneSimulator3D
@export var stumble_bone: PhysicalBone3D
@export var stumble_threshold: float = 35.0
@export var stumble_force: float = 8.0
@export var stumble_duration: float = 0.4
@export var stumble_state: StateChartState
@export var collision_shape: CollisionShape3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


@onready var triggerable_component: TriggerableComponent = $TriggerableComponent


@onready var enemy_shoot_component: EnemyShootingComponent = $EnemyShootComponent
@onready var body_kicker: Area3D = $BodyKicker


var character_height: float = 2.0
var anim_tree_state: AnimationNodeStateMachinePlayback

var acceleration: float = 10.0
var deceleration: float = 10.0

var previous_velocity: Vector3
var target: Node3D
var is_sliding: bool = false
var is_dead: bool = false
var vault_tween: Tween
var vault_start_position: Vector3
var vault_end_position: Vector3
var is_stumbling: bool = false
var pending_stumble_direction: Vector3 = Vector3.ZERO
var stumble_controller: ActiveRagdollStumbleController
var lost_target_time: float = 0.0
var squad_coordinator: EnemySquadCoordinator
var tactical_destination: Vector3 = Vector3.ZERO
var tactical_refresh_timer: float = 0.0
var burst_shots_remaining: int = 0
var burst_pause_timer: float = 0.0
var needs_reposition: bool = false

enum TraversalState {
	GROUND,
	AIRBORNE,
	VAULTING,
}

var traversal_state: TraversalState = TraversalState.GROUND

#region Lifecycle

func _ready() -> void:
	super._ready()

	target = get_tree().get_first_node_in_group("player")
	squad_coordinator = _get_or_create_squad_coordinator()
	squad_coordinator.register_enemy(self)
	health_component.died.connect(_on_died)
	health_component.damage_received.connect(_on_damage_received)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	stumble_controller = ActiveRagdollStumbleController.new()
	stumble_controller.actor = self
	stumble_controller.ragdoll_skeleton = ragdoll_skeleton
	stumble_controller.stumble_bone = stumble_bone
	stumble_controller.anim_tree = anim_tree
	stumble_controller.collision_shape = collision_shape
	stumble_controller.stumble_duration = stumble_duration
	stumble_controller.recovered.connect(_on_stumble_recovered)
	add_child(stumble_controller)
	if stumble_state:
		stumble_state.state_entered.connect(_on_stumble_state_entered)
		print("Connected to stumble state entered signal")



	anim_tree_state = anim_tree["parameters/playback"]
	# disable
		
	navigation_agent.target_desired_distance = randf_range(1.3, 3.0) # Randomize the distance to the player when following
	tactical_refresh_timer = randf_range(0.0, flank_reposition_interval)
	burst_shots_remaining = randi_range(burst_min_shots, burst_max_shots)



func _physics_process(delta: float) -> void:
	if traversal_state == TraversalState.VAULTING:
		_on_vaulting_state_physics_processing()
		update_blends()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# If stair stepping handled the movement, we don't need to move_and_slide
	var handled_stairs = _try_stair_stepping(velocity * delta)
	if not handled_stairs:
		if not _try_begin_vault():
			move_and_slide()
		
	# ALWAYS update blends, regardless of whether we climbed a stair or walked flat!
	update_blends()

#endregion

#region Navigation and Movement

func _try_stair_stepping(motion: Vector3) -> bool:
	if motion.length_squared() == 0:
		return false

	var jt_transform = global_transform
	var params = PhysicsTestMotionParameters3D.new()
	params.from = jt_transform
	params.motion = motion
	var result = PhysicsTestMotionResult3D.new()

	# 1. Test forward motion. If we don't hit a wall/stair, return false.
	# We let _physics_process handle normal move_and_slide().
	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		return false

	# 2. We hit something! Test if we can step up over it.
	var step_up_transform = jt_transform.translated(Vector3(0, max_step_up, 0))
	params.from = step_up_transform
	params.motion = motion

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		# We can move forward up high. Now cast down to find the stair tread.
		var step_down_transform = step_up_transform.translated(result.get_travel())
		params.from = step_down_transform
		params.motion = Vector3(0, -max_step_up * 2.0, 0)

		if PhysicsServer3D.body_test_motion(get_rid(), params, result):
			# We found the stair floor! Move the enemy up and forward cleanly.
			global_position = step_down_transform.origin + result.get_travel()
			return true # We handled the movement, skip move_and_slide!

	return false

func _on_velocity_computed(suggested_velocity: Vector3) -> void:
	var target_velocity = Vector3(suggested_velocity.x, velocity.y, suggested_velocity.z)
	var acceleration = acceleration if suggested_velocity.length() > 0.01 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * get_physics_process_delta_time())
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * get_physics_process_delta_time())

func _on_follow_state_physics_processing(delta: float) -> void:
	if traversal_state != TraversalState.GROUND:
		return

	if not is_instance_valid(target):
		return

	if needs_reposition:
		tactical_refresh_timer = maxf(tactical_refresh_timer - delta, 0.0)
		if tactical_refresh_timer <= 0.0 or tactical_destination == Vector3.ZERO:
			tactical_destination = squad_coordinator.get_tactical_destination(self, target)
			tactical_refresh_timer = flank_reposition_interval
		navigation_agent.target_position = tactical_destination
		if global_position.distance_to(tactical_destination) > cover_reposition_distance:
			_navigate_to_tactical_destination(delta)
			return
		needs_reposition = false

	if _can_see_target() and global_position.distance_to(target.global_position) <= attack_range:
		lost_target_time = 0.0
		state_chart.send_event("toAttack")
		return

	tactical_refresh_timer = maxf(tactical_refresh_timer - delta, 0.0)
	if tactical_refresh_timer <= 0.0 or tactical_destination == Vector3.ZERO:
		tactical_destination = squad_coordinator.get_tactical_destination(self, target)
		tactical_refresh_timer = flank_reposition_interval
	navigation_agent.target_position = tactical_destination

	if navigation_agent.is_navigation_finished() and global_position.distance_to(tactical_destination) <= cover_reposition_distance:
		navigation_agent.velocity = Vector3.ZERO
		# if animation_player and animation_player.current_animation != "Idle":
		# 	animation_player.play("Idle")
		return

	_navigate_to_tactical_destination(delta)

	# if animation_player and animation_player.current_animation != "Running":
	# 	animation_player.play("Running")
		# animation_player.seek(randf_range(0.0,animation_player.current_animation_length))

	if anim_tree_state.get_current_node() != "Follow":
		anim_tree_state.travel("Follow")

func _on_airborne_state_physics_processing(delta: float) -> void:
	traversal_state = TraversalState.AIRBORNE

	if is_on_floor() and velocity.y < 0.0:
		traversal_state = TraversalState.GROUND
		state_chart.send_event("toFollow")
		tactical_destination = Vector3.ZERO

func _on_navigation_agent_3d_link_reached(details: Dictionary) -> void:
	if is_dead or traversal_state == TraversalState.VAULTING:
		return

	var exit_position: Vector3 = _get_link_position(details, &"link_exit_position")
	var jump_direction: Vector3 = exit_position - global_position
	jump_direction.y = 0.0

	if jump_direction.length_squared() <= 0.001:
		jump_direction = -global_transform.basis.z

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
	if traversal_state != TraversalState.GROUND or not is_on_floor():
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
	navigation_agent.target_position = global_position
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

	var target_rotation: float = atan2(direction.x, direction.z)
	rotation.y = target_rotation

func _set_vault_position(position: Vector3) -> void:
	global_position = position

func _on_vaulting_state_physics_processing() -> void:
	velocity = Vector3.ZERO

func _finish_vault() -> void:
	if is_dead:
		return

	vault_tween = null
	global_position = vault_end_position
	traversal_state = TraversalState.GROUND
	navigation_agent.target_position = target.global_position if is_instance_valid(target) else global_position


#endregion

#region Animation

func _on_idle_state_state_physics_processing(delta: float) -> void:
	if anim_tree_state.get_current_node() != "Idle":
		anim_tree_state.travel("Idle")

func update_blends() -> void:
	var move_amount = velocity.length()
	move_amount = remap(move_amount,0.0,follow_speed,0.0,1.0)
	anim_tree["parameters/Follow/IdleRunBlend/blend_position"] = move_amount

#endregion

#region Combat and Detection

func _on_damage_received(info: DamageInfo, _applied_damage: float) -> void:
	if is_dead or is_stumbling or health_component.current_health <= 0.0:
		return

	if info.raw_damage < stumble_threshold:
		return

	pending_stumble_direction = _get_stumble_direction(info)
	state_chart.send_event("toStumble")

func _get_stumble_direction(info: DamageInfo) -> Vector3:
	var impact_direction: Vector3 = info.impact_direction
	if info.attacker is Node3D:
		var attacker: Node3D = info.attacker as Node3D
		var direction_from_attacker: Vector3 = global_position - attacker.global_position
		if direction_from_attacker.length_squared() > 0.001:
			impact_direction = direction_from_attacker.normalized()

	if impact_direction.length_squared() <= 0.001:
		impact_direction = global_transform.basis.z
	return impact_direction.normalized()

func _on_stumble_state_entered() -> void:
	if is_dead or is_stumbling or not stumble_controller:
		return

	is_stumbling = true
	navigation_agent.velocity = Vector3.ZERO
	navigation_agent.target_position = global_position

	if not stumble_controller.can_begin():
		is_stumbling = false
		state_chart.send_event("toFollow")
		return
	stumble_controller.begin(pending_stumble_direction, stumble_force)

func _on_stumble_recovered() -> void:
	if is_dead:
		return

	is_stumbling = false
	state_chart.send_event("toFollow")

func _on_detection_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_dead:
		target = body
		lost_target_time = 0.0
		if _can_see_target():
			on_triggered()

func on_triggered() -> void:
	if is_dead or not _can_see_target():
		return
	state_chart.send_event("toAttack")

func on_trigger(player: Node3D) -> void:
	if is_dead:
		return

	target = player
	lost_target_time = 0.0
	state_chart.send_event("toFollow")


func get_targetname() -> String:
	return triggerable_component.targetname if triggerable_component else ""

func _on_attack_state_physics_processing(delta: float) -> void:
	if not is_instance_valid(target):
		state_chart.send_event("toFollow")
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > attack_range + attack_reach_tolerance:
		state_chart.send_event("toFollow")
		return

	if not _can_see_target():
		lost_target_time += delta
		navigation_agent.velocity = Vector3.ZERO
		if lost_target_time >= lost_target_memory:
			state_chart.send_event("toFollow")
		return

	lost_target_time = 0.0
	navigation_agent.velocity = Vector3.ZERO
	burst_pause_timer = maxf(burst_pause_timer - delta, 0.0)

	var flat_direction = Vector3(
		target.global_position.x - global_position.x, 
		0.0, 
		target.global_position.z - global_position.z
	).normalized()
	
	if flat_direction.length_squared() > 0.001:
		var target_rot = atan2(flat_direction.x, flat_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 15.0 * delta)

	if is_instance_valid(enemy_shoot_component.shoot_position):
		var aim_target_position: Vector3 = _get_target_aim_position()
		var shoot_pos = enemy_shoot_component.shoot_position
		var aim_direction = (aim_target_position - shoot_pos.global_position).normalized()
		
		if aim_direction.length_squared() > 0.001:
			var target_basis = Basis.looking_at(aim_direction, Vector3.UP)
			
			var current_quat = shoot_pos.global_basis.orthonormalized().get_rotation_quaternion()
			var target_quat = target_basis.get_rotation_quaternion()
			
			shoot_pos.global_basis = Basis(current_quat.slerp(target_quat, 15.0 * delta))

	if burst_pause_timer > 0.0:
		return
	if burst_shots_remaining <= 0:
		burst_shots_remaining = randi_range(burst_min_shots, burst_max_shots)
		burst_pause_timer = randf_range(burst_pause_min, burst_pause_max)
		needs_reposition = true
		tactical_destination = Vector3.ZERO
		state_chart.send_event("toFollow")
		return

	enemy_shoot_component.fire()
	if enemy_shoot_component.fire_timer > 0.0:
		burst_shots_remaining -= 1

func _can_see_target() -> bool:
	if not is_instance_valid(target):
		return false

	var origin: Node3D = _get_vision_origin()
	var target_position: Vector3 = _get_target_aim_position()
	var to_target: Vector3 = target_position - origin.global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.001 or distance_to_target > vision_range:
		return false

	var view_direction: Vector3 = -origin.global_transform.basis.z
	var direction_dot: float = clampf(view_direction.normalized().dot(to_target.normalized()), -1.0, 1.0)
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

func _navigate_to_tactical_destination(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		navigation_agent.velocity = Vector3.ZERO
		return

	var next_pos: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = (next_pos - global_position).normalized()
	navigation_agent.velocity = direction * follow_speed

	var target_velocity_x: float = direction.x * follow_speed
	var target_velocity_z: float = direction.z * follow_speed
	if not navigation_agent.avoidance_enabled:
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity_z, acceleration * delta)

	if direction.length_squared() > 0.001:
		var target_rot: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)

func _get_vision_origin() -> Node3D:
	if is_instance_valid(vision_origin):
		return vision_origin
	if is_instance_valid(enemy_shoot_component.shoot_position):
		return enemy_shoot_component.shoot_position
	return self

func _get_target_aim_position() -> Vector3:
	return target.global_position + Vector3.UP * target_aim_height

#endregion

#region Death and Ragdoll

func _on_died() -> void:
	add_to_group("dead")
	if squad_coordinator:
		squad_coordinator.unregister_enemy(self)
	if stumble_controller:
		stumble_controller.cancel_for_death()
	state_chart.send_event("toDead")
	# put the enemy into a ragdoll group so the player can kick it around
	add_to_group("ragdoll")
	body_kicker.queue_free()
	navigation_agent.queue_free()

func _on_dead_state_entered() -> void:
	# 1. STOP the main body from running gravity and move_and_slide!
	# This prevents the parent node from dragging the ragdoll into the void.
	set_physics_process(false)
	is_dead = true
	navigation_agent.velocity = Vector3.ZERO
	# remove triggerable component
	if triggerable_component:
		triggerable_component.queue_free()
		triggerable_component = null
	# stop rotation and looking for the player
	# rotation.y = 0
	navigation_agent.target_position = global_position
	
	# 2. Turn the main body into a ghost to prevent collision explosions
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# 3. Disable the AnimationTree so it stops forcing poses
	if anim_tree:
		anim_tree.active = false
	
	# 4. Activate the Godot 4.3 Simulator and let bones take over
	if ragdoll_skeleton:
		ragdoll_skeleton.active = true
		print(ragdoll_skeleton.active)
		ragdoll_skeleton.physical_bones_start_simulation()
		
	# 5. Clean up after 5 seconds
	await get_tree().create_timer(5.0).timeout
	queue_free()

#endregion


func _on_stumble_state_physics_processing(delta: float) -> void:
	# Handle the physics processing for the stumble state
	# This is where you would implement the specific behavior for when the enemy is stumbling
	pass

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

func _exit_tree() -> void:
	if is_instance_valid(squad_coordinator):
		squad_coordinator.unregister_enemy(self)
