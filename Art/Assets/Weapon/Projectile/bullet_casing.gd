class_name BulletCasing extends RigidBody3D

# ---- Game-wide settings (hook these to your graphics menu) ----
static var streak_enabled_global: bool = true
## 1.0 = every casing spawns. Lower = a fraction of casings is skipped (cheap "casing density" option).
static var global_density: float = 1.0
## Max casings alive at once. The oldest ones fade out first.
static var max_alive: int = 40

static var _alive: Array[BulletCasing] = []

@export var lifetime: float = 5.0
## Kept so existing scenes still load. No longer used.
@export var speed_threshold: float = 4.0

@export_group("Motion streak")
@export var motion_streak: bool = true
## ShaderMaterial using casing_streak.gdshader (one shared resource is fine).
@export var streak_material: ShaderMaterial
## Streak length = speed * this (seconds).
@export var streak_time: float = 0.03
## Below this speed (m/s) there is no streak.
@export var streak_min_speed: float = 1.0
## At this speed the streak reaches full opacity.
@export var streak_full_speed: float = 6.0
@export_range(0.0, 1.0, 0.01) var streak_alpha: float = 0.35
## Width of the streak in metres (about the casing's length, since it tumbles).
@export var streak_width: float = 0.014
@export var streak_color: Color = Color(0.95, 0.75, 0.35)

@export_group("Optimization")
## Chance that a casing is never spawned at all (0 = always spawn). Multiplied with global_density.
@export_range(0.0, 1.0, 0.01) var skip_chance: float = 0.0
## Seconds the casing takes to fade out at the end of its life (0 = pop out).
@export var fade_time: float = 0.5
## Speed (m/s) under which the casing counts as resting.
@export var rest_speed: float = 0.15
## Seconds after coming to rest before it fades out (0 = only the normal lifetime applies).
@export var despawn_after_rest: float = 2.0
## Freeze the physics body once it rests, so it costs almost nothing.
@export var freeze_when_resting: bool = true
## Meshes disappear beyond this distance in metres (0 = off).
@export var max_visible_distance: float = 30.0

var _age: float = 0.0
var _rest_time: float = 0.0
var _launched: bool = false
var _retiring: bool = false
var _fade_left: float = 0.0
var _streak: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	if streak_material != null:
		_create_streak()
	for node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m == _streak:
			continue
		_meshes.append(m)
	_apply_visibility_range()

	_alive.append(self)
	_enforce_cap()


func _exit_tree() -> void:
	_alive.erase(self)


func _physics_process(delta: float) -> void:
	_age += delta

	if _retiring:
		_fade_step(delta)
		return

	if _age >= lifetime - fade_time:
		retire()
		return

	if _launched:
		_track_rest(delta)
	_update_streak()


## Old entry point, kept so the current shooter code keeps working.
func eject(linear_force: Vector3, angular_force: Vector3) -> void:
	if _should_skip():
		queue_free()
		return
	_launched = true
	sleeping = false
	apply_central_impulse(linear_force)
	apply_torque_impulse(angular_force)


## New entry point. port = the ejection port node (its basis defines the direction).
## inherited_velocity = weapon / player velocity. index = position in a burst (staggers the release).
func eject_with_profile(port: Node3D, profile: CasingEjectionProfile,
		inherited_velocity: Vector3 = Vector3.ZERO, index: int = 0) -> void:
	if _should_skip():
		queue_free()
		return
	_apply_physics(profile)

	var delay: float = profile.burst_stagger * float(index)
	if delay > 0.0:
		freeze = true
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree():
			return
		freeze = false

	if profile.position_jitter > 0.0:
		global_position += _random_unit() * randf() * profile.position_jitter

	var dir_local: Vector3 = _random_in_cone(profile.direction, deg_to_rad(profile.spread_degrees))
	var dir_world: Vector3 = (port.global_basis * dir_local).normalized()
	var speed: float = randf_range(profile.speed_min, profile.speed_max) * profile.power

	var spin_dir: Vector3
	if profile.spin_axis.length() > 0.001:
		spin_dir = port.global_basis * _random_in_cone(profile.spin_axis, deg_to_rad(profile.spin_axis_jitter_degrees))
	else:
		spin_dir = _random_unit()

	_launched = true
	sleeping = false
	linear_velocity = dir_world * speed + inherited_velocity * profile.inherit_velocity
	angular_velocity = spin_dir.normalized() * randf_range(profile.spin_min, profile.spin_max)


## Starts the fade-out, then removes the casing.
func retire() -> void:
	if _retiring:
		return
	_retiring = true
	if _streak != null:
		_streak.visible = false
	if fade_time <= 0.0:
		queue_free()
		return
	_fade_left = fade_time


func _fade_step(delta: float) -> void:
	_fade_left -= delta
	var t: float = 1.0 - clampf(_fade_left / fade_time, 0.0, 1.0)
	for m in _meshes:
		if is_instance_valid(m):
			m.transparency = t
	if _fade_left <= 0.0:
		queue_free()


func _track_rest(delta: float) -> void:
	var resting: bool = sleeping or freeze \
			or (linear_velocity.length() < rest_speed and angular_velocity.length() < rest_speed * 5.0)
	if resting:
		_rest_time += delta
		if freeze_when_resting and not freeze and _rest_time > 0.3:
			freeze = true
		if despawn_after_rest > 0.0 and _rest_time >= despawn_after_rest:
			retire()
	else:
		_rest_time = 0.0


func _should_skip() -> bool:
	return randf() > global_density * (1.0 - skip_chance)


func _apply_physics(profile: CasingEjectionProfile) -> void:
	mass = profile.mass
	linear_damp = profile.linear_damp
	angular_damp = profile.angular_damp
	gravity_scale = profile.gravity_scale
	var mat := PhysicsMaterial.new()
	mat.bounce = profile.bounce
	mat.friction = profile.friction
	physics_material_override = mat
	if profile.lifetime > 0.0:
		lifetime = profile.lifetime


func _apply_visibility_range() -> void:
	if max_visible_distance <= 0.0:
		return
	var all: Array[MeshInstance3D] = _meshes.duplicate()
	if _streak != null:
		all.append(_streak)
	for m in all:
		m.visibility_range_end = max_visible_distance
		m.visibility_range_end_margin = 2.0
		m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _create_streak() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_streak = MeshInstance3D.new()
	_streak.mesh = quad
	_streak.material_override = streak_material
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.extra_cull_margin = 4.0  # the shader moves the vertices far from the quad's own bounds
	_streak.visible = false
	add_child(_streak)
	_streak.set_instance_shader_parameter("streak_color", streak_color)
	_streak.set_instance_shader_parameter("streak_width", streak_width)


func _update_streak() -> void:
	if _streak == null:
		return
	var v: Vector3 = linear_velocity
	var k: float = 0.0
	if motion_streak and streak_enabled_global and not freeze:
		k = smoothstep(streak_min_speed, streak_full_speed, v.length())
	_streak.visible = k > 0.001
	if _streak.visible:
		_streak.set_instance_shader_parameter("streak_axis", -v * streak_time)
		_streak.set_instance_shader_parameter("streak_alpha", streak_alpha * k)


static func _enforce_cap() -> void:
	var active: Array = _alive.filter(func(c: BulletCasing) -> bool:
		return is_instance_valid(c) and not c._retiring)
	var extra: int = active.size() - max_alive
	for i in range(maxi(extra, 0)):
		(active[i] as BulletCasing).retire()


static func _random_unit() -> Vector3:
	var v := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if v.length() < 0.001:
		return Vector3.UP
	return v.normalized()


static func _random_in_cone(axis: Vector3, angle: float) -> Vector3:
	var a: Vector3 = axis.normalized()
	var helper: Vector3 = Vector3.UP if absf(a.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var u: Vector3 = a.cross(helper).normalized()
	var w: Vector3 = a.cross(u)
	var phi: float = randf() * TAU
	var theta: float = angle * randf()
	return (a * cos(theta) + (u * cos(phi) + w * sin(phi)) * sin(theta)).normalized()