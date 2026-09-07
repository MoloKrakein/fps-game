extends Node


#region UI 
signal weapon_ammo_changed(current_ammo: int, reserve_ammo: int)
signal weapon_chamber_status(is_chambered: bool)

signal player_health_changed(current_health: float, max_health: float)
signal player_armor_changed(current_armor: float, max_armor: float)
signal player_damage_taken(damage_amount: float)

signal change_visibility_of_crosshair(is_visible: bool)

#endregion

signal player_died
