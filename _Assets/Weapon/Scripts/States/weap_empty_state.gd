extends WeaponState

func _on_empty_state_state_entered() -> void:
	# pass # Replace with function body.
	print("Weapon is empty. Cannot fire.")


func _on_empty_state_state_physics_processing(delta: float) -> void:
	pass # Replace with function body.

