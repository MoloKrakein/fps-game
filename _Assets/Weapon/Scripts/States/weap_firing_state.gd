extends WeaponState

func _on_firing_state_state_entered() -> void:
	if not weapon_controller:
		return
	
	weapon_controller.fire_weapon()

func _on_firing_state_state_physics_processing(_delta: float) -> void:
	if not weapon_controller:
		return

	if weapon_controller.current_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("onEmpty")
		return

	if weapon_controller.current_fire_mode == Weapon.WeaponFireMode.BURST:
		if weapon_controller.can_fire():
			weapon_controller.weapon_state_chart.send_event("onFiring")
			return

		if weapon_controller.is_burst_fire():
			return

		weapon_controller.reset_trigger()
		weapon_controller.weapon_state_chart.send_event("onIdle")
		return

	if Input.is_action_just_released("combat_fire"):
		weapon_controller.stop_trigger()
		weapon_controller.weapon_state_chart.send_event("onIdle")
		return

	if weapon_controller.current_fire_mode == Weapon.WeaponFireMode.FULL_AUTO:
		if weapon_controller.can_fire():
			weapon_controller.weapon_state_chart.send_event("onFiring")
		return

	weapon_controller.weapon_state_chart.send_event("onIdle")

	
	# # Fire the weapon
	# weapon_controller.fire_weapon()

	# # Check if we ran out of ammo mid-spray
	# if weapon_controller.current_ammo <= 0:
	# 	weapon_controller.weapon_state_chart.send_event("onEmpty")
	# 	return

	# # If the player lets go of the trigger, return to Idle
	# if not Input.is_action_pressed("combat_fire"):
		
	# 	if not weapon_controller.is_burst_fire():
	# 		weapon_controller.weapon_state_chart.send_event("onIdle")
