class_name GasBurst extends GPUParticles3D
## Small gas puff for the muzzle or the ejection port.
## Put it on a GPUParticles3D whose draw pass is a QuadMesh with a StandardMaterial3D
## (billboard "Particles", flipbook frames, vertex colour as albedo). MuzzleFlash calls play() on every shot.
##
## Cheap by design: about a dozen particles, one texture sample each, no custom shader.
## Between shots the emitter idles at amount_ratio 0.

enum GasMode {
	FORWARD,  ## leaves along the barrel (-Z), together with the bullet
	EXPAND,   ## stays at the spot and just swells
	SIDE,     ## leaves to the side (+X / -X), like a muzzle brake or an open ejection port
	CUSTOM,   ## leaves along custom_direction
}
enum VentSide { RIGHT, LEFT, BOTH }

@export var enabled: bool = true
@export var mode: GasMode = GasMode.EXPAND
## SIDE only. BOTH adds a mirrored copy of this node, so it vents to both sides.
@export var side: VentSide = VentSide.BOTH
## CUSTOM only. Direction in this node's local space.
@export var custom_direction: Vector3 = Vector3.UP
## SIDE only. How much the sideways stream is lifted up (0 = flat, 1 = 45 degrees up).
@export_range(0.0, 2.0, 0.05) var side_lift: float = 0.15

@export_group("Motion")
## How long one puff lasts, in seconds. The flipbook plays once over this time.
@export_range(0.05, 1.0, 0.01) var duration: float = 0.25
## Quick fine tuning: 2.0 plays everything twice as fast (half the duration, same reach).
@export_range(0.25, 4.0, 0.05) var tempo: float = 1.0
## How far the gas travels before it stops, in metres. EXPAND uses a tenth of it.
@export_range(0.0, 3.0, 0.01) var reach: float = 0.5
@export_range(0.0, 180.0, 1.0) var spread_degrees: float = 14.0
## Slow upward drift in m/s^2.
@export var drift_up: float = 0.08

@export_group("Shot")
## Puffs per shot (each one is a particle).
@export_range(1, 8) var puffs_per_shot: int = 3
## Seconds after the shot before the gas appears.
@export var delay: float = 0.008

@export_group("Look")
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.35
@export var color: Color = Color(0.92, 0.94, 1.0)
## Size multiplier on top of the mesh size.
@export var size: float = 1.0
## Size at birth compared with the final size (0.4 = starts at 40%).
@export_range(0.1, 1.0, 0.05) var grow_from: float = 0.4

var _material: ParticleProcessMaterial
var _burst_tween: Tween
var _twin: GasBurst
var _is_twin: bool = false


func _ready() -> void:
	_is_twin = has_meta("gas_twin")
	lifetime = maxf(duration / tempo, 0.05)
	one_shot = false
	explosiveness = 0.0
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Own copy of the process material, so several GasBursts can share one resource.
	if process_material is ParticleProcessMaterial:
		_material = (process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		process_material = _material
	_apply()

	amount_ratio = 0.0
	emitting = true

	if mode == GasMode.SIDE and side == VentSide.BOTH and not _is_twin:
		_make_twin()


## Call on every shot.
func play() -> void:
	if not enabled:
		return
	if _twin != null and is_instance_valid(_twin):
		_twin.play()
	if delay > 0.0:
		var wait: Tween = create_tween()
		wait.tween_interval(delay)
		wait.tween_callback(_burst)
	else:
		_burst()


## Used by MuzzleFlash to apply the weapon's smoke color and scale.
func set_look(new_color: Color, new_size: float) -> void:
	color = new_color
	size = new_size
	_apply()
	if _twin != null:
		_twin.set_look(new_color, new_size)


## Apply consistent motion settings from the weapon resource.
func set_motion(new_duration: float, new_tempo: float, new_reach: float,
		new_spread_degrees: float, new_lift: float, new_puffs: int,
		new_delay: float, new_opacity: float) -> void:
	duration = clampf(new_duration, 0.05, 1.0)
	tempo = clampf(new_tempo, 0.25, 4.0)
	reach = clampf(new_reach, 0.0, 3.0)
	spread_degrees = clampf(new_spread_degrees, 0.0, 180.0)
	side_lift = clampf(new_lift, 0.0, 2.0)
	drift_up = clampf(new_lift * 0.2, 0.0, 0.2)
	puffs_per_shot = clampi(new_puffs, 1, 8)
	delay = clampf(new_delay, 0.0, 0.05)
	opacity = clampf(new_opacity, 0.0, 1.0)
	lifetime = maxf(duration / tempo, 0.05)
	_apply()
	if _twin != null:
		_twin.set_motion(new_duration, new_tempo, new_reach, new_spread_degrees,
				new_lift, new_puffs, new_delay, new_opacity)


func _burst() -> void:
	var rate: float = float(amount) / maxf(lifetime, 0.01)            # particles per second at full ratio
	var seconds: float = float(puffs_per_shot) / maxf(rate, 1.0)
	amount_ratio = 1.0
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_interval(seconds)
	_burst_tween.tween_callback(func() -> void: amount_ratio = 0.0)


func _apply() -> void:
	if _material == null:
		return
	var life: float = maxf(duration / tempo, 0.05)
	var travel: float = reach * (0.1 if mode == GasMode.EXPAND else 1.0)
	# ParticleProcessMaterial damping is a constant deceleration. With it set so the gas stops at
	# 60% of its life, the distance covered is 0.3 * speed * life, so speed = reach / (0.3 * life).
	var speed: float = travel / (0.3 * life)
	var decel: float = speed / (0.6 * life)

	_material.direction = _direction()
	_material.spread = 180.0 if mode == GasMode.EXPAND else spread_degrees
	_material.initial_velocity_min = speed * 0.75
	_material.initial_velocity_max = speed * 1.25
	_material.damping_min = decel * 0.9
	_material.damping_max = decel * 1.1
	_material.gravity = Vector3(0.0, drift_up, 0.0)

	_material.angle_min = 0.0
	_material.angle_max = 360.0
	_material.scale_min = size * 0.8
	_material.scale_max = size * 1.2
	_material.scale_curve = VfxCurves.grow_curve(grow_from)
	_material.color = Color(color.r, color.g, color.b, color.a * opacity)
	_material.color_ramp = VfxCurves.fade_ramp()
	# the flipbook plays once over the particle's life
	_material.anim_speed_min = 1.0
	_material.anim_speed_max = 1.0
	set_instance_shader_parameter("gas_color", color)
	set_instance_shader_parameter("gas_opacity", opacity)
	set_instance_shader_parameter("gas_size", size)
	set_instance_shader_parameter(
		"vent_direction",
		-1.0 if side == VentSide.LEFT else 1.0
	)


func _direction() -> Vector3:
	match mode:
		GasMode.FORWARD:
			return Vector3(0.0, 0.0, -1.0)
		GasMode.SIDE:
			var sign_x: float = -1.0 if side == VentSide.LEFT else 1.0
			return Vector3(sign_x, side_lift, 0.0).normalized()
		GasMode.CUSTOM:
			return custom_direction.normalized() if custom_direction.length() > 0.001 else Vector3.UP
	return Vector3.UP  # EXPAND: the 180 degree spread covers every direction


func _make_twin() -> void:
	var twin: GasBurst = duplicate() as GasBurst
	twin.set_meta("gas_twin", true)
	twin.side = VentSide.LEFT
	twin.name = String(name) + "Twin"
	_twin = twin
	get_parent().add_child.call_deferred(twin)
