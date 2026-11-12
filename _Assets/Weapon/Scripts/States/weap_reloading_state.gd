extends WeaponState
# Attach this to your ReloadingState node in the State Chart.
#
# No await/timer any more: WeaponActions runs the reload on a timeline.
# Ammo transfers on the clip's mag_in event (or when the action finishes if the
# clip has none), then WeaponActions sends onReloadFinish and calls
# finish_reload_step(), exactly as this script used to do after the timer.

func _on_reload_state_state_entered() -> void:
	if not weapon_controller or weapon_controller.current_weapon == null:
		return

	if not weapon_controller.can_reload():
		weapon_controller.weapon_state_chart.send_event("onReloadFinish")
		weapon_controller.is_reloading = false
		return

	var actions: WeaponActions = weapon_controller.actions
	var reload_type: StringName = WeaponActions.RELOAD_LOADED if weapon_controller.active_weapon_data.is_loaded else WeaponActions.RELOAD_EMPTY
	var duration: float = actions.get_reload_duration(reload_type)

	weapon_controller.is_reloading = true # must be set before start_reload(): a 0s reload finishes inside it
	weapon_controller.reload_timer_ui(duration)
	actions.start_reload(reload_type, duration)
