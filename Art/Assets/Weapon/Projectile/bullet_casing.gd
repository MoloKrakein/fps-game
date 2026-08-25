class_name BulletCasing extends RigidBody3D
@export var lifetime: float = 5.0
@export var speed_threshold: float = 4.0 # Speed needed for max stretch

@onready var mesh_instance: MeshInstance3D = $mesh
var base_scale: Vector3
@export var max_stretch: float = 2.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clean up casing after a few seconds to avoid clutter
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func eject(linear_force: Vector3, angular_force: Vector3) -> void:
	# Wake the physics engine and apply initial pop + tumble
	sleeping = false
	apply_central_impulse(linear_force)
	apply_torque_impulse(angular_force)

# func _physics_process(_delta: float) -> void:
# 	var current_speed: float = linear_velocity.length()

# 	# Only stretch while moving fast (during ejection)
# 	if current_speed > 0.5:
# 		var stretch_factor: float = clampf(current_speed / speed_threshold, 1.0, max_stretch)
		
# 		# Stretch along the flight axis (e.g. Y or Z depending on cylinder orientation)
# 		mesh_instance.scale = Vector3(
# 			base_scale.x / sqrt(stretch_factor),
# 			base_scale.y * stretch_factor,
# 			base_scale.z / sqrt(stretch_factor)
# 		)
		
# 		# Orient mesh toward velocity to align the blur streak
# 		mesh_instance.look_at(global_position + linear_velocity.normalized(), Vector3.UP)
# 	else:
# 		# Return to normal shape once it bounces/settles
# 		mesh_instance.scale = base_scale