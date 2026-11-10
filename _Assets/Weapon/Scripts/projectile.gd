class_name Projectile extends Area3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var attacker: Node3D
var is_explosive: bool = false
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var explosion_falloff: float = 1.0
var explosion_force: float = 0.0
var armor_penetration: float = 0.0
var trail_start_timer: Timer
var _has_detonated: bool = false
var real_time: bool = false

@export var trail_effect: MeshInstance3D
# @export var trail_effect: GPUParticles3D
@export var is_tracer: bool = false
@export_flags_3d_physics var explosion_collision_mask: int = 15


func _ready() -> void:
	# connect("body_entered", self, "_on_body_entered")
	body_entered.connect(_on_body_entered)
	_show_trail_effect()
	get_tree().create_timer(90.0).timeout.connect(queue_free)



func _physics_process(delta: float) -> void:
	# global_position += velocity * delta
	var space_state = get_world_3d().direct_space_state
	var start_position = global_position
	var step: float = PlayerTime.real(delta) if real_time else delta
	var end_position = start_position + velocity * step

	var query = PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.exclude = [self]  # Exclude the projectile itself from the raycast
	query.collision_mask = 1  # Set the collision mask to detect only relevant layers
	var result = space_state.intersect_ray(query)
	
	if result:
		global_position = result.position
		_on_body_entered(result.collider)
		return
	
	global_position = end_position


func setup(
		_velocity: Vector3,
		_damage: float,
		_attacker: Node3D = null,
		_explosive: bool = false,
		_explosion_radius: float = 0.0,
		_explosion_damage: float = 0.0,
		_explosion_falloff: float = 1.0,
		_explosion_force: float = 0.0,
		_armor_penetration: float = 0.0
	) -> void:
	velocity = _velocity
	damage = _damage
	attacker = _attacker
	is_explosive = _explosive
	explosion_radius = maxf(_explosion_radius, 0.0)
	explosion_damage = maxf(_explosion_damage, 0.0)
	explosion_falloff = clampf(_explosion_falloff, 0.0, 1.0)
	explosion_force = maxf(_explosion_force, 0.0)
	armor_penetration = clampf(_armor_penetration, 0.0, 1.0)
	real_time = attacker != null and attacker.is_in_group("player")
	if real_time and trail_start_timer != null:
		trail_start_timer.ignore_time_scale = true


func _on_body_entered(body: Node3D) -> void:
	if _has_detonated:
		return
	_has_detonated = true
	print("Projectile hit: ", body)
	if is_explosive:
		_explode()
	else:
		_spawn_impact_effect(global_position)
		var health_component: HealthComponent = _find_health_component(body)
		if health_component:
			health_component.take_damage(damage, attacker, false, false, armor_penetration)
	queue_free()


func _explode() -> void:
	var blast_position: Vector3 = global_position
	if explosion_radius <= 0.0 or explosion_damage <= 0.0:
		return

	var data: ExplosionData = ExplosionData.new()
	data.radius = explosion_radius
	data.damage = explosion_damage
	data.falloff = explosion_falloff
	data.force = explosion_force
	data.armor_penetration = armor_penetration
	data.target_mask = explosion_collision_mask
	data.requires_line_of_sight = false
	Explosion.detonate(self, blast_position, data, attacker)


func _find_health_component(node: Node) -> HealthComponent:
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


func _spawn_impact_effect(hit_position: Vector3) -> void:
	# Placeholder for spawning impact effects (e.g., particles, decals)
	# print("Spawn impact effect at position: ", hit_position, " with normal: ", hit_normal)
	var marker = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.1

	marker.mesh = ball

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN 
	marker.set_surface_override_material(0,material)

	get_tree().current_scene.add_child(marker)
	marker.global_transform.origin = hit_position


	get_tree().create_timer(1.0).timeout.connect(marker.queue_free)


func _spawn_explosion_effect(explosion_position: Vector3) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	marker.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.25, 0.03)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.08, 0.01)
	marker.set_surface_override_material(0, material)
	get_tree().current_scene.add_child(marker)
	marker.global_position = explosion_position
	var tween: Tween = marker.create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE * maxf(explosion_radius, 1.0), 0.12)
	tween.tween_callback(marker.queue_free)

func _show_trail_effect() -> void:
	if trail_effect:
		var random_number = randi() % 2
		if random_number == 0 or is_tracer:
			# add wait timer to delay the visibility of the trail effect
			trail_start_timer = Timer.new()
			trail_start_timer.wait_time = 0.0289
			trail_start_timer.one_shot = true
			trail_start_timer.ignore_time_scale = real_time
			trail_start_timer.timeout.connect(func() -> void: trail_effect.visible = true)
			add_child(trail_start_timer)
			trail_start_timer.start()
			trail_effect.visible = false
		else:
			trail_effect.visible = false

func _enable_trail_effect() -> void:
	if trail_effect:
		trail_effect.visible = true
	
	
		
