extends WeaponState

func _on_canted_aim_state_state_entered() -> void:
	if weapon_controller:
		# Assuming you have a function called aim_canted() in your controller!
		weapon_controller.aim_canted() 

func _on_canted_aim_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
		
	# 1. Did they let go of Right Click? Return to Hipfire
	if not Input.is_action_pressed("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
		
	# 2. Did they press the Toggle button again? Return to Standard ADS
	if Input.is_action_just_pressed("combat_alt_aim"):
		weapon_controller.weapon_state_chart.send_event("onCanted")