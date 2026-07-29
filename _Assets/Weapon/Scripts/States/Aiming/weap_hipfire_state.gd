extends WeaponState

func _on_hipfire_state_state_physics_processing(delta: float) -> void:
	if not weapon_controller:
		return
	
	# HOLD to Aim
	if Input.is_action_pressed("combat_aim"):
		# print("ADS State Entered")
		weapon_controller.weapon_state_chart.send_event("onAiming")
		
func _on_hipfire_state_state_entered() -> void:
	if weapon_controller:
		weapon_controller.aim_hipfire()