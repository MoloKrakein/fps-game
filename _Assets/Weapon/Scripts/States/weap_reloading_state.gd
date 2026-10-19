extends WeaponState
# Attach this to your ReloadingState node in the State Chart
var timer: float = 0.0

func _on_reload_state_state_entered() -> void:
	if not weapon_controller or weapon_controller.current_weapon == null:
		return

	if not weapon_controller.can_reload():
		weapon_controller.weapon_state_chart.send_event("onReloadFinish")
		weapon_controller.is_reloading = false
		return

	if weapon_controller.weapon_animation_player != null:
		timer = weapon_controller.weapon_animation_player.get_animation_length("Reload")
		weapon_controller.weapon_animation_player.reload_weapon_animation("empty_reload" if not weapon_controller.active_weapon_data.is_loaded else "loaded_reload")

	weapon_controller.is_reloading = true
	# For per-bullet weapons, each reload input inserts a single shell.
	var reload_time: float = timer
	if weapon_controller.current_weapon.is_reload_per_bullet:
		reload_time = weapon_controller.get_single_round_reload_time()
	elif weapon_controller.current_weapon.reload_time > 0.0:
		reload_time *= weapon_controller.current_weapon.get_calculated_reload_speed() / weapon_controller.current_weapon.reload_time

	weapon_controller.reload_timer_ui(reload_time)
	
	# Wait for this reload step to finish.
	await get_tree().create_timer(reload_time).timeout
	
	# Perform one reload action (one shell for per-bullet weapons).
	weapon_controller.execute_reload()
	
	# Finish this reload state entry; additional shells require another reload input.
	weapon_controller.weapon_state_chart.send_event("onReloadFinish")
	weapon_controller.finish_reload_step()
