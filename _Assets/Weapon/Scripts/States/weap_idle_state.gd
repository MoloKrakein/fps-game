extends WeaponState


func _on_idle_state_state_physics_processing(delta: float) -> void:
	# pass # Replace with function body.
	if not weapon_controller:
		return

	if Input.is_action_pressed("combat_fire") and weapon_controller.can_fire():
		# print("Firing weapon: %s" % weapon_controller.current_weapon.weapon_name)
		weapon_controller.weapon_state_chart.send_event("onFiring")


	if weapon_controller.current_ammo <= 0:
		weapon_controller.weapon_state_chart.send_event("onEmpty")
