class_name HealthComponent extends Node


signal health_changed(new_health: float, max_health: float)
signal damage_taken(damage_amount: float)
signal damage_received(info: DamageInfo, applied_damage: float)
signal armor_changed(new_armor: float, max_armor: float)
signal on_armor_broken()
signal died()
signal attack_dodged()


@export var max_health: float = 100.0
@export var armor_value: float = 0.0
@export_range(0.1,1.0) var armor_absorption: float = 0.5
@export var start_max_health: bool = true
@export var start_with_armor: bool = false

var current_health:float
var current_armor: float = 0.0
var is_alive: bool = true

@onready var player_stats_component: PlayerStats = get_parent().get_node_or_null("PlayerStats")


func take_damage_with_info(info: DamageInfo) -> void:
	if not is_alive:
		return
	var final_damage: float = info.raw_damage

	# player stats component can modify the damage based on player's stats
	if player_stats_component:
		if not info.bypass_evasion:
			var evasion = player_stats_component.get_stat("evasion_chance", 0.0)
			if evasion > 0.0 and randf() < evasion:
				attack_dodged.emit()
				print(get_parent().name, " dodged the attack!")
				return # negate the damage if evasion is successful

		var mitigation_percentage = player_stats_component.get_stat("damage_reduction", 0.0)
		var flat_armor_reduction = player_stats_component.get_stat("flat_armor_reduction", 0.0)
		final_damage *= (1.0 - mitigation_percentage)
		final_damage = max(final_damage - flat_armor_reduction,0.0)

	var effective_absorption: float = maxf(0.0, armor_absorption - info.armor_penetration)

	if current_armor > 0.0 and not info.bypass_armor:
		var armor_damage: float = final_damage * effective_absorption
		var health_damage: float = final_damage * (1.0 - effective_absorption)

		if current_armor >= armor_damage:
			current_armor -= armor_damage
			current_health -= health_damage
		else:
			var remaining_damage: float = armor_damage - current_armor
			armor_damage = current_armor
			health_damage += remaining_damage
			
			current_armor = 0.0
			on_armor_broken.emit()
			print(get_parent().name, " armor broken!")
	else:
		current_health -= final_damage

	damage_taken.emit(final_damage)
	damage_received.emit(info, final_damage)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		_handle_death()
	armor_changed.emit(current_armor, armor_value)

func take_damage(damage_amount: float, source: Node3D = null, is_headshot: bool = false, is_crit: bool = false, armor_penetration: float = 0.0) -> void:
	# Legacy method for compatibility, wraps the damage info into a DamageInfo object and calls take_damage_with_info
	var damage_info = DamageInfo.new()
	damage_info.raw_damage = damage_amount
	damage_info.attacker = source
	damage_info.is_headshot = is_headshot
	damage_info.is_critical = is_crit
	damage_info.armor_penetration = armor_penetration
	take_damage_with_info(damage_info)

func heal(heal_amount: float) -> void:
	if not is_alive:
		return
	var actual_heal = max(0.0, heal_amount)
	current_health = min(max_health, current_health + actual_heal)
	health_changed.emit(current_health, max_health)

func _handle_death() -> void:
	if not is_alive:
		return
	is_alive = false
	current_health = 0.0
	died.emit()
	# print(get_parent().name, " is Died")

func _ready() -> void:
	if start_max_health:
		current_health = max_health
	if start_with_armor:
		current_armor = armor_value
