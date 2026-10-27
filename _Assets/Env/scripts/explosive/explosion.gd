class_name Explosion extends RefCounted
## Everything that happens when something blows up. Projectiles, barrels and
## grenades all call Explosion.detonate() so they behave identically.
##
## What it does beyond a plain radius check:
##  - distance is measured to the closest point of the target's collision bounds
##    (not its origin, which is usually at the feet)
##  - cover: walls block the blast (3 sample rays per target, partial exposure)
##  - core radius + falloff curve for damage AND force
##  - rigid bodies get an off-centre impulse (spin) with an upward bias
##  - active-ragdoll characters with several bone bodies get mass-weighted impulses
##  - characters can implement apply_explosion_knockback(impulse, origin)
##  - anything in group "explosion_listener" gets on_explosion(origin, data)

const LISTENER_GROUP: StringName = &"explosion_listener"
const MAX_RESULTS: int = 128


class Victim:
	var health: HealthComponent
	var actor: Node3D
	var bodies: Array[PhysicsBody3D] = [] # RigidBody3D props and PhysicalBone3D ragdoll bones
	var bounds: AABB
	var has_bounds: bool = false


## source: node used for world access, excluded from cover checks and never a victim.
## attacker: who gets credit for damage (and self-damage rules).
static func detonate(source: Node3D, origin: Vector3, data: ExplosionData, attacker: Node3D = null) -> void:
	if source == null or data == null:
		return

	_spawn_effects(source, origin, data)
	source.get_tree().call_group(LISTENER_GROUP, "on_explosion", origin, data)

	if data.radius <= 0.0:
		return

	var space: PhysicsDirectSpaceState3D = source.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = data.radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = data.target_mask
	var hits: Array = space.intersect_shape(query, MAX_RESULTS)

	# Merge every collider belonging to the same thing (hitboxes, ragdoll bones...).
	var victims: Dictionary = {}
	for hit: Dictionary in hits:
		var collider: Node = hit.get("collider") as Node
		if collider == null:
			continue
		var health: HealthComponent = _find_health_component(collider)
		var body: PhysicsBody3D = _find_physics_body(collider)
		var actor: Node3D = _find_actor(health) if health else body
		if actor == null or actor == source:
			continue

		var key: Node = health if health else body
		var victim: Victim = victims.get(key)
		if victim == null:
			victim = Victim.new()
			victim.health = health
			victim.actor = actor
			victims[key] = victim
		if body and not victim.bodies.has(body):
			victim.bodies.append(body)

		var shape_bounds: AABB = _hit_shape_bounds(hit, collider)
		if shape_bounds.size != Vector3.ZERO:
			victim.bounds = shape_bounds if not victim.has_bounds else victim.bounds.merge(shape_bounds)
			victim.has_bounds = true

	var exclude: Array[RID] = []
	if source is CollisionObject3D:
		exclude.append((source as CollisionObject3D).get_rid())

	for victim: Victim in victims.values():
		if not victim.has_bounds:
			victim.bounds = AABB(victim.actor.global_position - Vector3.ONE * 0.25, Vector3.ONE * 0.5)
		_affect(source.get_tree(), space, origin, data, attacker, victim, exclude)


static func _affect(
		tree: SceneTree,
		space: PhysicsDirectSpaceState3D,
		origin: Vector3,
		data: ExplosionData,
		attacker: Node3D,
		victim: Victim,
		exclude: Array[RID]
	) -> void:
	var closest: Vector3 = origin.clamp(victim.bounds.position, victim.bounds.end)
	var distance: float = origin.distance_to(closest)
	if distance > data.radius:
		return # sphere touched the box's bounding corner only

	var exposure: float = _exposure(space, origin, data, victim, exclude)
	if exposure <= 0.0:
		return

	var t: float = clampf((distance - data.core_radius) / maxf(data.radius - data.core_radius, 0.001), 0.0, 1.0)
	var falloff_scale: float = 1.0 - data.falloff * pow(t, data.falloff_curve)
	var power: float = falloff_scale * exposure

	var to_center: Vector3 = victim.bounds.get_center() - origin
	var direction: Vector3 = to_center.normalized() if to_center.length_squared() > 0.001 else Vector3.UP

	# --- Damage ---
	var killed_by_blast: bool = false
	if victim.health and not _is_friendly(attacker, victim.actor):
		var amount: float = data.damage * power
		if not _is_living(victim.actor):
			amount *= data.object_damage_multiplier
		if victim.actor == attacker:
			amount *= data.self_damage_multiplier
		if amount > 0.0:
			var was_alive: bool = victim.health.is_alive
			var info: DamageInfo = DamageInfo.new(amount, attacker, "explosive")
			info.armor_penetration = data.armor_penetration
			info.bypass_evasion = true # a blast can't be dodged
			info.impact_direction = direction
			info.impact_position = origin
			victim.health.take_damage_with_info(info)
			killed_by_blast = was_alive and not victim.health.is_alive

	# A kill switches the enemy to its ragdoll. Wait one physics frame so the bones are
	# simulating before they get pushed, otherwise the corpse just drops.
	if killed_by_blast:
		await tree.physics_frame

	# --- Knockback ---
	var push: float = data.force * power
	if push <= 0.0:
		return

	var launch_direction: Vector3 = (direction + Vector3.UP * data.upward_bias).normalized()

	# Characters (CharacterBody3D etc.) opt in by implementing this method.
	if is_instance_valid(victim.actor) and victim.actor.has_method("apply_explosion_knockback"):
		victim.actor.call("apply_explosion_knockback", launch_direction * push, origin)

	# Physics bodies (props and ragdoll bones). The impulse is split by mass so a ragdoll made
	# of many bones gets the same total push as a single prop.
	var bodies: Array[PhysicsBody3D] = []
	var total_mass: float = 0.0
	for body: PhysicsBody3D in victim.bodies:
		if is_instance_valid(body):
			bodies.append(body)
			total_mass += _body_mass(body)
	total_mass = maxf(total_mass, 0.001)

	for body: PhysicsBody3D in bodies:
		var to_body: Vector3 = body.global_position - origin
		var body_direction: Vector3 = to_body.normalized() if to_body.length_squared() > 0.001 else Vector3.UP
		body_direction = (body_direction + Vector3.UP * data.upward_bias).normalized()
		var impulse: Vector3 = body_direction * push * (_body_mass(body) / total_mass)
		# Hit the side facing the blast, off-centre, so single props tumble.
		var offset: Vector3 = Vector3.ZERO
		if bodies.size() == 1:
			offset = closest - body.global_position
		_push_body(body, impulse, offset)


## 0..1, the fraction of sample points on the target the blast can actually reach.
static func _exposure(
		space: PhysicsDirectSpaceState3D,
		origin: Vector3,
		data: ExplosionData,
		victim: Victim,
		exclude: Array[RID]
	) -> float:
	if not data.requires_line_of_sight:
		return 1.0

	var b: AABB = victim.bounds
	var c: Vector3 = b.get_center()
	var points: Array[Vector3] = [
		c,
		Vector3(c.x, b.position.y + b.size.y * 0.85, c.z),
		Vector3(c.x, b.position.y + b.size.y * 0.15, c.z),
	]

	var reached: int = 0
	for point: Vector3 in points:
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, point, data.blocker_mask, exclude)
		var result: Dictionary = space.intersect_ray(ray)
		if result.is_empty() or _belongs_to(result.get("collider") as Node, victim.actor):
			reached += 1
	return float(reached) / float(points.size())


#region Effects
static func _spawn_effects(source: Node3D, origin: Vector3, data: ExplosionData) -> void:
	var root: Node = source.get_tree().current_scene
	if root == null:
		return

	if data.effect_scene:
		var fx: Node3D = data.effect_scene.instantiate() as Node3D
		if fx:
			root.add_child(fx)
			fx.global_position = origin
			return

	# Placeholder fireball
	var ball: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	ball.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
	ball.material_override = mat
	root.add_child(ball)
	ball.global_position = origin
	ball.scale = Vector3.ONE * 0.2
	var tween: Tween = ball.create_tween().set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * data.radius * 0.8, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ball.queue_free)

	# Flash light
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = data.radius * 2.0
	light.light_energy = 8.0
	root.add_child(light)
	light.global_position = origin
	var light_tween: Tween = light.create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.3)
	light_tween.tween_callback(light.queue_free)
#endregion


#region Lookup helpers
static func _hit_shape_bounds(hit: Dictionary, collider: Node) -> AABB:
	var object: CollisionObject3D = collider as CollisionObject3D
	if object == null:
		return AABB()
	var owner_id: int = object.shape_find_owner(int(hit.get("shape", 0)))
	var shape_node: CollisionShape3D = object.shape_owner_get_owner(owner_id) as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return AABB()
	var debug_mesh: Mesh = shape_node.shape.get_debug_mesh()
	if debug_mesh == null:
		return AABB()
	return shape_node.global_transform * debug_mesh.get_aabb()


static func _is_friendly(attacker: Node3D, target: Node3D) -> bool:
	return attacker is BaseEnemy and target is BaseEnemy


static func _is_living(target: Node3D) -> bool:
	return target is BaseEnemy or target is PlayerController


static func _belongs_to(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


static func _find_health_component(node: Node) -> HealthComponent:
	var current: Node = node
	while current != null:
		var health_component: HealthComponent = current as HealthComponent
		if health_component:
			return health_component
		var child_health: HealthComponent = current.get_node_or_null("HealthComponent") as HealthComponent
		if child_health:
			return child_health
		current = current.get_parent()
	return null


static func _find_physics_body(node: Node) -> PhysicsBody3D:
	var current: Node = node
	while current != null:
		if current is RigidBody3D or current is PhysicalBone3D:
			return current as PhysicsBody3D
		current = current.get_parent()
	return null


static func _body_mass(body: PhysicsBody3D) -> float:
	if body is RigidBody3D:
		return (body as RigidBody3D).mass
	if body is PhysicalBone3D:
		return (body as PhysicalBone3D).mass
	return 1.0


static func _push_body(body: PhysicsBody3D, impulse: Vector3, offset: Vector3) -> void:
	if body is RigidBody3D:
		(body as RigidBody3D).apply_impulse(impulse, offset)
	elif body is PhysicalBone3D:
		(body as PhysicalBone3D).apply_impulse(impulse, offset)


static func _find_actor(health_component: HealthComponent) -> Node3D:
	var current: Node = health_component.get_parent()
	while current != null:
		if current is BaseEnemy or current is PlayerController:
			return current as Node3D
		current = current.get_parent()
	return health_component.get_parent() as Node3D
#endregion
