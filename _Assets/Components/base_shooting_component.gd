class_name BaseShootingComponent
extends Node3D

# --- Preloaded Assets ---
const IMPACT_DECAL = preload("res://Scenes/debug/impact_node.tscn")

# --- Exported Resources ---
@export var weapon_data: Weapon 
@export var shoot_position: Node3D 
@export var shooter_body: CollisionObject3D # The body to ignore (Player, Enemy, Turret)

# --- State Variables ---
var fire_timer: float = 0.0

#region Lifecycle
func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
#endregion

#region Core Firing Logic
func can_fire() -> bool:
	return fire_timer <= 0.0 and weapon_data != null and is_instance_valid(shoot_position)

func fire() -> void:
	if not can_fire():
		return
		
	# 1. Ask the child script if we have ammo/heat to shoot. 
	# If the child says false (reloading/overheated), abort the shot!
	if not _handle_ammo_consumption():
		return
		
	# 2. Apply cooldown
	fire_timer = 60.0 / weapon_data.fire_rate_rpm 
	
	# 3. Shoot!
	if weapon_data.is_hitscan:
		_fire_hitscan(weapon_data)
	else:
		_fire_projectile(weapon_data)

## VIRTUAL FUNCTION: Child classes (Enemy, Turret, Player) MUST override this 
## to define their own ammo rules. Return TRUE to allow the shot, FALSE to block it.
func _handle_ammo_consumption() -> bool:
	return true # Default allows infinite firing
#endregion

#region Universal Ballistics Logic
func _fire_hitscan(data: Weapon) -> void:
	var space_state = get_world_3d().direct_space_state
	var start_pos = shoot_position.global_position
	var end_pos = start_pos + (-shoot_position.global_transform.basis.z * data.shoot_range)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	if shooter_body:
		query.exclude = [shooter_body.get_rid()] 
		
	var result = space_state.intersect_ray(query)
	if result:
		_handle_hit(result, data)

func _handle_hit(result: Dictionary, data: Weapon) -> void:
	var hit_target = result.collider
	
	_spawn_impact_effect(result.position, result.normal)

	if hit_target.has_method("take_damage"):
		var final_damage = data.damage
		
		if hit_target.is_in_group("head"):
			final_damage *= data.headshot_multiplier
			
		# Push 'self' into argument 2, and the penetration float into argument 5
		hit_target.take_damage(final_damage, self, false, false, data.armor_penetration)
		
	if hit_target is RigidBody3D:
		var push_dir = -shoot_position.global_transform.basis.z
		var force = data.get("impact_force")
		if force == null: force = 10.0 
		hit_target.apply_impulse(push_dir * force, result.position - hit_target.global_position)

func _fire_projectile(data: Weapon) -> void:
	if data.projectile_scene == null: return
	var projectile = data.projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = shoot_position.global_position
	projectile.global_rotation = shoot_position.global_rotation

func _spawn_impact_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	var impact = IMPACT_DECAL.instantiate()
	get_tree().root.add_child(impact)
	impact.global_position = hit_position
	if hit_normal != Vector3.UP and hit_normal != Vector3.DOWN:
		impact.look_at(hit_position + hit_normal, Vector3.UP)
	elif hit_normal == Vector3.UP:
		impact.rotation_degrees.x = -90
	elif hit_normal == Vector3.DOWN:
		impact.rotation_degrees.x = 90
#endregion