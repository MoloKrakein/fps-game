extends WeaponState

func _on_firing_state_state_entered() -> void:
	if not weapon_controller:
		return
	
	weapon_controller.fire_weapon()

func _on_firing_state_state_physics_processing(_delta: float) -> void:
	if not weapon_controller:
		return

	var weapon_data: WeaponData = weapon_controller.active_weapon_data
	if weapon_data != null and weapon_data.ammo_in_magazine <= 0 and not weapon_data.is_loaded:
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


