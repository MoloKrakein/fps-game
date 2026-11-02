class_name ProjectileTracer extends Node3D
## Bullet tracer for projectile weapons.
## Add as a child of the root of the projectile scene and assign `material`
## (a ShaderMaterial using tracer.gdshader, one shared resource is fine).
## Nothing else has to change: it follows its parent, so it works with any projectile node.

## Game-wide switch: hook to your settings menu.
static var enabled_global: bool = true

@export var enabled: bool = true
## Chance that this projectile is a tracer (0.33 = roughly every third round).
@export_range(0.0, 1.0, 0.01) var tracer_chance: float = 1.0
@export var material: ShaderMaterial

@export_group("Look")
@export var color: Color = Color(1.0, 0.55, 0.15)
## HDR brightness. Above about 4 makes Glow pick it up.
@export var intensity: float = 8.0
## Width in metres. The shader keeps it at least about 1.5 pixels wide at any distance.
@export var width: float = 0.03

@export_group("Length")
## Streak length = speed * this (seconds), when the speed is known.
@export var length_seconds: float = 0.05
@export var min_length: float = 0.5
@export var max_length: float = 8.0
## > 0 = always use this length in metres instead of the speed based one.
@export var fixed_length: float = 0.0

@export_group("Start and end")
## The tracer is invisible for the first metres, so it does not block the view at the muzzle.
@export var hide_start_distance: float = 3.0
## Metres over which it then fades in.
@export var fade_in_distance: float = 5.0
## When the projectile disappears, the streak shrinks into its last position over this time.
@export var fade_out_time: float = 0.08

var _active: bool = false
var _mesh: MeshInstance3D
var _spawn_pos: Vector3
var _have_spawn: bool = false
var _prev_physics_pos: Vector3
var _measured_velocity: Vector3 = Vector3.ZERO
var _last_axis: Vector3 = Vector3.ZERO
var _last_alpha: float = 0.0


func _ready() -> void:
	_active = enabled and enabled_global and material != null and randf() <= tracer_chance
	if not _active:
		set_process(false)
		set_physics_process(false)
		return
	_prev_physics_pos = global_position


func _physics_process(delta: float) -> void:
	if delta > 0.0:
		_measured_velocity = (global_position - _prev_physics_pos) / delta
	_prev_physics_pos = global_position


func _process(_delta: float) -> void:
	if not _have_spawn:
		# First frame: the shooter has placed the projectile by now.
		_spawn_pos = global_position
		_have_spawn = true
		_create_mesh()
		return
	if _mesh == null:
		return

	var head: Vector3 = global_position
	var travelled: float = head.distance_to(_spawn_pos)
	var velocity: Vector3 = _get_velocity()
	var speed: float = velocity.length()

	var dir: Vector3
	if speed > 0.5:
		dir = velocity / speed
	elif travelled > 0.01:
		dir = (head - _spawn_pos).normalized()
	else:
		_mesh.visible = false
		return

	var length: float = fixed_length
	if length <= 0.0:
		length = clampf(speed * length_seconds, min_length, max_length) if speed > 0.5 else min_length
	length = minf(length, travelled)  # never extend behind the point where it was fired

	var alpha: float = smoothstep(hide_start_distance, hide_start_distance + maxf(fade_in_distance, 0.01), travelled)
	_mesh.visible = alpha > 0.001 and length > 0.001
	if not _mesh.visible:
		return

	_last_axis = -dir * length
	_last_alpha = alpha
	_mesh.global_position = head
	_mesh.set_instance_shader_parameter("tracer_axis", _last_axis)
	_mesh.set_instance_shader_parameter("tracer_alpha", alpha)


func _exit_tree() -> void:
	# Do not pop out: let the streak shrink into the impact point, then remove it.
	var mesh: MeshInstance3D = _mesh
	_mesh = null
	if mesh == null or not is_instance_valid(mesh):
		return
	if not mesh.is_inside_tree() or not mesh.visible or fade_out_time <= 0.0:
		mesh.queue_free()
		return
	var axis: Vector3 = _last_axis
	var alpha: float = _last_alpha
	var tween: Tween = mesh.create_tween()
	tween.tween_method(func(k: float) -> void:
		mesh.set_instance_shader_parameter("tracer_axis", axis * k)
		mesh.set_instance_shader_parameter("tracer_alpha", alpha * k), 1.0, 0.0, fade_out_time)
	tween.tween_callback(mesh.queue_free)


func _create_mesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = maxf(max_length, fixed_length) + 2.0  # the shader moves the vertices far from the quad
	_mesh.visible = false
	# Lives in the world, not under the projectile, so it can outlive it for the fade-out.
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(_mesh)
	_mesh.global_position = global_position
	_mesh.set_instance_shader_parameter("tracer_color", color)
	_mesh.set_instance_shader_parameter("tracer_intensity", intensity)
	_mesh.set_instance_shader_parameter("tracer_width", width)
	_mesh.set_instance_shader_parameter("tracer_seed", randf() * 100.0)


func _get_velocity() -> Vector3:
	var p: Node = get_parent()
	if p is RigidBody3D:
		return (p as RigidBody3D).linear_velocity
	if p is CharacterBody3D:
		return (p as CharacterBody3D).velocity
	if p != null:
		var v: Variant = p.get("velocity")  # custom projectile scripts that keep their own velocity
		if v is Vector3:
			return v
	return _measured_velocity
