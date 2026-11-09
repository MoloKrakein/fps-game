class_name ProneDiveComponent extends Node
## Every tunable for prone and the omni-directional dolphin dive lives here.
##
## Two ways to tweak it:
##   1. Export variables below (base values, per player / per scene).
##   2. PlayerStats (skills, perks, abilities), read live every time a value is used:
##        multipliers (default 1.0): prone_speed, dive_speed, dive_height, dive_cooldown,
##                                   dive_land_slide, dive_fall_damage, dive_wall_bounce
##        additive    (default 0.0): dive_air_control
##        flags:                     dive_unlocked, dive_from_air, dive_from_walk,
##                                   dive_no_cooldown, dive_no_fall_damage, dive_shoot
##      e.g.  stats.set_stats("dive_speed", 1.25)   stats.set_flag("dive_no_fall_damage", true)

enum WallResponse { SLIDE, STOP, BOUNCE }

signal dive_started(direction: Vector3)
signal dive_landed

@export_category("References")
@export var player: PlayerController
@export var stats: PlayerStats

@export_category("Prone")
## Crawl speed (same units as PlayerController.default_speed)
@export var prone_speed: float = 0.3
## How fast the camera drops to / rises from the prone height
@export var prone_camera_speed: float = 3.0

@export_category("Dive")
## Master switch. Skills can also unlock it with the "dive_unlocked" flag.
@export var dive_enabled: bool = true
@export_group("Allowed from")
@export var allow_from_sprint: bool = true
@export var allow_from_slide: bool = true
@export var allow_from_walk: bool = false
@export var allow_from_crouch: bool = false
@export var allow_from_air: bool = true
## Minimum horizontal speed for a walking dive (only used when allow_from_walk is on)
@export var min_walk_speed: float = 1.0
@export_group("Launch")
## Horizontal launch speed in m/s before direction multipliers
@export var dive_speed: float = 6.0
## Upward launch speed in m/s
@export var dive_height: float = 2.4
## Vertical launch is scaled by this when the dive starts in mid-air
@export_range(0.0, 1.0, 0.05) var air_dive_height_scale: float = 0.5
## Speed multiplier by dive direction relative to where the player faces
@export var speed_forward: float = 1.0
@export var speed_strafe: float = 0.85
@export var speed_backward: float = 0.7
## Fraction of the current speed along the dive direction that is added on top (sprint into dive = longer dive)
@export_range(0.0, 1.0, 0.05) var momentum_inherit: float = 0.35
## With no input: false dives where the player faces, true dives where the player is already moving
@export var use_velocity_when_idle: bool = false
@export var max_dive_speed: float = 12.0
@export_group("In the air")
@export var dive_gravity_scale: float = 1.0
## 0 = locked trajectory, 1 = full steering with WASD
@export_range(0.0, 1.0, 0.01) var air_control: float = 0.15
## How fast the dive direction turns toward the stick when air_control > 0
@export var air_steer_rate: float = 3.0
## m/s lost per second while diving
@export var air_drag: float = 0.5
## Landing is ignored for this long after launch (launch frame still reads as on floor)
@export var min_air_time: float = 0.12
## Safety: force the dive to end after this long even if the player never lands
@export var max_air_time: float = 2.5
@export var cooldown: float = 0.8
@export_group("Wall impact")
## SLIDE: keep the speed along the wall (no rebound). STOP: kill the dive. BOUNCE: reflect off the wall.
@export var wall_response: WallResponse = WallResponse.SLIDE
## Walls are detected this far ahead of the body so the dive never presses into them
@export var wall_check_margin: float = 0.08
## Share of speed lost on each wall hit (SLIDE and BOUNCE)
@export_range(0.0, 1.0, 0.05) var wall_speed_loss: float = 0.2
## Fraction of the speed that comes back off the wall (BOUNCE only)
@export_range(0.0, 1.0, 0.05) var wall_bounce_factor: float = 0.35
## Walls steeper than this count as walls, flatter slopes are ignored (0 = vertical only, 1 = everything)
@export_range(0.0, 1.0, 0.05) var wall_normal_max_y: float = 0.5
@export_group("Landing")
## Seconds the dive momentum keeps sliding you along the floor after landing
@export var landing_slide_time: float = 0.45
## Fraction of dive speed carried into that slide
@export_range(0.0, 1.0, 0.05) var landing_slide_keep: float = 0.6
## Fall damage multiplier for landings during / right after a dive (0 = none)
@export_range(0.0, 2.0, 0.05) var fall_damage_scale: float = 0.5
@export var fall_damage_grace: float = 0.35
@export_group("Feel")
@export var dive_camera_speed: float = 8.0
## Camera tilt toward the dive direction, in degrees. Flip the sign if it leans the wrong way.
@export var cam_roll_degrees: float = 6.0
## Camera pitch while diving forward, in degrees (negative dips the view)
@export var cam_pitch_degrees: float = -3.0
@export var dive_fov_boost: float = 6.0
@export var fov_punch: float = 1.0
@export var landing_shake: float = 0.15
## Added to PlayerController tiredness at launch
@export var tiredness_cost: float = 15.0
@export_group("Weapon")
## Read by the weapon controller through allows_shooting(); it is not wired into the weapon scripts yet
@export var can_shoot_while_diving: bool = true

# --- runtime -------------------------------------------------------------
var dive_velocity: Vector3 = Vector3.ZERO
var dive_direction: Vector3 = Vector3.ZERO

var _air_time: float = 0.0
var _cooldown_left: float = 0.0
var _land_velocity: Vector3 = Vector3.ZERO
var _land_left: float = 0.0
var _land_total: float = 0.0


# --- stat helpers ----------------------------------------------------------
func _mult(key: String) -> float:
	return stats.get_stat(key, 1.0) if stats else 1.0

func _add(key: String) -> float:
	return stats.get_stat(key, 0.0) if stats else 0.0

# reads the flag's value (PlayerStats.has_flag only checks that the key exists)
func _flag(key: String) -> bool:
	return stats != null and bool(stats.active_flags.get(key, false))


# --- effective values (export base + skills) --------------------------------
func is_enabled() -> bool:
	return dive_enabled or _flag("dive_unlocked")

func get_prone_speed() -> float:
	return prone_speed * _mult("prone_speed")

func get_cooldown() -> float:
	return 0.0 if _flag("dive_no_cooldown") else cooldown * _mult("dive_cooldown")

func get_air_control() -> float:
	return clampf(air_control + _add("dive_air_control"), 0.0, 1.0)

func get_fall_damage_scale() -> float:
	return 0.0 if _flag("dive_no_fall_damage") else fall_damage_scale * _mult("dive_fall_damage")

func allows_shooting() -> bool:
	return can_shoot_while_diving or _flag("dive_shoot")

func get_cooldown_left() -> float:
	return _cooldown_left


# --- rules -------------------------------------------------------------------
func can_dive() -> bool:
	if player == null or not is_enabled():
		return false
	if player.is_diving or player.is_prone or _cooldown_left > 0.0:
		return false
	if not player.is_on_floor():
		return allow_from_air or _flag("dive_from_air")
	if player.is_sliding:
		return allow_from_slide
	if player.is_sprinting:
		return allow_from_sprint
	if player.is_crouching:
		return allow_from_crouch
	var flat_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	return (allow_from_walk or _flag("dive_from_walk")) and flat_speed >= min_walk_speed


# --- dive lifecycle (called by PlayerController through the Diving state) --------
func begin_dive() -> void:
	var basis: Basis = player.global_transform.basis
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var flat_vel := Vector3(player.velocity.x, 0.0, player.velocity.z)

	var dir: Vector3
	if input.length() > 0.1:
		dir = basis * Vector3(input.x, 0.0, input.y)
	elif use_velocity_when_idle and flat_vel.length() > 0.5:
		dir = flat_vel
	else:
		dir = -basis.z
	dir.y = 0.0
	dir = dir.normalized()

	# direction relative to the player's facing: x = right, y = forward
	var local := Vector2(dir.dot(basis.x), dir.dot(-basis.z))
	var dir_mult: float
	if local.y >= 0.0:
		dir_mult = lerpf(speed_strafe, speed_forward, local.y)
	else:
		dir_mult = lerpf(speed_strafe, speed_backward, -local.y)

	var launch: float = dive_speed * _mult("dive_speed") * dir_mult
	launch += maxf(0.0, flat_vel.dot(dir)) * momentum_inherit
	launch = minf(launch, max_dive_speed * _mult("dive_speed"))

	dive_direction = dir
	dive_velocity = dir * launch
	_air_time = 0.0
	_land_left = 0.0

	var h: float = dive_height * _mult("dive_height")
	if player.is_on_floor():
		player.velocity.y = h
	else:
		player.velocity.y = maxf(player.velocity.y, h * air_dive_height_scale)

	player.increase_tiredness(tiredness_cost)
	if player.cam_effects:
		player.cam_effects.add_fov_punch(fov_punch)
	dive_started.emit(dir)

func end_dive() -> void:
	var land_mult: float = _mult("dive_land_slide")
	var keep: float = landing_slide_keep * land_mult
	var time: float = landing_slide_time * land_mult
	if player.is_on_floor() and keep > 0.0 and time > 0.0:
		_land_velocity = dive_velocity * keep
		_land_total = time
		_land_left = time
	else:
		_land_left = 0.0
	dive_velocity = Vector3.ZERO
	_cooldown_left = get_cooldown()
	if player.cam_effects and landing_shake > 0.0:
		player.cam_effects.add_screen_shake(landing_shake, 0.12)
	dive_landed.emit()

func should_land() -> bool:
	return _air_time >= min_air_time and player.is_on_floor()

func timed_out() -> bool:
	return _air_time >= max_air_time

## Horizontal velocity the controller adds on top of normal movement (dive, then landing slide).
## Called once per physics tick right before move_and_slide(): walls ahead are resolved here so the body
## is never pushed into a wall (that push is what makes the character pop back out and rebound).
func get_extra_velocity(delta: float) -> Vector3:
	if player == null:
		return Vector3.ZERO
	if player.is_diving:
		dive_velocity = _resolve_wall(dive_velocity, delta, true)
		return dive_velocity
	if _land_left > 0.0 and _land_total > 0.0:
		_land_velocity = _resolve_wall(_land_velocity, delta, false)
		return _land_velocity * (_land_left / _land_total)
	return Vector3.ZERO

func _resolve_wall(vel: Vector3, delta: float, allow_bounce: bool) -> Vector3:
	var flat := Vector3(vel.x, 0.0, vel.z)
	if flat.length() < 0.05:
		return vel
	var motion: Vector3 = flat * delta + flat.normalized() * wall_check_margin
	var result := KinematicCollision3D.new()
	if not player.test_move(player.global_transform, motion, result, 0.001, false, 4):
		return vel
	for i in result.get_collision_count():
		var n: Vector3 = result.get_normal(i)
		if absf(n.y) > wall_normal_max_y:
			continue  # floor / ramp, not a wall
		n.y = 0.0
		if n == Vector3.ZERO:
			continue
		n = n.normalized()
		if flat.dot(n) > -0.05:
			continue  # moving along or away from the wall
		var response: WallResponse = wall_response if allow_bounce else WallResponse.SLIDE
		match response:
			WallResponse.STOP:
				flat = Vector3.ZERO
			WallResponse.BOUNCE:
				var bounce_factor: float = clampf(wall_bounce_factor * _mult("dive_wall_bounce"), 0.0, 1.0)
				flat = flat.bounce(n) * bounce_factor
			_:
				flat = flat.slide(n) * (1.0 - wall_speed_loss)
		break
	return Vector3(flat.x, vel.y, flat.z)


# --- per-frame ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if player == null:
		return
	if player.is_diving:
		_tick_dive(delta)
	elif _land_left > 0.0:
		_land_left = maxf(0.0, _land_left - delta)

func _tick_dive(delta: float) -> void:
	_air_time += delta

	var control: float = get_air_control()
	if control > 0.0:
		var wish: Vector3 = _get_wish_direction()
		var speed_now: float = dive_velocity.length()
		if wish != Vector3.ZERO and speed_now > 0.001:
			var steered: Vector3 = dive_velocity.lerp(wish * speed_now, clampf(control * air_steer_rate * delta, 0.0, 1.0))
			if steered.length() > 0.001:
				dive_velocity = steered.normalized() * speed_now

	if air_drag > 0.0:
		dive_velocity = dive_velocity.move_toward(Vector3.ZERO, air_drag * delta)

func _get_wish_direction() -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var dir: Vector3 = player.global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	return dir.normalized()
