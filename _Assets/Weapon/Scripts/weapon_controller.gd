class_name WeaponController extends Node

# Preloaded Assets for Object Pooling (Avoids Garbage Collection Spikes)
const IMPACT_DECAL = preload("res://Scenes/debug/impact_node.tscn") # Replace with your actual path!

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart
@export var reticle: Control
@export var shoot_position: Node3D
@export var shoot_position_offset: Vector3 = Vector3.ZERO
@export	var camera: Camera3D

@export_group("Sway Animations Settings")
@export_category("Idle Sway Animations Settings")
@export var idle_sway_enabled: bool = true
@export var idle_sway_frequency: float = 0.8
@export var idle_sway_amplitude: Vector2 = Vector2(0.005, 0.005)
@export var idle_sway_stiffness: float = 40.0
@export var idle_sway_damping: float = 60.0
@export var idle_sway_rotation_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.001) var idle_sway_tremor_threshold: float = 0.5
@export_category("Idle Aiming Sway Settings")
@export var aiming_sway_enabled: bool = true
@export var aim_sway_multiplier: float = 0.15
@export_category("Look Sway Settings")
@export var look_sway_enabled: bool = true
@export var look_lag_divisor: float = 10.0
@export var look_lag_rot_max: float = 5.0
@export var look_lag_pos_scale: float = 0.006

# Cached Data to prevent Singleton Bottlenecks
var active_weapon_data: WeaponData

var player: PlayerController
var current_weapon_model: Node3D
var current_ammo: int
var reserve_ammo: int = 0
var fire_timer: float = 0.0
var is_loaded: bool = false
var is_reloading: bool = false
var is_aiming: bool = false

# Animation and Procedural Weapon Animation Variables

var weapon_start_position: Vector3
var weapon_start_rotation: Vector3

var current_stance_pos: Vector3
var current_stance_rot: Vector3


# idle sway variables
var idle_time: float = 0.0
var _idle_x: float = 0.0
var _idle_y: float = 0.0
# var _idle_z: float = 0.0
var _idle_rot_x: float = 0.0
# var _idle_rot_y: float = 0.0
# var _idle_rot_z: float = 0.0
var _idle_x_velocity: float = 0.0
var _idle_y_velocity: float = 0.0
# var _idle_z_velocity: float = 0.0
var _idle_rot_x_velocity: float = 0.0
# var _idle_rot_y_velocity: float = 0.0

# look sway variables
var _previous_look_dir: Vector3 = Vector3.ZERO
var _camera_rotation_rate: Vector3 = Vector3.ZERO


var aim_tween: Tween
const AIM_SPEED: float = 0.2

var accuracy_modifier: float = 1.0

var current_fire_mode: Weapon.WeaponFireMode
var shots_fired_this_trigger: int = 0
var trigger_held: bool = false
var burst_shots_remaining: int = 0
const DEFAULT_BURST_SHOTS_PER_TRIGGER: int = 3

#region Lifecycle
func _ready() -> void:
	if current_weapon != null:
		spawn_weapon_model(current_weapon)
		# Initialize magazine and reserve from weapon stats
		current_ammo = current_weapon.mags_ammo
		reserve_ammo = current_weapon.max_ammo
		current_fire_mode = current_weapon.fire_mode
		is_loaded = current_ammo > 0

	# get active weapon data from the WeaponManager
	
	player = get_tree().get_first_node_in_group("player") as PlayerController
	call_deferred("update_weapon_ui")

	

func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
	_apply_offsets(delta)
#endregion

#region Trigger & Fire Mode
func get_burst_shot_count() -> int:
	if current_weapon == null:
		return DEFAULT_BURST_SHOTS_PER_TRIGGER

	if current_weapon.burst_shot_count > 0:
		return current_weapon.burst_shot_count

	return DEFAULT_BURST_SHOTS_PER_TRIGGER

func start_trigger() -> void:
	trigger_held = true
	if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
		burst_shots_remaining = get_burst_shot_count()

func stop_trigger() -> void:
	trigger_held = false
	if current_fire_mode != Weapon.WeaponFireMode.BURST:
		reset_trigger()

func toggle_fire_mode() -> void:
	if not current_weapon.can_change_fire_mode:
		return
		
	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			if current_weapon.has_burst_mode:
				current_fire_mode = Weapon.WeaponFireMode.BURST
			else:
				current_fire_mode = Weapon.WeaponFireMode.FULL_AUTO
		Weapon.WeaponFireMode.BURST:
			current_fire_mode = Weapon.WeaponFireMode.FULL_AUTO
		Weapon.WeaponFireMode.FULL_AUTO:
			current_fire_mode = Weapon.WeaponFireMode.SEMI_AUTO

	reset_trigger()

func is_burst_fire() -> bool:
	return current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining > 0 and burst_shots_remaining < get_burst_shot_count()

func reset_trigger() -> void:
	shots_fired_this_trigger = 0
	burst_shots_remaining = 0

func can_fire() -> bool:
	# Use the cached variable instead of digging through the global Manager every frame
	if current_weapon == null or active_weapon_data == null:
		return false

	if not active_weapon_data.is_loaded or fire_timer > 0.0:
		return false

	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			return trigger_held and shots_fired_this_trigger < 1
		Weapon.WeaponFireMode.BURST:
			return burst_shots_remaining > 0
		Weapon.WeaponFireMode.FULL_AUTO:
			return trigger_held

	return false

func can_reload() -> bool:
	if current_weapon == null or active_weapon_data == null:
		print("No weapon or weapon data available.")
		return false

	if active_weapon_data.reserve_ammo <= 0:
		print("No reserve ammo left to reload.")
		return false

	if active_weapon_data.ammo_in_magazine == current_weapon.mags_ammo:
		print("Magazine is already full.")
		return false

	return true

func fire_weapon() -> void:
	if not can_fire():
		return
		
	fire_timer = current_weapon.get_fire_interval_seconds()

	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			shots_fired_this_trigger = 1
		Weapon.WeaponFireMode.BURST:
			if burst_shots_remaining <= 0:
				burst_shots_remaining = get_burst_shot_count()
			burst_shots_remaining -= 1
			shots_fired_this_trigger += 1
		Weapon.WeaponFireMode.FULL_AUTO:
			pass

	if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
		trigger_held = false
		
	if current_weapon.is_hitscan:
		_perform_hitscan_fire()
	else:
		_perform_projectile_fire()

	_cycle_weapon()

func _cycle_weapon() -> void:
	# Bouncer logic + Cached data
	if current_weapon == null or active_weapon_data == null:
		return
		
	active_weapon_data.is_loaded = false

	if active_weapon_data.ammo_in_magazine > 0:
		active_weapon_data.ammo_in_magazine -= 1
		active_weapon_data.is_loaded = true

	update_weapon_ui()

func execute_reload() -> void:
	if not can_reload():
		return

	reset_trigger()


	if current_weapon == null or active_weapon_data == null:
		return

	
	var mag_capacity: int = current_weapon.mags_ammo
	if active_weapon_data.ammo_in_magazine >= mag_capacity:
		return
		
	var needed: int = mag_capacity - active_weapon_data.ammo_in_magazine
	var transfer: int = min(needed, active_weapon_data.reserve_ammo)
	
	active_weapon_data.ammo_in_magazine += transfer
	active_weapon_data.reserve_ammo -= transfer

	if not active_weapon_data.is_loaded and active_weapon_data.ammo_in_magazine > 0:
		_cycle_weapon()
	update_weapon_ui()
#endregion

#region Weapon Model
func spawn_weapon_model(weapon: Weapon) -> void:
	if current_weapon_model != null:
		current_weapon_model.queue_free()

	if weapon != null and weapon.weapon_model:
		current_weapon_model = weapon.weapon_model.instantiate()
		weapon_model_parent.add_child(current_weapon_model)
		current_weapon_model.position = weapon.weapon_position
		current_weapon_model.rotation = weapon.weapon_rotation
		current_weapon_model.scale = weapon.weapon_scale
		
		weapon_start_position = current_weapon_model.position
		weapon_start_rotation = current_weapon_model.rotation

		current_stance_pos = weapon_start_position
		current_stance_rot = weapon_start_rotation

		var muzzle: Node3D = current_weapon_model.get_node_or_null("Muzzle") as Node3D
		if muzzle != null:
			shoot_position = muzzle

func switch_weapon(weapon_data: WeaponData) -> void:
	if is_reloading:
		return
	# 1. Update current weapon
	current_weapon = weapon_data.weapon
	# 2. CACHE the active data immediately so _process loops don't have to query the Manager
	active_weapon_data = weapon_data 
	
	if current_weapon_model:
		current_weapon_model.queue_free()
	spawn_weapon_model(weapon_data.weapon)


func has_ammo() -> bool:
	return active_weapon_data != null and (active_weapon_data.ammo_in_magazine > 0 or active_weapon_data.reserve_ammo > 0)

func _apply_damage_to_target(target: Node3D, damage: float) -> void:
	if target == null or damage <= 0:
		return

	var health_component = target.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(current_weapon.damage, owner)
#endregion

#region Firing Implementations
func _perform_hitscan_fire() -> void:
	if current_weapon == null or shoot_position == null:
		return

	var space_state: PhysicsDirectSpaceState3D = shoot_position.get_world_3d().direct_space_state
	var from: Vector3 = shoot_position.global_transform.origin + shoot_position_offset
	var accuracy_spread: float = (100.0 - current_weapon.accuracy) / 1000.0 
	var forward: Vector3 = -shoot_position.global_transform.basis.z

	# The internal loop variables are now fully typed
	for i in range(current_weapon.pellet_count):
		var acc_x: float = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y: float = randf_range(-accuracy_spread, accuracy_spread)
		var direction: Vector3 = (forward + Vector3(acc_x, acc_y, 0)).normalized()
		var damage: float = current_weapon.damage
		if current_weapon.pellet_count > 1:
			var spread_x: float = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			var spread_y: float = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			direction += Vector3(spread_x, spread_y, 0) * shoot_position.global_transform.basis
			damage = (current_weapon.damage / current_weapon.pellet_count) * 10
		
		var to: Vector3 = from + direction * current_weapon.shoot_range
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			_spawn_impact_effect(result.position)
			_apply_damage_to_target(result.collider, damage)

func _spawn_impact_effect(hit_position: Vector3) -> void:
	# Instantiate the preloaded scene to avoid brutal Garbage Collection spikes
	if IMPACT_DECAL:
		var marker: Node3D = IMPACT_DECAL.instantiate()
		get_tree().current_scene.add_child(marker)
		marker.global_transform.origin = hit_position
		
		# A true object pool doesn't queue_free, but this is a massive upgrade over mesh generation
		get_tree().create_timer(0.5).timeout.connect(marker.queue_free)

func _perform_projectile_fire() -> void:
	if current_weapon == null or shoot_position == null:
		return

	var forward: Vector3 = -shoot_position.global_transform.basis.z
	var accuracy_spread: float = (100.0 - current_weapon.accuracy) / 1000.0

	for i in range(current_weapon.pellet_count):
		var projectile: Projectile = current_weapon.projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)

		projectile.global_position = shoot_position.global_position + shoot_position_offset
		var current_forward: Vector3 = forward
		var damage: float = current_weapon.damage
		
		if current_weapon.pellet_count > 1:
			var spread_x: float = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			var spread_y: float = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			current_forward += Vector3(spread_x, spread_y, 0) * shoot_position.global_transform.basis
			damage = (current_weapon.damage / current_weapon.pellet_count) * 10
		
		var acc_x: float = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y: float = randf_range(-accuracy_spread, accuracy_spread)
		var direction: Vector3 = current_forward + Vector3(acc_x, acc_y, 0) * shoot_position.global_transform.basis
		var projectile_velocity: Vector3 = direction * current_weapon.get_muzzle_velocity_mps()

		projectile.look_at(projectile.global_position + direction, Vector3.UP)
		projectile.setup(projectile_velocity, damage)
#endregion

#region Aiming & Tweens
func aim_hipfire() -> void:
	if current_weapon:
		EventBus.change_visibility_of_crosshair.emit(true)
		accuracy_modifier = 1.0
		player.cam_effects.reset_fov()
		tween_weapon_to_position(current_weapon.weapon_position, current_weapon.weapon_rotation)

func aim_ads() -> void:
	if current_weapon:
		accuracy_modifier = current_weapon.aim_accuracy_modifier
		# player.cam_effects.apply_ads_fov(current_weapon.aim_fov,1)
		player.cam_effects.apply_ads_fov(current_weapon.aim_fov)
		tween_weapon_to_position(current_weapon.aim_ADS_position, current_weapon.aim_ADS_rotation)
		
func aim_canted() -> void:
	if current_weapon:
		# var target_pos: Vector3 = current_weapon.canted_sight_position
		# var target_rot: Vector3 = current_weapon.canted_sight_rotation
		EventBus.change_visibility_of_crosshair.emit(false)
		tween_weapon_to_position(current_weapon.canted_sight_position, current_weapon.canted_sight_rotation)

func tween_weapon_to_position(target_position: Vector3, target_rotation: Vector3) -> void:
	if current_weapon_model == null:
		return

	# Critical: Kill the previous tween so they don't fight each other if you spam the aim button
	if aim_tween:
		aim_tween.kill()

	aim_tween = create_tween()
	aim_tween.set_trans(Tween.TRANS_SINE)
	aim_tween.set_ease(Tween.EASE_IN_OUT)
	aim_tween.set_parallel(true)

	aim_tween.tween_property(self,"current_stance_pos", target_position, AIM_SPEED)
	aim_tween.tween_property(self,"current_stance_rot", target_rotation, AIM_SPEED)

	# aim_tween.tween_property(current_weapon_model, "position", target_position, AIM_SPEED)
	# aim_tween.tween_property(current_weapon_model, "rotation", target_rotation, AIM_SPEED)
#endregion

func initialize_weapon_data(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return

	active_weapon_data = weapon_data
	current_ammo = weapon_data.ammo_in_magazine
	reserve_ammo = weapon_data.reserve_ammo
	is_loaded = weapon_data.is_loaded

func update_weapon_ui() -> void:
	# 1. Check if the manager exists yet
	if active_weapon_data == null:
		return
	var _reload_time: float = 0.0
	if current_weapon != null:
		EventBus.weapon_ammo_changed.emit(active_weapon_data.ammo_in_magazine, active_weapon_data.reserve_ammo)

func reload_timer_ui(reload_time: float) -> void:
	if active_weapon_data == null:
		return
	
	EventBus.weapon_ammo_changed.emit(active_weapon_data.ammo_in_magazine, active_weapon_data.reserve_ammo, reload_time)


#region Procedural Weapon Animations

func _disable_procedural_weapon_animations() -> void:
	idle_sway_enabled = false

func _update_idle_sway(delta: float) -> Vector3:
	if not idle_sway_enabled or current_weapon_model == null:
		return Vector3.ZERO

	# 1. Calculate the Normalized Tiredness (0.0 to 1.0)
	# Using clamp ensures we never accidentally get negative or > 100% values
	var tiredness_factor: float = clamp(player._player_current_tiredness / player._player_max_tiredness, 0.0, 1.0)

	# 2. Scale Frequency (Tired players breathe faster)
	# At 100% tiredness, the breathing speed is multiplied by 2.5x
	var current_frequency: float = idle_sway_frequency * (1.0 + (tiredness_factor * 1.5)) 
	idle_time += delta * current_frequency

	var player_speed = Vector2(player.velocity.x, player.velocity.z).length()
	var current_amplitude: Vector2 = idle_sway_amplitude
	
	if is_aiming:
		current_amplitude *= aim_sway_multiplier

	# 3. Apply Tiredness to Amplitude AFTER the aim multiplier
	# This ensures aiming is still difficult and shaky when fully exhausted
	current_amplitude *= (1.0 + (tiredness_factor * 2.0)) 
	var tremor_intensity = current_amplitude.y * (0.15 + (tiredness_factor * 0.35))
	var micro_tremor: float = sin(idle_time * 15.0) * tremor_intensity

	var target_x = 0.0
	var target_y = 0.0
	var target_rot_x = 0.0

	# 4. The Figure-8 Base
	if player_speed < 0.1 or is_aiming:
		target_x = sin(idle_time) * current_amplitude.x
		target_y = cos(idle_time * 2.0) * current_amplitude.y + micro_tremor

	# 2. Rotational Target (Exhausted Up/Down Tilt)
	if tiredness_factor > idle_sway_tremor_threshold:
		# Maps the remaining 0.5->1.0 tiredness to a 0.0->1.0 intensity scale
		var exhaust_intensity: float = (tiredness_factor - idle_sway_tremor_threshold) * (1.0 / (1.0 - idle_sway_tremor_threshold))
		
		# Drive the tilt using the vertical breathing wave
		target_rot_x = target_y * idle_sway_rotation_multiplier * exhaust_intensity

	# 3. Apply Spring Physics (Position)
	var result_x: Vector2 = SpringUtil.apply(_idle_x, _idle_x_velocity, target_x, delta, idle_sway_stiffness, idle_sway_damping)
	_idle_x = result_x.x
	_idle_x_velocity = result_x.y

	var result_y: Vector2 = SpringUtil.apply(_idle_y, _idle_y_velocity, target_y, delta, idle_sway_stiffness, idle_sway_damping)
	_idle_y = result_y.x
	_idle_y_velocity = result_y.y

	# 4. Apply Spring Physics (Rotation)
	var result_rot_x: Vector2 = SpringUtil.apply(_idle_rot_x, _idle_rot_x_velocity, target_rot_x, delta, idle_sway_stiffness, idle_sway_damping)
	_idle_rot_x = result_rot_x.x
	_idle_rot_x_velocity = result_rot_x.y


	var _sway_offset: Vector3 = Vector3(_idle_x, _idle_y, 0)
	return _sway_offset

func _update_look_sway(delta: float) -> Vector3:
	if not look_sway_enabled or current_weapon_model == null or not camera:
		return Vector3.ZERO
	
	var camera_rotation = camera.global_rotation

	var rotation_delta = camera_rotation - _previous_look_dir
	_previous_look_dir = camera_rotation
	
	var max_rad = deg_to_rad(look_lag_rot_max)
	rotation_delta.x = clamp(rotation_delta.x, -max_rad, max_rad)
	rotation_delta.y = clamp(rotation_delta.y, -max_rad, max_rad)
	rotation_delta.z = 0.0

	var interpolate_speed = (1.0 / delta) / look_lag_divisor
	_camera_rotation_rate = _camera_rotation_rate.lerp(rotation_delta, clamp(interpolate_speed * delta,0.0,1.0))

	var norm_pitch = _camera_rotation_rate.x / max_rad if max_rad > 0.0 else 0.0
	var norm_yaw = _camera_rotation_rate.y / max_rad if max_rad > 0.0 else 0.0

	var look_pos = Vector3(
		norm_yaw * look_lag_pos_scale,
		norm_pitch * look_lag_pos_scale,
		0.0
	)

	return look_pos

func _apply_offsets(delta: float) -> void:
	var idle_offset: Vector3 = _update_idle_sway(delta)
	var look_offset: Vector3 = _update_look_sway(delta)

	current_weapon_model.position = current_stance_pos + idle_offset + look_offset
	current_weapon_model.rotation = current_stance_rot + Vector3(_idle_rot_x, 0.0, 0.0)


#endregion
