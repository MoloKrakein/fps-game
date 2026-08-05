extends StaticBody3D


func _on_health_component_died() -> void:
	queue_free()