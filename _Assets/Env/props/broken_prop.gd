extends Node3D

@export var is_grabable: bool = true

func _ready():
    # get all rigidbody3d children and apply impulse to them
    for child in get_children():
    # give all child BaseGrabProp scripts 
        if child is RigidBody3D:
            var force_direction = Vector3(randf() - 0.5, randf(), randf() - 0.5).normalized()
            child.apply_central_impulse(force_direction * 4.0)

    # add timer for 60 seconds to delete the node
    var timer = Timer.new()
    timer.wait_time = 60.0
    timer.one_shot = true
    timer.connect("timeout", Callable(self, "_on_timer_timeout"))
    add_child(timer)
    timer.start()

func _on_timer_timeout():
    queue_free()
