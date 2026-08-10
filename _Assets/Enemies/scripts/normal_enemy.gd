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
	pass
