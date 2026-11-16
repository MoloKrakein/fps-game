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

## HUD hooks for active reload: the timing window opened / closed, and how it ended.
signal active_window_changed(is_open: bool)
signal active_reload_result(hit: bool)

## Short messages for a HUD ("Rack the bolt first").
signal hint(text: String)

const RELOAD_EMPTY: StringName = &"empty_reload"
const RELOAD_LOADED: StringName = &"loaded_reload"
## Double-tap reload: the magazine is dumped. Uses its own clip, or the empty reload clip.
const RELOAD_QUICK: StringName = &"quick_reload"
const RACK: StringName = &"rack"
const EQUIP: StringName = &"equip"

# --- Slide tuning (move to the Weapon resource / debug menu later) ---
var fire_travel: float = 1.0           # how far the slide blows back on a shot (0..1)
var shot_back_fraction: float = 0.3    # of the fire interval
var shot_return_fraction: float = 0.5  # of the fire interval
var shot_back_min_max: Vector2 = Vector2(0.02, 0.07)
var shot_return_min_max: Vector2 = Vector2(0.04, 0.16)
var rack_pull_curve: float = 0.5
var rack_release_curve: float = 2.2

## Set to true (e.g. in WeaponController._init) to print the slide state on every shot.
var debug_slide: bool = false

var ctrl: WeaponController
var timeline: ActionTimeline = ActionTimeline.new()
var slide: SlideDriver = SlideDriver.new()

var anim: WeaponAnimation:
	get:
		return ctrl.weapon_animation_player

## The weapon's action profile, or a default one (automatic, bolt catch, no active reload).
var profile: WeaponActionProfile:
	get:
		var weapon: Weapon = ctrl.current_weapon
		if weapon != null and weapon.action_profile != null:
			return weapon.action_profile
		return _default_profile

var _default_profile: WeaponActionProfile = WeaponActionProfile.new()

var _reload_committed: bool = false
var _rack_chamber_was_loaded: bool = false
var _rack_chamber_spent: bool = false
var _rack_cocking: bool = false          # this rack cocks an open bolt (no round is fed or ejected)
var _reload_after_rack: bool = false     # AUTO_RACK: start the reload when the rack finishes
var _quick_flag_left: float = 0.0        # seconds the quick reload request stays valid

# Active reload
var _reload_base_speed: float = 1.0
var _mag_in_time: float = 0.0       # timeline seconds at which the magazine seats
var _active_done: bool = false      # hit or missed: the window is over
var _active_buffered: bool = false  # pressed early, applied when the magazine seats
var _active_window_open: bool = false


func _init(controller: WeaponController) -> void:
	ctrl = controller
	timeline.event.connect(_on_event)
	timeline.finished.connect(_on_finished)
	timeline.cancelled.connect(_on_cancelled)


#region Lifecycle
func process(delta: float) -> void:
	timeline.tick(delta)
	slide.tick(delta)
	_update_active_window()
	if _quick_flag_left > 0.0:
		_quick_flag_left -= delta


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


## Slide pose for the current weapon:
##   open-bolt:   always rests open (loaded or not), no rack needed
##   closed-bolt: empty chamber = locked open (bolt-catch guns only), otherwise closed
func sync_slide_to_chamber() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	var open_bolt: bool = ctrl.current_weapon != null and ctrl.current_weapon.is_open_bolt
	slide.release()

	if open_bolt:
		# Cocked open-bolt guns rest with the bolt back. An uncocked one (just emptied) rests forward.
		var cocked: bool = not profile.cocks_open_bolt() or data == null or data.bolt_open
		slide.rest_value = 1.0 if cocked else 0.0
		slide.snap(1.0 if cocked else 0.0)
	else:
		slide.rest_value = 0.0
		var open: bool = data != null and not data.is_loaded and profile.locks_open_when_empty()
		slide.snap(1.0 if open else 0.0)
		if open:
			slide.lock(1.0)
	_debug_slide("sync to chamber")


func _debug_slide(label: String) -> void:
	if not debug_slide:
		return
	var data: WeaponData = ctrl.active_weapon_data
	var tree_value: Variant = null
	if anim != null and anim.weapon_animation_tree != null:
		tree_value = anim.weapon_animation_tree.get(anim.slide_blend_param)
	print("[slide] ", label,
		" | is_loaded=", data.is_loaded if data != null else "no data",
		" mag=", data.ammo_in_magazine if data != null else "-",
		" | driver value=", snappedf(slide.value, 0.01), " locked=", slide.locked,
		" apply_valid=", slide.apply.is_valid(),
		" | tree param=", tree_value)
#endregion


#region Shots
## Call after the chamber has been updated for the shot that just left the barrel.
func on_shot_cycled() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or ctrl.current_weapon == null:
		return

	# Pump / bolt-action: the action does not move on its own. The player racks.
	if is_manual_cycle() and not ctrl.current_weapon.is_open_bolt:
		return

	var interval: float = ctrl.current_weapon.get_fire_interval_seconds()
	var back: float = clampf(interval * shot_back_fraction, shot_back_min_max.x, shot_back_min_max.y)
	var ret: float = clampf(interval * shot_return_fraction, shot_return_min_max.x, shot_return_min_max.y)
	if ctrl.current_weapon.is_open_bolt:
		# The bolt rests open: it slams forward to fire, then recoils back to the open rest position.
		slide.kick(0.0, back, ret, false)
		if profile.cocks_open_bolt() and data.ammo_in_magazine <= 0:
			# Last round: nothing is left to fire, so the bolt recoils back, slams forward and stays
			# closed. The gun has to be racked open again before it can fire.
			data.bolt_open = false
			slide.rest_value = 0.0
			slide.move_to(0.0, ret, slide.return_curve, false)
	else:
		slide.kick(fire_travel, back, ret, not data.is_loaded and profile.locks_open_when_empty())
	_debug_slide("shot cycled")
#endregion


#region Reload
## Same maths the reloading state used to do inline: clip length scaled by the
## skill-adjusted reload time, or one shell's share for per-bullet weapons.
## Which reload variant the next reload is: quick (double-tap, chamber loaded), loaded, or empty.
## Call once when the reload starts; it consumes a pending quick reload request.
func pick_reload_type() -> StringName:
	var data: WeaponData = ctrl.active_weapon_data
	var quick: bool = _quick_flag_left > 0.0
	_quick_flag_left = 0.0
	if data == null:
		return RELOAD_EMPTY
	if quick and data.is_loaded:
		return RELOAD_QUICK # an empty chamber makes it an ordinary empty reload
	return RELOAD_LOADED if data.is_loaded else RELOAD_EMPTY


## The double-tap reload dumped the magazine: the next reload is a quick reload.
func request_quick_reload() -> void:
	_quick_flag_left = 0.35


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
	if reload_type == RELOAD_QUICK:
		duration *= profile.quick_reload_time_multiplier
	return duration


func start_reload(reload_type: StringName, duration: float) -> void:
	# A rack still in progress is completed first, so the chamber is consistent.
	if timeline.running and timeline.action == RACK:
		timeline.finish_now()

	_reload_committed = false
	_reload_after_rack = false
	_reset_active()

	var def: ActionDef = _get_def(reload_type)
	_reload_base_speed = _clip_speed(String(reload_type), duration)
	if anim != null:
		anim.play_action(def, _reload_base_speed, _pin_body(false))

	timeline.start(def, duration)
	# The magazine seats at the mag_in event (the end of the reload if the card has none).
	_mag_in_time = timeline.fraction_of(&"mag_in", timeline.fraction_of(&"shell_in", 1.0)) * duration


func cancel_reload() -> void:
	if timeline.running and _is_reload(timeline.action):
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
			if _active_buffered:
				_perform_active_hit()
		&"mag_out":
			pass # hook: spawn the dropped magazine (phase 7)
#endregion


#region Rack
func start_rack() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return
	_rack_cocking = ctrl.current_weapon != null and ctrl.current_weapon.is_open_bolt
	# For an open-bolt gun is_loaded only mirrors "has rounds": there is no chambered round to eject.
	_rack_chamber_was_loaded = data.is_loaded and not _rack_cocking
	_rack_chamber_spent = data.chamber_spent

	var duration: float = get_rack_duration()
	var def: ActionDef = _get_def(RACK)
	if anim != null:
		anim.play_action(def, _clip_speed("Rack", duration), _pin_body(true))
	timeline.start(def, duration)


func _on_rack_event(event_name: StringName) -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return

	match event_name:
		&"pull":
			slide.release()
			slide.move_to(1.0, _span(&"pull", &"peak"), rack_pull_curve)
		&"peak":
			# Slide fully back: this is the moment the live round (or the fired case of a
			# pump / bolt-action gun) leaves the gun.
			if _rack_chamber_was_loaded:
				ctrl.shooter.eject_casing("alive")
				data.is_loaded = false
			if _rack_chamber_spent:
				_eject_spent_case(data)
			ctrl.update_weapon_ui()
		&"release":
			if _rack_cocking:
				pass # the sear catches the bolt: it stays open
			elif data.ammo_in_magazine > 0 or not profile.locks_open_when_empty():
				slide.move_to(0.0, _span(&"release", &"closed"), rack_release_curve)
			else:
				slide.lock(1.0) # nothing to chamber: slide stays open (bolt-catch guns)
		&"closed":
			if _rack_cocking:
				data.bolt_open = true
				slide.rest_value = 1.0
				slide.release()
				ctrl.update_weapon_ui()
				return
			ctrl._feed_chamber()
			ctrl.update_weapon_ui()
			if not _rack_chamber_was_loaded and data.is_loaded:
				ctrl.send_state_event("onIdle")


## Playback speed that makes a clip last `duration` seconds (1.0 when unknown).
func _clip_speed(clip_name: String, duration: float) -> float:
	if anim == null:
		return 1.0
	var clip_len: float = anim.get_animation_length(clip_name)
	if clip_len <= 0.0:
		return 1.0
	if duration <= 0.0:
		return 100.0
	return clip_len / duration


## Fade the action layer out (no-op if its clip already ended).
func _end_clip() -> void:
	if anim != null:
		anim.end_action()


func _span(from_event: StringName, to_event: StringName) -> float:
	var f: float = timeline.fraction_of(to_event, 1.0) - timeline.fraction_of(from_event, 0.0)
	return maxf(f, 0.0) * timeline.duration
#endregion


#region Manual cycle (pump / bolt-action) and rack rules
func is_manual_cycle() -> bool:
	return profile.is_manual_cycle()


## Can the rack key do something right now?
func can_rack() -> bool:
	var data: WeaponData = ctrl.active_weapon_data
	if ctrl.current_weapon == null or data == null:
		return false
	if ctrl.current_weapon.is_open_bolt:
		# Racking cocks the bolt open. Only useful (and allowed) while it is closed.
		return profile.cocks_open_bolt() and not data.bolt_open
	if data.chamber_spent or data.is_loaded:
		return true # eject the fired case / the live round
	return data.ammo_in_magazine > 0 # chamber empty: feed one


func get_rack_duration() -> float:
	return profile.rack_time if profile.rack_time > 0.0 else ctrl.rack_lockout_time


## The fired case of a pump / bolt-action gun leaves the chamber.
func _eject_spent_case(data: WeaponData) -> void:
	data.chamber_spent = false
	ctrl.shooter.eject_casing("empty")
	var flash: Object = ctrl._muzzle_flash
	if flash != null and flash.has_method(&"eject_smoke"):
		flash.eject_smoke()
#endregion


#region Open-bolt cocking
## Can an open-bolt weapon fire? A cocked bolt is open; an emptied (or uncocked) one is closed.
func is_bolt_ready() -> bool:
	var data: WeaponData = ctrl.active_weapon_data
	if ctrl.current_weapon == null or data == null or not ctrl.current_weapon.is_open_bolt:
		return true
	return not profile.cocks_open_bolt() or data.bolt_open


## True when the reload key must not start a reload yet: an open-bolt gun with a closed bolt
## that has to be racked open first (BLOCKED or AUTO_RACK).
func needs_rack_before_reload() -> bool:
	var data: WeaponData = ctrl.active_weapon_data
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null or data == null or not weapon.is_open_bolt:
		return false
	if not profile.cocks_open_bolt() or data.bolt_open:
		return false
	return profile.reload_with_closed_bolt != WeaponActionProfile.ReloadWithClosedBolt.RELOAD_THEN_RACK


## The reload key was pressed while the bolt is closed.
func handle_reload_with_closed_bolt() -> void:
	if profile.reload_with_closed_bolt == WeaponActionProfile.ReloadWithClosedBolt.AUTO_RACK:
		_reload_after_rack = true
		ctrl.rack_slide()
		if not (timeline.running and timeline.action == RACK):
			_reload_after_rack = false # the rack could not start
		return
	hint.emit("Rack the bolt open before reloading")
	print("Rack the bolt open before reloading.")
#endregion


#region Active reload
## True while a press of the rack key would hit the window.
func is_active_window_open() -> bool:
	return _active_window_open


## Rack key pressed while reloading. Returns true if the press was used.
func try_active_rack() -> bool:
	if not _active_reload_possible():
		return false

	var now: float = timeline.elapsed
	if now < _mag_in_time - profile.active_early_seconds:
		return false # too early: ignored, no penalty
	if now > _mag_in_time + profile.active_late_seconds:
		return false # too late: the window is over

	if not _reload_committed:
		_active_buffered = true # applied the moment the magazine seats
		return true

	_perform_active_hit()
	return true


func _active_reload_possible() -> bool:
	if not timeline.running or timeline.action != RELOAD_EMPTY:
		return false
	if _active_done or not profile.active_reload_enabled:
		return false
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null or weapon.is_reload_per_bullet:
		return false
	if weapon.is_open_bolt:
		# An open-bolt gun can hit the window to cock its closed bolt as part of the reload.
		var data: WeaponData = ctrl.active_weapon_data
		return data != null and profile.cocks_open_bolt() and not data.bolt_open \
				and profile.reload_with_closed_bolt == WeaponActionProfile.ReloadWithClosedBolt.RELOAD_THEN_RACK
	return true


## The player hit the window: chamber a round now, and play the rest of the reload faster.
func _perform_active_hit() -> void:
	if _active_done:
		return
	_active_done = true
	_active_buffered = false

	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return

	var t: float = profile.active_rack_time
	slide.release()
	if ctrl.current_weapon != null and ctrl.current_weapon.is_open_bolt:
		# Cock the open bolt as part of the reload: pull it back and let the sear hold it.
		data.bolt_open = true
		slide.rest_value = 1.0
		slide.move_to(1.0, t, rack_pull_curve)
		ctrl.update_weapon_ui()
	else:
		# The same things a manual rack would do, packed into the reload.
		if data.chamber_spent:
			_eject_spent_case(data)
		ctrl._feed_chamber()
		ctrl.update_weapon_ui()
		if profile.rack_pulls_slide():
			slide.move_to(1.0, t * 0.5, rack_pull_curve)
			slide.move_to(0.0, t * 0.5, rack_release_curve, false)
		else:
			slide.move_to(0.0, t, rack_release_curve) # bolt catch: the locked slide slams shut

	timeline.time_scale = profile.active_speedup
	if anim != null:
		anim.set_action_speed(_reload_base_speed * profile.active_speedup)

	active_reload_result.emit(true)


## Opens / closes the window flag for the HUD and detects a missed window.
func _update_active_window() -> void:
	var open: bool = false
	if _active_reload_possible():
		var now: float = timeline.elapsed
		open = now >= _mag_in_time - profile.active_early_seconds and now <= _mag_in_time + profile.active_late_seconds
		if now > _mag_in_time + profile.active_late_seconds:
			_active_done = true # window passed without a press
			active_reload_result.emit(false)
	if open != _active_window_open:
		_active_window_open = open
		active_window_changed.emit(open)


func _reset_active() -> void:
	_active_done = false
	_active_buffered = false
	if _active_window_open:
		_active_window_open = false
		active_window_changed.emit(false)
#endregion


## Keep the weapon body where the aim stance put it while this action plays? Decided once, when
## the action starts. ADS and canted aim both set is_aiming.
func _pin_body(is_rack: bool) -> bool:
	if not ctrl.is_aiming:
		return false
	return profile.pin_body_in_ads_rack if is_rack else profile.pin_body_in_ads_reload


func _is_reload(action: StringName) -> bool:
	return action == RELOAD_EMPTY or action == RELOAD_LOADED or action == RELOAD_QUICK


#region Part visibility (dummy magazines and similar swaps)
func _apply_parts(source: ActionEvent) -> void:
	if source == null or anim == null:
		return
	if source.show_parts.is_empty() and source.hide_parts.is_empty():
		return
	anim.set_parts_visible(source.show_parts, source.hide_parts)


func _restore_parts() -> void:
	if anim != null:
		anim.restore_parts()
#endregion


#region Timeline signals
func _on_event(action: StringName, event_name: StringName, source: ActionEvent) -> void:
	world_event.emit(action, event_name)
	_apply_parts(source)
	match action:
		RACK:
			_on_rack_event(event_name)
		RELOAD_EMPTY, RELOAD_LOADED, RELOAD_QUICK:
			_on_reload_event(event_name)


func _on_finished(action: StringName) -> void:
	match action:
		RACK:
			_end_clip()
			_restore_parts()
			if _reload_after_rack:
				_reload_after_rack = false
				if ctrl.can_reload():
					ctrl.send_state_event("onReload")
		RELOAD_EMPTY, RELOAD_LOADED, RELOAD_QUICK:
			_commit_reload() # fallback when the clip has no mag_in event
			if _active_buffered:
				_perform_active_hit() # pressed in time, but the card has no mag_in event
			_end_clip()
			_restore_parts()
			_reset_active()
			ctrl.send_state_event("onReloadFinish")
			ctrl.finish_reload_step()


func _on_cancelled(action: StringName, _progress: float) -> void:
	match action:
		RELOAD_EMPTY, RELOAD_LOADED, RELOAD_QUICK:
			# No commit: if mag_in never happened, no ammo is transferred.
			_end_clip()
			_restore_parts()
			_reset_active()
			ctrl.send_state_event("onReloadFinish")
			ctrl.finish_reload_step()
#endregion


#region Action definitions
## The weapon's own ActionDef when it has one, otherwise the built-in default
## (ActionDef.make_default), so each weapon can be migrated one at a time.
func _get_def(id: StringName) -> ActionDef:
	if anim != null:
		var def: ActionDef = anim.get_action_def(id)
		if def != null:
			return def
	if id == RELOAD_QUICK:
		return _quick_def_from_empty()
	return ActionDef.make_default(id)


## A weapon with no quick reload card reuses its empty reload card (fades and events),
## but with the quick reload id and clip role.
func _quick_def_from_empty() -> ActionDef:
	var base: ActionDef = _get_def(RELOAD_EMPTY)
	var def: ActionDef = base.duplicate() as ActionDef
	def.id = RELOAD_QUICK
	def.clip_role = ClipResolver.ROLE_RELOAD_QUICK
	return def
#endregion
