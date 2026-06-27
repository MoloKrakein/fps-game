extends PlayerState


func _on_walking_state_processing(delta: float) -> void:
	# pass # Replace with function body.
    if Input.is_action_pressed("move_sprint"):
        player_controller.state_chart.send_event("onSprinting")
