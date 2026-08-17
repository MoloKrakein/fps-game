class_name EnemyShootingComponent
extends Node3D

# --- Preloaded Assets ---
# MUST match the path used in your weapon_controller.gd
const IMPACT_DECAL = preload("res://Scenes/debug/impact_node.tscn") 

# --- Exported Resources ---
@export var weapon_data: Weapon 
@export var shoot_position: Node3D # We will assign the AimRaycast node here!
@export var enemy_body: CollisionObject3D # The enemy's CharacterBody3D (so it doesn't shoot itself)

# --- State Variables ---
var current_ammo: int = 0
var fire_timer: float = 0.0
var reload_timer: float = 0.0

#region Lifecycle
func _ready() -> void:
	if weapon_data != null:
		current_ammo = weapon_data.mags_ammo

func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
		
	if reload_timer > 0.0:
		reload_timer = maxf(reload_timer - delta, 0.0)
		if reload_timer == 0.0:
			_finish_reload()
#endregion

#region AI Logic (Simple Ammo & Timers)
func fire() -> void:
	if weapon_data == null or not is_instance_valid(shoot_position):
		return
		
	if fire_timer > 0.0 or reload_timer > 0.0:
		return

	if current_ammo <= 0:
		_start_reload()
		return
		
	_execute_shot()

func _start_reload() -> void:
	# Assume standard 2.0s reload if weapon doesn't specify one
	var r_time = weapon_data.get("reload_time")
	reload_timer = r_time if r_time != null else 2.0

func _finish_reload() -> void:
	current_ammo = weapon_data.mags_ammo

func _execute_shot() -> void:
	current_ammo -= 1
	fire_timer = 60.0 / weapon_data.fire_rate_rpm 
	
	# Match Player's WeaponController logic
	if weapon_data.is_hitscan:
		_fire_hitscan(weapon_data)
	else:
		_fire_projectile(weapon_data)
#endregion

#region Ballistics Logic (Matches Player WeaponController)
func _fire_hitscan(data: Weapon) -> void:
	var space_state = get_world_3d().direct_space_state
	var start_pos = shoot_position.global_position
	# Shoot forward along the -Z axis of the AimRaycast
	var end_pos = start_pos + (-shoot_position.global_transform.basis.z * data.shoot_range)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	
	# Crucial: Exclude the enemy itself so it doesn't block its own bullets
	if enemy_body:
		query.exclude = [enemy_body.get_rid()] 
		
	var result = space_state.intersect_ray(query)

	if result:
		_handle_hit(result, data)

func _handle_hit(result: Dictionary, data: Weapon) -> void:
	var hit_target = result.collider
	var healthcomponent = hit_target.get_node_or_null("HealthComponent")
	# 1. Spawn Impact Decal on walls/floor
	_spawn_impact_effect(result.position, result.normal)

	# 2. Advanced Damage Application
	if healthcomponent and healthcomponent.has_method("take_damage"):
		healthcomponent.take_damage(data.damage, owner)

	# 3. Physics Impulse (Push crates and ragdolls!)
	if hit_target is RigidBody3D:
		var push_dir = -shoot_position.global_transform.basis.z
		var force = data.get("impact_force")
		if force == null: force = 10.0 # Fallback if impact_force isn't in Weapon.gd yet
		
		hit_target.apply_impulse(push_dir * force, result.position - hit_target.global_position)

func _fire_projectile(data: Weapon) -> void:
	if data.projectile_scene == null:
		push_error("Weapon is set to Projectile but no scene assigned!")
		return
		
	var projectile = data.projectile_scene.instantiate()
	# Always add projectiles to the root so they don't move with the enemy
	get_tree().root.add_child(projectile)
	
	projectile.global_position = shoot_position.global_position
	projectile.global_rotation = shoot_position.global_rotation
	
	# If your projectile has a setup function to pass damage stats, call it here:
	# projectile.setup(data)

func _spawn_impact_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	var impact = IMPACT_DECAL.instantiate()
	get_tree().root.add_child(impact)
	
	impact.global_position = hit_position
	# Align the decal perfectly with the surface normal
	if hit_normal != Vector3.UP and hit_normal != Vector3.DOWN:
		impact.look_at(hit_position + hit_normal, Vector3.UP)
	elif hit_normal == Vector3.UP:
		impact.rotation_degrees.x = -90
	elif hit_normal == Vector3.DOWN:
		impact.rotation_degrees.x = 90
#endregion
