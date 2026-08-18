class_name BaseBreakable extends Node3D

@export_category("Component Settings")
@export var force_multiplier: float = 1.0
@export var break_scene: PackedScene

# Called when the node enters the scene tree for the first time.

func _on_health_component_died() -> void:
	if break_scene:
		var break_instance:Node3D = break_scene.instantiate()

		get_parent().add_child(break_instance)
		break_instance.transform = self.transform

		self.queue_free()
		