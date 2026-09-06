extends PlayerState

var _slide_timer:float = 0.0

func _on_sliding_state_entered() -> void:
# 1. Call start_slide FIRST so the controller can calculate the dynamic math
	player_controller.start_slide()
	# 2. Grab the newly calculated duration
	_slide_timer = player_controller.current_slide_duration

func _on_sliding_state_physics_processing(delta: float) -> void:
	_slide_timer -= delta
	player_controller.camera.update_camera_height(delta, -2)

	# 3. Use the dynamic variables to calculate friction decay
	player_controller.slide_modifier = player_controller.current_slide_power * (_slide_timer / player_controller.current_slide_duration)
	
	if _slide_timer <= 0.0:
		player_controller.state_chart.send_event("onCrouching")

func _on_sliding_state_exited() -> void:
	
	player_controller.end_slide()
