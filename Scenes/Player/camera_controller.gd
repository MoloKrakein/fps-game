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
## Camera rig height while prone / diving (rig y; the eye ends up about 0.14 lower because of the Cam child)
@export var prone_offset: float = -0.5

var _rotation: Vector3
const DEFAULT_HEIGHT: float = 0.5

var _limit_active: bool = false
var _limit_yaw_center: float = 0.0
var _limit_yaw_half: float = 0.0
var _limit_pitch_min: float = 0.0
var _limit_pitch_max: float = 0.0

@export_group("Step Smoothing")
@export var step_speed: float = 8.0
var _target_h: float = 0.0
var _step_smoothing: bool = false

var offset_height: float = 0.0

@export_group("Recoil Climb")
## Seconds after the last shot before the view starts settling back
@export var climb_recover_delay: float = 0.12
## How fast the view settles back
@export var climb_recover_speed: float = 3.0
## Fraction of the climb that comes back on its own (the rest the player has to pull down)
@export_range(0.0, 1.0, 0.05) var climb_recover_ratio: float = 0.6

var _climb_pending: Vector2 = Vector2.ZERO  # radians (pitch, yaw) that can still recover
var _climb_timer: float = 0.0

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

## Peek displacement for the camera, in the rig's local space. CamEffects adds it to its own position.
func get_peek_cam_offset() -> Vector3:
	return transform.basis.inverse() * _peek_offset

## Where the camera would be with no peek applied (stable origin for cover probes).
func get_base_eye_position() -> Vector3:
	return global_position

## Locks the view to an arc around where the player is looking right now (radians).
func set_view_limits(yaw_half: float, pitch_down: float, pitch_up: float) -> void:
	_limit_active = true
	_limit_yaw_center = _rotation.y
	_limit_yaw_half = yaw_half
	_limit_pitch_min = maxf(_rotation.x - pitch_down, deg_to_rad(tilt_low_limit))
	_limit_pitch_max = minf(_rotation.x + pitch_up, deg_to_rad(tilt_high_limit))

func clear_view_limits() -> void:
	_limit_active = false

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
	if _limit_active:
		_rotation.y = _limit_yaw_center + clampf(wrapf(_rotation.y - _limit_yaw_center, -PI, PI), -_limit_yaw_half, _limit_yaw_half)
		_rotation.x = clampf(_rotation.x, _limit_pitch_min, _limit_pitch_max)

	var _player_rotation = Vector3(0.0, _rotation.y, 0.0)
	var _camera_rotation = Vector3(_rotation.x, 0.0, 0.0)

	transform.basis = Basis.from_euler(_camera_rotation)
	player_controller.update_rotation(_player_rotation)

	rotation.z = _peek_roll
	if debug:
		print("Camera Rotation: ", _rotation)

func _process(delta: float) -> void:
	var mouse_input: Vector2 = component_mouse_capture._mouse_input
	if mouse_input != Vector2.ZERO:
		_cancel_climb_with_input(mouse_input)
		update_camera_rotation(mouse_input)
	_update_climb_recovery(delta)
	
	if _step_smoothing:
		_target_h = lerp(_target_h, 0.0, step_speed * delta)
		if abs(_target_h) < 0.01:
			_target_h = 0.0
			_step_smoothing = false

	position.y = offset_height + _target_h
	_apply_peek()

func smooth_step(height_change: float) -> void:
	_target_h -= height_change
	_step_smoothing = true

## Moves the camera rig toward a target height. Used by every stance (stand / crouch / prone / dive).
func move_camera_to(delta: float, target_height: float, speed: float) -> void:
	offset_height = move_toward(offset_height, target_height, speed * delta)
	position.y = move_toward(position.y, target_height, speed * delta)

# direction > 0 raises to standing height, direction < 0 lowers to crouch height.
# Works from any current height, so coming up out of prone lands on the crouch height instead of sticking.
func update_camera_height(delta: float, direction: int) -> void:
	var speed: float = crouch_speed * absf(direction)
	if direction > 0:
		move_camera_to(delta, DEFAULT_HEIGHT, speed)
	elif direction < 0:
		move_camera_to(delta, crouch_offset, speed)

func _apply_peek() -> void:
	if _cam:
		# CamEffects re-adds the offset to the child; this node only keeps the roll.
		_cam.position = _cam_base_position
	rotation.z = _peek_roll


## Real aim climb from weapon recoil (radians). Called by CamEffects.add_weapon_recoil.
func add_recoil_climb(pitch_rad: float, yaw_rad: float) -> void:
	_rotation.x = clampf(_rotation.x + pitch_rad, deg_to_rad(tilt_low_limit), deg_to_rad(tilt_high_limit))
	_rotation.y += yaw_rad
	_climb_pending += Vector2(pitch_rad, yaw_rad) * climb_recover_ratio
	_climb_timer = climb_recover_delay
	update_camera_rotation(Vector2.ZERO)  # re-applies the rotation without any mouse input


# If the player pulls against the climb, that counts as compensation, so it must not recover again.
func _cancel_climb_with_input(input: Vector2) -> void:
	var dx: float = input.y * (1.0 if is_Vertical_inverted else -1.0)
	var dy: float = input.x * (1.0 if is_Horizontal_inverted else -1.0)
	if signf(dx) == -signf(_climb_pending.x):
		_climb_pending.x = move_toward(_climb_pending.x, 0.0, absf(dx))
	if signf(dy) == -signf(_climb_pending.y):
		_climb_pending.y = move_toward(_climb_pending.y, 0.0, absf(dy))


func _update_climb_recovery(delta: float) -> void:
	if _climb_timer > 0.0:
		_climb_timer -= delta
		return
	if _climb_pending == Vector2.ZERO:
		return
	var step: Vector2 = _climb_pending * minf(1.0, climb_recover_speed * delta)
	_climb_pending -= step
	_rotation.x -= step.x
	_rotation.y -= step.y
	update_camera_rotation(Vector2.ZERO)
	if _climb_pending.length() < 0.0005:
		_climb_pending = Vector2.ZERO