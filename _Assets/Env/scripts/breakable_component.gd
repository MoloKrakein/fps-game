class_name BrakeableComponent extends Node
@export var brake_force: float = 10.0
@export var health_component: HealthComponent
@export var debris_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_prop_destroyed)


func _on_prop_destroyed() -> void:
	if debris_scene:
		# set the debris size scene to match the parent size
		var debris = debris_scene.instantiate()
		debris.scale = get_parent().scale
		get_tree().root.add_child(debris)

		# Match the parent's physical position
		debris.global_position = get_parent().global_position 
		
	# Delete the parent physics body (the crate/barrel)
	get_parent().queue_free()
