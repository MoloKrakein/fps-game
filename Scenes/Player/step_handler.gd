class_name StepHandlerComponent extends Node

@export_category("references")
@export var player: PlayerController
@export_category("Step Settings")
@export_range(0.0, 1.0, 0.01) var surface_threshold: float = 0.3 # Higher values only treat more horizontal surfaces as steps; lower values treat more walls as steps.
@export_range(0.0, 2.0, 0.01) var max_step_height: float = 0.35 # Maximum step height the player can climb in world units.
@export_range(0.0, 1.0, 0.01) var step_probe_distance: float = 0.25 # How far forward the step probe checks for the top of the step.
@export_range(0.0, 0.2, 0.01) var step_forward_clearance: float = 0.06 # Small forward nudge after stepping up so the player clears the stair edge.
@export_flags_3d_physics var step_collision_mask: int = 1

var step_status: String = "No Step Detected"
const FEET_ADJUST_HEIGHT: float = 0.05
const MIN_MOVEMENT_LENGTH: float = 0.1
const MIN_DOT_VALUE: float = 0.5

# rotate the check direction to be more in line with the player's movement direction, so that steps can be detected even if the player is not moving directly forward.
var step_check_direction: Vector3 = Vector3.FORWARD

func handle_step() -> void:
	if player == null or not player.is_on_floor():
		return

	for i in range(player.get_slide_collision_count()):
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
	if abs(normal.y) <= surface_threshold and not _is_valid_step_direction(collision):
		step_status = "Col Shape:" + str(normal)
		return true
	return _check_collision_normal(collision)

func handle_step_climb(collision: KinematicCollision3D) -> bool:
	var player_feet_pos = _get_player_feet_pos()
	var collision_point = collision.get_position()
	var contact_height = collision.get_position().y - player_feet_pos.y
	
	if contact_height > max_step_height + FEET_ADJUST_HEIGHT:
		step_status = "Contact Too High"
		return false

	if not _is_valid_step_direction(collision):
		step_status = "Invalid Step Direction"
		return false
	
	if not _is_vertical_surface(collision):
		step_status = "Not Vertical Surface"
		return false

	# FIX: Calculate the forward vector FIRST
	var forward = _get_step_forward_vector(collision)
	if forward == Vector3.ZERO:
		step_status = "No Forward Vector"
		return false

	# FIX: Pass the forward vector into the measurement function
	var measured_height = _measure_step_height(collision, forward)
	if not _is_valid_step_height(measured_height):
		step_status = "Step Height Too High"
		return false

	if not _has_step_landing_depth(collision_point, player_feet_pos, forward, measured_height):
		step_status = "No Step Landing"
		return false

	if measured_height > MIN_MOVEMENT_LENGTH:
		player.global_position.y += measured_height
		player.global_position += forward * step_forward_clearance
		player.velocity = player.previous_velocity
		player.velocity.y = 0.0
		player.camera.smooth_step(measured_height)
		step_status = "Step Height: " + str(measured_height)
		return true

	return false
	# if not _is_vertical_surface(collision):
	# 	return false

	# if not _is_valid_step_direction(collision):
	# 	step_status = "Invalid Step Direction"
	# 	return false

	# var measured_height = _measure_step_height(collision)
	# if not _is_valid_step_height(measured_height):
	# 	step_status = str(measured_height) + " / Limit: " + str(max_step_height) + " (Too High)"
	# 	return false

	# player.global_position.y += measured_height
	# var forward = _get_step_forward_vector(collision)
	# if forward != Vector3.ZERO:
	# 	player.global_position += forward * step_forward_clearance
	# player.velocity.y = 0.0
	# step_status = "Step Height: " + str(measured_height)
	return true

func _measure_step_height(collision: KinematicCollision3D, forward: Vector3) -> float:
	var space_state = player.get_world_3d().direct_space_state
	var collision_point = collision.get_position()
	
	# FIX: Nudge the raycast 5cm inward to avoid floating-point edge misses
	var shifted_point = collision_point + (forward * 0.05) 
	
	var player_feet_pos = _get_player_feet_pos()
	var active_col = _get_active_collision_shape()
	var player_head_y = player.global_position.y
	
	if active_col != null:
		player_head_y = active_col.global_position.y + _get_shape_half_height(active_col.shape)

	# Use the shifted X and Z coordinates
	var ray_start = Vector3(shifted_point.x, player_head_y, shifted_point.z)
	var ray_end = Vector3(shifted_point.x, player_feet_pos.y, shifted_point.z)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = step_collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and result.normal.y >= surface_threshold:
		return result.position.y - player_feet_pos.y
		
	return 0.0

func _has_step_landing_depth(collision_point: Vector3, player_feet_pos: Vector3, forward: Vector3, expected_height: float) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var probe_point = collision_point + forward * step_probe_distance
	var ray_start = Vector3(probe_point.x, player.global_position.y + max_step_height, probe_point.z)
	var ray_end = Vector3(probe_point.x, player_feet_pos.y, probe_point.z)

	draw_debug_line(ray_start, ray_end, Color.BLUE) # Draw the probe ray for debugging
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = step_collision_mask
	query.exclude = [player.get_rid()]

	var result = space_state.intersect_ray(query)
	if result and result.normal.y >= surface_threshold:
		var landing_height = result.position.y - player_feet_pos.y
		return absf(landing_height - expected_height) <= max_step_height

	return false

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
	return height > 0.0 and height <= max_step_height

func _is_valid_step_direction(collision: KinematicCollision3D) -> bool:
	var collision_normal = collision.get_normal()
	var input_dir = player.get_input_dir()
	var movement_dir = player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	if collision_normal == Vector3.ZERO:
		return false
	if movement_dir.length() > MIN_MOVEMENT_LENGTH:
		movement_dir = movement_dir.normalized()
		var dot = movement_dir.dot(-collision_normal)
		return dot > MIN_DOT_VALUE
	return false

func draw_debug_line(pos1: Vector3, pos2: Vector3, color: Color = Color.RED) -> void:
	# Only draw if we exist and debug is enabled
	if player == null or not player.debug: 
		return
		
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()

	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# FIX 1: Turn off depth testing so the line draws ON TOP of the wall!
	material.no_depth_test = true 

	mesh_instance.mesh = immediate_mesh
	mesh_instance.material_override = material
	
	# FIX 2: Ensure the mesh doesn't inherit any weird positioning
	mesh_instance.top_level = true

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()

	# FIX 3: Add directly to the current scene instead of the window root
	player.get_tree().current_scene.add_child(mesh_instance)
	
	# FIX 4: Increased time to 0.5 seconds so you can actually see it
	await player.get_tree().create_timer(0.5).timeout
	
	# FIX 5: Safety check to prevent errors if the game is closed mid-draw
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()