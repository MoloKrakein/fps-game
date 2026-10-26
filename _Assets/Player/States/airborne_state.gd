extends PlayerState



func _on_airborne_state_physics_processing(delta: float) -> void:
	if player_controller.is_on_floor():
		player_controller.state_chart.send_event("onGrounded")
	player_controller.current_fall_velocity = player_controller.velocity.y
