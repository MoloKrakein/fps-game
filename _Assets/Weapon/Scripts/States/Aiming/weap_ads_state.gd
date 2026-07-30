extends WeaponState

func _on_aim_down_state_state_entered() -> void:
	if weapon_controller:
		weapon_controller.aim_ads()

func _on_aim_down_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return

	# Because this is a TOGGLE, we wait for a fresh click to exit back to hipfire!
	if Input.is_action_just_pressed("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
		
	# Manual Alt-Aim override
	if Input.is_action_just_pressed("combat_alt_aim"):
		weapon_controller.weapon_state_chart.send_event("onCanted")
		# Toggle global slow-motion for debugging (press to enable/disable)
		var slowmo_enabled := Engine.time_scale != 1.0
		if not slowmo_enabled:
			Engine.time_scale = 0.005
		else:
			Engine.time_scale = 1.0