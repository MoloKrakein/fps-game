extends PlayerState



func _on_airborne_state_physics_processing(delta: float) -> void:
	# pass # Replace with function body.
    if player_controller.is_on_floor():
        player_controller.state_chart.send_event("onGrounded")

