class_name CamEffects extends Camera3D

@export_category("References")
@export var player: PlayerController


@export_category("Effects")
@export var enable_tilt: bool = true
@export var enable_fall_kick: bool = true
@export var enable_damage_kick: bool = true
@export var enable_weapon_recoil_kick: bool = true
@export var enable_screen_shake: bool = true
@export var enable_headbob: bool = true
@export var enable_slide_effect: bool = true


@export_category("Kick & Recoil settings")
@export_group("Run Tilt Settings")
@export var run_pitch: float = 0.1
@export var run_roll: float = 0.25
@export var max_pitch: float = 1.0
@export var max_roll: float = 2.5
@export_group("Fall Kick Settings")
@export var fall_time: float = 0.3 
@export var fall_kick_scale: float = 0.18
@export var max_fall_kick: float = 5.0
@export_group("Damage Kick Settings")
@export var dmg_time: float = 0.3
@export var damage_kick_scale: float = 0.06
@export_group("Weapon Recoil Settings")
# @export var weapon_decay: float = 0.5
@export var recoil_cam_stiffness: float = 80.0
@export var recoil_cam_damping: float = 10.0
@export var recoil_cam_max_angle: float = 50.0
## true = the kick is applied as speed, so the view snaps up over a few frames instead of teleporting
@export var recoil_kick_as_velocity: bool = true
@export var recoil_kick_velocity_scale: float = 1.4
## Fraction of the pitch / yaw kick that stays as real aim climb (needs CameraController.add_recoil_climb)
@export_range(0.0, 1.0, 0.05) var recoil_climb_ratio: float = 0.5

@export_subgroup("Headbob Settings")
@export_range(0.0, 1.0,0.001) var headbob_pitch: float = 0.05
@export_range(0.0, 1.0,0.001) var headbob_roll: float = 0.025
@export_range(0.0, 0.4,0.001) var headbob_up: float = 0.005
@export_range(3.0, 8.0, 0.1) var headbob_frequency: float = 6.0
@export var run_bob_multiplier: float = 1.2
@export_group("Slide Settings")
@export var slide_pitch: float = 1.5 # Degrees to tilt up/down
@export var slide_roll: float = 3.0  # Degrees to tilt left/right
@export var slide_fov: float = 105.0 
@export var fov_transition_speed: float = 8.0
@export_group("Weapon FOV Punch")
@export var fov_punch_stiffness: float = 350.0
@export var fov_punch_damping: float = 26.0

var _fall_value: float = 0.0
var _fall_timer: float = 0.0

var _dmg_value: float = 0.0
var _dmg_roll_value: float = 0.0
var _dmg_timer: float = 0.0


# var _weapon_kick_angle: Vector3 = Vector3.ZERO DEPRECATED
var _recoil_angles: Vector3 = Vector3.ZERO
var _recoil_velocity: Vector3 = Vector3.ZERO



var _step_timer: float = 0.0

var _base_fov: float = 90.0
var _aim_fov: float = 90.0
var _target_slide_roll: float = 0.0
var _target_slide_pitch: float = 0.0
var _fov_tween: Tween
var _fov_aim_tween: Tween
var _fov_smooth: float = 90.0
var _fov_punch: float = 0.0
var _fov_punch_vel: float = 0.0

var _current_run_pitch: float = 0.0
var _current_run_roll: float = 0.0

var _screen_shake_tween: Tween = null
const MIN_SHAKE_INTENSITY: float = 0.008
const MAX_SHAKE_INTENSITY: float = 0.06

var _dive_roll: float = 0.0
var _dive_pitch: float = 0.0

func _ready() -> void:
	_base_fov = fov
	_aim_fov = _base_fov
	_fov_smooth = fov

func _process(delta: float) -> void:
	calculate_view_offset(PlayerTime.real(delta))

	# if Input.is_action_just_pressed("combat_fire"):
	#     add_fall_kick(2.0)

func calculate_view_offset(delta):
	if not player:
		return

	_fall_timer -= delta
	_dmg_timer -= delta
	
	var velocity = player.velocity

	# Headbob effect
	var speed = Vector2(velocity.x, velocity.z).length()
	if speed > 0.1 and player.is_on_floor():
		_step_timer += delta * (speed / headbob_frequency)
		_step_timer = fmod(_step_timer, 1.0)
	else:
		_step_timer = 0.0
	
	var headbob_sin = sin(_step_timer * 2.0 * PI) * 0.5

	var angles = Vector3.ZERO
	var offset = Vector3.ZERO
	
	# apply tilt slide effect based on player movement
	


	# tilt camera based on player movement
	if enable_tilt:
		var target_run_pitch: float= 0.0
		var target_run_roll: float = 0.0

		if not player.is_sliding:
			var forward = global_transform.basis.z
			var right = global_transform.basis.x

			var forward_dot = velocity.dot(forward)
			var forward_tilt = clampf(forward_dot * deg_to_rad(run_pitch), deg_to_rad(-max_pitch), deg_to_rad(max_pitch))

			var right_dot = velocity.dot(right)
			var right_tilt = clampf(right_dot * deg_to_rad(run_roll), deg_to_rad(-max_roll), deg_to_rad(max_roll))

			target_run_pitch = forward_tilt
			target_run_roll = right_tilt

		
		_current_run_pitch = lerp(_current_run_pitch, target_run_pitch, delta * 10.0)
		_current_run_roll = lerp(_current_run_roll, target_run_roll, delta * 10.0)

		angles.z = _current_run_roll
		angles.x = _current_run_pitch

	# apply fall kick effect
	if enable_fall_kick:
		var fall_ratio = max(0.0, _fall_timer / fall_time)
		var fall_kick_amount = fall_ratio * _fall_value
		angles.x -= fall_kick_amount
		offset.y -= fall_kick_amount

	# apply damage kick effect
	if enable_damage_kick:
		var dmg_ratio = max(0.0, _dmg_timer / dmg_time)
		angles.x -= dmg_ratio * _dmg_value
		angles.z += dmg_ratio * _dmg_roll_value

	# apply weapon recoil effect
	if enable_weapon_recoil_kick:
		var d = min(delta, 0.05)
		var angle_max = deg_to_rad(recoil_cam_max_angle)
		for axis in 3:
			var r: Vector2 = SpringUtil.apply_stable(_recoil_angles[axis], _recoil_velocity[axis], 0.0, d, recoil_cam_stiffness, recoil_cam_damping)
			_recoil_angles[axis] = clamp(r.x, -angle_max, angle_max)
			_recoil_velocity[axis] = r.y

		angles += _recoil_angles


	# apply headbob effect
	if enable_headbob:
		var bob_scale: float = speed
		if player.is_sprinting:
			bob_scale *= run_bob_multiplier

		var headbob_pitch_delta = headbob_sin * deg_to_rad(headbob_pitch) * bob_scale
		angles.x -= headbob_pitch_delta

		var headbob_roll_delta = headbob_sin * deg_to_rad(headbob_roll) * bob_scale
		angles.z -= headbob_roll_delta

		var headbob_height = headbob_sin * bob_scale * headbob_up
		offset.y += headbob_height

	# apply slide effect
	var target_fov = _base_fov
	if enable_slide_effect and player.is_sliding:
		target_fov = slide_fov
	elif player.is_diving and player.prone_dive:
		target_fov = _base_fov + player.prone_dive.dive_fov_boost

	_fov_smooth = lerpf(_fov_smooth, target_fov, delta * fov_transition_speed)
	var fov_d: float = minf(delta, 0.05)
	_fov_punch_vel += (-fov_punch_stiffness * _fov_punch - fov_punch_damping * _fov_punch_vel) * fov_d
	_fov_punch += _fov_punch_vel * fov_d
	fov = _fov_smooth + _fov_punch

	if enable_slide_effect:
		if player.is_sliding:
			var cam_forward = -global_transform.basis.z
			var cam_right = global_transform.basis.x

			var sideway_intensity = player._slide_direction.dot(cam_right)
			var forward_intensity = player._slide_direction.dot(cam_forward)

			_target_slide_roll =  sideway_intensity * deg_to_rad(slide_roll)
			_target_slide_pitch = forward_intensity * deg_to_rad(slide_pitch)
		else:
			_target_slide_roll = lerp(_target_slide_roll, 0.0, delta * fov_transition_speed)
			_target_slide_pitch = lerp(_target_slide_pitch, 0.0, delta * fov_transition_speed)

		angles.z += _target_slide_roll
		angles.x += _target_slide_pitch
	# Dive effect
	var dive_roll_t: float = 0.0
	var dive_pitch_t: float = 0.0
	if player.is_diving and player.prone_dive:
		var dv: Vector3 = player.prone_dive.dive_velocity
		if dv.length() > 0.1:
			var dn: Vector3 = dv.normalized()
			dive_roll_t = dn.dot(global_transform.basis.x) * deg_to_rad(player.prone_dive.cam_roll_degrees)
			dive_pitch_t = dn.dot(-global_transform.basis.z) * deg_to_rad(player.prone_dive.cam_pitch_degrees)
	_dive_roll = lerpf(_dive_roll, dive_roll_t, delta * fov_transition_speed)
	_dive_pitch = lerpf(_dive_pitch, dive_pitch_t, delta * fov_transition_speed)
	angles.z += _dive_roll
	angles.x += _dive_pitch

	
	# Keep the camera at the rig origin and add the peek offset in the rig's local space.
	var rig := get_parent() as CameraController
	position = offset + (rig.get_peek_cam_offset() if rig != null else Vector3.ZERO)
	rotation = angles
	

# fall
func add_fall_kick(amount: float) -> void:
	_fall_value = deg_to_rad(clampf(amount, 0.0, max_fall_kick))
	_fall_timer = fall_time

func add_landing_kick(impact_speed: float) -> void:
	if impact_speed <= 0.5:
		return

	var kick_amount: float = clampf(impact_speed * fall_kick_scale, 0.8, max_fall_kick)
	add_fall_kick(kick_amount)

# damage kick
func add_damage_kick(pitch_amount: float, roll_amount: float, source: Vector3) -> void:
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	var source_dir = (source - global_transform.origin).normalized()
	var forward_dot = source_dir.dot(forward)
	var right_dot = source_dir.dot(right)
	_dmg_value = deg_to_rad(pitch_amount) * forward_dot
	_dmg_roll_value = deg_to_rad(roll_amount) * right_dot
	_dmg_timer = dmg_time

func add_damage_impact(damage_amount: float, source: Node3D = null) -> void:
	var damage_ratio: float = clampf(damage_amount / 100.0, 0.0, 1.0)
	var kick_scale: float = lerpf(0.7, 1.5, damage_ratio)
	var pitch_amount: float = damage_kick_scale * 100.0 * kick_scale
	var roll_amount: float = pitch_amount * 0.45

	if is_instance_valid(source):
		add_damage_kick(pitch_amount, roll_amount, source.global_position)
	else:
		_dmg_value = deg_to_rad(pitch_amount)
		_dmg_roll_value = deg_to_rad(randf_range(-roll_amount, roll_amount))
		_dmg_timer = dmg_time

	add_screen_shake(clampf(damage_ratio * 0.15, 0.03, 0.15), lerpf(0.08, 0.14, damage_ratio))

# weapon recoil
func add_weapon_recoil(pitch: float, yaw: float, roll: float) -> void:
	var p: float = deg_to_rad(pitch)
	var y: float = deg_to_rad(randf_range(-yaw, yaw))
	var r: float = deg_to_rad(randf_range(-roll, roll))

	# layer 1: view punch (springs back to zero)
	if recoil_kick_as_velocity:
		var gain: float = sqrt(recoil_cam_stiffness) * recoil_kick_velocity_scale
		_recoil_velocity.x += p * gain
		_recoil_velocity.y += y * gain
		_recoil_velocity.z += r * gain
	else:
		_recoil_angles.x += p
		_recoil_angles.y += y
		_recoil_angles.z += r

	# layer 2: aim climb (stays until the player pulls down or it slowly settles)
	var controller := get_parent() as CameraController
	if controller != null and recoil_climb_ratio > 0.0:
		controller.add_recoil_climb(p * recoil_climb_ratio, y * recoil_climb_ratio)


# FOV punch: positive widens briefly, negative pulls in. Try about -0.6 .. 1.0 degrees.
func add_fov_punch(degrees: float) -> void:
	_fov_punch_vel += degrees * sqrt(fov_punch_stiffness) * 1.2


# screen shake
func add_screen_shake(intensity: float, duration: float) -> void:
	if _screen_shake_tween:
		_screen_shake_tween.kill()


	_screen_shake_tween = PlayerTime.real_tween(create_tween())
	_screen_shake_tween.tween_method(update_screen_shake.bind(intensity), 0.0, 1.0,duration).set_ease(Tween.EASE_OUT)


func update_screen_shake(alpha:float, amount: float) -> void:
	amount = remap(amount, 0.0, 1.0, MIN_SHAKE_INTENSITY, MAX_SHAKE_INTENSITY)
	var curr_shake_amount = amount * (1.0 - alpha)
	h_offset = randf_range(-curr_shake_amount, curr_shake_amount)
	v_offset = randf_range(-curr_shake_amount, curr_shake_amount)


func _animate_fov(target_fov: float, duration: float) -> void:
	if _fov_tween:
		_fov_tween.kill()

	_fov_tween = PlayerTime.real_tween(create_tween())
	_fov_tween.set_ease(Tween.EASE_OUT)
	_fov_tween.set_trans(Tween.TRANS_SINE)

	_fov_tween.tween_property(self, "fov", target_fov, duration)

func _change_fov(target_fov: float) -> void:
	if _fov_tween:
		_fov_tween.kill()

	_fov_tween = PlayerTime.real_tween(create_tween())
	_fov_tween.set_ease(Tween.EASE_OUT)
	_fov_tween.set_trans(Tween.TRANS_SINE)

	_fov_tween.tween_property(self, "fov", target_fov, 0.5)

	

func apply_ads_fov(target_fov: float) -> void:
	if _fov_tween:
		_fov_tween.kill()
	if _fov_aim_tween:
		_fov_aim_tween.kill()

	_aim_fov = target_fov

func reset_fov() -> void:
	if _fov_tween:
		_fov_tween.kill()
	if _fov_aim_tween:
		_fov_aim_tween.kill()

	_aim_fov = _base_fov


func get_bob_phase() -> float:
	return _step_timer