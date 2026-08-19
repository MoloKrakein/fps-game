extends Node


#region UI 
signal weapon_ammo_changed(current_ammo: int, reserve_ammo: int)

signal player_health_changed(current_health: float, max_health: float)
signal player_armor_changed(current_armor: float, max_armor: float)
signal player_damage_taken(damage_amount: float)
signal player_died
#endregion
