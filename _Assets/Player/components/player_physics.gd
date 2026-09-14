class_name PlayerPhysics extends Node

@export var controller: CharacterBody3D
@export_range(0.0, 500.0, 0.1) var force_multiplier: float = 100.0
@export var enabled : bool = true


func _physics_process(delta: float) -> void:
	if enabled and controller.get_slide_collision_count() > 0:
		var col = controller.get_last_slide_collision()
		if col.get_collider() is RigidBody3D:
			var push_force = force_multiplier
			var push_dir = -col.get_normal()
			col.get_collider().apply_central_impulse(push_dir * push_force)

	
