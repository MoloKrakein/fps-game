class_name CoverPeek extends Node
## Far Cry 3 style automatic peek. While aiming next to cover the camera (and the
## weapon with it) moves up over low cover, or out around a corner of a tall
## wall, then returns when you stop aiming.
##
## Setup: add this as a Node under "Component". It uses physics queries only,
## so no RayCast nodes are needed. Requires the patched camera_controller.gd.

@export var enabled: bool = true

@export_group("When")
@export var require_aiming: bool = true
@export var require_grounded: bool = true

@export_group("Detection")
## Physics layers that count as cover / walls. Must include your level geometry.
@export_flags_3d_physics var cover_mask: int = 1
## How close a wall must be (in front of the player) to count as cover.
@export var cover_reach: float = 0.9
## The "is there cover?" ray starts this far below the eye.
@export var chest_drop: float = 0.35
## Eye ray starts a hair above the eye; if it hits, the wall is too tall to look over.
@export var eye_rise: float = 0.03

@export_group("Peek Over (low cover)")
@export var max_raise: float = 0.55
## Keep the eye this far above the top edge of the cover.
@export var raise_clearance: float = 0.18

@export_group("Peek Around (corners)")
@export var side_distance: float = 0.55
@export var side_roll_degrees: float = 7.0

@export_group("Safety / Feel")
## Camera clearance. The peek is shortened so the camera never enters geometry.
@export var camera_radius: float = 0.18
@export var peek_in_speed: float = 12.0
@export var peek_out_speed: float = 14.0

var _player: PlayerController
var _weapon: WeaponController
var _rig: CameraController
var _cam_shape := SphereShape3D.new()

var _target_offset := Vector3.ZERO   # player-local space
var _target_roll: float = 0.0
var _offset := Vector3.ZERO
var _roll: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		push_warning("CoverPeek: no node in group 'player'.")
		return
	_weapon = _player.weapon_controller
	_rig = _player.camera


func _physics_process(_delta: float) -> void:
	_target_offset = Vector3.ZERO
	_target_roll = 0.0
	if not enabled or _player == null or _weapon == null or _rig == null:
		return
	if require_aiming and not _weapon.is_aiming:
		return
	if require_grounded and not _player.is_on_floor():
		return
	if _player.is_sprinting or _player.is_sliding:
		return
	_detect_cover()


func _process(delta: float) -> void:
	if _rig == null:
		return
	var goal_is_active := _target_offset != Vector3.ZERO
	var speed := peek_in_speed if goal_is_active else peek_out_speed
	var t := 1.0 - exp(-speed * delta)
	_offset = _offset.lerp(_target_offset, t)
	_roll = lerpf(_roll, _target_roll, t)
	_rig.set_peek(_offset, _roll)


func _detect_cover() -> void:
	var space := _player.get_world_3d().direct_space_state
	var eye := _rig.get_base_eye_position()
	var basis := _player.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x

	var chest := eye - Vector3.UP * chest_drop
	var chest_hit := _ray(space, chest, chest + forward * cover_reach)
	var eye_start := eye + Vector3.UP * eye_rise
	var eye_hit := _ray(space, eye_start, eye_start + forward * (cover_reach + 0.15))

	if not chest_hit.is_empty() and eye_hit.is_empty():
		_peek_over(space, eye, forward, chest_hit)
	elif not eye_hit.is_empty():
		_peek_around(space, eye, forward, right)


func _peek_over(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, chest_hit: Dictionary) -> void:
	# Find the top edge of the cover just beyond its face.
	var p: Vector3 = chest_hit.position + forward * 0.12
	var down := _ray(space, Vector3(p.x, eye.y + max_raise, p.z), Vector3(p.x, eye.y - 1.5, p.z))

	var raise: float
	if down.is_empty():
		raise = max_raise * 0.5
	else:
		raise = (down.position.y + raise_clearance) - eye.y
	raise = clampf(raise, 0.0, max_raise)
	if raise < 0.02:
		return   # already looking over it

	_apply_target(space, eye, Vector3(0.0, raise, 0.0), 0.0)


func _peek_around(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, right: Vector3) -> void:
	var open_right := _side_is_open(space, eye, forward, right, 1.0)
	var open_left := _side_is_open(space, eye, forward, right, -1.0)
	if not open_right and not open_left:
		return

	var side := 1.0
	if open_right and open_left:
		# Both open: follow the strafe input, otherwise default to the right.
		side = -1.0 if _player.get_input_dir().x < 0.0 else 1.0
	elif open_left:
		side = -1.0

	var roll := -side * deg_to_rad(side_roll_degrees)   # leaning right rolls clockwise
	_apply_target(space, eye, Vector3(side * side_distance, 0.0, 0.0), roll)


func _side_is_open(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, right: Vector3, side: float) -> bool:
	var start := eye + right * side * side_distance
	return _ray(space, start, start + forward * (cover_reach + 0.15)).is_empty()


## Shortens the peek if the camera would end up inside geometry, then stores it.
func _apply_target(space: PhysicsDirectSpaceState3D, eye: Vector3, local_offset: Vector3, roll: float) -> void:
	var world_offset := _player.global_transform.basis * local_offset

	_cam_shape.radius = camera_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _cam_shape
	params.transform = Transform3D(Basis.IDENTITY, eye)
	params.motion = world_offset
	params.collision_mask = cover_mask
	params.exclude = [_player.get_rid()]
	var result := space.cast_motion(params)
	var fraction: float = result[0] if result.size() >= 2 else 1.0

	if fraction < 0.05:
		return
	_target_offset = local_offset * fraction
	_target_roll = roll * fraction


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, cover_mask, [_player.get_rid()])
	return space.intersect_ray(params)
