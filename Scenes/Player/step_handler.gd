class_name StepHandlerComponent extends Node

@export_category("references")
@export var player: PlayerController
@export_category("Step Settings")
@export_range(0.0, 1.0, 0.01) var surface_threshold: float = 0.3 # Higher values only treat more horizontal surfaces as steps; lower values treat more walls as steps.
@export_range(0.0, 2.0, 0.01) var max_step_height: float = 0.35 # Maximum step height the player can climb in world units.
@export_range(0.0, 1.0, 0.01) var step_probe_distance: float = 0.25 # How far forward the step probe checks for the top of the step.
@export_range(0.0, 0.2, 0.01) var step_forward_clearance: float = 0.06 # Small forward nudge after stepping up so the player clears the stair edge.


var step_status: String = "No Step Detected"
const FEET_ADJUST_HEIGHT: float = 0.05
const MIN_MOVEMENT_LENGTH: float = 0.1
const MIN_DOT_VALUE: float = 0.5

func handle_step() -> void:
	if player == null:
		return

	for i in player.get_slide_collision_count():
		var collision = player.get_slide_collision(i)
		if _is_vertical_surface(collision) and handle_step_climb(collision):
			break

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

func handle_step_climb(collision: KinematicCollision3D) -> bool:
	step_status = "Step Climb Logic Not Implemented"

	if not _is_vertical_surface(collision):
		return false

	if not _is_valid_step_direction(collision):
		step_status = "Invalid Step Direction"
		return false

	var measured_height = _measure_step_height(collision)
	if not _is_valid_step_height(measured_height):
		step_status = "Step Height: " + str(measured_height) + " / Limit: " + str(max_step_height) + " (Too High)"
		return false

	player.global_position.y += measured_height
	var forward = _get_step_forward_vector(collision)
	if forward != Vector3.ZERO:
		player.global_position += forward * step_forward_clearance
	player.velocity.y = 0.0
	step_status = "Step Height: " + str(measured_height)
	return true

func _measure_step_height(collision: KinematicCollision3D) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()

	var player_feet_pos = _get_player_feet_pos()
	var player_head_y =  player.global_position.y + (player.standing_col.shape.height / 2.0)

	var ray_start = Vector3(collision_point.x, player_head_y, collision_point.z)
	var ray_end = Vector3(collision_point.x, player_feet_pos.y, collision_point.z)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y - player_feet_pos.y

	return 0.0
	# var horizontal_velocity = Vector3(player.velocity.x, 0.0, player.velocity.z)
	# if horizontal_velocity.length() == 0.0:
	# 	horizontal_velocity = Vector3(-collision.get_normal().x, 0.0, -collision.get_normal().z)

	# if horizontal_velocity.length() == 0.0:
	# 	return 0.0

	# var forward = horizontal_velocity.normalized()
	# var player_feet_pos = _get_player_feet_pos()
	# var probe_pos = player_feet_pos + forward * step_probe_distance
	# var ray_start = probe_pos + Vector3.UP * max_step_height
	# var ray_end = probe_pos + Vector3.DOWN * (max_step_height * 2.0)

	# var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	# query.collision_mask = player.collision_mask
	# query.exclude = [player.get_rid()]

	# var result = space_state.intersect_ray(query)
	# if result and result.normal.y >= surface_threshold:
	# 	return result.position.y - player_feet_pos.y
	# return 0.0

func _get_step_forward_vector(collision: KinematicCollision3D) -> Vector3:
	var horizontal_velocity = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity.length() > 0.0:
		return horizontal_velocity.normalized()

	var normal = collision.get_normal().slide(Vector3.UP)
	if normal.length() > 0.0:
		return -normal.normalized()

	return Vector3.ZERO

func _get_player_feet_pos() -> Vector3:
	var feet_pos = player.global_position
	var active_col = _get_active_collision_shape()
	if active_col != null:
		feet_pos.y = active_col.global_position.y - _get_shape_half_height(active_col.shape)
	feet_pos.y += FEET_ADJUST_HEIGHT  # Slightly above the ground to avoid clipping
	return feet_pos

func _get_active_collision_shape() -> CollisionShape3D:
	if player == null:
		return null
	if player.crouching_col != null and not player.crouching_col.disabled:
		return player.crouching_col
	if player.standing_col != null and not player.standing_col.disabled:
		return player.standing_col
	return player.standing_col if player.standing_col != null else player.crouching_col

func _get_shape_half_height(shape: Shape3D) -> float:
	if shape == null:
		return 0.0
	if shape is CapsuleShape3D:
		return (shape.height * 0.5) + shape.radius
	if shape is SphereShape3D:
		return shape.radius
	if shape is BoxShape3D:
		return shape.size.y * 0.5
	return 0.0

func _is_valid_step_height(height: float) -> bool:
	return height > 0 and height <= max_step_height

func _is_valid_step_direction(collision: KinematicCollision3D) -> bool:
	var collision_normal = collision.get_normal()
	var input_dir = player.get_input_dir()
	var movement_dir = player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	if movement_dir.length() > MIN_MOVEMENT_LENGTH:
		movement_dir = movement_dir.normalized()
		var dot = movement_dir.dot(-collision_normal)
		return dot > MIN_DOT_VALUE
	return false

