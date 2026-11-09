extends PlayerState


func _on_crouching_state_physics_processing(delta: float) -> void:
	player_controller.camera.update_camera_height(delta, -1)

	# prone key from crouch
	if Input.is_action_just_pressed("move_prone"):
		player_controller.request_prone()
		return

	# if not Input.is_action_pressed("move_crouch") and player_controller.is_on_floor() and not player_controller.crouch_check.is_colliding():
	# 	player_controller.state_chart.send_event("onStanding")

	if player_controller.isToggleCrouch:
		if Input.is_action_just_pressed("move_crouch") and player_controller.is_on_floor() and not player_controller.crouch_check.is_colliding():
			player_controller.is_crouching = false
			player_controller.state_chart.send_event("onStanding")
	else:
		if not Input.is_action_pressed("move_crouch") and player_controller.is_on_floor() and not player_controller.crouch_check.is_colliding():
			player_controller.is_crouching = false
			player_controller.state_chart.send_event("onStanding")
	


func _on_crouching_state_entered() -> void:
	# pass # Replace with function body.
	player_controller.slide_modifier = 0.0
	player_controller.crouch()
	# print("Crouching State Entered")
