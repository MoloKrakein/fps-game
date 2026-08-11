class_name NormalEnemy
extends BaseEnemy

@export var follow_speed: float = 5.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var state_chart: StateChart = $StateChart
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


var target: Node3D

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
	state_chart.send_event("toFollow")

func _on_velocity_computed(suggested_velocity: Vector3) -> void:
	velocity.x = suggested_velocity.x
	velocity.z = suggested_velocity.z

func _on_died() -> void:
	var timer = Timer.new()
	# since the enemy just simple cylinder, make this object fall over the ground, so we can see the death animation

	timer.wait_time = 1.0
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_death_timer_timeout"))
	add_child(timer)
	timer.start()
	queue_free()

func _on_follow_state_physics_processing(delta: float) -> void:
	# move towards the target using the navigation agent

	if not target:
		return

	navigation_agent.target_position = target.global_position


	if navigation_agent.is_navigation_finished():
		navigation_agent.velocity = Vector3.ZERO
		return

	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()

	navigation_agent.velocity = direction * follow_speed

	if direction.length() > 0.01:
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 5.0 * delta)


func _on_detection_range_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		on_triggered()
