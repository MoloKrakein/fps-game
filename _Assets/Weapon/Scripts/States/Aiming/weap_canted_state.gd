extends WeaponState

func _on_canted_aim_state_state_entered() -> void:
	if weapon_controller:
		# print("Canted State Entered")
		weapon_controller.aim_canted() 

func _on_canted_aim_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
		
	# 1. Did they let go? Return to Hipfire.
	if Input.is_action_just_released("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
		
	# 2. Did they press Alt-Aim? Swap back to Standard ADS!
	if Input.is_action_just_pressed("combat_alt_aim"):
		weapon_controller.weapon_state_chart.send_event("onStandardADS")