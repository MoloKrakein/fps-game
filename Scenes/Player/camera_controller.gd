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

func update_camera_rotation(input: Vector2) -> void:
	_rotation.x += input.y * (1 if is_Vertical_inverted else -1)
	_rotation.y += input.x * (1 if is_Horizontal_inverted else -1)
	_rotation.x = clamp(_rotation.x, deg_to_rad(tilt_low_limit), deg_to_rad(tilt_high_limit))

	var _player_rotation = Vector3(0.0, _rotation.y, 0.0)
	var _camera_rotation = Vector3(_rotation.x, 0.0, 0.0)

	transform.basis = Basis.from_euler(_camera_rotation)
	player_controller.update_rotation(_player_rotation)

	rotation.z = 0
	if debug:
		print("Camera Rotation: ", _rotation)

func _process(delta: float) -> void:
	if component_mouse_capture._mouse_input != Vector2.ZERO:
		update_camera_rotation(component_mouse_capture._mouse_input)

func update_camera_height(delta: float, direction: int) -> void:
	# if position.y >= crouch_offset and position.y <= DEFAULT_HEIGHT:
	# 	position.y = clamp(position.y + (crouch_speed * direction) * delta, crouch_offset, DEFAULT_HEIGHT)

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
		