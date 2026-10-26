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
var external_accuracy_multiplier: float = 1.0 # This is used to modify the weapon's accuracy from outside the weapon (e.g., player perks, enemy debuffs, etc.)

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
	
	var forward = -shoot_position.global_transform.basis.z
	
	# 1. Calculate the spread (Matches your WeaponController math)
	# A perfectly accurate gun (100.0) has 0 spread.
	var base_spread: float = (100.0 - data.accuracy) / 1000.0 
	var final_spread: float = base_spread * external_accuracy_multiplier
	
	# 2. Randomize X and Y offsets based on the final spread
	var acc_x: float = randf_range(-final_spread, final_spread)
	var acc_y: float = randf_range(-final_spread, final_spread)
	
	# 3. Apply offsets relative to the barrel's actual rotation
	var right = shoot_position.global_transform.basis.x
	var up = shoot_position.global_transform.basis.y
	var direction = (forward + (right * acc_x) + (up * acc_y)).normalized()
	
	var end_pos = start_pos + (direction * data.shoot_range)
	
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = _get_ray_exclusions()
		
	var result = space_state.intersect_ray(query)
	if result:
		result = _refine_hit(result, start_pos, end_pos)
		_handle_hit(result, data)

## VIRTUAL FUNCTION: bodies the shot must ignore. By default only the shooter's own body.
## Shooters whose body has child colliders (e.g. a ragdoll's bones) should return all of them.
func _get_ray_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if shooter_body:
		exclusions.append(shooter_body.get_rid())
	return exclusions

## Lets a coarse collider (e.g. an enemy's capsule) hand the shot to a more precise hitbox.
## The collider only needs a resolve_hit(from, to) -> Dictionary method.
func _refine_hit(result: Dictionary, from: Vector3, to: Vector3) -> Dictionary:
	var collider = result.collider
	if collider != null and collider.has_method("resolve_hit"):
		var refined: Dictionary = collider.resolve_hit(from, to)
		if not refined.is_empty():
			return refined
	return result

func _handle_hit(result: Dictionary, data: Weapon) -> void:
	var hit_target = result.collider
	
	_spawn_impact_effect(result.position, result.normal)

	if hit_target.has_method("take_damage"):
		# Optional: lets hitboxes know the exact impact point and direction.
		if hit_target.has_method("set_hit_context"):
			hit_target.set_hit_context(result.position, (result.position - shoot_position.global_position).normalized())

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
