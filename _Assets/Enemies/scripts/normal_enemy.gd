class_name NormalEnemy
extends BaseEnemy

@export var follow_speed: float = 5.0
@export var max_step_up: float = 1.0
@export var max_step_down: float = 1.0


@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@onready var enemy_shoot_component: Node3D = $EnemyShootComponent



var character_height: float = 2.0
var attack_range: float = 10.0

var previous_velocity: Vector3
var target: Node3D
var is_sliding: bool = false

func _ready() -> void:
	super._ready()

	target = get_tree().get_first_node_in_group("player")
	health_component.died.connect(_on_died)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	# move_and_slide()
	if not _try_stair_stepping(velocity * delta):
		move_and_slide()


func on_triggered() -> void:
	# print("Saw Player")
	state_chart.send_event("toFollow")
	state_chart.send_event("toAttack")

func _on_velocity_computed(suggested_velocity: Vector3) -> void:
	velocity.x = suggested_velocity.x
	velocity.z = suggested_velocity.z

func _on_died() -> void:
	
	queue_free()

func _on_follow_state_physics_processing(delta: float) -> void:
	if not target:
		return

	navigation_agent.target_position = target.global_position


	if navigation_agent.is_navigation_finished():
		navigation_agent.velocity = Vector3.ZERO
		return

	# Move towards the target


	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()

	navigation_agent.velocity = direction * follow_speed



	if direction.length() > 0.01:
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)


func _on_detection_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		on_triggered()


func _on_attack_state_physics_processing(delta: float) -> void:
	if not target:
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Transition back to follow if player runs away
	if distance_to_target > attack_range:
		state_chart.send_event("toFollow")
		return
		
	# 1. Stop moving
	navigation_agent.velocity = Vector3.ZERO
	
	# 2. Rotate the Enemy Body Left/Right (Yaw)
	# We force the Y-axis to 0 so the enemy capsule doesn't tilt over on ramps/stairs.
	var flat_direction = Vector3(
		target.global_position.x - global_position.x, 
		0.0, 
		target.global_position.z - global_position.z
	).normalized()
	
	var target_rot = atan2(flat_direction.x, flat_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 10.0 * delta)
	
	# 3. Rotate the AimRaycast Up/Down/All-around (Pitch/Yaw)
	# We add a Y-offset so the enemy aims at your chest/head, not your feet!
	var aim_target_position = target.global_position + Vector3(0.0, 2.0, 0.0) # Adjust 2.0 based on your player's height
	
	# We grab the raycast and smoothly interpolate its 3D rotation towards the player
	var raycast = enemy_shoot_component.aim_raycast
	var current_transform = raycast.global_transform
	var target_transform = current_transform.looking_at(aim_target_position, Vector3.UP)
	
	# slerp (Spherical Linear Interpolation) makes the 3D rotation smooth
	raycast.global_transform.basis = current_transform.basis.slerp(target_transform.basis, 15.0 * delta)
	
	# 4. Pull the trigger!
	enemy_shoot_component.fire()

func _try_stair_stepping(motion: Vector3) -> bool:
	if motion.length_squared() == 0:
		return false
	

	var jt_transform = global_transform
	var params = PhysicsTestMotionParameters3D.new()
	params.from = jt_transform
	params.motion = motion
	var result = PhysicsTestMotionResult3D.new()

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
		move_and_slide()
		return true


	var step_up_transform = jt_transform.translated(Vector3(0, max_step_up, 0))
	params.from = step_up_transform
	params.motion = motion
	

	if not PhysicsServer3D.body_test_motion(get_rid(), params, result):

		var step_down_transform = step_up_transform.translated(result.get_travel())
		params.from = step_down_transform
		params.motion = Vector3(0, -max_step_up * 2.0, 0)
		
		if PhysicsServer3D.body_test_motion(get_rid(), params, result):

			global_position = step_down_transform.origin + result.get_travel()
			move_and_slide()
			return true

	return false
