extends AnimatableBody3D

@export var open_angle: float = 90.0
@export var swing_speed: float = 0.5

# CRITICAL: This is the distance from the center to the edge of your mesh!
@export var hinge_offset: Vector3 = Vector3(1.0, 0.0, 0.0) 

var is_open: bool = false
var base_transform: Transform3D
var door_tween: Tween
var current_angle: float = 0.0

func _ready() -> void:
    # Save the pristine, closed transform state
    base_transform = transform

func interact() -> void:
    is_open = !is_open
    var target_angle = deg_to_rad(open_angle) if is_open else 0.0
    
    if door_tween: 
        door_tween.kill()
        
    door_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    # Tween the custom angle variable, NOT the default rotation property
    door_tween.tween_method(_swing_door, current_angle, target_angle, swing_speed)

func _swing_door(angle: float) -> void:
    current_angle = angle
    var new_transform = base_transform
    
    # 1. Shift the mathematical origin to your custom offset
    new_transform = new_transform.translated_local(hinge_offset)
    # 2. Rotate the door around that new mathematical hinge
    new_transform = new_transform.rotated_local(Vector3.UP, angle)
    # 3. Shift the origin back so the door does not fly away
    new_transform = new_transform.translated_local(-hinge_offset)
    
    # Apply the final matrix to the root node
    transform = new_transform