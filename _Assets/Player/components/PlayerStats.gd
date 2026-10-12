class_name PlayerStats extends Node

# Stats multiplier and offset values for the player character. These values can be used to modify the player's attributes, such as health, speed, damage, etc.
var stats: Dictionary = {
    # Defense & Survival Stats
    "max_health": 100.0, # Maximum health of the player
    "max_armor": 50.0, # Maximum armor of the player
    "evasion_chance": 0.05, # Chance to evade attacks (5%)
    "damage_reduction": 0.10, # Damage reduction percentage (10%)
    "flat_armor_reduction": 5.0, # Flat armor reduction value

    # Offensive Stats
    "damage_modifier": 1.0, # Damage multiplier for the player
    "recoil_stability": 1.0, # Recoil stability multiplier (lower is better)
    "reload_speed": 1.0, # Reload speed multiplier (higher is faster)

    # Movement Stats
    "movement_speed": 1.0, # Movement speed multiplier (higher is faster)
}
# Behavioral flags that can be toggled on or off to enable or disable certain player abilities or game mechanics.
var active_flags: Dictionary = {} # Array to hold active behavioral flags for the player, can be used to enable or disable certain abilities or mechanics example: ["double_jump", "reload_while_moving"]

# Helper function to apply stat changes from a skill resource to the player's stats. This function takes a SkillResource object and applies its stat changes based on the skill's tier (BASIC or ADVANCED).
func get_stats(stats_name: String, default_value: float = 1.0) -> float:
    return stats.get(stats_name, default_value)

func set_stats(stats_name: String, value: float) -> void:
    stats[stats_name] = value

func has_flag(flag_name: String) -> bool:
    return active_flags.has(flag_name)

func set_flag(flag_name: String, value: bool) -> void:
    active_flags[flag_name] = value


# common function to apply stat changes from a skill resource to the player's stats. This function takes a SkillResource object and applies its stat changes based on the skill's tier (BASIC or ADVANCED).
func modify_damage(base_damage: float) -> float:
    var damage_modifier = get_stats("damage_modifier", 1.0)
    return base_damage * damage_modifier

func modify_recoil(base_recoil: float) -> float:
    var recoil_stability = get_stats("recoil_stability", 1.0)
    return base_recoil * recoil_stability


func reset_stats() -> void:
    stats = {
        "max_health": 100.0,
        "max_armor": 50.0,
        "evasion_chance": 0.0,
        "damage_reduction": 0.0,
        "flat_armor_reduction": 0.0,
        "damage_modifier": 1.0,
        "recoil_stability": 1.0,
        "reload_speed": 1.0,
        "movement_speed": 1.0,
    }
    active_flags.clear()
