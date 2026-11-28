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
@warning_ignore("unused_signal")
signal bullet_time_changed(intensity: float)

signal on_gadget_activated(player: Node, deck_id: StringName)
signal on_bullet_time_toggled(player: Node, active: bool)
signal on_dive_or_slide(player: Node)
signal on_vault(player: Node)
signal on_prop_thrown(player: Node, prop: Node)
signal on_hit_dealt(attacker: Node, target: Node, damage: float)
signal on_crit_hit(attacker: Node, target: Node, damage: float)
signal on_armor_broken(target: Node, attacker: Node)
signal on_enemy_stumbled(enemy: Node, attacker: Node)
signal on_enemy_fallen(enemy: Node, attacker: Node)
signal on_enemy_ragdolled(enemy: Node, attacker: Node)
signal on_enemy_killed(enemy: Node, attacker: Node)
signal on_damage_taken(player: Node, damage: float, armor_damage: float)
signal on_armor_depleted(player: Node)
signal on_armor_regen_started(player: Node)
signal on_objective_tick(player: Node, objective: Node)
