class_name PlayerController extends CharacterBody3D


@export var debug: bool = false
@export_category("References")
@export var camera : CameraController
@export var state_chart : StateChart
@export var standing_col: CollisionShape3D
@export var crouching_col: CollisionShape3D
@export var crouch_check: ShapeCast3D
@export_category("Movement")
# @export var speed: float = 0.1
@export var default_speed: float = 0.1
@export var sprint_speed: float = 0.5
@export var crouch_speed: float = -5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0

@export_category("Jumping")
@export var jump_velocity: float = 4.5

@export_category("Sliding")
@export var slide_duration: float = 1.0
@export var slide_power: float = 10.0

@export_category("Settings")
@export var isToggleCrouch: bool = false
@export var isToggleSprint: bool = false

var _input_dir: Vector2 = Vector2.ZERO
var _movement_velocity: Vector3 = Vector3.ZERO
var sprint_modifier: float = 0.0
var speed : float = 0.0
var crouch_modifier: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var slide_modifier: float = 0.0

# settings
var is_crouching: bool = false
var is_sprinting: bool = false
var is_sliding: bool = false

func _physics_process(delta: float) -> void:
	
	# var acceleration = 
	# var deceleration = speed * delta
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	var speed_modifier: float = sprint_modifier + crouch_modifier
	speed = default_speed + speed_modifier + slide_modifier

	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var current_velocity = Vector2(_movement_velocity.x, _movement_velocity.z)
	var direction = (transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)).normalized()


	if direction != Vector3.ZERO:
		current_velocity = lerp(current_velocity, Vector2(direction.x, direction.z)* speed, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)

	

	_movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)

	velocity = _movement_velocity

	# if debug:
		# print("================================")
		# print("Input Direction: ", _input_dir)
		# print("Current Velocity: ", current_velocity)
		# print("Movement Velocity: ", _movement_velocity)
		# print("================================")
		# print("Speed: ", speed)
		# print("Sprint Modifier: ", sprint_modifier)
		# print("Crouch Modifier: ", crouch_modifier)
		# print("Is Sprinting: ", is_sprinting)
		# print("Is Crouching: ", is_crouching)

	move_and_slide()


func update_rotation(rotation_input)-> void:
	global_transform.basis = Basis.from_euler(rotation_input)

func sprint() -> void:
	sprint_modifier = sprint_speed
	if debug:
		print("Changed sprint modifier to: ", sprint_modifier)
	# is_sprinting = true

func walk() -> void:
	sprint_modifier = 0.0
	if debug:
		print("Changed sprint modifier to: ", sprint_modifier)
	# is_sprinting = false

func stand() -> void:
	crouch_modifier = 0.0
	standing_col.disabled = false
	crouching_col.disabled = true
	if debug:
		print("Changed crouch modifier to: ", crouch_modifier)
	is_crouching = false

func crouch() -> void:
	crouch_modifier = crouch_speed
	crouching_col.disabled = false
	standing_col.disabled = true
	if debug:
		print("Changed crouch modifier to: ", crouch_modifier)
	is_crouching = true

func jump() -> void:
	# if is_on_floor():
	velocity.y = jump_velocity

func start_slide() -> void:
	is_sliding = true
	_slide_direction = (transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)).normalized()
	# gradually decrease slide_modifier over time in _physics_process or a separate function
	slide_modifier = slide_power




func end_slide() -> void:
	is_sliding = false
	_slide_direction = Vector3.ZERO



