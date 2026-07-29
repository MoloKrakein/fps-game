extends WeaponState


func _on_aim_down_state_state_entered() -> void:
	print("ADS State Entered")
	if weapon_controller:
		weapon_controller.aim_ads()



func _on_aim_down_state_state_physics_processing(delta: float) -> void:
	if not Input.is_action_pressed("combat_aim"):
		weapon_controller.weapon_state_chart.send_event("onHipfire")
	# if Input.is_action_just_pressed("toggle_sight"):
	# 	weapon_controller.weapon_state_chart.send_event("onToggleSight")
