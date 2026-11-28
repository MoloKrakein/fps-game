class_name AmmoPickup extends BasePickup

@export var weapon_slot: int = 1
@export var ammo_amount: int = 10


func can_pickup(_player: PlayerController) -> bool:
	if weapon_slot not in Manager.weapon_manager.weapons:
		return false

	var weapon_data = Manager.weapon_manager.weapons[weapon_slot]

	return weapon_data.is_unlocked and weapon_data.reserve_ammo < weapon_data.weapon.max_ammo


func apply_pickup(player: PlayerController) -> void:
	var weapon_data = Manager.weapon_manager.weapons[weapon_slot]

	var space_available = weapon_data.weapon.max_ammo - weapon_data.reserve_ammo
	var pickup_multiplier: float = (
		player.player_stats.get_stat("ammo_pickup_multiplier", 1.0) if player.player_stats else 1.0
	)
	var ammo_to_add = min(space_available, maxi(0, roundi(ammo_amount * pickup_multiplier)))

	weapon_data.reserve_ammo += ammo_to_add
	EventBus.weapon_ammo_changed.emit(weapon_data.ammo_in_magazine, weapon_data.reserve_ammo)
	if player.player_stats != null and player.player_stats.has_flag("field_repair"):
		var health: HealthComponent = player.health_component
		if health.current_armor < health.armor_value:
			health.current_armor = minf(health.armor_value, health.current_armor + 3.0)
			health.armor_changed.emit(health.current_armor, health.armor_value)
