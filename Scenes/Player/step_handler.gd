class_name StepHandlerComponent extends Node

@export_category("references")
@export var player: PlayerController
@export_category("Step Settings")
@export var surface_threshold: float = 0.3


var step_status: String = "No Step Detected"
const FEET_ADJUST_HEIGHT: float = 0.05
const MIN_STEP_HEIGHT: float = 0.1

func handle_step() -> void:
	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		if _check_collision_normal(collision):
			print("Step detected", collision.get_normal())
			break
		else:
			print("No step detected", collision.get_normal())
	pass 




func _check_collision_normal(collision: KinematicCollision3D) -> bool:
	var normal = collision.get_normal()
	if abs(normal.y) > surface_threshold:
		return false
	return true

func _is_vertical_surface(collision: KinematicCollision3D) -> bool:
	var normal = collision.get_normal()
	if abs(normal.y) <= surface_threshold:
		step_status = "Col Shape:" + str(normal)
		return true
	return _check_collision_normal(collision)

func handle_step_climb() -> void:
	# This function will handle the logic for climbing steps
	# It will check if the player is colliding with a step and adjust the player's position accordingly
	step_status = "Step Climb Logic Not Implemented"

	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		if _is_vertical_surface(collision):
			var measured_height = _measure_step_height(collision)
			if measured_height > 0 and measured_height <= MIN_STEP_HEIGHT :
				step_status = "Step Height: " + str(measured_height)
			else:
				step_status = "Step Height: " + str(measured_height) + " (Too High)"
			break


func _check_collision_surface(collision: KinematicCollision3D) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var col_point = collision.get_position()

	var player_feet_pos = _get_player_feet_pos()
	col_point.y = player_feet_pos.y

	var query = PhysicsRayQueryParameters3D.create(player_feet_pos, col_point)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and abs(result.normal.y) <= surface_threshold:
		step_status = "Ray Hit: " + str(result.normal)
		return true

	step_status = "Ray Miss: " + str(result.normal if result else "No Hit")
	return false

func _measure_step_height(collision: KinematicCollision3D) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var col_point = collision.get_position()

	var player_feet_pos = _get_player_feet_pos()
	col_point.y = player_feet_pos.y

	var query = PhysicsRayQueryParameters3D.create(player_feet_pos, col_point)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y - player_feet_pos.y
	return 0.0

func _get_player_feet_pos() -> Vector3:
	var feet_pos = player.global_position
	feet_pos.y -= player.get_collision.shape.height / 2
	feet_pos.y += FEET_ADJUST_HEIGHT  # Slightly above the ground to avoid clipping
	return feet_pos

func _is_valid_step_height(height: float) -> bool:
	return height > 0 and height <= MIN_STEP_HEIGHT