extends PlayerState

var _slide_timer:float = 0.0

func _on_sliding_state_entered() -> void:
	_slide_timer = player_controller.slide_duration
	# We removed the local cooldown variable here. The controller handles it now.
	# player_controller.crouch()
	# player_controller.cam_effects.slide_effect(0.0, -1)
	player_controller.start_slide()

func _on_sliding_state_physics_processing(delta: float) -> void:
	_slide_timer -= delta
	player_controller.camera.update_camera_height(delta, -2)

	# gradually decrease slide_modifier over time
	player_controller.slide_modifier = player_controller.slide_power * (_slide_timer / player_controller.slide_duration)
	 
	player_controller.cam_effects.slide_movement_effect(delta, 2.0, player_controller._slide_direction)
	player_controller.cam_effects.slide_fov_effect(2.0, delta)
	if _slide_timer <= 0.0:
		# end_slide() is now called, which will trigger the cooldown timer!
		player_controller.state_chart.send_event("onCrouching")

func _on_sliding_state_exited() -> void:
	player_controller.cam_effects.slide_movement_effect(0.0, 0.0, Vector3.ZERO)
	player_controller.cam_effects.slide_fov_effect(0.0, 1)
	player_controller.end_slide()
