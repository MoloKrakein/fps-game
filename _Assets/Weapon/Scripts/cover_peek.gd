class_name CoverPeek extends Node
## Automatic cover peek + manual lean, tuned to this project's rig.
## Drop-in replacement for _Assets/Weapon/Scripts/cover_peek.gd (same class name, same node).
##
## Rig facts this script relies on (all verified in the repo):
##  - CameraController.set_peek(offset_in_player_space, roll) / get_base_eye_position()
##  - the Cam sits ~0.6 m IN FRONT of the CameraController pivot, and the player capsule is
##    0.5 m wide, so the eye can be inside a wall when you stand against it. All probes therefore
##    start on the body axis, not at the eye.
##  - physics layers: 2 = Player, 3 = Wall (layer 1 is unnamed world geometry)
##
## Probes use plain rays (no shape casts), so results do not depend on how the physics engine
## treats shapes that already overlap something.

@export var enabled: bool = true
## Prints a line whenever the peek mode changes.
@export var debug: bool = false

@export_group("When")
@export var require_aiming: bool = true            ## automatic peek only while aiming
@export var manual_requires_aiming: bool = true    ## false = Q/E lean also works without aiming
@export var require_grounded: bool = true
@export var lean_left_action: StringName = &"lean_left"
@export var lean_right_action: StringName = &"lean_right"

@export_group("Detection")
## What counts as cover. 5 = layer 1 (world) + layer 3 (Wall). Do NOT include layer 2 (Player).
@export_flags_3d_physics var world_mask: int = 5
## A wall must be within this distance in front of the eye to count as cover.
@export var cover_reach: float = 0.9

@export_group("Peek Over (low cover)")
@export var max_raise: float = 0.85
@export var raise_step: float = 0.05
## Keep the eye this far above the top edge of the cover.
@export var raise_clearance: float = 0.22

@export_group("Peek Around (corners)")
@export var side_distance: float = 0.72
@export var side_step: float = 0.04
## Extra lean past the edge of the opening.
@export var side_margin: float = 0.10
## If both sides need a similar lean, keep the side that is already active.
@export var side_hysteresis: float = 0.10
@export var side_roll_degrees: float = 10.0
@export var lean_raise: float = 0.12

@export_group("Feel / Safety")
## Camera clearance used by the wall-safety rays (metres). Keep small (0.1 - 0.25).
@export_range(0.02, 0.4, 0.01) var camera_clearance: float = 0.18
@export var peek_in_speed: float = 12.0
@export var peek_out_speed: float = 14.0
## Keeps the peek for a moment after the opening is lost, so it does not flicker at edges.
@export var release_delay: float = 0.15

var _player: PlayerController
var _weapon: WeaponController
var _rig: CameraController

var _target_offset := Vector3.ZERO   # player-local space
var _target_roll: float = 0.0
var _offset := Vector3.ZERO
var _roll: float = 0.0

var _last_side: float = 0.0
var _hold_timer: float = 0.0
var _held_offset := Vector3.ZERO
var _held_roll: float = 0.0
var _mode: StringName = &"none"


func _ready() -> void:
	_ensure_lean_actions()
	_warn_key_conflicts()
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		push_warning("CoverPeek: no node in group 'player'.")
		return
	_weapon = _player.weapon_controller
	_rig = _player.camera


# =========================================================================== decision
func _physics_process(delta: float) -> void:
	_target_offset = Vector3.ZERO
	_target_roll = 0.0
	if not enabled or _player == null or _weapon == null or _rig == null:
		return
	if (require_grounded and not _player.is_on_floor()) \
			or _player.is_sprinting or _player.is_sliding or _player.is_diving:
		_reset_latch()
		_set_mode(&"none")
		return

	var manual := _requested_side()
	if manual != 0.0 and (_weapon.is_aiming or not manual_requires_aiming):
		_reset_latch()
		_apply_manual_lean(manual)
		_set_mode(&"manual")
		return

	if require_aiming and not _weapon.is_aiming:
		_reset_latch()
		_last_side = 0.0
		_set_mode(&"none")
		return

	_detect_cover()
	if _target_offset != Vector3.ZERO:
		_hold_timer = release_delay
		_held_offset = _target_offset
		_held_roll = _target_roll
	elif _hold_timer > 0.0:
		_hold_timer -= delta
		_target_offset = _held_offset
		_target_roll = _held_roll
	else:
		_last_side = 0.0
	_set_mode(&"auto" if _target_offset != Vector3.ZERO else &"none")


func _process(delta: float) -> void:
	if _rig == null:
		return
	var goal_is_active := _target_offset != Vector3.ZERO
	var speed := peek_in_speed if goal_is_active else peek_out_speed
	var t := 1.0 - exp(-speed * delta)
	_offset = _offset.lerp(_target_offset, t)
	_roll = lerpf(_roll, _target_roll, t)
	_rig.set_peek(_offset, _roll)


func _reset_latch() -> void:
	_hold_timer = 0.0
	_held_offset = Vector3.ZERO
	_held_roll = 0.0


func _set_mode(mode: StringName) -> void:
	if debug and mode != _mode:
		print("CoverPeek: ", _mode, " -> ", mode, "  offset=", _target_offset)
	_mode = mode


# =========================================================================== automatic
func _detect_cover() -> void:
	var ctx := _context()
	var raise := _find_raise(ctx)
	# raise ==  0 : the view ahead is already clear, nothing to do
	# raise  >  0 : rise by that much (low cover)
	# raise  <  0 : cannot be cleared by rising (tall wall / low ceiling) -> try a corner
	if raise > 0.0:
		_apply_target(ctx, Vector3(0.0, raise, 0.0), 0.0)
	if _target_offset == Vector3.ZERO and raise != 0.0:
		_peek_around(ctx)


## Smart Cover Peeking idea: raise the eye in small steps and take the first height where the
## view ahead is clear. 0.0 = already clear, -1.0 = not possible within max_raise / headroom.
func _find_raise(ctx: Dictionary) -> float:
	var headroom := _free_distance(ctx, ctx.eye, Vector3.UP, max_raise)
	var steps := int(ceil(max_raise / raise_step))
	for i in range(steps + 1):
		var h := minf(float(i) * raise_step, max_raise)
		var p: Vector3 = ctx.eye + Vector3.UP * (h - raise_clearance)
		if _forward_clear(ctx, p):
			return h if h <= headroom + 0.001 else -1.0
	return -1.0


func _peek_around(ctx: Dictionary) -> void:
	var r := _find_side_offset(ctx, 1.0)
	var l := _find_side_offset(ctx, -1.0)
	var side := _pick_side(ctx, l, r)
	if side == 0.0:
		return
	_last_side = side
	_set_side_target(ctx, side, r if side > 0.0 else l)


## Closer opening wins. Near-ties keep the active side, then the side with more room.
## No left/right default: a perfect tie takes the closer opening.
func _pick_side(ctx: Dictionary, l: float, r: float) -> float:
	if l > 0.0 and r > 0.0:
		if absf(l - r) >= side_hysteresis:
			return -1.0 if l < r else 1.0
		if _last_side != 0.0:
			return _last_side
		var room_l := _free_distance(ctx, ctx.eye, -ctx.right, side_distance)
		var room_r := _free_distance(ctx, ctx.eye, ctx.right, side_distance)
		if not is_equal_approx(room_l, room_r):
			return -1.0 if room_l > room_r else 1.0
		return -1.0 if l <= r else 1.0
	if l > 0.0:
		return -1.0
	if r > 0.0:
		return 1.0
	return 0.0


# =========================================================================== manual
func _requested_side() -> float:
	var left: bool = Input.is_action_pressed(lean_left_action)
	var right: bool = Input.is_action_pressed(lean_right_action)
	if left == right:
		return 0.0
	return -1.0 if left else 1.0


func _apply_manual_lean(side: float) -> void:
	var ctx := _context()
	var dist := side_distance
	# Something in front: lean exactly as far as the opening needs. Otherwise a normal lean.
	if not _forward_clear(ctx, ctx.eye):
		var needed := _find_side_offset(ctx, side)
		if needed > 0.0:
			dist = needed
	_set_side_target(ctx, side, dist)


# =========================================================================== shared
func _set_side_target(ctx: Dictionary, side: float, dist: float) -> void:
	var ratio := clampf(dist / side_distance, 0.4, 1.0)
	var roll := -side * deg_to_rad(side_roll_degrees) * ratio   # leaning right rolls clockwise
	_apply_target(ctx, Vector3(side * dist, lean_raise * ratio, 0.0), roll)


## Walks sideways from the eye; the first step with a clear view ahead is the edge of the opening.
## Returns the lean distance (edge + margin) or -1.0 if there is none within the free space.
func _find_side_offset(ctx: Dictionary, side: float) -> float:
	var dir: Vector3 = ctx.right * side
	var limit := minf(side_distance, _free_distance(ctx, ctx.eye, dir, side_distance))
	var off := side_step
	while off <= limit:
		if _forward_clear(ctx, ctx.eye + dir * off):
			return minf(off + side_margin, limit)
		off += side_step
	return -1.0


## True if nothing blocks the view ahead of point p. The ray starts on the body axis (ctx.back
## behind p) so a wall the camera is already poking into still counts.
func _forward_clear(ctx: Dictionary, p: Vector3) -> bool:
	var from: Vector3 = p - ctx.forward * ctx.back
	var to: Vector3 = p + ctx.forward * (cover_reach + 0.15)
	return _ray(ctx.space, from, to).is_empty()


## Free travel distance for a camera-sized "sphere" moving from `from` along `dir` (up to dist).
## Five parallel rays approximate the sphere; this never depends on overlap behaviour.
func _free_distance(ctx: Dictionary, from: Vector3, dir: Vector3, dist: float) -> float:
	if dist <= 0.0:
		return 0.0
	var d := dir.normalized()
	var r := camera_clearance
	var p1 := d.cross(Vector3.UP)
	if p1.length() < 0.01:
		p1 = Vector3.RIGHT
	p1 = p1.normalized()
	var p2 := d.cross(p1).normalized()
	var best := dist
	for o in [Vector3.ZERO, p1 * r, -p1 * r, p2 * r, -p2 * r]:
		var start: Vector3 = from + o
		var hit := _ray(ctx.space, start, start + d * (dist + r))
		if not hit.is_empty():
			best = minf(best, (hit.position - start).dot(d) - r)
	return maxf(best, 0.0)


## Shortens the peek if the camera would end up in geometry, then stores it.
func _apply_target(ctx: Dictionary, local_offset: Vector3, roll: float) -> void:
	var world_offset: Vector3 = _player.global_transform.basis * local_offset
	var dist := world_offset.length()
	if dist < 0.001:
		return
	var fraction := clampf(_free_distance(ctx, ctx.eye, world_offset, dist) / dist, 0.0, 1.0)
	if fraction < 0.1:
		return
	_target_offset = local_offset * fraction
	_target_roll = roll * fraction


func _context() -> Dictionary:
	var basis := _player.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var eye := _rig.get_base_eye_position()
	return {
		"space": _player.get_world_3d().direct_space_state,
		"eye": eye,
		"forward": forward,
		"right": basis.x,
		# how far the eye sits in front of the body axis (about 0.6 m in this rig)
		"back": maxf((eye - _player.global_position).dot(forward), 0.0),
	}


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, world_mask, [_player.get_rid()])
	return space.intersect_ray(params)


# =========================================================================== input
func _ensure_lean_actions() -> void:
	_register_lean_action(lean_left_action, KEY_Q)
	_register_lean_action(lean_right_action, KEY_E)


func _register_lean_action(action: StringName, keycode: Key) -> void:
	if action.is_empty() or InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


## Q/E are also "action_drop" / "action_use" in project.godot; warn if a lean key is shared.
func _warn_key_conflicts() -> void:
	for lean in [lean_left_action, lean_right_action]:
		if not InputMap.has_action(lean):
			continue
		for lean_event in InputMap.action_get_events(lean):
			if not lean_event is InputEventKey:
				continue
			for other in InputMap.get_actions():
				if other == lean or String(other).begins_with("ui_"):
					continue
				for ev in InputMap.action_get_events(other):
					if ev is InputEventKey and ev.physical_keycode == lean_event.physical_keycode \
							and other != lean_left_action and other != lean_right_action:
						push_warning("CoverPeek: '%s' shares its key with '%s'." % [lean, other])
