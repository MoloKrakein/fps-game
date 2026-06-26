class_name PlayerState extends Node

@export var debug: bool = false

var player_controller: PlayerController

func _ready() -> void:
    # if %StateMachine and %StateMachine is PlayerStateMachine:
    #     player_controller = %StateMachine.player_controller
    #     print("PlayerState: PlayerController reference set successfully.")
    # else:
    #     print("PlayerState: PlayerController reference not found. Ensure this state is a child of PlayerStateMachine.")

    # get state machine reference
    var state_machine = get_parent()
    if state_machine and state_machine is PlayerStateMachine:
        player_controller = state_machine.player_controller
        print("PlayerState: PlayerController reference set successfully.")
    else:
        print("PlayerState: PlayerController reference not found. Ensure this state is a child of PlayerStateMachine.")

