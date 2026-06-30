class_name PlayerStateMachine extends Node

@export var debug: bool = false
@export_category("References")
@export var player_controller: PlayerController

func _ready() -> void:
    add_to_group("StateMachine")
    if debug or true:
        print("StateMachine _ready, player_controller = ", player_controller)
    _inject_references(self)

func _inject_references(node: Node) -> void:
    for child in node.get_children():
        if child is PlayerState:
            child.player_controller = player_controller
            print("  -> Injected into ", child.name, " = ", player_controller)
        _inject_references(child)