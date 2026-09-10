extends RayCast3D

var current_object: Object = null

func interact() -> void:
    if is_colliding():
        var object = get_collider()
        if object == current_object:
            return
        else:
            current_object = object

        # check if node has a interaction method then call it
        if object.has_method("interact"):
            print("Interacting with object: ", object)
            object.interact()
        else:
            print("Object does not have an interact method: ", object)


# func _process(delta: float) -> void:
#     if is_colliding():
#         var object = get_collider()
#         if object == current_object:
#             return
#         else:
#             current_object = object

#         # check if node has a interaction method then call it
#         if object.has_method("interact"):
#             object.interact()
#         else:
#             print("Object does not have an interact method: ", object)
