class_name WeaponController extends Node

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D


var current_weapon_model: Node3D


func _ready() -> void:
    if current_weapon != null:
        spawn_weapon_model(current_weapon)

func spawn_weapon_model(weapon: Weapon) -> void:
    if current_weapon_model != null:
        current_weapon_model.queue_free()

    if current_weapon.weapon_model:
        current_weapon_model = current_weapon.weapon_model.instantiate()
        weapon_model_parent.add_child(current_weapon_model)
        current_weapon_model.position = current_weapon.weapon_position
        current_weapon_model.rotation = current_weapon.weapon_rotation
        current_weapon_model.scale = current_weapon.weapon_scale