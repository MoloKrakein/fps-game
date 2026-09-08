class_name BreakeableComponent extends Node
@export var brake_force: float = 10.0
@export var health_component: HealthComponent
@export var debris_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_prop_destroyed)


func _on_prop_destroyed() -> void:
	if debris_scene:
		var debris = debris_scene.instantiate()
		# put the debris scene in rigidbody root
		get_tree().root.add_child(debris)
		
		# Match the parent's physical position
		debris.global_position = get_parent().global_position 
		debris.global_rotation = get_parent().global_rotation
		# if debris is Node3D:
		# 	var force_direction = Vector3(randf() - 0.5, randf(), randf() - 0.5).normalized()
		# 	debris.apply_central_impulse(force_direction * brake_force)

		
	# Delete the parent physics body (the crate/barrel)
	get_parent().queue_free()
