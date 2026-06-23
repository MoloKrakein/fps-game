extends Node3D

# Weapon Variables
var base_damage: float = 25.0
var accuracy: float = 0.02 
var stability: float = 1.0 
var crit_chance: float = 0.15 
var armor_penetration: float = 0.8 
var impact_force: float = 15.0

# Notice the path is shorter now because the RayCast is a direct child!
@onready var aim_raycast = $RayCast3D

func shoot():
	# 1. Apply Accuracy (Bullet Spread)
	var spread_x = randf_range(-accuracy, accuracy)
	var spread_y = randf_range(-accuracy, accuracy)
	var hit_point = aim_raycast.get_collision_point()
	
	aim_raycast.target_position = Vector3(spread_x, spread_y, -50.0) 
	aim_raycast.force_raycast_update()

	# 2. Check for Hits
	if aim_raycast.is_colliding():
		var target = aim_raycast.get_collider()
		print("Hit detected: ", target.name)
		if target is RigidBody3D:
			# Get the direction the camera/raycast is pointing
			var push_dir = -aim_raycast.global_transform.basis.z.normalized()
			
			# Calculate the hit point relative to the object's center
			var local_hit_point = hit_point - target.global_position
			
			# Smack the object exactly where the laser touched it
			target.apply_impulse(push_dir * impact_force, local_hit_point)
			print("Pushed a physics object!")
		# 3. Calculate Critical Hits
		var final_damage = base_damage
		if randf() <= crit_chance:
			final_damage *= 2.0 
			print("CRITICAL HIT!")
			
		# 4. Apply Damage and Penetration
		if target.has_method("take_damage"):
			target.take_damage(final_damage, armor_penetration)
			print("Hit: ", target.name, " for ", final_damage, " damage.")
		else:
			print("Hit a wall or object: ", target.name)