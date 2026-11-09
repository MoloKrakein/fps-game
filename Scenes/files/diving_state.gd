extends PlayerState

func _on_diving_state_entered() -> void:
	player_controller.start_dive()

func _on_diving_state_physics_processing(delta: float) -> void:
	var dive: ProneDiveComponent = player_controller.prone_dive
	if dive == null:
		player_controller.state_chart.send_event("onProne")
		return

	var cam: CameraController = player_controller.camera
	cam.move_camera_to(delta, cam.prone_offset, dive.dive_camera_speed)

	if dive.should_land() or dive.timed_out():
		player_controller.state_chart.send_event("onProne")

func _on_diving_state_exited() -> void:
	player_controller.end_dive()
