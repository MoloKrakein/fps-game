extends WeaponState

func _on_empty_state_state_entered() -> void:
	# pass # Replace with function body.
	print("Weapon is empty. Cannot fire.")


func _on_empty_state_state_physics_processing(_delta: float) -> void:
	if Input.is_action_just_pressed("combat_fire"):
		print("Cannot fire. Weapon is empty.")
