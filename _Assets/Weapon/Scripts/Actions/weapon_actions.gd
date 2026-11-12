class_name WeaponActions extends RefCounted
## Runs timed weapon actions (reload, rack) and drives the code-owned slide.
## Created in WeaponController._init() next to animator / shooter / reload /
## attachments, and ticked from WeaponController._process() with the same
## PlayerTime.real(delta) the controller already uses.
##
## Rule: game state (ammo, chamber, UI, state chart events) changes on ACTION
## EVENTS, never on button press and never from the animation callbacks.

## Re-emitted for hooks that don't exist yet: dropped magazine, audio, enemy hearing.
signal world_event(action: StringName, event_name: StringName)

const RELOAD_EMPTY: StringName = &"empty_reload"
const RELOAD_LOADED: StringName = &"loaded_reload"
const RACK: StringName = &"rack"

# --- Slide tuning (move to the Weapon resource / debug menu later) ---
var fire_travel: float = 1.0           # how far the slide blows back on a shot (0..1)
var shot_back_fraction: float = 0.3    # of the fire interval
var shot_return_fraction: float = 0.5  # of the fire interval
var shot_back_min_max: Vector2 = Vector2(0.02, 0.07)
var shot_return_min_max: Vector2 = Vector2(0.04, 0.16)
var rack_pull_curve: float = 0.5
var rack_release_curve: float = 2.2

var ctrl: WeaponController
var timeline: ActionTimeline = ActionTimeline.new()
var slide: SlideDriver = SlideDriver.new()

var anim: WeaponAnimation:
	get:
		return ctrl.weapon_animation_player

var _reload_committed: bool = false
var _rack_chamber_was_loaded: bool = false


func _init(controller: WeaponController) -> void:
	ctrl = controller
	timeline.event.connect(_on_event)
	timeline.finished.connect(_on_finished)
	timeline.cancelled.connect(_on_cancelled)


#region Lifecycle
func process(delta: float) -> void:
	timeline.tick(delta)
	slide.tick(delta)


func is_busy() -> bool:
	return timeline.running


## Call after a new weapon model (and its WeaponAnimation) has been bound.
func bind_animation(model_anim: WeaponAnimation) -> void:
	timeline.stop()
	if model_anim != null:
		slide.apply = model_anim.set_slide_value
	else:
		slide.apply = Callable()
	sync_slide_to_chamber()


## Call at the top of switch_weapon(), before active_weapon_data changes.
func on_weapon_switching() -> void:
	# A rack that is cut off still completes logically, so the chamber never
	# stays half-racked. Reloads cannot be switched out of (switch_weapon blocks them).
	if timeline.running and timeline.action == RACK:
		timeline.finish_now()


## Slide pose follows the chamber: empty chamber = locked open, otherwise closed.
func sync_slide_to_chamber() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	var open: bool = data != null and not data.is_loaded
	slide.release()
	slide.snap(1.0 if open else 0.0)
	if open:
		slide.lock(1.0)
#endregion


#region Shots
## Call after the chamber has been updated for the shot that just left the barrel.
func on_shot_cycled() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or ctrl.current_weapon == null:
		return

	var interval: float = ctrl.current_weapon.get_fire_interval_seconds()
	var back: float = clampf(interval * shot_back_fraction, shot_back_min_max.x, shot_back_min_max.y)
	var ret: float = clampf(interval * shot_return_fraction, shot_return_min_max.x, shot_return_min_max.y)
	slide.kick(fire_travel, back, ret, not data.is_loaded)
#endregion


#region Reload
## Same maths the reloading state used to do inline: clip length scaled by the
## skill-adjusted reload time, or one shell's share for per-bullet weapons.
func get_reload_duration(reload_type: StringName) -> float:
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null:
		return 0.0

	var calculated: float = weapon.get_calculated_reload_speed()
	var duration: float = 0.0
	if anim != null:
		duration = anim.get_animation_length(String(reload_type))
	if duration <= 0.0:
		duration = calculated

	if weapon.is_reload_per_bullet:
		var capacity: int = weapon.get_calculated_magazine_capacity()
		if capacity > 0:
			duration = calculated / float(capacity)
	elif weapon.reload_time > 0.0:
		duration *= calculated / weapon.reload_time
	return duration


func start_reload(reload_type: StringName, duration: float) -> void:
	# A rack still in progress is completed first, so the chamber is consistent.
	if timeline.running and timeline.action == RACK:
		timeline.finish_now()

	_reload_committed = false

	if anim != null:
		var clip_len: float = anim.get_animation_length(String(reload_type))
		var time_scale: float = 1.0
		if clip_len > 0.0:
			time_scale = 100.0 if duration <= 0.0 else clip_len / duration
		anim.set_reload_time_scale(time_scale)
		anim.reload_weapon_animation(String(reload_type))

	timeline.start(_get_def(reload_type), duration)


func cancel_reload() -> void:
	if timeline.running and (timeline.action == RELOAD_EMPTY or timeline.action == RELOAD_LOADED):
		timeline.cancel()


func _commit_reload() -> void:
	if _reload_committed:
		return
	_reload_committed = true
	ctrl.execute_reload()


func _on_reload_event(event_name: StringName) -> void:
	match event_name:
		&"mag_in", &"shell_in":
			_commit_reload()
		&"mag_out":
			pass # hook: spawn the dropped magazine (phase 7)
#endregion


#region Rack
func start_rack() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return
	_rack_chamber_was_loaded = data.is_loaded
	ctrl._play_animation("Rack") # body motion only: remove Slider_2 from the RackOneShot filter
	timeline.start(_get_def(RACK), ctrl.rack_lockout_time)


func _on_rack_event(event_name: StringName) -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return

	match event_name:
		&"pull":
			slide.release()
			slide.move_to(1.0, _span(&"pull", &"peak"), rack_pull_curve)
		&"peak":
			# Slide fully back: this is the moment the live round leaves the gun.
			if _rack_chamber_was_loaded:
				ctrl.shooter.eject_casing("alive")
				data.is_loaded = false
				ctrl.update_weapon_ui()
		&"release":
			if data.ammo_in_magazine > 0:
				slide.move_to(0.0, _span(&"release", &"closed"), rack_release_curve)
			else:
				slide.lock(1.0) # nothing to chamber: slide stays open
		&"closed":
			ctrl._feed_chamber()
			ctrl.update_weapon_ui()
			if not _rack_chamber_was_loaded and data.is_loaded:
				ctrl.send_state_event("onIdle")


func _span(from_event: StringName, to_event: StringName) -> float:
	var f: float = timeline.fraction_of(to_event, 1.0) - timeline.fraction_of(from_event, 0.0)
	return maxf(f, 0.0) * timeline.duration
#endregion


#region Timeline signals
func _on_event(action: StringName, event_name: StringName) -> void:
	world_event.emit(action, event_name)
	match action:
		RACK:
			_on_rack_event(event_name)
		RELOAD_EMPTY, RELOAD_LOADED:
			_on_reload_event(event_name)


func _on_finished(action: StringName) -> void:
	match action:
		RELOAD_EMPTY, RELOAD_LOADED:
			_commit_reload() # fallback when the clip has no mag_in event
			ctrl.send_state_event("onReloadFinish")
			ctrl.finish_reload_step()


func _on_cancelled(action: StringName, _progress: float) -> void:
	match action:
		RELOAD_EMPTY, RELOAD_LOADED:
			# No commit: if mag_in never happened, no ammo is transferred.
			ctrl.send_state_event("onReloadFinish")
			ctrl.finish_reload_step()
#endregion


#region Default action definitions
## Used when the model's WeaponAnimation has no ActionDef for this action,
## so each weapon can be migrated one at a time.
func _get_def(id: StringName) -> ActionDef:
	if anim != null:
		var def: ActionDef = anim.get_action_def(id)
		if def != null:
			return def

	match id:
		RACK:
			return _make_def(id, {&"pull": 0.0, &"peak": 0.45, &"release": 0.55, &"closed": 1.0})
		_:
			return _make_def(id, {}) # reloads: ammo commits on finish


static func _make_def(id: StringName, fractions: Dictionary) -> ActionDef:
	var def: ActionDef = ActionDef.new()
	def.id = id
	for key: StringName in fractions:
		var ev: ActionEvent = ActionEvent.new()
		ev.event_name = key
		ev.fraction = float(fractions[key])
		def.events.append(ev)
	return def
#endregion
