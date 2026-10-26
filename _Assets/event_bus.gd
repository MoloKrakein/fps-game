extends Node


#region UI 
signal weapon_ammo_changed(current_ammo: int, reserve_ammo: int)
signal weapon_chamber_status(is_chambered: bool)
signal weapon_magazine_changed(current_ammo: int, max_ammo_in_magazine: int)
signal weapon_2d_ammo_visibility_changed(is_visible: bool)

signal player_health_changed(current_health: float, max_health: float)
signal player_armor_changed(current_armor: float, max_armor: float)
signal player_damage_taken(damage_amount: float)

signal change_visibility_of_crosshair(is_visible: bool)

#endregion

signal player_died

## Semantic audio request. SoundEngine owns assets, buses, pooling and attenuation.
@warning_ignore("unused_signal")
signal sound_requested(
	event_id: StringName,
	world_position: Vector3,
	volume_scale: float,
	pitch_scale: float,
	spatial: bool
)
