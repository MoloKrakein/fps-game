extends Node3D

func _on_health_component_died() -> void:
	# pass # Replace with function body.
	queue_free()