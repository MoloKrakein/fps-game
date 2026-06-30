extends PlayerState

# get player_controller before the 


func _on_standing_state_physics_processing(delta: float) -> void:
	if Input.is_action_pressed("move_crouch") and player_controller.is_on_floor():
		player_controller.state_chart.send_event("onCrouching")

	# if player_controller.isToggleCrouch:
	#     if Input.is_action_just_pressed("move_crouch") and player_controller.is_on_floor():
	#         player_controller.is_crouching = true
	#         player_controller.state_chart.send_event("onCrouching")
	# else:
	#     if Input.is_action_pressed("move_crouch") and player_controller.is_on_floor():
	#         player_controller.is_crouching = true
	#         player_controller.state_chart.send_event("onCrouching")


func _on_standing_state_entered() -> void:
	# pass # Replace with function body.
	player_controller.stand()
	# print("Standing State Entered")
