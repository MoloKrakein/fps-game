@tool
class_name StaticStairs extends StaticBody3D

@export var stair_physics_material: PhysicsMaterial

func _ready() -> void:
    # 1. Add this body to a specific group for your player controller to detect
    add_to_group("stairs")
    
    # 2. Apply the custom physics material if provided
    if stair_physics_material:
        physics_material_override = stair_physics_material
        
    # Optional: If you have child MeshInstance3D nodes that also need the group or collision adjustments
    for child in get_children():
        if child is CollisionShape3D:
            # You can fine-tune collision layers here if needed
            pass
	