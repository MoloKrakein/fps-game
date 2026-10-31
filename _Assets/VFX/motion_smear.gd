class_name MotionSmear extends Node
## Optional, very subtle motion blur for (a) ejected casings and (b) the weapon model during recoil.
## Add as a child of the casing scene root or of the weapon model root and assign overlay_material.
## It puts the smear shader on every MeshInstance3D under `target` as a material_overlay,
## so the original materials are not touched.

enum Kind { CASING, WEAPON }

## Game-wide switches: hook these to your settings menu, e.g. MotionSmear.casing_blur_enabled = false
static var casing_blur_enabled: bool = true
static var weapon_blur_enabled: bool = true

@export var kind: Kind = Kind.CASING
## Per-instance switch (on top of the game-wide one)
@export var enabled: bool = true
## ShaderMaterial using motion_smear.gdshader (one shared resource is fine)
@export var overlay_material: ShaderMaterial
## Node whose meshes get the smear. Empty = parent.
@export var target: Node3D
## WEAPON only: measure motion relative to the camera, so walking / turning don't blur the gun
@export var relative_to_camera: bool = true

@export_group("Look")
## Shutter time in seconds. Bigger = longer streak.
@export var blur_length: float = 0.03
## Below this speed (m/s) there is no blur
@export var min_speed: float = 1.0
## At this speed (m/s) the blur reaches full opacity
@export var max_speed: float = 8.0
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.3
@export var tint: Color = Color(0.8, 0.6, 0.25)
## Velocity smoothing, 0 = raw
@export var smoothing: float = 25.0

@export_group("Debug")
## Prints the highest measured speed once per second. Use it to calibrate min_speed / max_speed.
@export var debug_print_speed: bool = false

var _target: Node3D
var _meshes: Array[MeshInstance3D] = []
var _old_overlays: Dictionary = {}
var _active: bool = false
var _have_prev: bool = false
var _prev_pos: Vector3
var _vel: Vector3 = Vector3.ZERO
var _pulse_vel: Vector3 = Vector3.ZERO
var _pulse_left: float = 0.0
var _pulse_total: float = 0.0
var _peak_speed: float = 0.0
var _debug_time: float = 0.0


func _ready() -> void:
	_target = target if target != null else get_parent() as Node3D
	if _target == null or overlay_material == null:
		push_warning("MotionSmear: needs a Node3D target and an overlay_material.")
		set_process(false)
		return
	for n in _target.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)
	if _target is MeshInstance3D:
		_meshes.append(_target as MeshInstance3D)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var want := _is_enabled()
	if want != _active:
		_set_active(want)
	if not _active:
		return

	var raw := _measure_velocity(delta)
	var k := 1.0 if smoothing <= 0.0 else 1.0 - exp(-smoothing * delta)
	_vel = _vel.lerp(raw, k)

	var shown := _vel
	if _pulse_left > 0.0:
		_pulse_left -= delta
		shown += _pulse_vel * clampf(_pulse_left / _pulse_total, 0.0, 1.0)

	if debug_print_speed:
		_peak_speed = maxf(_peak_speed, shown.length())
		_debug_time += delta
		if _debug_time >= 1.0:
			print("MotionSmear[", _target.name, "] peak speed: ", snappedf(_peak_speed, 0.01), " m/s")
			_peak_speed = 0.0
			_debug_time = 0.0

	for m in _meshes:
		if is_instance_valid(m):
			m.set_instance_shader_parameter("blur_velocity", shown)


## Fakes a quick kick of motion, e.g. when a shot fires. world_velocity is in m/s, world space.
## Works even if the measured speed is too small to notice.
func pulse(world_velocity: Vector3, duration: float = 0.06) -> void:
	_pulse_vel = world_velocity
	_pulse_left = duration
	_pulse_total = maxf(duration, 0.001)


func _is_enabled() -> bool:
	if not enabled or not _target.is_visible_in_tree():
		return false
	return casing_blur_enabled if kind == Kind.CASING else weapon_blur_enabled


func _measure_velocity(delta: float) -> Vector3:
	var cam: Camera3D = null
	if kind == Kind.WEAPON and relative_to_camera:
		cam = get_viewport().get_camera_3d()

	var pos: Vector3 = _target.global_position
	if cam != null:
		pos = cam.global_transform.affine_inverse() * pos  # camera space

	var result := Vector3.ZERO
	if _have_prev:
		result = (pos - _prev_pos) / delta
		if cam != null:
			result = cam.global_basis * result  # back to world space for the shader
	_prev_pos = pos
	_have_prev = true
	return result


func _set_active(on: bool) -> void:
	_active = on
	_have_prev = false
	_vel = Vector3.ZERO
	for m in _meshes:
		if not is_instance_valid(m):
			continue
		if on:
			_old_overlays[m] = m.material_overlay
			m.set_instance_shader_parameter("blur_length", blur_length)
			m.set_instance_shader_parameter("speed_range", Vector2(min_speed, max_speed))
			m.set_instance_shader_parameter("opacity", opacity)
			m.set_instance_shader_parameter("tint", tint)
			m.set_instance_shader_parameter("blur_velocity", Vector3.ZERO)
			m.material_overlay = overlay_material
		else:
			m.material_overlay = _old_overlays.get(m)
	if not on:
		_old_overlays.clear()