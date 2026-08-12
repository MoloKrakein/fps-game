class_name NormalEnemy
extends BaseEnemy

@export var follow_speed: float = 5.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

@onready var shoot_component: EnemyShootComponent = $EnemyShootComponent

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

	move_and_slide()


func on_triggered() -> void:
	print("Saw Player")
	state_chart.send_event("toFollow")

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
	if distance_to_target > attack_range:
		state_chart.send_event("toFollow")
		return

	navigation_agent.velocity = Vector3.ZERO

	var direction_to_target = (target.global_position - global_position).normalized()
	var target_rot = atan2(direction_to_target.x, direction_to_target.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 15.0 * delta)

	shoot_component._execute_shot()
