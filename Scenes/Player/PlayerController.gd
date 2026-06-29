class_name PlayerController extends CharacterBody3D


@export var debug: bool = false
@export_category("References")
@export var camera : CameraController
@export var state_chart : StateChart
# @export standing_col:CollisionShape3D
@export_category("Movement")
# @export var speed: float = 0.1
@export var default_speed: float = 0.1
@export var sprint_speed: float = 0.5
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0

var _input_dir: Vector2 = Vector2.ZERO
var _movement_velocity: Vector3 = Vector3.ZERO
var sprint_modifier: float = 0.0
var speed : float = 0.0


func _physics_process(delta: float) -> void:
	
	# var acceleration = 
	# var deceleration = speed * delta
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var current_velocity = Vector2(_movement_velocity.x, _movement_velocity.z)
	var direction = (transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		current_velocity = lerp(current_velocity, Vector2(direction.x, direction.z)*speed, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)


	var speed_modifier: float = sprint_modifier
	speed = default_speed + speed_modifier

	_movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)

	velocity = _movement_velocity

	if debug:
		print("Input Direction: ", _input_dir)
		print("Current Velocity: ", current_velocity)
		print("Movement Velocity: ", _movement_velocity)

	move_and_slide()


func update_rotation(rotation_input)-> void:
	global_transform.basis = Basis.from_euler(rotation_input)

func sprint() -> void:
	sprint_modifier = sprint_speed

func walk() -> void:
	sprint_modifier = 0.0


# const SPEED = 5.0
# const JUMP_VELOCITY = 4.5


# func _physics_process(delta: float) -> void:
# 	# Add the gravity.
# 	if not is_on_floor():
# 		velocity += get_gravity() * delta

# 	# Handle jump.
# 	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
# 		velocity.y = JUMP_VELOCITY

# 	# Get the input direction and handle the movement/deceleration.
# 	# As good practice, you should replace UI actions with custom gameplay actions.
# 	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
# 	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
# 	if direction:
# 		velocity.x = direction.x * SPEED
# 		velocity.z = direction.z * SPEED
# 	else:
# 		velocity.x = move_toward(velocity.x, 0, SPEED)
# 		velocity.z = move_toward(velocity.z, 0, SPEED)

# 	move_and_slide()
