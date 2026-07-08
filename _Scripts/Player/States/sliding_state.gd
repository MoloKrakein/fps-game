extends PlayerState

var _slide_timer:float = 0.0
var _slide_cooldown:float = 0.0


func _on_sliding_state_entered() -> void:
	# pass # Replace with function body.
	_slide_timer = player_controller.slide_duration
	_slide_cooldown = player_controller.slide_cooldown
	player_controller.start_slide()


func _on_sliding_state_physics_processing(delta: float) -> void:
	_slide_timer -= delta
	player_controller.camera.update_camera_height(delta, -2)
	player_controller.slide_modifier = player_controller.slide_power * (_slide_timer / player_controller.slide_duration) # gradually decrease slide_modifier over time
	if _slide_timer <= 0.0:
		player_controller.end_slide()
		player_controller.state_chart.send_event("onCrouching")

	
		

func _on_sliding_state_exited() -> void:
	# pass # Replace with function body.
	player_controller.end_slide()