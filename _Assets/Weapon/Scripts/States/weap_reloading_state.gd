extends WeaponState
# Attach this to your ReloadingState node in the State Chart


func _on_reload_state_state_entered() -> void:
	# if not weapon_controller.can_reload():
	# 	weapon_controller.weapon_state_chart.send_event("onReloadFinish")

	weapon_controller.is_reloading = true
	# print("State Chart: Entered Reloading State")
	# 1. Get the reload time from your weapon stats
	var reload_time = weapon_controller.current_weapon.reload_time
	weapon_controller.reload_timer_ui(reload_time)
	
	# 2. Wait for the reload to finish
	await get_tree().create_timer(reload_time).timeout
	
	# 3. Tell the controller to refill the bullets
	weapon_controller.execute_reload()
	
	# 4. Tell the state chart we are done, so it can go back to Idle
	weapon_controller.weapon_state_chart.send_event("onReloadFinish")
	weapon_controller.is_reloading = false
