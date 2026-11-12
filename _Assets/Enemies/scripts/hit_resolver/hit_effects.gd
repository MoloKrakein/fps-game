class_name HitEffects
extends RefCounted
## Small procedural hit effects, so enemies react visibly without needing any art assets.
## Replace the body of spawn_flesh_hit() with your own particle scene later if you like.

static var _blood_mesh: SphereMesh


## A short spray of droplets. Headshots spray more and further.
## `direction` is the way the bullet was travelling, `normal` the surface normal at the impact.
static func spawn_flesh_hit(
		root: Node,
		hit_position: Vector3,
		normal: Vector3,
		direction: Vector3,
		is_headshot: bool = false
) -> void:
	if root == null or not root.is_inside_tree():
		return

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 1.0
	particles.amount = 28 if is_headshot else 12
	particles.lifetime = 0.5
	particles.mesh = _get_blood_mesh()
	# Most of the spray continues along the shot, some bounces back off the body.
	var spray: Vector3 = (direction.normalized() * 0.7 + normal.normalized() * 0.5)
	particles.direction = spray.normalized() if spray.length_squared() > 0.0001 else Vector3.UP
	particles.spread = 50.0 if is_headshot else 35.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 7.0 if is_headshot else 4.5
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.4 if is_headshot else 1.1

	root.add_child(particles)
	particles.global_position = hit_position
	particles.emitting = true
	root.get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


static func _get_blood_mesh() -> SphereMesh:
	if _blood_mesh == null:
		_blood_mesh = SphereMesh.new()
		_blood_mesh.radius = 0.025
		_blood_mesh.height = 0.05
		_blood_mesh.radial_segments = 6
		_blood_mesh.rings = 3
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.55, 0.02, 0.02)
		material.roughness = 0.35
		_blood_mesh.material = material
	return _blood_mesh
