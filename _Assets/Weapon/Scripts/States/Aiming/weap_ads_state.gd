extends WeaponState

func _on_aim_down_state_state_entered() -> void:
	if weapon_controller:
		# print("ADS State Entered")
		weapon_controller.aim_ads()

func _on_aim_down_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return

	# 1. Did they let go? Return to Hipfire. (Removed the 'not'!)
	if Input.is_action_just_released("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
		
	# 2. Did they press Alt-Aim? Swap to Canted!
	if Input.is_action_just_pressed("combat_alt_aim"):
		weapon_controller.weapon_state_chart.send_event("onCanted")