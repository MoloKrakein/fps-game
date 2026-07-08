extends PlayerState



func _on_sprinting_state_processing(delta: float) -> void:
	# pass # Replace with function body.
    # if not Input.is_action_pressed("move_sprint"):
    #     player_controller.state_chart.send_event("onWalking")

    if player_controller.isToggleSprint:
        if Input.is_action_just_pressed("move_sprint"):
            player_controller.state_chart.send_event("onWalking")
            
    else:
        if not Input.is_action_pressed("move_sprint"):
            player_controller.state_chart.send_event("onWalking")

    # if Input.is_action_just_pressed("move_crouch") and player_controller.is_on_floor():
    #     player_controller.state_chart.send_event("onSliding")
    
    if Input.is_action_just_pressed("move_crouch"):
        if player_controller.can_slide():
            player_controller.state_chart.send_event("onSliding")
        elif player_controller.is_on_floor() and not player_controller.crouch_check.is_colliding():
            player_controller.state_chart.send_event("onCrouching")
        
func _on_sprinting_state_entered() -> void:
    player_controller.sprint()
