class_name StepHandlerComponent extends Node

@export_category("references")
@export var player: PlayerController
@export_category("Step Settings")
@export var surface_threshold: float = 0.3
@export var max_step_height: float = 0.35
@export var step_probe_distance: float = 0.25


var step_status: String = "No Step Detected"
const FEET_ADJUST_HEIGHT: float = 0.05

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

	var measured_height = _measure_step_height(collision)
	if not _is_valid_step_height(measured_height):
		step_status = "Step Height: " + str(measured_height) + " (Too High)"
		return false

	player.global_position.y += measured_height
	player.velocity.y = 0.0
	step_status = "Step Height: " + str(measured_height)
	return true

func _measure_step_height(collision: KinematicCollision3D) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var horizontal_velocity = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if horizontal_velocity.length() == 0.0:
		horizontal_velocity = Vector3(-collision.get_normal().x, 0.0, -collision.get_normal().z)

	if horizontal_velocity.length() == 0.0:
		return 0.0

	var forward = horizontal_velocity.normalized()
	var player_feet_pos = _get_player_feet_pos()
	var probe_pos = player_feet_pos + forward * step_probe_distance
	var ray_start = probe_pos + Vector3.UP * max_step_height
	var ray_end = probe_pos + Vector3.DOWN * (max_step_height * 2.0)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and result.normal.y >= surface_threshold:
		return result.position.y - player_feet_pos.y
	return 0.0

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
