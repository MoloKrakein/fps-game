extends WeaponState

func _on_empty_state_state_entered() -> void:
	# pass # Replace with function body.
	print("Weapon is empty. Cannot fire.")


func _on_empty_state_state_physics_processing(delta: float) -> void:
	if Input.is_action_just_pressed("combat_fire"):
		print("Cannot fire. Weapon is empty.")
	if Input.is_action_just_pressed("combat_reload"):
		print("Reloading weapon...")
		# Transition to reload state
		weapon_controller.weapon_state_chart.send_event("onReload")
