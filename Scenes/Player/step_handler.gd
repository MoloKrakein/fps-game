class_name StepHandlerComponent extends Node

@export_category("References")
@export var player: PlayerController

@export_category("Step Settings")
@export var surface_threshold: float = 0.3
@export var max_step_height: float = 0.35 # Changed from 0.01 to a realistic 35cm step

const FEET_ADJUST_HEIGHT: float = 0.05 # Lowered from 0.5 to prevent floating feet
const MIN_STEP_HEIGHT: float = 0.1
const MIN_MOVEMENT_LENGHT: float = 0.1
const MIN_DOT: float = 0.5

var step_status: String = ""

func handle_step_climbing():
	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		if _is_vertical_surface(collision):
			var measured_height = _measure_step_height(collision)
			
			# Using the corrected max_step_height variable
			if measured_height > MIN_STEP_HEIGHT and measured_height <= max_step_height and _is_valid_step_dir(collision) and not player.is_sliding:
				step_status = "Step detected with height: " + str(measured_height)
				player.global_position.y += measured_height
				player.velocity = player.previous_velocity
				player.camera.smooth_step(measured_height)
			else:
				step_status = "Step detected but too high: " + str(measured_height)
			break

func _is_vertical_surface(collision: KinematicCollision3D) -> bool:
	var normal = collision.get_normal()
	if abs(normal.y) <= surface_threshold:
		step_status = "Collision detected" + str(normal)
		return true
	
	return _check_collision_surface(collision)

func _check_collision_surface(collision: KinematicCollision3D) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()

	var player_feet_pos = _get_player_feet_position()
	collision_point.y = player_feet_pos.y

	var query = PhysicsRayQueryParameters3D.create(player_feet_pos, collision_point)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and abs(result.normal.y) <= surface_threshold:
		step_status = "Collision detected" + str(result.normal)
		return true

	step_status = "No collision detected"
	return false

func _get_player_feet_position() -> Vector3:
	var feet_position = player.global_position
	feet_position.y -= player.standing_col.shape.height / 2.0
	feet_position.y += FEET_ADJUST_HEIGHT # Safe 5cm buffer
	return feet_position

func _measure_step_height(collision: KinematicCollision3D) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()

	var player_feet_pos = _get_player_feet_position()
	
	# Check slightly below max step height so we don't accidentally measure the roof!
	# var check_height = player_feet_pos.y + max_step_height + 0.05 
	var player_head_pos = player.global_position.y + (player.standing_col.shape.height / 2) + max_step_height + 0.05 # Check slightly above max step height to avoid roof collisions

	# Calculate inward shift based on the wall's normal
	# This pushes the ray 5cm DEEP into the step to avoid the mathematical edge
	var inward_shift = -collision.get_normal() * 0.05
	inward_shift.y = 0.0

	var ray_start = Vector3(collision_point.x, player_head_pos, collision_point.z)
	var ray_end = Vector3(collision_point.x, player_feet_pos.y, collision_point.z)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y - player_feet_pos.y

	return 0.0

func _is_valid_step_dir(collision: KinematicCollision3D) -> bool:
	var coll_normal = collision.get_normal()
	var input_dir = player.get_input_dir()
	var movement_dir = player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	
	if movement_dir.length() > MIN_MOVEMENT_LENGHT:
		movement_dir = movement_dir.normalized()
		var dot_product = movement_dir.dot(-coll_normal)
		return dot_product > MIN_DOT
		
	return false
