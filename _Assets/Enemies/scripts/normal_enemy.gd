class_name NormalEnemy
extends BaseEnemy

@export var follow_speed: float = 5.0
@export var max_step_up: float = 1.0
@export var max_step_down: float = 1.0

@export var animation_player: AnimationPlayer
@export var anim_tree: AnimationTree
@export var ledge_raycast: RayCast3D
@export var ragdoll_skeleton: PhysicalBoneSimulator3D
@export var collision_shape: CollisionShape3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


@onready var triggerable_component: TriggerableComponent = $TriggerableComponent


@onready var enemy_shoot_component: EnemyShootingComponent = $EnemyShootComponent
@onready var body_kicker: Area3D = $BodyKicker


var character_height: float = 2.0
var attack_range: float = 10.0

var anim_tree_state: AnimationNodeStateMachinePlayback

var acceleration: float = 10.0
var deceleration: float = 10.0

var previous_velocity: Vector3
var target: Node3D
var is_sliding: bool = false
var is_dead: bool = false

#region Lifecycle

func _ready() -> void:
	super._ready()

	target = get_tree().get_first_node_in_group("player")
	health_component.died.connect(_on_died)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)



	anim_tree_state = anim_tree["parameters/playback"]
	# disable
		
	navigation_agent.target_desired_distance = randf_range(1.3, 3.0) # Randomize the distance to the player when following



func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	# If stair stepping handled the movement, we don't need to move_and_slide
	var handled_stairs = _try_stair_stepping(velocity * delta)
	if not handled_stairs:
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
	navigation_agent.target_position = target.global_position

	if navigation_agent.is_navigation_finished():
		navigation_agent.velocity = Vector3.ZERO
		# if animation_player and animation_player.current_animation != "Idle":
		# 	animation_player.play("Idle")
		return

	# Move towards the target
	# if not ledge_raycast.is_colliding() and is_on_floor():
	# 	var forward_dir = -global_transform.basis.z
	# 	velocity = forward_dir * follow_speed

	# 	state_chart.send_event("toAirborne")
	# 	return

	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()

	navigation_agent.velocity = direction * follow_speed

	var target_velocity_x = direction.x * follow_speed
	var target_velocity_z = direction.z * follow_speed

	if not navigation_agent.avoidance_enabled:
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity_z, acceleration * delta)
	# if animation_player and animation_player.current_animation != "Running":
	# 	animation_player.play("Running")
		# animation_player.seek(randf_range(0.0,animation_player.current_animation_length))

	if anim_tree_state.get_current_node() != "Follow":
		anim_tree_state.travel("Follow")

	if direction.length() > 0.01:
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)

func _on_airborne_state_physics_processing(delta: float) -> void:
	if is_on_floor() and velocity.y < 0.0:
		state_chart.send_event("toFollow")
		navigation_agent.target_position = target.global_position

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

func _on_detection_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_dead:
		on_triggered()

func on_triggered() -> void:
	# print("Saw Player")
	state_chart.send_event("toFollow")
	# state_chart.send_event("toAttack")

func on_trigger(player) -> void:
	# print("Saw Player")
	state_chart.send_event("toFollow")


func get_targetname() -> String:
	return triggerable_component.targetname if triggerable_component else ""

func _on_attack_state_physics_processing(delta: float) -> void:
	if not target:
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > attack_range:
		state_chart.send_event("toFollow")
		return

	# 1. Stop moving
	navigation_agent.velocity = Vector3.ZERO

	# 2. Rotate the Enemy Body Left/Right (Yaw) safely keeping Y flat
	var flat_direction = Vector3(
		target.global_position.x - global_position.x, 
		0.0, 
		target.global_position.z - global_position.z
	).normalized()
	
	if flat_direction.length_squared() > 0.001:
		var target_rot = atan2(flat_direction.x, flat_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 15.0 * delta)

	# 3. Rotate the Shoot Position Up/Down/All-Around using Quaternions
	if is_instance_valid(enemy_shoot_component.shoot_position):
		# Aim at the center of the player, not their toes (adjust the +1.0 if needed)
		var aim_target_position = target.global_position + Vector3(0.0, 1.0, 0.0) 
		
		var shoot_pos = enemy_shoot_component.shoot_position
		var aim_direction = (aim_target_position - shoot_pos.global_position).normalized()
		
		if aim_direction.length_squared() > 0.001:
			var target_basis = Basis.looking_at(aim_direction, Vector3.UP)
			
			# Use Quaternions to prevent scaling/stretching crashes!
			var current_quat = shoot_pos.global_basis.orthonormalized().get_rotation_quaternion()
			var target_quat = target_basis.get_rotation_quaternion()
			
			shoot_pos.global_basis = Basis(current_quat.slerp(target_quat, 15.0 * delta))
	
	# 4. Pull the trigger!
	enemy_shoot_component.fire()

#endregion

#region Death and Ragdoll

func _on_died() -> void:
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
	# stop rotation and looking for the player
	# rotation.y = 0
	navigation_agent.target_position = global_position
	
	# 2. Turn the main body into a ghost to prevent collision explosions
	collision_layer = 0
	collision_mask = 1
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
