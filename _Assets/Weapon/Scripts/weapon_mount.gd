class_name WeaponMount extends Node
## Rest the weapon on a ledge / flat surface or against a wall corner while aiming
## (Modern Warfare 2019 style). While mounted you get:
##   - less camera recoil and less weapon-model recoil
##   - tighter spread
##   - almost no idle sway / look lag
##   - the weapon visibly lowered onto the surface (ledge mounts)
##   - a limited view arc around the mount direction
##
## Setup: add this as a Node under "Component" (next to CoverPeek / WeaponWallTuck).
## It finds the player and WeaponController through the "player" group.
## Needs the small patches in mount_and_peek_patches.md (WeaponController multipliers,
## animator / shooter hooks, CameraController.set_view_limits).
##
## Controls: aim near a surface, a prompt state becomes available (see `mount_available_changed`),
## press `weapon_mount` (X by default) to mount. Press it again, stop aiming, jump, sprint, change
## stance or walk away to dismount. With auto_mount on it mounts by itself after a short delay.

signal mount_available_changed(available: bool)
signal mounted_changed(is_mounted: bool)

@export var enabled: bool = true
## Prints a line on every mount / dismount / availability change.
@export var debug: bool = false

@export_group("Input")
@export var mount_action: StringName = &"weapon_mount"
@export var require_aiming: bool = true
## Mount automatically after auto_mount_delay seconds of aiming at a mountable surface.
@export var auto_mount: bool = false
@export var auto_mount_delay: float = 0.35

@export_group("Detection")
## Layers that count as surfaces. 5 = layer 1 (world) + layer 3 (Wall). Not the Player layer.
@export_flags_3d_physics var world_mask: int = 5
## How far in front of the camera a surface may be.
@export var reach: float = 0.9
## A ledge top must be between these distances BELOW the camera.
@export var min_below: float = 0.15
@export var max_below: float = 0.60
@export var max_slope_deg: float = 30.0
## The surface must stay flat for this much depth (stops mounting on thin edges / poles).
@export var min_depth: float = 0.12
@export var corner_mount: bool = true
## Corner probe height below the camera (about where the weapon is).
@export var corner_height_below: float = 0.20
## A wall edge must be within this sideways distance of the aim line.
@export var corner_max_lateral: float = 0.45
@export var corner_step: float = 0.05

@export_group("Mounted Effects (1 = no change)")
@export_range(0.0, 1.0, 0.05) var mounted_recoil: float = 0.45
@export_range(0.0, 1.0, 0.05) var mounted_spread: float = 0.5
@export_range(0.0, 1.0, 0.05) var mounted_sway: float = 0.15
@export var view_yaw_limit_deg: float = 50.0
@export var view_pitch_down_deg: float = 25.0
@export var view_pitch_up_deg: float = 30.0

@export_group("Pose")
## Distance from the camera down to the underside of the weapon in your ADS pose.
## The weapon is lowered by (surface depth - this value). Tune once per weapon style.
@export var underside_below_eye: float = 0.30
@export var max_drop: float = 0.12
@export var max_lift: float = 0.04
## Pulls the weapon slightly into the shoulder (camera-space +Z).
@export var push_back: float = 0.02
@export var pose_rotation_degrees: Vector3 = Vector3.ZERO

@export_group("Dismount / Feel")
@export var unmount_distance: float = 0.35
## The surface may be lost for this long (seconds) before the mount breaks.
@export var lost_grace: float = 0.3
@export var blend_speed: float = 10.0

var _player: PlayerController
var _weapon: WeaponController

var _mounted: bool = false
var _available: bool = false
var _cand: Dictionary = {}
var _anchor_pos := Vector3.ZERO
var _stance_key: int = 0
var _lost_time: float = 0.0
var _auto_time: float = 0.0
var _press: bool = false

var _blend: float = 0.0
var _drop: float = 0.0
var _target_drop: float = 0.0


func is_mounted() -> bool:
	return _mounted


func _ready() -> void:
	process_priority = 11   # after WeaponController (animator) and WeaponWallTuck (10)
	_register_action(mount_action, KEY_X)
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		push_warning("WeaponMount: no node in group 'player'.")
		return
	_weapon = _player.weapon_controller


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(mount_action):
		_press = true


# =========================================================================== decision
func _physics_process(delta: float) -> void:
	if not enabled or _player == null or _weapon == null:
		return

	var pressed := _press
	_press = false
	var allowed := _can_mount_now()

	if _mounted:
		_update_mounted(delta, allowed, pressed)
		return

	if not allowed:
		_set_available(false)
		_auto_time = 0.0
		return

	_cand = _probe()
	_set_available(not _cand.is_empty())
	if _cand.is_empty():
		_auto_time = 0.0
		return

	_auto_time += delta
	if pressed or (auto_mount and _auto_time >= auto_mount_delay):
		_mount()


func _can_mount_now() -> bool:
	if _weapon.current_weapon_model == null:
		return false
	if require_aiming and not _weapon.is_aiming:
		return false
	if not _player.is_on_floor():
		return false
	if _player.is_sprinting or _player.is_sliding or _player.is_diving:
		return false
	return true


func _update_mounted(delta: float, allowed: bool, pressed: bool) -> void:
	var moved := _player.global_position.distance_to(_anchor_pos) > unmount_distance
	var jumped := Input.is_action_just_pressed("move_jump")
	var stance_changed := _current_stance_key() != _stance_key
	if pressed or not allowed or moved or jumped or stance_changed:
		_unmount()
		return

	_cand = _probe()
	if _cand.is_empty():
		_lost_time += delta
		if _lost_time > lost_grace:
			_unmount()
	else:
		_lost_time = 0.0
		_target_drop = _compute_drop(_cand)


func _mount() -> void:
	_mounted = true
	_anchor_pos = _player.global_position
	_stance_key = _current_stance_key()
	_lost_time = 0.0
	_auto_time = 0.0
	_target_drop = _compute_drop(_cand)
	_set_available(false)
	_player.camera.set_view_limits(
		deg_to_rad(view_yaw_limit_deg),
		deg_to_rad(view_pitch_down_deg),
		deg_to_rad(view_pitch_up_deg))
	if debug:
		print("WeaponMount: mounted on ", _cand.get("kind", &"?"), " drop=", snappedf(_target_drop, 0.001))
	mounted_changed.emit(true)


func _unmount() -> void:
	if not _mounted:
		return
	_mounted = false
	_cand = {}
	_target_drop = 0.0
	_player.camera.clear_view_limits()
	if debug:
		print("WeaponMount: dismounted")
	mounted_changed.emit(false)


func _set_available(value: bool) -> void:
	if value == _available:
		return
	_available = value
	if debug:
		print("WeaponMount: available = ", value)
	mount_available_changed.emit(value)


func _current_stance_key() -> int:
	return int(_player.is_crouching) + 2 * int(_player.is_prone)


# =========================================================================== probes
func _probe() -> Dictionary:
	var cam: Camera3D = _weapon.camera
	var eye := cam.global_position
	var basis := _player.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space := _player.get_world_3d().direct_space_state

	var result := _probe_top(space, eye, forward)
	if result.is_empty() and corner_mount:
		result = _probe_corner(space, eye, forward, basis.x)
	return result


## Ledge / table / car hood: a flat surface a little below the camera, with an open line of sight
## over it.
func _probe_top(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3) -> Dictionary:
	# A wall at eye height is not a ledge.
	if not _ray(space, eye, eye + forward * (reach + 0.2)).is_empty():
		return {}
	var cos_slope := cos(deg_to_rad(max_slope_deg))
	var d := 0.3
	while d <= reach:
		var hit := _down(space, eye, forward, d)
		if not hit.is_empty() and _is_valid_top(hit, eye, cos_slope):
			var hit2 := _down(space, eye, forward, d + min_depth)
			if not hit2.is_empty() and hit2.normal.y >= cos_slope \
					and absf(hit2.position.y - hit.position.y) < 0.06:
				return {"kind": &"top", "anchor": hit.position, "surface_y": hit.position.y}
		d += 0.1
	return {}


func _down(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, d: float) -> Dictionary:
	var from := eye + forward * d + Vector3.UP * 0.05
	return _ray(space, from, from + Vector3.DOWN * (0.05 + max_below + 0.1))


func _is_valid_top(hit: Dictionary, eye: Vector3, cos_slope: float) -> bool:
	var below: float = eye.y - hit.position.y
	return hit.normal.y >= cos_slope and below >= min_below and below <= max_below


## A wall in front with a vertical edge close to the aim line (you are aiming along a corner).
func _probe_corner(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, right: Vector3) -> Dictionary:
	var h := eye + Vector3.DOWN * corner_height_below
	var center := _ray(space, h, h + forward * reach)
	if center.is_empty() or absf(center.normal.y) > 0.3:
		return {}

	var best := {}
	var best_off := INF
	for side in [-1.0, 1.0]:
		var last := center
		var last_dist := h.distance_to(center.position)
		var off := corner_step
		while off <= corner_max_lateral:
			var p: Vector3 = h + right * side * off
			var hit := _ray(space, p, p + forward * (reach + 0.1))
			if hit.is_empty() or p.distance_to(hit.position) - last_dist > 0.3:
				if off < best_off:
					best_off = off
					best = {"kind": &"corner", "anchor": last.position, "surface_y": last.position.y}
				break
			last = hit
			last_dist = p.distance_to(hit.position)
			off += corner_step
	return best


func _compute_drop(cand: Dictionary) -> float:
	if cand.get("kind", &"") != &"top":
		return 0.0
	var eye := _weapon.camera.global_position
	var gap := (eye.y - float(cand.surface_y)) - underside_below_eye
	return clampf(gap, -max_lift, max_drop)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, world_mask, [_player.get_rid()])
	return space.intersect_ray(params)


# =========================================================================== visuals / multipliers
func _process(delta: float) -> void:
	if _weapon == null:
		return

	var k := 1.0 - exp(-blend_speed * delta)
	_blend = lerpf(_blend, 1.0 if _mounted else 0.0, k)
	if not _mounted and _blend < 0.002:
		_blend = 0.0
	_drop = lerpf(_drop, _target_drop if _mounted else 0.0, k)

	# These three are read by the recoil / sway / spread code (see the patches file).
	_weapon.recoil_multiplier = lerpf(1.0, mounted_recoil, _blend)
	_weapon.spread_multiplier = lerpf(1.0, mounted_spread, _blend)
	_weapon.sway_multiplier = lerpf(1.0, mounted_sway, _blend)

	_apply_pose()


## Runs after the animator wrote the model's full pose (same trick as WeaponWallTuck):
## add one bounded offset, never accumulate.
func _apply_pose() -> void:
	var model: Node3D = _weapon.current_weapon_model
	var cam: Camera3D = _weapon.camera
	if model == null or cam == null or (_blend <= 0.0 and absf(_drop) < 0.0005):
		return
	# the drop is a WORLD-space distance, so convert it into the camera's space
	var drop_local: Vector3 = cam.global_transform.basis.inverse() * Vector3(0.0, -_drop, 0.0)
	model.position += drop_local + Vector3(0.0, 0.0, push_back) * _blend
	model.rotation += Vector3(
		deg_to_rad(pose_rotation_degrees.x),
		deg_to_rad(pose_rotation_degrees.y),
		deg_to_rad(pose_rotation_degrees.z)) * _blend


func _register_action(action: StringName, keycode: Key) -> void:
	if action.is_empty() or InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
