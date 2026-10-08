# Damage Payload Script
class_name DamageInfo
extends RefCounted

# The amount of damage to be applied. This can be modified by other systems (e.g., armor, buffs, debuffs) before being applied to the target.
var raw_damage: float = 0.0

# The entity that caused the damage. This can be null if the damage was environmental or self-inflicted.
var attacker: Node = null

# The type of damage being applied. This can be used to determine how the damage interacts with different resistances or vulnerabilities. For example, "fire", "ice", "physical", etc.
var damage_type: String = "bullet"

# The direction from which the damage is coming. This can be used for knockback effects, directional resistances, or other gameplay mechanics that depend on the direction of the attack.
var impact_direction: Vector3 = Vector3.FORWARD

# The position in the world where the damage impact occurred. This can be used for visual effects, sound effects, or other gameplay mechanics that depend on the location of the impact.
var impact_position: Vector3 = Vector3.ZERO
# Whether the damage was a headshot. This can be used to apply additional effects or multipliers for headshot damage.
var is_headshot: bool = false
# Whether the damage was a critical hit. This can be used to apply additional effects or multipliers for critical damage.
var is_critical: bool = false


# specific flags for damage application, these can be used to bypass certain mechanics or apply special effects. For example, bypassing armor or dodge mechanics.
var bypass_armor: bool = false
var bypass_dodge: bool = false

func _init(p_damage: float = 0.0, p_attacker: Node = null, p_type: String = "bullet") -> void:
	raw_damage = p_damage
	attacker = p_attacker
	damage_type = p_type