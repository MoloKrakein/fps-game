# Player Skill Resource
# This script defines a resource for player skills in a game.

class_name SkillResource
extends Resource

enum SkillSet{
    LOCKED,
    BASIC,
    ADVANCED,
}

@export_group("Basic Info")
@export var id: String = "skill_id" # Unique identifier for the skill
@export_category("UI")
@export var skill_name: String = "Skill Name" # Display name of the skill
# @export var skill_description: String = "Skill Description" # Description of the skill
@export var skill_icon: Texture2D # Icon representing the skill in the UI
@export_range(0,4) var tier: int = 0 # Tier level of the skill, can be used for progression or unlocking higher-level skills

@export_group("Description & Cost")
@export_multiline var skill_basic_description: String = "Skill Description" # Description of the skill
@export_multiline var skill_advanced_description: String = "Advanced Skill Description" # Description of the advanced version of the skill
@export var skill_cost_basic: int = 1 # Cost to use the skill, can be
@export var skill_cost_advanced: int = 3 # Cost to use the advanced version of the skill, can be

@export_group("Basic Skill Effect")
# Stat multipliers added when Basic is unlocked. Key: Stat name, Value: modifier offset.
# Example: {"recoil_multiplier": -0.15, "movement_speed": 0.10}
@export var basic_stats_changes: Dictionary = {} # Dictionary to hold basic skill effect stats, can be used to modify player attributes or apply effects
# Game rule flags enabled when Basic is unlocked.
# Example: ["fire_while_sprinting"]
@export var basic_rule_flags: Array = [] # Array to hold basic skill effect rule flags, can be used to enable or disable certain game mechanics

@export_group("Advanced Skill Effect")
# Stat multipliers added when Advanced is unlocked. Key: Stat name, Value: modifier offset
# Example: {"recoil_multiplier": -0.30, "movement_speed": 0.20}
@export var advanced_stats_changes: Dictionary = {} # Dictionary to hold advanced skill effect stats,
# can be used to modify player attributes or apply effects
# Game rule flags enabled when Advanced is unlocked.
# Example: ["fire_while_sprinting", "increased_critical_chance"]
@export var advanced_rule_flags: Array = [] # Array to hold advanced skill effect rule flags
