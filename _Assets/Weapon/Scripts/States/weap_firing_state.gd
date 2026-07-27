extends WeaponState

func _on_firing_state_state_entered() -> void:
	if not weapon_controller:
		return
	weapon_controller.reset_trigger()

func _on_firing_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
		
	# Fire the weapon
	weapon_controller.fire_weapon()

	# Check if we ran out of ammo mid-spray
	if weapon_controller.current_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("onEmpty")
		return

	# If the player lets go of the trigger, return to Idle
	if not Input.is_action_pressed("combat_fire"):
		
		if not weapon_controller.is_burst_fire():
			weapon_controller.weapon_state_chart.send_event("onIdle")
