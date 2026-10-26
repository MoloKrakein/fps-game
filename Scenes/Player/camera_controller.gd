class_name CameraController extends Node3D

@export var debug: bool = false
@export_category("References")
@export var player_controller: PlayerController
@export var component_mouse_capture: MouseCaptureComponent
@export_category("Camera Settings")
@export_group("Camera Tilt Settings")
@export_range(-90,-60) var tilt_low_limit: int = -90
@export_range(60,90) var tilt_high_limit: int = 90
@export_group("Camera Other Settings")
@export var is_Vertical_inverted: bool = false
@export var is_Horizontal_inverted: bool = false
@export var crouch_offset: float = 0.0
@export var crouch_speed: float = 3.0

var _rotation: Vector3
const DEFAULT_HEIGHT: float = 0.5


@export_group("Step Smoothing")
@export var step_speed: float = 8.0
var _target_h: float = 0.0
var _step_smoothing: bool = false

var offset_height: float = 0.0

# --- Cover peek (driven by CoverPeek) ---------------------------------
# Offset is in player-local space (x = right, y = up). It is applied to the Cam
# child's position, NOT to this node's position, so the crouch / step-smoothing
# code below that reads and writes position.y is left untouched.
var _peek_offset: Vector3 = Vector3.ZERO
var _peek_roll: float = 0.0
var _cam: Node3D
var _cam_base_position: Vector3

func set_peek(offset: Vector3, roll: float) -> void:
	_peek_offset = offset
	_peek_roll = roll

## Where the camera would be with no peek applied (stable origin for cover probes).
func get_base_eye_position() -> Vector3:
	# pitch-only, so the roll we add for leaning can't feed back into the probes
	var parent := get_parent_node_3d()
	var pitch_only := Basis.from_euler(Vector3(rotation.x, 0.0, 0.0))
	return global_position + parent.global_transform.basis * (pitch_only * _cam_base_position)

func _ready() -> void:
	_rotation = player_controller.rotation
	offset_height = DEFAULT_HEIGHT
	_cam = get_node_or_null("Cam") as Node3D
	if _cam:
		_cam_base_position = _cam.position

func update_camera_rotation(input: Vector2) -> void:
	_rotation.x += input.y * (1 if is_Vertical_inverted else -1)
	_rotation.y += input.x * (1 if is_Horizontal_inverted else -1)
	_rotation.x = clamp(_rotation.x, deg_to_rad(tilt_low_limit), deg_to_rad(tilt_high_limit))

	var _player_rotation = Vector3(0.0, _rotation.y, 0.0)
	var _camera_rotation = Vector3(_rotation.x, 0.0, 0.0)

	transform.basis = Basis.from_euler(_camera_rotation)
	player_controller.update_rotation(_player_rotation)

	rotation.z = _peek_roll
	if debug:
		print("Camera Rotation: ", _rotation)

func _process(delta: float) -> void:
	_apply_peek()
	if component_mouse_capture._mouse_input != Vector2.ZERO:
		update_camera_rotation(component_mouse_capture._mouse_input)
	
	if _step_smoothing:
		_target_h = lerp(_target_h, 0.0, step_speed * delta)
		if abs(_target_h) < 0.01:
			_target_h = 0.0
			_step_smoothing = false

		position.y = offset_height + _target_h

func smooth_step(height_change: float) -> void:
	_target_h -= height_change
	_step_smoothing = true

func update_camera_height(delta: float, direction: int) -> void:
	# if position.y >= crouch_offset and position.y <= DEFAULT_HEIGHT:
	# 	position.y = clamp(position.y + (crouch_speed * direction) * delta, crouch_offset, DEFAULT_HEIGHT)

	if offset_height >= crouch_offset and offset_height <= DEFAULT_HEIGHT:
		offset_height = clamp(offset_height + (crouch_speed * direction) * delta, crouch_offset, DEFAULT_HEIGHT)

	# lower the camera to crouch offset
	if direction < 0:
		if position.y > crouch_offset:
			position.y = clamp(max(position.y + (crouch_speed * direction) * delta, crouch_offset), crouch_offset, DEFAULT_HEIGHT)
		# print("Camera Lowering: ", position.y)
	# raise the camera to default height
	elif direction > 0:
		if position.y < DEFAULT_HEIGHT:
			position.y = clamp(min(position.y + (crouch_speed * direction) * delta, DEFAULT_HEIGHT), crouch_offset, DEFAULT_HEIGHT)
		# print("Camera Raising: ", position.y)

func _apply_peek() -> void:
	if _cam:
		# offset is player-local; this node is pitched, so undo the pitch for the child
		var pitch_only := Basis.from_euler(Vector3(rotation.x, 0.0, 0.0))
		_cam.position = _cam_base_position + pitch_only.inverse() * _peek_offset
	rotation.z = _peek_roll
