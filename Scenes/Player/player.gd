extends CharacterBody3D

# --- Variables ---
const SPEED = 5.0
const SPRINT_SPEED = 8.0 # Added a boost for move_sprint
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready():
    # Attempt to capture mouse on startup
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
    # Fallback: Click the game screen to lock the mouse
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        
    # Press ESC to unlock the mouse so you can close the window
    if event.is_action_pressed("ui_cancel"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
    # Only look around if the mouse is currently captured!
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
    # Add gravity.
    if not is_on_floor():
        velocity.y -= gravity * delta

    # Handle Jump using your new custom action.
    if Input.is_action_just_pressed("move_jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Handle Sprinting
    var current_speed = SPEED
    if Input.is_action_pressed("move_sprint"):
        current_speed = SPRINT_SPEED

    # Get the input direction using your custom actions.
    # The order is vital: left, right, forward, backward
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    
    # Transform the 2D input into 3D space, relative to where the player is looking
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    if direction:
        velocity.x = direction.x * current_speed
        velocity.z = direction.z * current_speed
    else:
        velocity.x = move_toward(velocity.x, 0, current_speed)
        velocity.z = move_toward(velocity.z, 0, current_speed)

    move_and_slide()