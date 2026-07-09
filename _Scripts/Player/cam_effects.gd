class_name CamEffects extends Camera3D

@export_category("References")
@export var player: PlayerController


@export_category("Effects")
@export var enable_tilt: bool = true
@export var enable_fall_kick: bool = true


@export_category("Kick & Recoil settings")
@export_group("Run Tilt Settings")
@export var run_pitch: float = 0.1
@export var run_roll: float = 0.25
@export var max_pitch: float = 1.0
@export var max_roll: float = 2.5
@export_group("Fall Kick Settings")
@export var fall_time: float = 0.3 

var _fall_value: float = 0.0
var _fall_timer: float = 0.0


func _process(delta: float) -> void:
    calculate_view_offset(delta)

    # if Input.is_action_just_pressed("combat_fire"):
    #     add_fall_kick(2.0)

func calculate_view_offset(delta):
    if not player:
        return

    _fall_timer -= delta

    
    var velocity = player.velocity


    var angles = Vector3.ZERO
    var offset = Vector3.ZERO


    if enable_tilt:
        var forward = global_transform.basis.z
        var right = global_transform.basis.x

        var forward_dot = velocity.dot(forward)
        var forward_tilt = clampf(forward_dot * deg_to_rad(run_pitch), deg_to_rad(-max_pitch), deg_to_rad(max_pitch))
        angles.x = forward_tilt

        var right_dot = velocity.dot(right)
        var right_tilt = clampf(right_dot * deg_to_rad(run_roll), deg_to_rad(-max_roll), deg_to_rad(max_roll))
        angles.z = right_tilt

    if enable_fall_kick:
        var fall_ratio = max(0.0, _fall_timer / fall_time)
        var fall_kick_amount = fall_ratio * _fall_value
        angles.x -= fall_kick_amount
        offset.y -= fall_kick_amount

    position = offset
    rotation = angles


func add_fall_kick(amount: float) -> void:
    _fall_value = deg_to_rad(amount)
    _fall_timer = fall_time