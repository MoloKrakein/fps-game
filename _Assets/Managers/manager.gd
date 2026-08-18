extends Node

var weapon_manager: WeaponManager
var ui_manager: UIManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("find_managers")
	Manager.weapon_manager = weapon_manager
	Manager.ui_manager = ui_manager


func find_managers() -> void:
	weapon_manager = get_tree().get_first_node_in_group("weapon_manager")
	ui_manager = get_tree().get_first_node_in_group("ui_manager")