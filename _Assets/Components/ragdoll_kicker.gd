class_name RagdollKicker
extends Area3D

@export_category("Component Settings")
## The body we are tracking to calculate momentum (e.g., the Player or Enemy)
@export var actor: CharacterBody3D 
@export var kick_force: float = 3.0
@export var base_walk_speed: float = 5.0

func _ready() -> void:
	# body_entered.connect(_on_body_entered)
	pass

func _on_body_entered(body: Node3D) -> void:
	# DEBUG: Print EVERYTHING that ever enters this area!
	# print("Entered Area: ", body.name, " | Class: ", body.get_class())
	
	if not actor or actor.velocity.length() < 0.5:
		return
		
	if body is PhysicalBone3D:
		var current_speed: float = actor.velocity.length()
		var push_dir = global_position.direction_to(body.global_position)
		push_dir.y = 0 
		push_dir = push_dir.normalized()
		
		var speed_multiplier = current_speed / base_walk_speed
		var final_force = push_dir * kick_force * speed_multiplier
		
		body.apply_central_impulse(final_force)
		
func _physics_process(_delta: float) -> void:
	# 1. Safety check: Don't do anything if no actor is assigned
	if not actor:
		return
		
	# 2. Get the actor's current speed
	var current_speed: float = actor.velocity.length()
	
	# 3. If the actor is standing still, don't push things
	if current_speed < 0.5:
		return
		
	var overlapping_bodies = get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# print("RagdollKicker: _physics_process called")
		# Check if the body we are touching is a ragdoll bone

		# check if the body is in group "ragdoll" to ensure we only apply force to ragdoll bones

		if body.is_in_group("ragdoll") or body is PhysicalBoneSimulator3D:
			# print("RagdollKicker: Overlapping body is in group 'ragdoll', applying force")
			# Calculate the direction from the component to the bone
			var push_dir = global_position.direction_to(body.global_position)
			
			# Nullify the Y axis so we don't push bodies into the floor or launch them
			push_dir.y = 0 
			push_dir = push_dir.normalized()
			
			# Calculate final force based on actor speed (sprinting kicks harder!)
			var speed_multiplier = current_speed / base_walk_speed
			var final_force = push_dir * kick_force * speed_multiplier
			
			# Apply the impulse to the bone
			body.apply_central_impulse(final_force)
