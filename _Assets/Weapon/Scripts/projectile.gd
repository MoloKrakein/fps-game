class_name Projectile extends Area3D

var velocity: Vector3
var damage: float

func _ready() -> void:
	# connect("body_entered", self, "_on_body_entered")
	body_entered.connect(_on_body_entered)

	get_tree().create_timer(5.0).timeout.connect(queue_free)



func _physics_process(delta: float) -> void:
	# global_position += velocity * delta
	var space_state = get_world_3d().direct_space_state
	var start_position = global_position
	var end_position = start_position + velocity * delta

	var query = PhysicsRayQueryParameters3D.create(start_position, end_position)
	var result = space_state.intersect_ray(query)

	if result:
		global_position = result.position
		_on_body_entered(result.collider)
		return
	
	global_position = end_position


func setup(_velocity: Vector3, _damage: float) -> void:
	velocity = _velocity
	damage = _damage


func _on_body_entered(body: Node3D) -> void:
	print("Projectile hit: ", body)
	_spawn_impact_effect(global_position)
	queue_free()

func _spawn_impact_effect(hit_position: Vector3) -> void:
	# Placeholder for spawning impact effects (e.g., particles, decals)
	# print("Spawn impact effect at position: ", hit_position, " with normal: ", hit_normal)
	var marker = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = 1.5
	ball.height = 1.5
	marker.mesh = ball

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN # Red color
	marker.set_surface_override_material(0,material)

	get_tree().current_scene.add_child(marker)
	marker.global_transform.origin = hit_position


	get_tree().create_timer(0.5).timeout.connect(marker.queue_free)

