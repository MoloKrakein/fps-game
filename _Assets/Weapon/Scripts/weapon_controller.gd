class_name WeaponController extends Node
## Coordinates the equipped weapon: trigger and fire modes, aiming, model
## spawning, weapon switching and ammo UI.
##
## The heavy lifting lives in small helper classes created in _init():
##   animator    - procedural sway / bob / recoil of the weapon model
##   shooter     - hitscan, projectiles, casings, impact effects, spread
##   reload      - ammo transfer and reload input handling
##   attachments - attachment data, models and ADS overrides
##
## Public method names are unchanged (see "Compatibility wrappers" at the
## bottom), so the state chart, UI and animation tracks that call into this
## node keep working.

const AIM_SPEED: float = 0.2
const DEFAULT_BURST_SHOTS_PER_TRIGGER: int = 3
const TIREDNESS_PER_SHOT: float = 1.5

#region Exported settings
@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart
@export var reticle: Control
@export var shoot_position: Node3D
@export var casing_position: Node3D
@export var shoot_position_offset: Vector3 = Vector3.ZERO
@export var camera: CamEffects
@export var cam_rig: CameraController
# @export var ammo_counter_ui_offset: Vector3 = Vector3(0, 0, 0.5)

@export_group("Weapon Animations Settings")
@export_category("Crouch Stance Settings")
@export var crouch_pos_offset: Vector3 = Vector3(0.04, -0.03, 0.06)
@export var crouch_rot_offset: Vector3 = Vector3(deg_to_rad(-5), 0, deg_to_rad(15))
@export var crouch_transition_speed: float = 10.0
@export_category("Tactical Sprint Settings")
@export var sprint_pos_offset: Vector3 = Vector3(0.16, 0.10, 0.08)
@export var sprint_rot_offset: Vector3 = Vector3(deg_to_rad(-28.0), deg_to_rad(8.0), deg_to_rad(-32.0))
@export var sprint_transition_speed: float = 12.0
@export var sprint_animation_min_speed: float = 0.35
@export var sprint_animation_stop_speed: float = 0.20
@export var sprint_motion_transition_speed: float = 8.0
@export var sprint_motion_frequency: float = 1.35
@export var sprint_bob_amount: float = 0.035
@export var sprint_swing_amount: float = 0.045
@export var sprint_sway_amount: Vector2 = Vector2(0.018, 0.0)
@export var sprint_pitch_amount: float = deg_to_rad(5.0)
@export var sprint_yaw_amount: float = deg_to_rad(3.0)
@export var sprint_roll_amount: float = deg_to_rad(6.0)
@export_category("Idle Sway Animations Settings")
@export var idle_sway_enabled: bool = true
@export var idle_sway_frequency: float = 0.8
@export var idle_sway_amplitude: Vector2 = Vector2(0.005, 0.005)
@export var idle_sway_stiffness: float = 40.0
@export var idle_sway_damping: float = 60.0
@export var idle_sway_rotation_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.001) var idle_sway_tremor_threshold: float = 0.5
@export_category("Idle Aiming Sway Settings")
@export var aiming_sway_enabled: bool = true # currently unused
@export var aim_sway_multiplier: float = 0.15
@export_category("Look Sway Settings")
@export var look_sway_enabled: bool = true
@export var look_lag_divisor: float = 10.0
@export var look_lag_rot_max: float = 5.0
@export var look_lag_pos_scale: float = 0.006
@export_category("Strafe Tilt Settings")
@export var strafe_tilt_enabled: bool = true
@export var strafe_tilt_scale: float = 0.3
@export var strafe_tilt_max: float = 0.09
@export var strafe_tilt_stiffness: float = 90.0
@export var strafe_tilt_damping: float = 10.0
@export_category("Weapon Bob Settings")
@export var weapon_bob_enabled: bool = true
@export var bob_amplitude: Vector2 = Vector2(0.05, 0.05)
@export var bob_max_speed: float = 10.0
@export var bob_stiffness: float = 60.0
@export var bob_damping: float = 10.0
@export_category("vertical lag Settings")
@export var vertical_lag_enabled: bool = true
@export var vertical_lag_stiffness: float = 60.0
@export var vertical_lag_damping: float = 12.0
@export var vertical_lag_max: float = 0.1
@export var vertical_lag_vel_max: float = 10.0 # currently unused
@export var vertical_lag_deadzone: float = 0.05

@export_group("Weapon Recoil Settings")
@export var enable_recoil: bool = true
@export var disable_recoil_during_sprint: bool = true
@export var recoil_model_stillness: float = 200.0
@export var recoil_model_damping: float = 10.0
@export var recoil_model_max_angle: float = 50.0
@export var recoil_pitch_max: float = 0.4

@export_range(0.0, 0.95, 0.01) var recoil_lateral_persistence: float = 0.5
@export var recoil_ads_visual_multiplier: float = 0.5
@export var recoil_roll_coupling: float = 0.15
@export var recoil_vertical_lift: float = 0.15

@export_group("Weapon Recoil Hands")
## Use the GripHand / SupportHand markers to decide one- or two-handed recoil
@export var recoil_use_hand_markers: bool = true
## Turn the recoil rotation around a pivot between the hands instead of the model origin
@export var recoil_pivot_enabled: bool = true
## 0 = pivot at the grip hand, 1 = at the support hand (ignored if the model has a RecoilPivot marker)
@export_range(0.0, 1.0, 0.05) var recoil_pivot_blend: float = 0.5
## 0 = rotate around the model origin (old behaviour), 1 = fully around the pivot
@export_range(0.0, 1.0, 0.05) var recoil_pivot_strength: float = 1.0
## Hands further apart = more leverage = less muzzle rise. 0 = off
@export_range(0.0, 1.0, 0.05) var recoil_hand_leverage: float = 0.5
## Hand separation (metres) that counts as normal leverage
@export var recoil_hand_reference_distance: float = 0.3


@export_group("Weapon Handling")
@export var rack_lockout_time: float = 0.5
#endregion


#region State
# Components (created in _init)
var animator: WeaponProceduralAnimator
var shooter: WeaponShooter
var reload: WeaponReload
var attachments: WeaponAttachments

# Cached data (avoids digging through singletons every frame)
var active_weapon_data: WeaponData
var player: PlayerController
var player_stats_component: PlayerStats

var current_weapon_model: WeaponModel
var weapon_animation_player: WeaponAnimation
var _muzzle_flash: MuzzleFlash
var _weapon_smear: MotionSmear

# Ammo (cached copies of active_weapon_data)
var current_ammo: int
var reserve_ammo: int = 0
var is_loaded: bool = false

# Flags driven by the state chart
var is_reloading: bool = false
var is_aiming: bool = false

# Trigger / fire mode
var fire_timer: float = 0.0
var _rack_timer: float = 0.0
var current_fire_mode: Weapon.WeaponFireMode
var shots_fired_this_trigger: int = 0
var trigger_held: bool = false
var burst_shots_remaining: int = 0

# Stance (tweened when aiming, read by the animator)
var weapon_start_position: Vector3
var weapon_start_rotation: Vector3
var current_stance_pos: Vector3
var current_stance_rot: Vector3
var aim_tween: Tween
var wall_tuck: WeaponWallTuck

# Accuracy
var stance_accuracy_modifier: float = 1.0
var accuracy_modifier: float = 1.0
var dynamic_accuracy_spread: float = 0.0
#endregion


#region Lifecycle
func _init() -> void:
	animator = WeaponProceduralAnimator.new(self)
	shooter = WeaponShooter.new(self)
	reload = WeaponReload.new(self)
	attachments = WeaponAttachments.new(self)


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		player_stats_component = player.get_node_or_null("PlayerStats") as PlayerStats

	if current_weapon != null:
		# Inject stats into the weapon for damage calculations
		current_weapon.stats_component = player_stats_component
		spawn_weapon_model(current_weapon)
		# Initialize magazine and reserve from weapon stats
		current_ammo = current_weapon.get_calculated_magazine_capacity()
		reserve_ammo = current_weapon.max_ammo
		current_fire_mode = current_weapon.fire_mode
		is_loaded = current_ammo > 0

	call_deferred("update_weapon_ui")


func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
	if _rack_timer > 0.0:
		_rack_timer = maxf(_rack_timer - delta, 0.0)

	reload.process(delta)
	animator.apply_offsets(delta)
	_handle_combat_input()

	if OS.is_debug_build():
		_debug_ads_tuner()


func _handle_combat_input() -> void:
	if Input.is_action_just_pressed("combat_switch_fire_mode"):
		toggle_fire_mode()
	if Input.is_action_just_pressed("combat_rack_gun"):
		rack_slide()
	if Input.is_action_just_pressed("combat_reload") and not is_reloading:
		request_reload()


## Live ADS tuner (debug builds only). Hold the "ui_focus_next" action (Tab) and use
## I/K (z), J/L (x), U/O (y). Hold Shift for fine steps, press P to print the position.
func _debug_ads_tuner() -> void:
	if not Input.is_action_pressed("ui_focus_next"):
		return

	var step: float = 0.001 if Input.is_key_pressed(KEY_SHIFT) else 0.01
	if Input.is_key_pressed(KEY_I): current_stance_pos.z += step
	if Input.is_key_pressed(KEY_K): current_stance_pos.z -= step
	if Input.is_key_pressed(KEY_J): current_stance_pos.x -= step
	if Input.is_key_pressed(KEY_L): current_stance_pos.x += step
	if Input.is_key_pressed(KEY_U): current_stance_pos.y += step
	if Input.is_key_pressed(KEY_O): current_stance_pos.y -= step

	if Input.is_key_pressed(KEY_P):
		print("Current Tweak Position: ", current_stance_pos)


func _disable_procedural_weapon_animations() -> void:
	idle_sway_enabled = false


## Forwards an event to the weapon state chart, if there is one.
func send_state_event(event: StringName) -> void:
	if weapon_state_chart != null:
		weapon_state_chart.send_event(event)
#endregion


#region Weapon data
func initialize_weapon_data(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return

	active_weapon_data = weapon_data
	_sync_cached_state_from_active_data()
	_set_and_persist_fire_mode(_resolve_initial_fire_mode_for_weapon_data())


func _sync_cached_state_from_active_data() -> void:
	if active_weapon_data == null:
		return

	current_ammo = active_weapon_data.ammo_in_magazine
	reserve_ammo = active_weapon_data.reserve_ammo
	is_loaded = active_weapon_data.is_loaded


func _set_and_persist_fire_mode(mode: Weapon.WeaponFireMode) -> void:
	current_fire_mode = mode
	if active_weapon_data != null:
		active_weapon_data.fire_mode = mode


func _resolve_initial_fire_mode_for_weapon_data() -> Weapon.WeaponFireMode:
	if current_weapon == null:
		return Weapon.WeaponFireMode.SEMI_AUTO

	if active_weapon_data == null:
		return current_weapon.fire_mode

	var mode: Weapon.WeaponFireMode = active_weapon_data.fire_mode
	if mode == Weapon.WeaponFireMode.BURST and not current_weapon.has_burst_mode:
		mode = current_weapon.fire_mode

	return mode


func has_ammo() -> bool:
	if active_weapon_data == null:
		return false
	return active_weapon_data.is_loaded or active_weapon_data.ammo_in_magazine > 0 or active_weapon_data.reserve_ammo > 0
#endregion


#region Trigger & fire mode
func start_trigger() -> void:
	trigger_held = true
	if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
		burst_shots_remaining = get_burst_shot_count()
	if weapon_animation_player != null:
		weapon_animation_player.set_trigger_pressed(true)


func stop_trigger() -> void:
	trigger_held = false
	if weapon_animation_player != null:
		weapon_animation_player.set_trigger_pressed(false)
	if current_fire_mode != Weapon.WeaponFireMode.BURST:
		reset_trigger()


func reset_trigger() -> void:
	shots_fired_this_trigger = 0
	burst_shots_remaining = 0


func toggle_fire_mode() -> void:
	if current_weapon == null or not current_weapon.can_change_fire_mode:
		return

	_set_and_persist_fire_mode(_next_fire_mode())
	reset_trigger()


func _next_fire_mode() -> Weapon.WeaponFireMode:
	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			if current_weapon.has_burst_mode:
				return Weapon.WeaponFireMode.BURST
			return Weapon.WeaponFireMode.FULL_AUTO
		Weapon.WeaponFireMode.BURST:
			return Weapon.WeaponFireMode.FULL_AUTO
		Weapon.WeaponFireMode.FULL_AUTO:
			return Weapon.WeaponFireMode.SEMI_AUTO
	return current_fire_mode


func get_burst_shot_count() -> int:
	if current_weapon == null:
		return DEFAULT_BURST_SHOTS_PER_TRIGGER

	if current_weapon.burst_shot_count > 0:
		return current_weapon.burst_shot_count

	return DEFAULT_BURST_SHOTS_PER_TRIGGER


func is_burst_fire() -> bool:
	return current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining > 0 and burst_shots_remaining < get_burst_shot_count()


func can_fire() -> bool:
	if current_weapon == null or active_weapon_data == null:
		return false

	if fire_timer > 0.0:
		return false

	if wall_tuck != null and wall_tuck.is_blocked():
		return false

	if current_weapon.is_open_bolt:
		if active_weapon_data.ammo_in_magazine <= 0:
			return false
	elif not active_weapon_data.is_loaded:
		return false

	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			return trigger_held and shots_fired_this_trigger < 1
		Weapon.WeaponFireMode.BURST:
			return burst_shots_remaining > 0
		Weapon.WeaponFireMode.FULL_AUTO:
			return trigger_held

	return false
#endregion


#region Firing & chamber
func fire_weapon() -> void:
	if not can_fire():
		return

	fire_timer = current_weapon.get_fire_interval_seconds()
	_register_shot()
	_apply_recoil()

	if current_weapon.is_hitscan:
		shooter.fire_hitscan()
	else:
		shooter.fire_projectile()

	if player != null:
		player.increase_tiredness(TIREDNESS_PER_SHOT)

	_play_fire_feedback()
	_cycle_weapon()


## Trigger / burst bookkeeping for the shot that is about to leave the barrel.
func _register_shot() -> void:
	match current_fire_mode:
		Weapon.WeaponFireMode.SEMI_AUTO:
			shots_fired_this_trigger = 1
		Weapon.WeaponFireMode.BURST:
			if burst_shots_remaining <= 0:
				burst_shots_remaining = get_burst_shot_count()
			burst_shots_remaining -= 1
			shots_fired_this_trigger += 1
		# FULL_AUTO needs no bookkeeping.

	if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
		trigger_held = false


func _apply_recoil() -> void:
	if camera != null:
		var pitch: float = current_weapon.get_calculated_recoil() * randf_range(0.9, 1.1)
		var yaw: float = current_weapon.recoil_cam_yaw
		if is_aiming:
			pitch *= 0.7
			yaw *= 0.7
		camera.add_weapon_recoil(pitch, yaw, current_weapon.recoil_cam_roll)
		camera.add_fov_punch(current_weapon.recoil_fov_punch)
	animator.add_recoil()


func _play_fire_feedback() -> void:
	shooter.eject_casing()

	if _muzzle_flash != null:
		_muzzle_flash.flash(current_weapon.muzzle_light_color, current_weapon.muzzle_light_energy, current_weapon.muzzle_light_duration)
	else:
		print("Muzzle flash not found on weapon model.")

	if weapon_animation_player != null:
		_play_animation("Fire")


## Called after every shot: the fired round is gone, and the action cycles.
func _cycle_weapon() -> void:
	if current_weapon == null or active_weapon_data == null:
		return

	if current_weapon.is_open_bolt:
		active_weapon_data.ammo_in_magazine = maxi(active_weapon_data.ammo_in_magazine - 1, 0)
		active_weapon_data.is_loaded = active_weapon_data.ammo_in_magazine > 0
	else:
		_feed_chamber()

	_play_animation("Loaded" if active_weapon_data.is_loaded else "Empty")
	update_weapon_ui()


func _feed_chamber() -> void:
	if active_weapon_data.ammo_in_magazine > 0:
		active_weapon_data.ammo_in_magazine -= 1
		active_weapon_data.is_loaded = true
	else:
		active_weapon_data.is_loaded = false


func rack_slide() -> void:
	if current_weapon == null or active_weapon_data == null:
		return
	if is_reloading or _rack_timer > 0.0 or current_weapon.is_open_bolt:
		return

	var chamber_was_loaded: bool = active_weapon_data.is_loaded
	if not chamber_was_loaded and active_weapon_data.ammo_in_magazine <= 0:
		return

	if chamber_was_loaded:
		shooter.eject_casing("alive")

	_feed_chamber()
	_play_animation("Rack")
	if chamber_was_loaded:
		_play_animation("Loaded" if active_weapon_data.is_loaded else "Empty")

	_rack_timer = rack_lockout_time
	fire_timer = maxf(fire_timer, rack_lockout_time)
	reset_trigger()
	update_weapon_ui()

	if not chamber_was_loaded and active_weapon_data.is_loaded:
		send_state_event("onIdle")


func _play_animation(animation_name: String) -> void:
	if weapon_animation_player != null:
		weapon_animation_player.play_animation(animation_name)
#endregion


#region Weapon model & switching
func spawn_weapon_model(weapon: Weapon) -> void:
	if current_weapon_model != null:
		current_weapon_model.queue_free()
		current_weapon_model = null

	if weapon == null or not weapon.weapon_model:
		return

	current_weapon_model = weapon.weapon_model.instantiate() as WeaponModel
	weapon_model_parent.add_child(current_weapon_model)

	current_weapon_model.position = weapon.weapon_position
	current_weapon_model.rotation = weapon.weapon_rotation
	current_weapon_model.scale = weapon.weapon_scale

	weapon_start_position = current_weapon_model.position
	weapon_start_rotation = current_weapon_model.rotation
	current_stance_pos = weapon_start_position
	current_stance_rot = weapon_start_rotation

	current_weapon.stats_component = player_stats_component
	current_weapon.active_weapon_data_ref = active_weapon_data

	animator.reset_motion_state()
	if wall_tuck != null:
		wall_tuck.reset_state()
	_bind_model_nodes(current_weapon_model)
	attachments.mount_all()


## Finds the muzzle, ejection port, muzzle flash and animation player on a freshly spawned model.
func _bind_model_nodes(model: WeaponModel) -> void:
	var muzzle: Node3D = model.get_node_or_null("Muzzle") as Node3D
	var ejection_port: Node3D = model.get_node_or_null("EjectionPort") as Node3D

	_muzzle_flash = null
	_weapon_smear = null
	if muzzle != null:
		shoot_position = muzzle
		var found: Array[Node] = model.find_children("*", "MuzzleFlash", true, false)
		_muzzle_flash = (found[0] as MuzzleFlash) if not found.is_empty() else null
		print("Muzzle flash found: ", _muzzle_flash != null)
		if _muzzle_flash:
			var ejection_port_smoke: GPUParticles3D = model.get_node_or_null("EjectionPort/Smoke") as GPUParticles3D
			if ejection_port_smoke != null:
				_muzzle_flash.ejection_smoke = ejection_port_smoke
			_muzzle_flash.configure(current_weapon)

	var smear_nodes: Array[Node] = model.find_children("*", "MotionSmear", true, false)
	if not smear_nodes.is_empty():
		_weapon_smear = smear_nodes[0] as MotionSmear

	if ejection_port != null:
		casing_position = ejection_port

	weapon_animation_player = model.get_node_or_null("WeaponAnimation") as WeaponAnimation
	if weapon_animation_player == null:
		print("WeaponAnimation node not found in the weapon model.")
	else:
		weapon_animation_player.play_animation("Equip")


func switch_weapon(weapon_data: WeaponData) -> void:
	if is_reloading or weapon_data == null or weapon_data.weapon == null:
		return

	shooter.flush_casing_tube()
	current_weapon = weapon_data.weapon
	# Cache the active data immediately so per-frame code doesn't have to query a manager.
	active_weapon_data = weapon_data
	_sync_cached_state_from_active_data()
	_set_and_persist_fire_mode(_resolve_initial_fire_mode_for_weapon_data())
	reset_trigger()
	fire_timer = 0.0

	# Inject stats into the weapon for damage calculations
	current_weapon.stats_component = player_stats_component

	# An empty weapon leaves the trigger chart in EmptyState. Weapon swapping
	# must re-arm the chart for the newly selected weapon.
	send_state_event("onIdle")

	spawn_weapon_model(weapon_data.weapon)


func get_weapon_position() -> Vector3:
	if current_weapon_model != null:
		return current_weapon_model.position
	return Vector3.ZERO
#endregion


#region Aiming
func aim_hipfire() -> void:
	if current_weapon:
		EventBus.change_visibility_of_crosshair.emit(true)
		accuracy_modifier = 1.0
		player.cam_effects.reset_fov()
		tween_weapon_to_position(current_weapon.weapon_position, current_weapon.weapon_rotation)


func aim_ads() -> void:
	if current_weapon:
		EventBus.change_visibility_of_crosshair.emit(false)
		accuracy_modifier = current_weapon.aim_accuracy_modifier
		player.cam_effects.apply_ads_fov(get_effective_ads_fov())
		tween_weapon_to_position(get_effective_ads_position(), get_effective_ads_rotation())


func aim_canted() -> void:
	if current_weapon:
		EventBus.change_visibility_of_crosshair.emit(false)
		player.cam_effects.apply_ads_fov(current_weapon.canted_sight_fov)
		tween_weapon_to_position(current_weapon.canted_sight_position, current_weapon.canted_sight_rotation)


func tween_weapon_to_position(target_position: Vector3, target_rotation: Vector3) -> void:
	if current_weapon_model == null:
		return

	# Kill the previous tween so they don't fight each other if the aim button is spammed.
	if aim_tween:
		aim_tween.kill()

	aim_tween = create_tween()
	aim_tween.set_trans(Tween.TRANS_SINE)
	aim_tween.set_ease(Tween.EASE_IN_OUT)
	aim_tween.set_parallel(true)

	aim_tween.tween_property(self, "current_stance_pos", target_position, AIM_SPEED)
	aim_tween.tween_property(self, "current_stance_rot", target_rotation, AIM_SPEED)
#endregion


#region Ammo UI
func update_weapon_ui() -> void:
	if active_weapon_data == null:
		return

	_sync_cached_state_from_active_data()
	if current_weapon != null:
		EventBus.weapon_ammo_changed.emit(active_weapon_data.ammo_in_magazine, active_weapon_data.reserve_ammo)
		EventBus.weapon_chamber_status.emit(active_weapon_data.is_loaded)
		EventBus.weapon_magazine_changed.emit(active_weapon_data.ammo_in_magazine, current_weapon.get_calculated_magazine_capacity())


func reload_timer_ui(reload_time: float) -> void:
	if active_weapon_data == null:
		return

	EventBus.weapon_ammo_changed.emit(active_weapon_data.ammo_in_magazine, active_weapon_data.reserve_ammo, reload_time)
#endregion


#region Compatibility wrappers
# Thin forwards to the helper classes so existing callers keep working.
# Once you've searched the project and nothing uses one of these names,
# delete it and call the helper directly (e.g. weapon_controller.reload.execute_reload()).

# Reload
func can_reload() -> bool:
	return reload.can_reload()

func request_reload() -> void:
	shooter.flush_casing_tube()
	reload.request_reload()

func dump_magazine_and_reload() -> void:
	reload.dump_magazine_and_reload()

func finish_reload_step() -> void:
	reload.finish_reload_step()

func execute_reload() -> void:
	reload.execute_reload()

func get_single_round_reload_time() -> float:
	return reload.get_single_round_reload_time()

func reload_single_round() -> void:
	reload.reload_single_round()

func reload_magazine() -> void:
	reload.reload_magazine()

func reload_per_bullet(_delta: float) -> void:
	# Legacy compatibility wrapper. Reload state now drives one shell per reload input.
	reload.reload_single_round()

# Shooting
func get_effective_spread() -> float:
	return shooter.get_effective_spread()

func _ejecting_bullet_case(casing_type: String = "empty") -> void:
	shooter.eject_casing(casing_type)

# Attachments
func equip_attachment(att: Attachment) -> void:
	attachments.equip(att)

func unequip_attachment(slot: Attachment.AttachmentSlot) -> void:
	attachments.unequip(slot)

func spawn_attachment_model(att: Attachment) -> void:
	attachments.spawn_model(att)

func remove_attachment_model(att: Attachment) -> void:
	attachments.remove_model(att)

func _mount_attachments() -> void:
	attachments.mount_all()

func get_effective_ads_position() -> Vector3:
	return attachments.get_ads_position()

func get_effective_ads_rotation() -> Vector3:
	return attachments.get_ads_rotation()

func get_effective_ads_fov() -> float:
	return attachments.get_ads_fov()
#endregion
