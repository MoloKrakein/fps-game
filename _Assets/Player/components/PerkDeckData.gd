class_name PerkDeckData extends Resource

@export var deck_id: StringName
@export var display_name: String = ""
@export var archetype_tag: String = ""
@export var signature_gadget_name: String = ""
@export var signature_effect: StringName
@export_range(0.0, 120.0, 0.1) var gadget_cooldown: float = 20.0
@export_range(0.0, 30.0, 0.1) var gadget_radius: float = 6.0
@export_multiline var role_summary: String = ""
@export_multiline var tier_1_summary: String = ""
@export_multiline var tier_2_summary: String = ""
@export_multiline var tier_3_summary: String = ""
@export var role_gadget_scene: PackedScene
@export var tier_1_modifiers: Array[StatModifier] = []
@export var tier_2_modifiers: Array[StatModifier] = []
@export var tier_3_modifiers: Array[StatModifier] = []


func get_modifiers_for_tier(tier: int) -> Array[StatModifier]:
	match tier:
		1:
			return tier_1_modifiers
		2:
			return tier_2_modifiers
		3:
			return tier_3_modifiers
	return []


func get_tier_summary(tier: int) -> String:
	match tier:
		1:
			return tier_1_summary
		2:
			return tier_2_summary
		3:
			return tier_3_summary
	return ""
