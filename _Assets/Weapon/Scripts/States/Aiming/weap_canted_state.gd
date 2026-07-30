extends WeaponState

func _on_canted_aim_state_state_entered() -> void:
	if weapon_controller:
		weapon_controller.aim_canted() 

func _on_canted_aim_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
		
	# Because this is a HOLD, exiting happens the moment they let go!
	if Input.is_action_just_released("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
		
	# Manual Alt-Aim override
	if Input.is_action_just_pressed("combat_alt_aim"):
		weapon_controller.weapon_state_chart.send_event("onADS")
		# Toggle global slow-motion for debugging (press to enable/disable)
		var slowmo_enabled := Engine.time_scale != 1.0
		if not slowmo_enabled:
			Engine.time_scale = 0.25
		else:
			Engine.time_scale = 1.0