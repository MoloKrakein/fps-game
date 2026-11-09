extends PlayerState

func _on_prone_state_entered() -> void:
	player_controller.prone()

func _on_prone_state_physics_processing(delta: float) -> void:
	var cam: CameraController = player_controller.camera
	var dive: ProneDiveComponent = player_controller.prone_dive
	var cam_speed: float = dive.prone_camera_speed if dive else 3.0
	cam.move_camera_to(delta, cam.prone_offset, cam_speed)

	if not player_controller.is_on_floor():
		return

	# C / Ctrl: up to crouch
	if Input.is_action_just_pressed("move_crouch"):
		if player_controller.can_leave_prone_to_crouch():
			player_controller.state_chart.send_event("onCrouching")
		return

	# prone key again or jump: stand up, or crouch if there is no room to stand
	if Input.is_action_just_pressed("move_prone") or Input.is_action_just_pressed("move_jump"):
		if player_controller.can_stand_from_prone():
			player_controller.state_chart.send_event("onStanding")
		elif player_controller.can_leave_prone_to_crouch():
			player_controller.state_chart.send_event("onCrouching")
