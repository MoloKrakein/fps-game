class_name WeaponWallTuck extends Node
## Pushes the weapon back / lowers the muzzle when the barrel gets close to a
## wall, and (optionally) blocks firing while it is jammed against it.
##
## Setup: add this as a Node under "Component". No other wiring needed.
## It finds the player and the WeaponController through the "player" group.

@export var enabled: bool = true

@export_group("Detection")
## Physics layers that count as "wall". Must include your level geometry layer.
@export_flags_3d_physics var world_mask: int = 1
## Thickness of the probe. Bigger = tucks a little earlier near edges.
@export var probe_radius: float = 0.1
## Used when the weapon model has no muzzle_socket assigned.
@export var fallback_length: float = 0.9
## Extra reach beyond the muzzle so the tuck starts just before contact.
@export var length_margin: float = 0.08
## > 0 forces a weapon length (metres from the camera) and skips auto-measure.
@export var length_override: float = 0.0

@export_group("Pose (camera space: +Z = toward the player)")
@export var tuck_position: Vector3 = Vector3(0.0, -0.04, 0.22)
## Degrees. Negative X points the muzzle down; Z rolls it sideways.
@export var tuck_rotation_degrees: Vector3 = Vector3(-22.0, 12.0, 18.0)
## How much of the tuck stays while aiming (0 = none, 1 = full).
@export_range(0.0, 1.0) var ads_strength: float = 0.35

@export_group("Feel")
@export var tuck_in_speed: float = 16.0
@export var tuck_out_speed: float = 9.0
## 1 = linear, >1 = barely moves until the wall is really close.
@export_range(0.5, 3.0) var response_curve: float = 1.2

@export_group("Firing")
@export var block_fire: bool = true
## Tuck amount (0..1) above which the weapon cannot fire.
@export_range(0.0, 1.0) var block_fire_threshold: float = 0.6

var amount: float = 0.0   # current smoothed tuck, 0..1

var _player: PlayerController
var _weapon: WeaponController
var _cam: Node3D
var _probe := SphereShape3D.new()
var _target: float = 0.0
var _aim_scale: float = 1.0


func _ready() -> void:
	process_priority = 10   # run after WeaponController, so we modify the final pose
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		push_warning("WeaponWallTuck: no node in group 'player'.")
		return
	_weapon = _player.weapon_controller
	_cam = _player.cam_effects
	if _weapon != null:
		_weapon.wall_tuck = self


func is_blocked() -> bool:
	return enabled and block_fire and amount >= block_fire_threshold


func _physics_process(_delta: float) -> void:
	if not enabled or _weapon == null or _cam == null or _weapon.current_weapon_model == null:
		_target = 0.0
		return

	var length := _get_weapon_length(_weapon.current_weapon_model) + length_margin
	if length <= 0.01:
		_target = 0.0
		return

	_probe.radius = probe_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe
	params.transform = Transform3D(Basis.IDENTITY, _cam.global_position)
	params.motion = -_cam.global_basis.z * length
	params.collision_mask = world_mask
	params.exclude = [_player.get_rid()]

	# [safe_fraction, unsafe_fraction]; [1,1] = nothing hit, [0,0] = already inside something
	var result := _player.get_world_3d().direct_space_state.cast_motion(params)
	var safe_fraction: float = result[0] if result.size() >= 2 else 1.0
	_target = pow(clampf(1.0 - safe_fraction, 0.0, 1.0), response_curve)


func _process(delta: float) -> void:
	if _weapon == null or _weapon.current_weapon_model == null:
		amount = 0.0
		return

	var model: Node3D = _weapon.current_weapon_model
	_aim_scale = lerpf(_aim_scale, ads_strength if _weapon.is_aiming else 1.0, 1.0 - exp(-12.0 * delta))

	var goal := _target * _aim_scale if enabled else 0.0
	var speed := tuck_in_speed if goal > amount else tuck_out_speed
	amount = lerpf(amount, goal, 1.0 - exp(-speed * delta))
	if amount < 0.0005:
		return

	# Additive on top of whatever the animator just wrote this frame.
	model.position += tuck_position * amount
	var rot := Vector3(
		deg_to_rad(tuck_rotation_degrees.x),
		deg_to_rad(tuck_rotation_degrees.y),
		deg_to_rad(tuck_rotation_degrees.z)) * amount
	model.basis = Basis.from_euler(rot) * model.basis   # rotates about the model's own origin


## Distance from the camera to the muzzle at the weapon's rest pose, measured
## from the model itself so it adapts to every weapon automatically and is not
## affected by sway, recoil or the tuck itself.
func _get_weapon_length(model: Node3D) -> float:
	if length_override > 0.0:
		return length_override
	var muzzle: Node3D = (model as WeaponModel).muzzle_socket if model is WeaponModel else null
	if muzzle == null:
		return fallback_length

	var muzzle_local: Vector3 = model.to_local(muzzle.global_position)
	var rest_basis := Basis.from_euler(_weapon.weapon_start_rotation).scaled(model.scale)
	var muzzle_in_cam: Vector3 = _weapon.weapon_start_position + rest_basis * muzzle_local
	return maxf(-muzzle_in_cam.z, 0.0)
