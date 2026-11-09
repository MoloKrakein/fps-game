class_name WeaponProceduralAnimator extends RefCounted
## Procedural motion layered on top of the weapon model's stance position:
## idle sway, look sway, strafe tilt, walk bob, vertical lag, crouch and recoil.
##
## Tuning values are still the @exports on WeaponController, so your existing
## inspector settings keep working. Only the per-frame spring state lives here.


## Small spring helper that replaces the old `_x` / `_x_velocity` variable pairs.
class SpringValue:
	var value: float = 0.0
	var velocity: float = 0.0

	## Advances the spring toward `target`. `limit` clamps the value (not the velocity).
	func step(target: float, delta: float, stiffness: float, damping: float, limit: float = INF) -> float:
		var result: Vector2 = SpringUtil.apply_stable(value, velocity, target, delta, stiffness, damping)
		value = clampf(result.x, -limit, limit)
		velocity = result.y
		return value

	## Tune by natural frequency (rad/s) and damping ratio instead of stiffness/damping.
	## zeta < 1 overshoots and settles (heavy feel), zeta > 1 just drags.
	func step_zeta(target: float, delta: float, omega: float, zeta: float, limit: float = INF) -> float:
		return step(target, delta, omega * omega, 2.0 * zeta * omega, limit)

	func reset() -> void:
		value = 0.0
		velocity = 0.0


## A single impulse-driven spring keeps recoil responsive without a second
## high-frequency "snap" spring fighting the recovery spring.
class RecoilSpring:
	var value: float = 0.0
	var velocity: float = 0.0

	func kick(amount: float, impulse_scale: float = 1.0) -> void:
		velocity += amount * impulse_scale

	func step(delta: float, stiffness: float, damping: float, limit: float = INF) -> float:
		var result: Vector2 = SpringUtil.apply_stable(value, velocity, 0.0, delta, stiffness, damping)
		value = clampf(result.x, -limit, limit)
		velocity = result.y
		return value

	func reset() -> void:
		value = 0.0
		velocity = 0.0


var ctrl: WeaponController

# Shortcuts into the controller so the maths below stays readable.
var weapon: Weapon:
	get:
		return ctrl.current_weapon
var player: PlayerController:
	get:
		return ctrl.player
var camera: CamEffects:
	get:
		return ctrl.camera
var is_aiming: bool:
	get:
		return ctrl.is_aiming
var is_reloading: bool:
	get:
		return ctrl.is_reloading

# Spring state
var _idle_time: float = 0.0
var _idle_x := SpringValue.new()
var _idle_y := SpringValue.new()
var _idle_z := SpringValue.new()
var _idle_rot_x := SpringValue.new()
var _bob_x := SpringValue.new()
var _bob_y := SpringValue.new()
var _strafe_tilt := SpringValue.new()
var _vlag_y := SpringValue.new()
var _look_root_x := SpringValue.new()
var _look_root_y := SpringValue.new()
var _look_tip_x := SpringValue.new()
var _look_tip_y := SpringValue.new()
var _look_rot_x := SpringValue.new()
var _look_rot_y := SpringValue.new()
var _look_rot_z := SpringValue.new()
var _recoil_back: RecoilSpring = RecoilSpring.new()
var _recoil_pitch: RecoilSpring = RecoilSpring.new()
var _recoil_yaw: RecoilSpring = RecoilSpring.new()
var _last_yaw_dir: float = 0.0

# Hand markers on the weapon model (GripHand, SupportHand, optional RecoilPivot), cached per model.
var _markers_model: WeaponModel = null
var _has_grip: bool = false
var _has_support: bool = false
var _has_pivot: bool = false
var _grip_local: Vector3 = Vector3.ZERO
var _support_local: Vector3 = Vector3.ZERO
var _pivot_local: Vector3 = Vector3.ZERO
var _recoil_offset_pos: Vector3 = Vector3.ZERO
var _recoil_offset_rot: Vector3 = Vector3.ZERO

# Other per-frame state
var _previous_look_dir: Vector3 = Vector3.ZERO
var _look_rate: Vector2 = Vector2.ZERO # x = pitch rate, y = yaw rate, rad/s, smoothed
var _look_seeded: bool = false
var _inertia_x := SpringValue.new()
var _inertia_z := SpringValue.new()
var _prev_planar_velocity: Vector3 = Vector3.ZERO
var _inertia_seeded: bool = false
var _prev_camera_y: float = 0.0
var _vlag_seeded: bool = false
var _crouch_pos: Vector3 = Vector3.ZERO
var _crouch_rot: Vector3 = Vector3.ZERO
var _sprint_pos: Vector3 = Vector3.ZERO
var _sprint_rot: Vector3 = Vector3.ZERO
var _sprint_motion_pos: Vector3 = Vector3.ZERO
var _sprint_motion_rot: Vector3 = Vector3.ZERO
var _sprint_motion_weight: float = 0.0
var _sprint_motion_time: float = 0.0
var _sprint_animation_active: bool = false
var _2d_ammo_visible: bool = false


func _init(controller: WeaponController) -> void:
	ctrl = controller


## Call every frame. Writes the final position/rotation onto the weapon model.
func apply_offsets(delta: float) -> void:
	var model: WeaponModel = ctrl.current_weapon_model
	if model == null:
		return

	var idle_offset: Vector3 = _update_idle_sway(delta)
	var look_offset: Vector3 = _update_look_sway(delta)
	var look_rotation: Vector3 = _update_look_rotation(delta)
	var strafe_tilt: float = _update_strafe_tilt(delta)
	var bob_offset: Vector3 = _update_weapon_bob(delta)
	var vertical_lag_offset: Vector3 = _update_vertical_lag(delta)
	var inertia_offset: Vector3 = _update_inertia(delta)
	_update_crouch_stance(delta)
	_update_sprint_stance(delta)

	if ctrl.enable_recoil and not _is_recoil_suppressed():
		_update_recoil(delta)
	else:
		# Clear accumulated kick while sprinting so firing cannot throw the
		# weapon out of the tactical-sprint pose or leave it offset afterward.
		reset_recoil()
		_recoil_offset_pos = Vector3.ZERO
		_recoil_offset_rot = Vector3.ZERO

	_ensure_markers(model)
	var full_rotation: Vector3 = ctrl.current_stance_rot + Vector3(_idle_rot_x.value, 0.0, strafe_tilt) + look_rotation + _crouch_rot + _sprint_rot + _sprint_motion_rot + _recoil_offset_rot
	var pivot_shift: Vector3 = _recoil_pivot_shift(model, full_rotation)

	model.position = ctrl.current_stance_pos + idle_offset + look_offset + bob_offset + _crouch_pos + _sprint_pos + _sprint_motion_pos + _recoil_offset_pos + vertical_lag_offset + inertia_offset + pivot_shift
	model.rotation = full_rotation


func reset_bob() -> void:
	_bob_x.reset()
	_bob_y.reset()


func reset_motion_state() -> void:
	_idle_time = 0.0
	_idle_x.reset()
	_idle_y.reset()
	_idle_z.reset()
	_idle_rot_x.reset()
	_bob_x.reset()
	_bob_y.reset()
	_strafe_tilt.reset()
	_vlag_y.reset()
	_look_root_x.reset()
	_look_root_y.reset()
	_look_tip_x.reset()
	_look_tip_y.reset()
	_look_rot_x.reset()
	_look_rot_y.reset()
	_look_rot_z.reset()
	_recoil_offset_pos = Vector3.ZERO
	_recoil_offset_rot = Vector3.ZERO
	_previous_look_dir = Vector3.ZERO
	_look_rate = Vector2.ZERO
	_look_seeded = false
	_inertia_x.reset()
	_inertia_z.reset()
	_prev_planar_velocity = Vector3.ZERO
	_inertia_seeded = false
	_prev_camera_y = 0.0
	_vlag_seeded = false
	_crouch_pos = Vector3.ZERO
	_crouch_rot = Vector3.ZERO
	_sprint_pos = Vector3.ZERO
	_sprint_rot = Vector3.ZERO
	_sprint_motion_pos = Vector3.ZERO
	_sprint_motion_rot = Vector3.ZERO
	_sprint_motion_weight = 0.0
	_sprint_motion_time = 0.0
	_sprint_animation_active = false
	reset_recoil()


func reset_recoil() -> void:
	_recoil_back.reset()
	_recoil_pitch.reset()
	_recoil_yaw.reset()
	_last_yaw_dir = 0.0
	_recoil_offset_pos = Vector3.ZERO
	_recoil_offset_rot = Vector3.ZERO


#region Recoil
## Kicks the weapon model. Call once per shot.
func add_recoil() -> void:
	if not ctrl.enable_recoil or ctrl.current_weapon_model == null or _is_recoil_suppressed():
		return

	var two_handed: bool = _is_two_handed_weapon()
	var running_aim_multiplier: float = _running_aim_multiplier(weapon.running_aim_recoil_multiplier)
	# Up to +40% recoil when fully exhausted.
	var strength: float = 1.0 + _tiredness_factor() * 0.4
	if is_aiming:
		strength *= ctrl.recoil_ads_visual_multiplier
	strength *= running_aim_multiplier

	# A support hand keeps a long gun aligned with the bore. It still pushes
	# the stock into the shoulder, but produces less muzzle climb and wobble.
	var kick_multiplier: float = 1.12 if two_handed else 1.0
	var rise_multiplier: float = (0.62 if two_handed else 1.0) * _hand_leverage_multiplier()
	var lateral_multiplier: float = 0.35 if two_handed else 1.0
	var rise: float = deg_to_rad(weapon.recoil_weapon_rise) * rise_multiplier * strength

	# Kick velocity rather than position. This gives a soft acceleration into
	# recoil followed by one continuous recovery instead of a rigid snap.
	_recoil_back.kick(weapon.recoil_weapon_kick * kick_multiplier * strength, 42.0)
	_recoil_pitch.kick(rise, 30.0)
	_last_yaw_dir = lerpf(randf_range(-1.0, 1.0), _last_yaw_dir, ctrl.recoil_lateral_persistence)
	var yaw_range: float = weapon.recoil_weapon_rise * 0.5 * strength
	_recoil_yaw.kick(deg_to_rad(_last_yaw_dir * yaw_range) * lateral_multiplier, 24.0)


func _update_recoil(delta: float) -> void:
	var two_handed: bool = _is_two_handed_weapon()
	var running_aim_multiplier: float = _running_aim_multiplier(weapon.running_aim_recoil_multiplier)
	var stiffness: float = ctrl.recoil_model_stillness * (0.65 if two_handed else 0.55)
	var damping: float = ctrl.recoil_model_damping * (1.6 if two_handed else 1.45)
	var max_angle: float = ctrl.recoil_model_max_angle
	var pitch_max: float = ctrl.recoil_pitch_max
	pitch_max *= running_aim_multiplier
	max_angle *= running_aim_multiplier
	var back: float = _recoil_back.step(delta, stiffness, damping, max_angle)
	var pitch: float = _recoil_pitch.step(delta, stiffness, damping, pitch_max)
	var yaw: float = _recoil_yaw.step(delta, stiffness, damping, max_angle)
	var roll: float = -yaw * ctrl.recoil_roll_coupling * (0.55 if two_handed else 1.0)
	_recoil_offset_pos = Vector3(0.0, back * ctrl.recoil_vertical_lift, back)
	_recoil_offset_rot = Vector3(pitch, yaw, roll)


func _is_recoil_suppressed() -> bool:
	return ctrl.disable_recoil_during_sprint and _is_sprint_animation_active()


func _running_aim_multiplier(base_multiplier: float) -> float:
	if player == null or not player.is_sprinting or not is_aiming:
		return 1.0
	return maxf(base_multiplier, 1.0)
#endregion


#region Sway, tilt, bob, lag, crouch
func _update_idle_sway(delta: float) -> Vector3:
	if not ctrl.idle_sway_enabled:
		return Vector3.ZERO

	var tiredness: float = _tiredness_factor()
	var two_handed: bool = _is_two_handed_weapon()
	var w: float = _weight()

	# Tired players breathe faster (2.5x at full tiredness). Heavier guns sway slower and wider.
	var frequency: float = ctrl.idle_sway_frequency * (1.0 + tiredness * 1.5) * lerpf(1.15, 0.85, w)
	var amplitude: Vector2 = ctrl.idle_sway_amplitude * lerpf(0.8, 1.2, w)
	var stiffness: float = ctrl.idle_sway_stiffness
	var damping: float = ctrl.idle_sway_damping

	if two_handed:
		# A rifle follows the torso and support hand instead of freely
		# swinging from the firing hand.
		frequency *= 0.8
		amplitude *= 0.68
		stiffness *= 0.82
		damping *= 1.1
	_idle_time += delta * frequency

	if is_aiming:
		amplitude *= ctrl.aim_sway_multiplier
	amplitude *= _running_aim_multiplier(weapon.running_aim_sway_multiplier)
	# Tiredness is applied AFTER the aim multiplier so aiming stays shaky when exhausted.
	amplitude *= 1.0 + tiredness * 2.0

	var tremor_intensity: float = amplitude.y * (0.15 + tiredness * 0.35)
	var micro_tremor: float = sin(_idle_time * 15.0) * tremor_intensity

	var target_x: float = 0.0
	var target_y: float = 0.0
	var target_z: float = 0.0
	var target_rot_x: float = 0.0

	# Breathing cycle, only while standing still (or aiming): figure-8 in x/y,
	# plus a slow push/pull in z and a small pitch so the whole gun rides the breath.
	if _planar_speed() < 0.1 or is_aiming:
		target_x = sin(_idle_time) * amplitude.x
		target_y = cos(_idle_time * 2.0) * amplitude.y + micro_tremor
		target_z = cos(_idle_time) * amplitude.y * 0.8
		target_rot_x = target_y * ctrl.idle_sway_rotation_multiplier * 0.3

	# Exhausted up/down tilt, driven by the vertical breathing wave.
	var threshold: float = ctrl.idle_sway_tremor_threshold
	if tiredness > threshold:
		# Maps threshold..1.0 tiredness onto a 0..1 intensity.
		var exhaust_intensity: float = (tiredness - threshold) * (1.0 / (1.0 - threshold))
		target_rot_x += target_y * ctrl.idle_sway_rotation_multiplier * exhaust_intensity

	var sp: Vector2 = _weighted_spring(stiffness, damping)
	var x: float = _idle_x.step(target_x, delta, sp.x, sp.y)
	var y: float = _idle_y.step(target_y, delta, sp.x, sp.y)
	var z: float = _idle_z.step(target_z, delta, sp.x, sp.y)
	_idle_rot_x.step(target_rot_x, delta, sp.x, sp.y)
	return Vector3(x, y, z)


## Updates the smoothed camera turn rate (rad/s). Called once per frame from
## _update_look_sway; _update_look_rotation reuses the result.
func _update_look_rate(delta: float) -> void:
	var camera_rotation: Vector3 = camera.global_rotation
	if not _look_seeded:
		_previous_look_dir = camera_rotation
		_look_rate = Vector2.ZERO
		_look_seeded = true
		return

	var dt: float = maxf(delta, 0.0001)
	var raw := Vector2(
		wrapf(camera_rotation.x - _previous_look_dir.x, -PI, PI),
		wrapf(camera_rotation.y - _previous_look_dir.y, -PI, PI)
	) / dt
	_previous_look_dir = camera_rotation

	# look_lag_rot_max is degrees per frame at 60 FPS, converted to a rate so it no longer depends on FPS.
	var max_rate: float = deg_to_rad(ctrl.look_lag_rot_max) * 60.0
	raw.x = clampf(raw.x, -max_rate, max_rate)
	raw.y = clampf(raw.y, -max_rate, max_rate)

	var tau: float = maxf(ctrl.look_lag_divisor / 60.0, 0.001)
	_look_rate = _look_rate.lerp(raw, 1.0 - exp(-dt / tau))


func _fast_turn_strength() -> float:
	var threshold_deg: float = maxf(ctrl.look_lag_fast_turn_threshold_deg, 0.1)
	var turn_speed_deg: float = rad_to_deg(_look_rate.length())
	return smoothstep(0.0, 1.0, clampf((turn_speed_deg - threshold_deg) / threshold_deg, 0.0, 1.0))


func _update_look_sway(delta: float) -> Vector3:
	if not ctrl.look_sway_enabled or not camera:
		return Vector3.ZERO

	_update_look_rate(delta)
	var fast_turn_strength: float = _fast_turn_strength()

	# Tuned at 60 FPS, where one frame of rotation was the old unit.
	var rate60: Vector2 = _look_rate / 60.0
	var running_aim_multiplier: float = _running_aim_multiplier(weapon.running_aim_lag_multiplier)
	var stance_weight: float = ctrl.look_lag_ads_weight if is_aiming else ctrl.look_lag_hipfire_weight
	var fast_turn_boost: float = 1.0 + fast_turn_strength * ctrl.look_lag_fast_turn_boost
	var weight_scale: float = lerpf(0.8, 1.3, _weight())
	var scale: float = ctrl.look_lag_pos_scale * running_aim_multiplier * stance_weight * fast_turn_boost * weight_scale

	# Slightly underdamped: a fast flick overshoots a little and settles, which reads as mass.
	var omega: float = _omega(13.0, 7.5)
	var zeta: float = _zeta(0.85, 0.55)
	var root_x: float = _look_root_x.step_zeta(rate60.y * scale, delta, omega, zeta)
	var root_y: float = _look_root_y.step_zeta(rate60.x * scale, delta, omega, zeta)
	var tip_lag: float = lerpf(ctrl.look_lag_tip_follow_slow, ctrl.look_lag_tip_follow_fast, fast_turn_strength)
	var tip_x: float = _look_tip_x.step_zeta(root_x * tip_lag, delta, omega * 0.8, zeta * 0.85)
	var tip_y: float = _look_tip_y.step_zeta(root_y * tip_lag, delta, omega * 0.8, zeta * 0.85)

	# The chassis reacts immediately, but the muzzle / front of the gun keeps
	# swinging behind it like a weighted object.
	return Vector3(root_x - tip_x, root_y - tip_y, 0.0)


func _update_look_rotation(delta: float) -> Vector3:
	if not ctrl.look_sway_enabled or not camera:
		return Vector3.ZERO

	var fast_turn_strength: float = _fast_turn_strength()
	var rate60: Vector2 = _look_rate / 60.0
	var stance_weight: float = ctrl.look_lag_ads_weight if is_aiming else ctrl.look_lag_hipfire_weight
	var w: float = _weight()
	var weight_scale: float = lerpf(0.8, 1.3, w)

	var target_pitch: float = rate60.x * 0.55 * stance_weight * (1.0 + fast_turn_strength * 0.85) * weight_scale
	var target_yaw: float = rate60.y * 0.45 * stance_weight * (1.0 + fast_turn_strength * 0.85) * weight_scale
	var target_roll: float = -rate60.y * 0.30 * stance_weight * (1.0 + fast_turn_strength * 1.1) * weight_scale

	var omega: float = _omega(12.0, 7.0)
	var zeta: float = _zeta(0.8, 0.5)
	var pitch: float = _look_rot_x.step_zeta(target_pitch, delta, omega, zeta)
	var yaw: float = _look_rot_y.step_zeta(target_yaw, delta, omega, zeta)
	var roll: float = _look_rot_z.step_zeta(target_roll, delta, omega * 0.9, zeta * 0.9)

	var max_rotation: float = deg_to_rad(lerpf(6.0, 9.0, w))
	return Vector3(
		clampf(pitch, -max_rotation, max_rotation),
		clampf(yaw, -max_rotation, max_rotation),
		clampf(roll, -max_rotation, max_rotation)
	)


func _update_strafe_tilt(delta: float) -> float:
	if not ctrl.strafe_tilt_enabled or not player or not camera:
		return 0.0

	var local_vel: Vector3 = camera.global_transform.basis.inverse() * player.velocity
	var x_z: Vector2 = Vector2(local_vel.x, local_vel.z)
	var x_z_speed: float = x_z.length()
	var lateral_fraction: float = absf(x_z.x) / x_z_speed if x_z_speed > 0.1 else 0.0

	var tilt_multiplier: float = weapon.aim_tilt_amount if is_aiming else 1.0
	tilt_multiplier *= _running_aim_multiplier(weapon.running_aim_tilt_multiplier)
	tilt_multiplier *= 1.0 + _tiredness_factor() * 2.0

	var target_tilt: float = clampf(
		local_vel.x * lateral_fraction * ctrl.strafe_tilt_scale * tilt_multiplier,
		-ctrl.strafe_tilt_max,
		ctrl.strafe_tilt_max
	)
	var sp: Vector2 = _weighted_spring(ctrl.strafe_tilt_stiffness, ctrl.strafe_tilt_damping)
	return _strafe_tilt.step(target_tilt, delta, sp.x, sp.y)


func _update_weapon_bob(delta: float) -> Vector3:
	if not ctrl.weapon_bob_enabled or not player or not camera:
		return Vector3.ZERO

	var phase: float = camera.get_bob_phase()
	var speed: float = _planar_speed()
	var bob_multiplier: float = 0.08 if is_aiming else 1.0
	bob_multiplier *= _running_aim_multiplier(weapon.running_aim_bob_multiplier)
	var tiredness: float = _tiredness_factor()

	var target_x: float = 0.0
	var target_y: float = 0.0

	if speed > 0.1 and not player.is_sliding:
		var speed_factor: float = clampf(speed / ctrl.bob_max_speed, 0.0, 1.0)
		var angle: float = phase * TAU

		# Heavier footsteps when tired: up to 50% wider and 80% higher at full fatigue.
		var amp_x: float = ctrl.bob_amplitude.x * (1.0 + tiredness * 0.5)
		var amp_y: float = ctrl.bob_amplitude.y * (1.0 + tiredness * 0.8)

		# The "limp": a half-speed wave that throws the gun slightly off balance when tired.
		var limp_wobble: float = sin(angle * 0.5) * (ctrl.bob_amplitude.x * tiredness * 0.6)

		target_x = (sin(angle) * amp_x * speed_factor * bob_multiplier) + limp_wobble
		target_y = -absf(sin(angle)) * amp_y * speed_factor * bob_multiplier

	var sp: Vector2 = _weighted_spring(ctrl.bob_stiffness, ctrl.bob_damping)
	var x: float = _bob_x.step(target_x, delta, sp.x, sp.y)
	var y: float = _bob_y.step(target_y, delta, sp.x, sp.y)
	return Vector3(x, y, 0.0)


func _update_vertical_lag(delta: float) -> Vector3:
	if not ctrl.vertical_lag_enabled or not camera or ctrl.cam_rig == null:
		return Vector3.ZERO

	var camera_y: float = ctrl.cam_rig.global_position.y

	if not _vlag_seeded:
		# This spring stores a local weapon offset, not the camera's world height.
		_vlag_y.value = 0.0
		_prev_camera_y = camera_y
		_vlag_seeded = true
		return Vector3.ZERO

	var cam_vel_y: float = (camera_y - _prev_camera_y) / maxf(delta, 0.0001)
	_prev_camera_y = camera_y

	# Clamp the VELOCITY with vertical_lag_vel_max (was wrongly using the offset limit).
	cam_vel_y = clampf(cam_vel_y, -ctrl.vertical_lag_vel_max, ctrl.vertical_lag_vel_max)
	if absf(cam_vel_y) < ctrl.vertical_lag_deadzone:
		cam_vel_y = 0.0

	var lag_multiplier: float = weapon.aim_lag_amount if is_aiming else 1.0
	lag_multiplier *= _running_aim_multiplier(weapon.running_aim_lag_multiplier)
	lag_multiplier *= lerpf(0.8, 1.5, _weight())
	var target_y: float = -cam_vel_y * ctrl.vertical_lag_velocity_scale * weapon.vertical_lag_multiplier * lag_multiplier
	var sp: Vector2 = _weighted_spring(ctrl.vertical_lag_stiffness, ctrl.vertical_lag_damping)
	var y: float = _vlag_y.step(target_y, delta, sp.x, sp.y, ctrl.vertical_lag_max)
	return Vector3(0.0, y, 0.0)


## The weapon lags against planar acceleration: pushed back when you start running,
## forward when you stop, sideways on strafe reversals.
func _update_inertia(delta: float) -> Vector3:
	if not ctrl.inertia_lag_enabled or player == null or camera == null:
		return Vector3.ZERO

	var vel: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if not _inertia_seeded:
		_prev_planar_velocity = vel
		_inertia_seeded = true
		return Vector3.ZERO

	var accel: Vector3 = ((vel - _prev_planar_velocity) / maxf(delta, 0.0001)).limit_length(60.0)
	_prev_planar_velocity = vel
	var local: Vector3 = camera.global_transform.basis.inverse() * accel

	var k: float = ctrl.inertia_lag_scale * lerpf(0.8, 1.6, _weight())
	if is_aiming:
		k *= 0.35
	k *= _running_aim_multiplier(weapon.running_aim_lag_multiplier)

	var omega: float = _omega(12.0, 7.0)
	var zeta: float = _zeta(0.75, 0.5)
	var x: float = _inertia_x.step_zeta(clampf(-local.x * k, -ctrl.inertia_lag_max_x, ctrl.inertia_lag_max_x), delta, omega, zeta)
	var z: float = _inertia_z.step_zeta(clampf(-local.z * k, -ctrl.inertia_lag_max_z, ctrl.inertia_lag_max_z), delta, omega, zeta)
	return Vector3(x, 0.0, z)


func _update_crouch_stance(delta: float) -> void:
	var target_pos: Vector3 = Vector3.ZERO
	var target_rot: Vector3 = Vector3.ZERO
	if player != null and player.is_crouching and not is_aiming:
		target_pos = ctrl.crouch_pos_offset
		target_rot = ctrl.crouch_rot_offset

	var blend: float = ctrl.crouch_transition_speed * delta
	_crouch_pos = _crouch_pos.lerp(target_pos, blend)
	_crouch_rot = _crouch_rot.lerp(target_rot, blend)


func _update_sprint_stance(delta: float) -> void:
	var target_pos: Vector3 = Vector3.ZERO
	var target_rot: Vector3 = Vector3.ZERO
	var sprinting: bool = _is_sprint_animation_active()
	_set_ammo_display_visible(not sprinting)
	_set_2d_ammo_visible(sprinting)

	if sprinting:
		target_pos = _get_sprint_position_offset()
		target_rot = _get_sprint_rotation_offset()

	var blend: float = clampf(ctrl.sprint_transition_speed * delta, 0.0, 1.0)
	_sprint_pos = _sprint_pos.lerp(target_pos, blend)
	_sprint_rot = _sprint_rot.lerp(target_rot, blend)

	var target_weight: float = 1.0 if sprinting else 0.0
	_sprint_motion_weight = move_toward(
		_sprint_motion_weight,
		target_weight,
		ctrl.sprint_motion_transition_speed * delta
	)

	if sprinting:
		var speed_ratio: float = clampf(_planar_speed() / ctrl.bob_max_speed, 0.0, 1.0)
		_sprint_motion_time += delta * lerpf(
			ctrl.sprint_motion_frequency * 0.7,
			ctrl.sprint_motion_frequency,
			speed_ratio
		)

	var motion_multiplier: float = _get_sprint_motion_multiplier()
	var motion_phase: float = _sprint_motion_time * TAU
	var motion_scale: float = _sprint_motion_weight * motion_multiplier
	_sprint_motion_pos = Vector3(
		sin(motion_phase * 0.5) * ctrl.sprint_sway_amount.x,
		sin(motion_phase) * ctrl.sprint_bob_amount,
		cos(motion_phase) * ctrl.sprint_swing_amount
	) * motion_scale
	_sprint_motion_rot = Vector3(
		sin(motion_phase) * ctrl.sprint_pitch_amount,
		cos(motion_phase * 0.5) * ctrl.sprint_yaw_amount,
		sin(motion_phase * 0.5) * ctrl.sprint_roll_amount
	) * motion_scale


func _set_ammo_display_visible(is_visible: bool) -> void:
	var model: WeaponModel = ctrl.current_weapon_model
	if model == null:
		return
	model.set_ammo_display_visible(is_visible)


func _set_2d_ammo_visible(is_visible: bool) -> void:
	if _2d_ammo_visible == is_visible:
		return
	_2d_ammo_visible = is_visible
	EventBus.weapon_2d_ammo_visibility_changed.emit(is_visible)


func _is_sprint_animation_active() -> bool:
	if player == null or not player.is_on_floor() or not player.is_sprinting or player.is_crouching or player.is_sliding or is_aiming or is_reloading:
		_sprint_animation_active = false
		return false

	var speed: float = _planar_speed()
	if _sprint_animation_active:
		var stop_speed: float = minf(ctrl.sprint_animation_stop_speed, ctrl.sprint_animation_min_speed)
		_sprint_animation_active = speed >= stop_speed
	else:
		_sprint_animation_active = speed >= ctrl.sprint_animation_min_speed
	return _sprint_animation_active


func _get_sprint_position_offset() -> Vector3:
	if weapon != null and weapon.override_tactical_sprint_pose:
		return weapon.tactical_sprint_position_offset
	return ctrl.sprint_pos_offset


func _get_sprint_rotation_offset() -> Vector3:
	if weapon != null and weapon.override_tactical_sprint_pose:
		return weapon.tactical_sprint_rotation_offset
	return ctrl.sprint_rot_offset


func _get_sprint_motion_multiplier() -> float:
	if weapon == null:
		return 1.0
	return weapon.tactical_sprint_motion_multiplier
#endregion


#region Helpers
## 0 = light and agile, 1 = heavy. 0.5 when no weapon is equipped.
func _weight() -> float:
	return weapon.handling_weight if weapon != null else 0.5


## Natural frequency / damping ratio picked between a light and a heavy value.
func _omega(light: float, heavy: float) -> float:
	return lerpf(light, heavy, _weight())


func _zeta(light: float, heavy: float) -> float:
	return lerpf(light, heavy, _weight())


## Re-tunes an existing stiffness/damping pair for the current weapon's weight.
## Neutral at handling_weight 0.5: heavier = lower frequency and slightly lower damping ratio.
func _weighted_spring(stiffness: float, damping: float) -> Vector2:
	var w: float = _weight()
	var k_scale: float = pow(2.0, (0.5 - w) * 1.4)
	var zeta_scale: float = pow(0.8, (w - 0.5) * 2.0)
	return Vector2(stiffness * k_scale, damping * sqrt(k_scale) * zeta_scale)


## 0.0 (fresh) to 1.0 (fully exhausted).
func _tiredness_factor() -> float:
	if player == null or player._player_max_tiredness <= 0.0:
		return 0.0
	return clampf(player._player_current_tiredness / player._player_max_tiredness, 0.0, 1.0)


func _planar_speed() -> float:
	if player == null:
		return 0.0
	return Vector2(player.velocity.x, player.velocity.z).length()


func _is_two_handed_weapon() -> bool:
	if weapon == null:
		return false

	# Hand markers on the model decide it when present: SupportHand = two hands, only GripHand = one hand.
	if ctrl.recoil_use_hand_markers:
		_ensure_markers(ctrl.current_weapon_model)
		if _has_support:
			return true
		if _has_grip:
			return false

	return weapon.weapon_type in [
		Weapon.WeaponType.RIFLE,
		Weapon.WeaponType.SHOTGUN,
		Weapon.WeaponType.SNIPER,
		Weapon.WeaponType.HEAVY
	]
#endregion


#region Hand markers and recoil pivot
## Finds GripHand / SupportHand / RecoilPivot on the model once per spawned model.
func _ensure_markers(model: WeaponModel) -> void:
	if model == _markers_model:
		return
	_markers_model = model
	_has_grip = false
	_has_support = false
	_has_pivot = false
	if model == null:
		return
	var grip: Node3D = model.find_child("GripHand", true, false) as Node3D
	var support: Node3D = model.find_child("SupportHand", true, false) as Node3D
	var pivot: Node3D = model.find_child("RecoilPivot", true, false) as Node3D
	if grip != null:
		_has_grip = true
		_grip_local = model.to_local(grip.global_position)
	if support != null:
		_has_support = true
		_support_local = model.to_local(support.global_position)
	if pivot != null:
		_has_pivot = true
		_pivot_local = model.to_local(pivot.global_position)


## Pivot point in model-local space. RecoilPivot wins, otherwise a point between the two hands.
func _recoil_pivot_local() -> Vector3:
	if _has_pivot:
		return _pivot_local
	if _has_grip and _has_support:
		return _grip_local.lerp(_support_local, ctrl.recoil_pivot_blend)
	if _has_grip:
		return _grip_local
	if _has_support:
		return _support_local
	return Vector3.ZERO


## Position correction so the recoil rotation turns around the pivot instead of the model origin.
func _recoil_pivot_shift(model: WeaponModel, full_rotation: Vector3) -> Vector3:
	if not ctrl.recoil_pivot_enabled or _recoil_offset_rot == Vector3.ZERO:
		return Vector3.ZERO
	var pivot: Vector3 = _recoil_pivot_local() * model.scale
	if pivot == Vector3.ZERO:
		return Vector3.ZERO
	var base_basis: Basis = Basis.from_euler(full_rotation - _recoil_offset_rot)
	var full_basis: Basis = Basis.from_euler(full_rotation)
	return (base_basis * pivot - full_basis * pivot) * ctrl.recoil_pivot_strength


## Hands further apart = more leverage = less muzzle rise. 1.0 when off or markers are missing.
func _hand_leverage_multiplier() -> float:
	if ctrl.recoil_hand_leverage <= 0.0:
		return 1.0
	_ensure_markers(ctrl.current_weapon_model)
	if not (_has_grip and _has_support):
		return 1.0
	var separation: float = (_grip_local - _support_local).length() * _markers_model.scale.x
	var ratio: float = ctrl.recoil_hand_reference_distance / maxf(separation, 0.05)
	return lerpf(1.0, clampf(ratio, 0.6, 1.5), ctrl.recoil_hand_leverage)
#endregion