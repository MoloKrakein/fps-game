class_name PlayerStateMachine extends Node

@export var debug: bool = false
@export_category("References")
@export var player_controller: PlayerController

func _ready() -> void:
    add_to_group("state_machine")
    if debug:
        print("PlayerStateMachine: ready, player_controller = %s" % player_controller)