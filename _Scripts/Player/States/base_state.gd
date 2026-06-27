class_name PlayerState extends Node

@export var debug: bool = false

var player_controller: PlayerController

func _ready() -> void:
    # Defer so the full scene tree is ready before we search
    call_deferred("_setup_references")

func _setup_references() -> void:
    # Walk up the tree manually instead of relying on groups
    var sm = get_node_or_null("/root/PlayerController/Component/StateMachine")
    if sm and sm is PlayerStateMachine:
        player_controller = sm.player_controller
        if debug:
            print("PlayerState [%s]: Got player_controller = %s" % [name, player_controller])
    else:
        # Fallback: search the whole tree
        var root = get_tree().root
        var found = _find_state_machine(root)
        if found:
            player_controller = found.player_controller
            if debug:
                print("PlayerState [%s]: Got player_controller via fallback = %s" % [name, player_controller])
        else:
            printerr("PlayerState [%s]: FAILED to find PlayerStateMachine anywhere in tree." % name)

func _find_state_machine(node: Node) -> PlayerStateMachine:
    if node is PlayerStateMachine:
        return node
    for child in node.get_children():
        var result = _find_state_machine(child)
        if result:
            return result
    return null