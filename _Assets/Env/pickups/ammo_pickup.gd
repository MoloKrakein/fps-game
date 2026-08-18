class_name AmmoPickup extends BasePickup

@export var weapon_slot: int = 1
@export var ammo_amount: int = 10


func can_pickup(player: PlayerController) -> bool:
    if weapon_slot not in Manager.weapon_manager.weapons:
        return false

    var weapon_data = Manager.weapon_manager.weapons[weapon_slot]

    return weapon_data.is_unlocked and weapon_data.reserve_ammo < weapon_data.weapon.max_ammo


func apply_pickup(player: PlayerController) -> void:
    var weapon_data = Manager.weapon_manager.weapons[weapon_slot]
    
    var space_available = weapon_data.weapon.max_ammo - weapon_data.reserve_ammo
    var ammo_to_add = min(space_available, ammo_amount)

    weapon_data.reserve_ammo += ammo_to_add
    EventBus.weapon_ammo_changed.emit(weapon_data.ammo_in_magazine, weapon_data.reserve_ammo)