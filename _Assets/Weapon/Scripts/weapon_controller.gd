class_name WeaponController extends Node

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart
# @export var camera: Camera3D
@export var reticle: Control
@export var shoot_position: Node3D
@export var shoot_position_offset: Vector3 = Vector3(0, 0, 0)

var player: PlayerController
var current_weapon_model: Node3D
var current_ammo: int
var reserve_ammo: int = 0
var fire_timer: float = 0.0
var is_loaded: bool = false
var is_reloading: bool = false

# var weapon_hipfire_position: Vector3 = Vector3(0, 0, 0)
# var weapon_hipfire_rotation: Vector3 = Vector3(0, 0, 0)

# var hipfire_location: Vector3 = Vector3(0, 0, 0)
# var hipfire_rotation: Vector3 = Vector3(0, 0, 0)

# var ads_location: Vector3 = Vector3(0, 0, 0)
# var ads_rotation: Vector3 = Vector3(0, 0, 0)

# var canted_sight_location: Vector3 = Vector3(0, 0, 0)
# var canted_sight_rotation: Vector3 = Vector3(0, 0, 0)

var aim_tween: Tween
const AIM_SPEED: float = 0.2

var accuracy_modifier: float = 1.0

var current_fire_mode: Weapon.WeaponFireMode
var shots_fired_this_trigger: int = 0
var trigger_held: bool = false
var burst_shots_remaining: int = 0
var w_data: WeaponData
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

	player = get_parent() as PlayerController
	print("hipfire position: ", current_weapon.weapon_position, " hipfire rotation: ", current_weapon.weapon_rotation)

func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
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
	if current_weapon == null:
		return false

	if not is_loaded or fire_timer > 0.0:
		return false

	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			return trigger_held and shots_fired_this_trigger < 1
		Weapon.WeaponFireMode.BURST:
			return burst_shots_remaining > 0
		Weapon.WeaponFireMode.FULL_AUTO:
			return trigger_held

	return false

func fire_weapon() -> void:
	if can_fire():
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
		# print("Fired weapon: %s, Remaining ammo: %d" % [current_weapon.weapon_name, current_ammo])

func _cycle_weapon() -> void:
	var weapon_data = Manager.weapon_manager.weapons[Manager.weapon_manager.current_weap_slot]

	if current_weapon == null:
		return
		
	is_loaded = false

	if weapon_data.ammo_in_magazine > 0:
		weapon_data.ammo_in_magazine -= 1
		is_loaded = true
	else:
		print("Out of ammo for weapon: %s" % current_weapon.weapon_name)

func execute_reload() -> void:
	var weapon_data = Manager.weapon_manager.weapons[Manager.weapon_manager.current_weap_slot]
	# This function is now ONLY called by the State Chart when the reload timer finishes
	reset_trigger()

	if current_weapon == null:
		return

	if weapon_data.reserve_ammo <= 0:
		print("No reserve ammo to reload.")
		return
	
	var mag_capacity = current_weapon.mags_ammo
	if weapon_data.ammo_in_magazine >= mag_capacity:
		print("Magazine already full. Mag:", weapon_data.ammo_in_magazine, "Reserve:", weapon_data.reserve_ammo)
		return
	weapon_data.ammo_in_magazine = min(mag_capacity, weapon_data.ammo_in_magazine + weapon_data.reserve_ammo)
	weapon_data.reserve_ammo = max(0, weapon_data.reserve_ammo - (mag_capacity - weapon_data.ammo_in_magazine))
	
	if not is_loaded and weapon_data.ammo_in_magazine > 0:
		_cycle_weapon()


	# if current_weapon == null:
	# 	return

	# if reserve_ammo <= 0:
	# 	print("No reserve ammo to reload.")
	# 	return

	# var mag_capacity = current_weapon.mags_ammo
	# var needed = max(mag_capacity - current_ammo, 0)
	# if needed == 0:
	# 	print("Magazine already full. Mag:", current_ammo, "Reserve:", reserve_ammo)
	# 	return

	# var transfer = min(needed, reserve_ammo)
	# current_ammo += transfer
	# reserve_ammo -= transfer

	# # If chamber empty, chamber a round (consume one from magazine)
	# if not is_loaded:
	# 	# Consume one round from the magazine to chamber it
	# 	print("Reloaded and chambered a round. Mag:", current_ammo, "Reserve:", reserve_ammo)
	# 	_cycle_weapon()
	# 	return
	
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
		# look for Node3D named "Muzzle" and set the shoot_position to it
		var muzzle = current_weapon_model.get_node_or_null("Muzzle") as Node3D
		if muzzle != null:
			shoot_position = muzzle

func switch_weapon(weapon_data:WeaponData) -> void:
	current_weapon = weapon_data.weapon
	if current_weapon_model:
		current_weapon_model.queue_free()
	spawn_weapon_model(weapon_data.weapon)
	weapon_data = Manager.weapon_manager.weapons[Manager.weapon_manager.current_weap_slot]
#endregion


#region Firing Implementations
func _perform_hitscan_fire() -> void:
	if current_weapon == null or shoot_position == null:
		print("Cannot perform hitscan fire: Weapon or shoot position is null.")
		return

	var space_state = shoot_position.get_world_3d().direct_space_state
	var from = shoot_position.global_transform.origin + shoot_position_offset
	
	var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0 

	for i in range(current_weapon.pellet_count):
		var forward = -shoot_position.global_transform.basis.z
		
		var acc_x = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y = randf_range(-accuracy_spread, accuracy_spread)
		var direction = (forward + Vector3(acc_x, acc_y, 0)).normalized()

		if current_weapon.pellet_count > 1:
			var spread_x = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			var spread_y = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			direction += Vector3(spread_x, spread_y, 0) * shoot_position.global_transform.basis
		
		var to = from + direction * current_weapon.shoot_range


		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var hit_position = result.position
			# var hit_normal = result.normal
			# var hit_collider = result.collider

			# print("Hitscan hit at position: ", hit_position, " with normal: ", hit_normal, " on collider: ", hit_collider)
			_spawn_impact_effect(hit_position)
		else:
			print("Hitscan did not hit any target.")

func _spawn_impact_effect(hit_position: Vector3) -> void:
	# Placeholder for spawning impact effects (e.g., particles, decals)
	# print("Spawn impact effect at position: ", hit_position, " with normal: ", hit_normal)
	var marker = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.1
	marker.mesh = ball

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED # Red color
	marker.set_surface_override_material(0,material)

	# skip player collision for the impact effec
	

	get_tree().current_scene.add_child(marker)
	marker.global_transform.origin = hit_position


	get_tree().create_timer(0.5).timeout.connect(marker.queue_free)


func _perform_projectile_fire() -> void:
	if current_weapon == null or shoot_position == null:
		print("Cannot perform projectile fire: Weapon or shoot position is null.")
		return

	for i in range(current_weapon.pellet_count):
		var projectile = current_weapon.projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)

		projectile.global_position = shoot_position.global_position + shoot_position_offset
		var forward = -shoot_position.global_transform.basis.z
		
		var accuracy_spread = (100 - current_weapon.accuracy) / 1000.0
		if current_weapon.pellet_count > 1:
			var spread_x = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			var spread_y = randf_range(-current_weapon.spread_angle, current_weapon.spread_angle)
			forward += Vector3(spread_x, spread_y, 0) * shoot_position.global_transform.basis
		var acc_x = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y = randf_range(-accuracy_spread, accuracy_spread)
		var direction = forward + Vector3(acc_x, acc_y, 0) * shoot_position.global_transform.basis

		var projectile_velocity = direction * current_weapon.get_muzzle_velocity_mps()


		# make sure the projectile is facing the direction it is moving

		projectile.look_at(projectile.global_position + direction, Vector3.UP)
		projectile.setup(projectile_velocity, current_weapon.damage)
#endregion


#region Aiming & Tweens
func aim_hipfire() -> void:
	if current_weapon:
		accuracy_modifier = 1.0
		tween_weapon_to_position(current_weapon.weapon_position, current_weapon.weapon_rotation)

	# _set_reticle_visible(true)

func aim_ads() -> void:
	if current_weapon:
		accuracy_modifier = current_weapon.aim_accuracy_modifier
		tween_weapon_to_position(current_weapon.aim_ADS_position, current_weapon.aim_ADS_rotation)
		
	# _set_reticle_visible(false)

func aim_canted() -> void:
	if current_weapon:
		var target_pos = current_weapon.aim_ADS_position
		
		# Calculate the 45-degree tilt
		var target_rot = current_weapon.aim_ADS_rotation
		target_rot.z += deg_to_rad(45) 
		
		tween_weapon_to_position(target_pos, target_rot)

func _set_reticle_visible(is_visible: bool) -> void:
	if reticle == null:
		return

	reticle.visible = is_visible
	var reticle_parent := reticle.get_parent()
	if reticle_parent is Control:
		reticle_parent.visible = is_visible


func tween_weapon_to_position(target_position: Vector3, target_rotation: Vector3) -> void:
	if current_weapon_model == null:
		return

	if aim_tween:
		aim_tween.kill()

	aim_tween = create_tween()
	aim_tween.set_trans(Tween.TRANS_SINE)
	aim_tween.set_ease(Tween.EASE_IN_OUT)

	aim_tween.set_parallel(true)

	aim_tween.tween_property(current_weapon_model, "position", target_position, AIM_SPEED)
	aim_tween.tween_property(current_weapon_model, "rotation", target_rotation, AIM_SPEED)
#endregion
