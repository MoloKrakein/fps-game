extends Node3D
class_name LaserAttachment

@export var max_length := 50.0
@onready var ray: RayCast3D = $RayCast3D
@onready var beam: MeshInstance3D = $Beam
@onready var hit_dot: MeshInstance3D = $HitDot

func _ready() -> void:
	ray.target_position = Vector3(0, 0, -max_length)
	beam.rotation_degrees.x = 90.0  # cylinder points along -Z

func _process(_delta: float) -> void:
	ray.force_raycast_update()
	var dist := max_length
	hit_dot.visible = ray.is_colliding()

	if ray.is_colliding():
		var hit_point := ray.get_collision_point()
		dist = global_position.distance_to(hit_point)
		# Nudge off the surface to avoid z-fighting
		hit_dot.global_position = hit_point + ray.get_collision_normal() * 0.01

	var cyl := beam.mesh as CylinderMesh
	cyl.height = dist
	beam.position.z = -dist * 0.5
