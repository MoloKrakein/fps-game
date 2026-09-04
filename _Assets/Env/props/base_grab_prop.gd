class_name BaseGrabProp extends RigidBody3D

@export var pull_power: float = 15.0
@export var throw_power: float = 15.0

var is_held: bool = false
var hold_target: Marker3D = null


func _physics_process(delta: float) -> void:
    if is_held and is_instance_valid(hold_target):
        var space_state = get_world_3d().direct_space_state
        var query = PhysicsRayQueryParameters3D.create(global_position, hold_target.global_position)
        query.exclude = [get_rid()]

        if space_state.intersect_ray(query):
            drop()
            return

        var distance = global_position.distance_to(hold_target.global_position)

        if distance > 5.0:
            drop()
            return

        var weight_modifier = 1.0 / max(mass, 1.0)
        var direction = global_position.direction_to(hold_target.global_position)
  

        var spring_vel = direction * (distance * pull_power * weight_modifier)
        linear_velocity = linear_velocity.lerp(spring_vel, (10.0 * weight_modifier) * delta)
  

func grab(target_marker: Marker3D) -> void:
    is_held = true
    hold_target = target_marker
    gravity_scale = 0.0
    angular_damp = 5.0

func drop() -> void:
    is_held = false
    hold_target = null
    gravity_scale = 1.0
    angular_damp = 0.0

func throw(throw_direction: Vector3) -> void:
    drop()
    apply_central_impulse(throw_direction * throw_power)