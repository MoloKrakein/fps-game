extends WeaponState


func _on_idle_state_state_physics_processing(_delta: float) -> void:
	# pass # Replace with function body.
	if not weapon_controller:
		return

	if Input.is_action_just_pressed("combat_fire"):
		weapon_controller.start_trigger()

	if Input.is_action_just_released("combat_fire"):
		weapon_controller.stop_trigger()

	if Input.is_action_pressed("combat_fire") and weapon_controller.can_fire():
		# print("Firing weapon: %s" % weapon_controller.current_weapon.weapon_name)
		weapon_controller.weapon_state_chart.send_event("onFiring")

	if Input.is_action_just_pressed("combat_reload"):
		weapon_controller.weapon_state_chart.send_event("onReload")

	# Only go to empty state if there are no rounds in the magazine and no round chambered
	if weapon_controller.current_ammo <= 0 and not weapon_controller.is_loaded:
		weapon_controller.weapon_state_chart.send_event("onEmpty")
