class_name WeaponModel extends Node3D

@export_category("Socket")
@export var muzzle_socket: Node3D
@export var ejection_socket: Node3D

@export_category("UI Components")
@export var ammo_display: AmmoUI


func update_ammo_display(current_ammo: int, reserved_ammo: int, reload_time: float) -> void:
    if ammo_display:
        ammo_display.set_ammo_values(current_ammo, reserved_ammo, reload_time)

