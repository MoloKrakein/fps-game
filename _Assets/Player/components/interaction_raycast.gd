extends RayCast3D

var current_object: Object = null

func _process(delta: float) -> void:
    if is_colliding():
        var object = get_collider()
        if object == current_object:
            return
        else:
            current_object = object

        if (current_object is RigidBody3D or current_object is PhysicalBone3D) and Input.is_action_pressed("action_use"):
            # grab the object
            print("Grabbing object: ", current_object.name)
            pass # You can add additional logic here to handle the grabbing of the object

            
            # You can add additional logic here to handle the collision with the object, such as applying forces or triggering events.
    else:
        current_object = null
