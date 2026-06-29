extends PlayerState



func _on_sprinting_state_processing(delta: float) -> void:
	# pass # Replace with function body.
    if not Input.is_action_pressed("move_sprint"):
        player_controller.state_chart.send_event("onWalking")

func _on_sprinting_state_entered() -> void:
    player_controller.sprint()
