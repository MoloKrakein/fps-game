class_name UIManager extends Node

@export var user_interface: CanvasLayer

func _ready() -> void:
    add_to_group("ui_manager")

func update_ammo_display(current_ammo: int, max_ammo: int) -> void:
    var ammo_label = user_interface.ammo_label
    if ammo_label:
        ammo_label.text = str(current_ammo) + " / " + str(max_ammo)