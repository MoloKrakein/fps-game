class_name PlayerController extends CharacterBody3D


@export var debug: bool = false
@export_category("References")
@export var camera : CameraController
@export var state_chart : StateChart
@export var weapon_controller: WeaponController
@export var standing_col: CollisionShape3D
@export var crouching_col: CollisionShape3D
@export var crouch_check: ShapeCast3D
@export var interaction_raycast: RayCast3D
@export var cam_effects: CamEffects
@export var step_handler: StepHandlerComponent
@export_category("Movement")
# @export var speed: float = 0.1
@export var default_speed: float = 0.1
@export var sprint_speed: float = 0.5
@export var crouch_speed: float = -5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0

@export_category("Jumping")
@export var jump_velocity: float = 4.5
@export var fall_velocity_threshold: float = -5.0

@export_category("Sliding")
@export var slide_duration: float = 1.0
@export var slide_power: float = 10.0
@export var slide_cooldown: float = 1.0
@export var min_slide_momentum: float = 4.0

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
var _current_slide_cooldown: float = 0.0
var _current_max_velocity: float = 0.0
var current_fall_velocity: float = 0.0
var previous_velocity: Vector3 = Vector3.ZERO
var current_player_rotation: float = 0.0

# settings
var is_crouching: bool = false
var is_sprinting: bool = false
var is_sliding: bool = false


func _physics_process(delta: float) -> void:
	
#region Physics Process
	previous_velocity = velocity
	# var acceleration = 
	# var deceleration = speed * delta
	
	# player dirrection

	if _current_slide_cooldown > 0.0:
		_current_slide_cooldown -= delta
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	var speed_modifier: float = sprint_modifier + crouch_modifier
	speed = default_speed + speed_modifier + slide_modifier

	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var current_velocity = Vector2(_movement_velocity.x, _movement_velocity.z)
	var direction: Vector3
	if is_sliding:
		direction = _slide_direction
	else:
		direction = (transform.basis * Vector3(_input_dir.x, 0, _input_dir.y)).normalized()

	current_player_rotation = _input_dir.angle()

	if direction != Vector3.ZERO:
		current_velocity = lerp(current_velocity, Vector2(direction.x, direction.z)* speed, acceleration * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration * delta)

	_movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)

	velocity = _movement_velocity

	# get max velocity for debugging purposes
	if _movement_velocity.length() > _current_max_velocity:
		_current_max_velocity = _movement_velocity.length()
	move_and_slide()

	if is_on_floor():
		step_handler.handle_step_climbing()
#endregion


#region Movement Functions
func get_input_dir() -> Vector2:
	return _input_dir


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
#endregion

#region Slide

func start_slide() -> void:
	is_sliding = true
	_slide_direction = Vector3(velocity.x, 0, velocity.z).normalized()
	standing_col.disabled = true
	crouching_col.disabled = false
	slide_modifier = slide_power
	# disable wasd movement input while sliding
	disable_movement()

	
func can_slide() -> bool:
	if _current_slide_cooldown > 0.0:
		return false
	if not is_on_floor():
		return false
	# check momentum
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() < min_slide_momentum:
		return false
	return true

func end_slide() -> void:
	is_sliding = false
	standing_col.disabled = false
	crouching_col.disabled = true
	_slide_direction = Vector3.ZERO
	_current_slide_cooldown = slide_cooldown

	# cam_effects._animate_fov(cam_effects._base_fov, 0.5)
#endregion

#region Fall logic
func check_fall_speed() -> bool:
	if current_fall_velocity < fall_velocity_threshold:
		current_fall_velocity = 0.0
		return true
	else:
		current_fall_velocity = velocity.y
		return false
#endregion

func disable_movement() -> void:
	_input_dir = Vector2.ZERO

func enable_movement() -> void:
	# nothing to do here for now, but this function can be used to re-enable movement if needed
	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _on_aiming_state_state_entered() -> void:
	pass # Replace with function body.
