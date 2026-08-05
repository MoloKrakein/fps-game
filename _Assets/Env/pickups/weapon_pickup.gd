class_name WeaponPickup extends BasePickup

@export var weapon_slot: int = 1
@export var weapon_resource: Weapon


func can_pickup(player: PlayerController) -> bool:
	var weapon_data = Manager.weapon_manager.weapons[weapon_slot]

	return not weapon_data.is_unlocked or weapon_data.reserve_ammo < weapon_resource.max_ammo

func apply_pickup(player: PlayerController) -> void:
	var weapon_data = Manager.weapon_manager.weapons[weapon_slot]

	if weapon_data.is_unlocked:
		# If the weapon is already unlocked, just add ammo
		weapon_data.reserve_ammo = min(weapon_data.reserve_ammo + weapon_resource.max_ammo, weapon_resource.max_ammo)
	else:
		# Unlock the weapon and set its ammo
		Manager.weapon_manager.unlock_weapon(weapon_slot, weapon_resource)
		Manager.weapon_manager.equip_weapon(weapon_slot)
		print("Picked up weapon: %s" % weapon_resource.weapon_name)