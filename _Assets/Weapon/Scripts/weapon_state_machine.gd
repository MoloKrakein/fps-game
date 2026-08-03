class_name WeaponStateMachine extends Node

@export var debug: bool = false
@export var weapon_controller: WeaponController

func _ready() -> void:
    add_to_group("WeaponStateMachine")
    print("WeaponStateMachine _ready, weapon_controller = ", weapon_controller)
    _inject_references(self)

func _inject_references(node: Node) -> void:
    for child in node.get_children():
        # Pass the controller to any child that is a WeaponState
        if child is WeaponState:
            child.weapon_controller = weapon_controller
            print("  -> Injected into ", child.name, " = ", weapon_controller)
        _inject_references(child)

func _process(delta: float) -> void:
    # Update any relevant properties in the state chart
    if weapon_controller or debug:
        weapon_controller.weapon_state_chart.set_expression_property("Current Ammo", weapon_controller.current_ammo)
        weapon_controller.weapon_state_chart.set_expression_property("Can Fire", weapon_controller.can_fire())
        weapon_controller.weapon_state_chart.set_expression_property("Fire Mode", weapon_controller.current_fire_mode)
        weapon_controller.weapon_state_chart.set_expression_property("Bullet in chamber ?",weapon_controller.is_loaded)
