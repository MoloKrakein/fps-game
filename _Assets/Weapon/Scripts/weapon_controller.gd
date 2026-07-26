class_name WeaponController extends Node

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart

var current_weapon_model: Node3D
var current_ammo: int


func _ready() -> void:
    if current_weapon != null:
        spawn_weapon_model(current_weapon)
        current_ammo = current_weapon.max_ammo

func spawn_weapon_model(weapon: Weapon) -> void:
    if current_weapon_model != null:
        current_weapon_model.queue_free()

    if current_weapon.weapon_model:
        current_weapon_model = current_weapon.weapon_model.instantiate()
        weapon_model_parent.add_child(current_weapon_model)
        current_weapon_model.position = current_weapon.weapon_position
        current_weapon_model.rotation = current_weapon.weapon_rotation
        current_weapon_model.scale = current_weapon.weapon_scale


func can_fire() -> bool:
    return current_ammo > 0

func fire_weapon() -> void:
    if can_fire():
        current_ammo -= 1
        print("Fired weapon: %s, Remaining ammo: %d" % [current_weapon.weapon_name, current_ammo])