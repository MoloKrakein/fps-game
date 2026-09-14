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
@export var grab_controller: GrabController
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
@export var fall_damage_multiplier: float = 2.0

@export_category("Sliding")
@export var base_slide_duration: float = 1.0
@export var base_slide_power: float = 10.0
@export var slide_cooldown: float = 1.0
@export var min_slide_momentum: float = 4.0
@export var max_slide_momentum: float = 12.0

@export_category("Settings")
@export var isToggleCrouch: bool = false
@export var isToggleSprint: bool = false

@onready var health_component: HealthComponent = get_node("HealthComponent")

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
var impact_velocity: float = 0.0
var on_airbone_time: float = 0.0

var current_slide_duration: float = 0.0
var current_slide_power: float = 0.0

# stamina system just for visual purposes
var _player_current_tiredness: float = 0
var _player_max_tiredness: float = 100

# settings
var is_crouching: bool = false
var is_sprinting: bool = false
var is_sliding: bool = false

var _is_holding_drop: bool = false
var _drop_hold_time: float = 0.0
var _hold_item_mass: float = 0.0
const THROW_HOLD_THRESHOLD: float = 0.5 # Time in seconds to hold the drop button before throwing


func _ready() -> void:
	health_component.damage_taken.connect(_on_damage_taken)
	_initilize_ui()

func _on_health_component_health_changed(new_health: float, max_health: float) -> void:
	print("Health changed: ", new_health, " / ", max_health)
	EventBus.player_health_changed.emit(new_health, max_health)

func _on_damage_taken(damage_amount: float) -> void:
	EventBus.player_damage_taken.emit(damage_amount)
	if cam_effects:
		var intensity = clamp(damage_amount / 100.0, 0.1, 0.6)


func _on_health_component_armor_changed(new_armor: float, max_armor: float) -> void:
	print("Armor changed: ", new_armor, " / ", max_armor)
	EventBus.player_armor_changed.emit(new_armor, max_armor)

func _initilize_ui() -> void:
	# print("Initializing UI with current health and armor values")
	# print("Current Health: ", health_component.current_health, " / ", health_component.max_health)
	# print("Current Armor: ", health_component.current_armor, " / ", health_component.armor_value)
	# print("Emitting initial health and armor values to UI")
	await get_tree().process_frame
	EventBus.player_health_changed.emit(health_component.current_health, health_component.max_health)
	EventBus.player_armor_changed.emit(health_component.current_armor, health_component.armor_value)

func _physics_process(delta: float) -> void:
	
#region Physics Process
	previous_velocity = velocity
	# var acceleration = 
	# var deceleration = speed * delta
	
	# player dirrection

	if _is_holding_drop and grab_controller.held_object:
		_drop_hold_time += delta
		if _drop_hold_time >= THROW_HOLD_THRESHOLD:
			grab_controller.try_throw()
			_is_holding_drop = false

	if _current_slide_cooldown > 0.0:
		_current_slide_cooldown -= delta
	
	if not is_on_floor():
		velocity += get_gravity() * delta
		on_airbone_time += delta
	else:
		on_airbone_time = 0.0
	
	if grab_controller:
		if grab_controller.held_object:
			_hold_item_mass = grab_controller.object_weight * -1.0
		else:
			_hold_item_mass = 0.0


	var speed_modifier: float = sprint_modifier + crouch_modifier + (_hold_item_mass * 0.5) # Adjust the multiplier as needed for balance
	var raw_speed: float = default_speed + speed_modifier + slide_modifier
	speed = maxf(0.5, raw_speed)

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

	var is_moving:bool = direction != Vector3.ZERO
	_handle_tiredness(delta, is_moving)

	_movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)

	velocity = _movement_velocity
	var y_velocity_before_on_floor = velocity.y
	

	# get max velocity for debugging purposes
	if _movement_velocity.length() > _current_max_velocity:
		_current_max_velocity = _movement_velocity.length()


	move_and_slide()

	if is_on_floor() and y_velocity_before_on_floor < 0.0:
		impact_velocity = y_velocity_before_on_floor

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if is_on_floor() and (not is_sliding or on_airbone_time >= 0.0) and collider is not RigidBody3D:
			step_handler.handle_step_climbing()

		# if collider is RigidBody3D:
		# 	var push_force = 5.0

		# 	var push_dir = -collision.get_normal()
		# 	collider.apply_central_impulse(push_dir * push_force)




func _handle_tiredness(delta: float, is_moving: bool) -> void:
	var rate: float = 0.0

	if is_moving:
		if is_sprinting:
			rate = 25.0 # Tires out very fast while sprinting
		elif is_crouching:
			rate = -5.0 # Slowly recovers while crouch-walking (tactical!)
		else:
			rate = 5.0 # Normal walking slowly increases tiredness
	else:
		if is_crouching and not is_sprinting and not is_sliding:
			rate = -20.0 # Rapid recovery while idle and crouched
		else:
			rate = -10.0 # Normal recovery while idle and standing

	# Apply the rate and clamp it between 0 and Max
	_player_current_tiredness += rate * delta
	_player_current_tiredness = clamp(_player_current_tiredness, 0.0, _player_max_tiredness)

func increase_tiredness(amount: float) -> void:
	_player_current_tiredness += amount
	_player_current_tiredness = clamp(_player_current_tiredness, 0.0, _player_max_tiredness)
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
	disable_movement() # Ensure WASD is locked as previously discussed
	
	# Calculate the momentum multiplier
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	horizontal_speed = clampf(horizontal_speed, min_slide_momentum, max_slide_momentum)
	
	var momentum_multiplier = horizontal_speed / min_slide_momentum
	
	# Generate this specific slide's stats based on the multiplier
	current_slide_duration = base_slide_duration * momentum_multiplier
	current_slide_power = base_slide_power * momentum_multiplier
	
	slide_modifier = current_slide_power

	
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
	slide_modifier = 0.0

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

# fall damage calculation based on the current fall velocity
func calculate_fall_damage() -> float:
	var damage: float = 0.0
	if impact_velocity < fall_velocity_threshold:
		damage = abs(impact_velocity) * fall_damage_multiplier
	return damage

func apply_fall_damage() -> void:
	var damage_amount = calculate_fall_damage()

	if damage_amount > 0.0:
		# var health_component = get_node_or_null("HealthComponent")
		if health_component:
			health_component.take_damage(damage_amount)
		# if cam_effects:
		# 	var intensity = clamp(damage_amount / 100.0, 0.1, 0.6)
		# 	cam_effects.add_fall_kick(intensity)

func take_damage(amount: float, source: Node3D = null, is_headshot: bool = false, is_crit: bool = false, penetration: float = 0.0) -> void:
	if health_component:
		health_component.take_damage(amount, null, false, false, penetration)
	if cam_effects and source:
        # Scale shake intensity based on damage
		var intensity = clamp(amount / 100.0, 0.1, 0.6)
		cam_effects.add_screen_shake(intensity, 0.35)
        
        # Feed the enemy's exact 3D position into your directional math!
		cam_effects.add_damage_kick(15.0, 5.0, source.global_position)

#endregion

func disable_movement() -> void:
	_input_dir = Vector2.ZERO

func enable_movement() -> void:
	# nothing to do here for now, but this function can be used to re-enable movement if needed
	_input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _on_aiming_state_state_entered() -> void:
	pass # Replace with function body.

func _on_player_dead() -> void:
	# Disable player input and movement
	disable_movement()

#region Debugging
func _unhandled_input(event: InputEvent) -> void:
	# shoot ur self debug
	var health_component = get_node_or_null("HealthComponent")
	if health_component and event.is_action_pressed("test1"):
		health_component.take_damage(50)

	if event.is_action_pressed("action_use"):
		interaction_raycast.force_raycast_update()
		interaction_raycast.interact()
		grab_controller.try_grab()

	if event.is_action_pressed("action_drop"):
		_is_holding_drop = true
		_drop_hold_time = 0.0

	if event.is_action_released("action_drop"):
			if _is_holding_drop and grab_controller.held_object:
				grab_controller.try_drop()
			_is_holding_drop = false
