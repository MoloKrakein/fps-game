extends PlayerState

var _slide_timer:float = 0.0

func _on_sliding_state_entered() -> void:
# 1. Call start_slide FIRST so the controller can calculate the dynamic math
	player_controller.start_slide()
	# 2. Grab the newly calculated duration
	_slide_timer = player_controller.current_slide_duration

func _on_sliding_state_physics_processing(delta: float) -> void:
	_slide_timer -= PlayerTime.move(delta)
	player_controller.camera.update_camera_height(PlayerTime.real(delta), -2)

	player_controller.slide_modifier = player_controller.current_slide_power * (_slide_timer / player_controller.current_slide_duration)

	# prone key mid-slide: dive out of it (or just go prone)
	if Input.is_action_just_pressed("move_prone"):
		player_controller.request_prone()
		return

	# 1. Calculate exactly how long we have been sliding
	var time_in_slide = player_controller.current_slide_duration - _slide_timer
	
	# 2. The Grace Period: Only allow cancel if 150ms have passed
	if time_in_slide > 0.001:
		if Input.is_action_just_pressed("move_crouch") and player_controller.is_sliding:
			# 3. Just send the event! The State Chart's exited function handles the cleanup.
			player_controller.state_chart.send_event("onStanding")
			return # Skip the rest of the frame so it transitions cleanly

	if _slide_timer <= 0.0:
		player_controller.state_chart.send_event("onCrouching")

func _on_sliding_state_exited() -> void:
	
	player_controller.end_slide()
