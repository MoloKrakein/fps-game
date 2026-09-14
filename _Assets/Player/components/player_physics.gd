class_name PlayerPhysics extends Node

@export var controller: CharacterBody3D
@export_range(0.0, 500.0, 0.1) var force_multiplier: float = 100.0
@export var enabled : bool = true

# on ready, create collision area shape and set it to the controller's position, set the layer to 4 layer so the physics objects can interact with it, and set the collision mask to 0 so it doesn't collide with anything
var collision_shape: CollisionShape3D

# func _ready() -> void:
# 	collision_shape = CollisionShape3D.new()
# 	collision_shape.shape = BoxShape3D.new()
# 	collision_shape.position = controller.position
# 	call_deferred("add_child", collision_shape)
# 	collision_shape.set_owner(controller.get_tree().get_root())
# 	collision_shape.collision_layer = 4
# 	collision_shape.collision_mask = 0
# 	collision_shape.connect("body_entered",Callable(self,"_on_body_entered"))

# # when the collision_shape collides with a rigidbody, apply an impulse to the rigidbody in the direction of the collision normal, multiplied by the force_multiplier

# func _on_body_entered(body: Node3D) -> void:
# 	if body is RigidBody3D:
# 		var push_force = force_multiplier
# 		var push_dir = -collision_shape.get_normal()
# 		body.apply_central_impulse(push_dir * push_force)

func _physics_process(delta: float) -> void:
	if enabled and controller.get_slide_collision_count() > 0:
		var col = controller.get_last_slide_collision()
		if col.get_collider() is RigidBody3D:
			var push_force = force_multiplier
			var push_dir = -col.get_normal()
			col.get_collider().apply_central_impulse(push_dir * push_force)

	
