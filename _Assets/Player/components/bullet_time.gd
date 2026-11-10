class_name BulletTime extends Node
## Slows the whole world while the player and their gun stay in real time.
##
## It only owns the global clock (Engine.time_scale) and the ramp. Player-side
## scripts convert their delta back with PlayerTime (see BULLET_TIME_PATCHES.md).

signal activated
signal deactivated
## 0..1 after easing. 0 = normal speed, 1 = full bullet time.
signal intensity_changed(intensity: float)
signal focus_changed(current: float, maximum: float)

@export_group("Input")
## Defaults to the existing alternate-aim action, preserving the debug toggle button.
## The action is registered at runtime if it does not exist, so project.godot stays untouched.
@export var input_action: StringName = &"combat_alt_aim"
@export var default_key: Key = KEY_F
## false = hold to stay in bullet time, true = press to toggle.
@export var toggle_mode: bool = true

@export_group("Time")
## Engine.time_scale at full intensity. About 0.05 - 0.15 reads as "almost standing still".
## Do not go near 0.005: deltas become so small that springs and physics misbehave.
@export_range(0.02, 1.0, 0.01) var world_time_scale: float = 0.12
## Player movement speed as a share of real time (gun, aim and camera are always 1.0).
@export_range(0.05, 1.0, 0.05) var movement_ratio: float = 1.0
## Ramp times are in REAL seconds.
@export_range(0.01, 2.0, 0.01) var ramp_in_time: float = 0.12
@export_range(0.01, 2.0, 0.01) var ramp_out_time: float = 0.3

@export_group("Focus")
## Meter that drains while bullet time is on and refills while it is off.
@export var use_focus: bool = true
@export var max_focus: float = 100.0
@export var drain_per_second: float = 20.0
@export var regen_per_second: float = 12.0
@export var min_focus_to_start: float = 15.0

@export_group("Screen effect")
## CanvasItem with the post_processing_layer ShaderMaterial. Optional.
## If empty, the first node in the group "bullet_time_fx" is used.
@export var effect_target: CanvasItem
@export_range(0.0, 2.0, 0.01) var effect_saturation: float = 0.45
@export_range(0.0, 0.02, 0.001) var effect_chromatic_aberration: float = 0.006
@export_range(0.0, 1.0, 0.01) var effect_vignette_strength: float = 0.4

# Shader defaults of post_processing_layer.gdshader, used when the material has no override yet.
const BASE_SATURATION: float = 0.92
const BASE_CHROMATIC: float = 0.0015
const BASE_VIGNETTE: float = 0.16

var focus: float = 0.0

var _wants_active: bool = false
var _intensity: float = 0.0 # raw 0..1 ramp value
var _last_usec: int = 0
var _effect_material: ShaderMaterial
var _base_saturation: float = BASE_SATURATION
var _base_chromatic: float = BASE_CHROMATIC
var _base_vignette: float = BASE_VIGNETTE


func _ready() -> void:
	_register_input_action()
	focus = max_focus
	_last_usec = Time.get_ticks_usec()
	PlayerTime.reset()
	_resolve_effect_material()
	focus_changed.emit(focus, max_focus)


func _exit_tree() -> void:
	# Never leave the game slowed after the player is removed or the scene reloads.
	Engine.time_scale = 1.0
	PlayerTime.reset()
	_apply_screen_effect(0.0)


func _process(_delta: float) -> void:
	var dt: float = _real_delta()
	_handle_input()
	_update_focus(dt)

	var target: float = 1.0 if _wants_active else 0.0
	var ramp_time: float = ramp_in_time if target > _intensity else ramp_out_time
	var previous: float = _intensity
	_intensity = move_toward(_intensity, target, dt / maxf(ramp_time, 0.01))
	if not is_equal_approx(previous, _intensity):
		_apply()


#region Public API
func activate() -> void:
	if _wants_active:
		return
	if use_focus and focus < min_focus_to_start:
		return
	_wants_active = true
	activated.emit()


func deactivate() -> void:
	if not _wants_active:
		return
	_wants_active = false
	deactivated.emit()


## Call when the player dies or a menu opens: leaves bullet time at once, no ramp.
func cancel_immediately() -> void:
	_wants_active = false
	_intensity = 0.0
	_apply()


func is_active() -> bool:
	return _wants_active


## Eased 0..1.
func get_intensity() -> float:
	return smoothstep(0.0, 1.0, _intensity)
#endregion


#region Internals
## Real elapsed time, independent of Engine.time_scale and capped so a hitch cannot jump the ramp.
func _real_delta() -> float:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_usec) / 1_000_000.0
	_last_usec = now
	return minf(dt, 0.1)


func _handle_input() -> void:
	if not InputMap.has_action(input_action):
		return
	if toggle_mode:
		if Input.is_action_just_pressed(input_action):
			if _wants_active:
				deactivate()
			else:
				activate()
	else:
		if Input.is_action_just_pressed(input_action):
			activate()
		elif Input.is_action_just_released(input_action):
			deactivate()


func _update_focus(dt: float) -> void:
	if not use_focus:
		return
	var previous: float = focus
	if _wants_active:
		focus = maxf(focus - drain_per_second * dt, 0.0)
		if focus <= 0.0:
			deactivate()
	else:
		focus = minf(focus + regen_per_second * dt, max_focus)
	if not is_equal_approx(previous, focus):
		focus_changed.emit(focus, max_focus)


func _apply() -> void:
	var eased: float = get_intensity()
	Engine.time_scale = lerpf(1.0, world_time_scale, eased)
	PlayerTime.movement_scale = lerpf(1.0, movement_ratio, eased)
	_apply_screen_effect(eased)
	intensity_changed.emit(eased)


func _register_input_action() -> void:
	if InputMap.has_action(input_action):
		return
	InputMap.add_action(input_action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = default_key
	InputMap.action_add_event(input_action, event)


func _resolve_effect_material() -> void:
	var target: CanvasItem = effect_target
	if target == null:
		target = get_tree().get_first_node_in_group(&"bullet_time_fx") as CanvasItem
	if target == null:
		return
	_effect_material = target.material as ShaderMaterial
	if _effect_material == null:
		return
	_base_saturation = _read_param("saturation", BASE_SATURATION)
	_base_chromatic = _read_param("chromatic_aberration", BASE_CHROMATIC)
	_base_vignette = _read_param("vignette_strength", BASE_VIGNETTE)


func _read_param(param: StringName, fallback: float) -> float:
	var value: Variant = _effect_material.get_shader_parameter(param)
	return float(value) if value != null else fallback


func _apply_screen_effect(eased: float) -> void:
	if _effect_material == null:
		return
	_effect_material.set_shader_parameter(&"saturation", lerpf(_base_saturation, effect_saturation, eased))
	_effect_material.set_shader_parameter(&"chromatic_aberration", lerpf(_base_chromatic, effect_chromatic_aberration, eased))
	_effect_material.set_shader_parameter(&"vignette_strength", lerpf(_base_vignette, effect_vignette_strength, eased))
#endregion
