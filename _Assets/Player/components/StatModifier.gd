class_name StatModifier extends Resource

@export var flat_modifiers: Dictionary[StringName, float] = {}
@export var multipliers: Dictionary[StringName, float] = {}
@export var rule_flags: Array[StringName] = []


static func apply_to_value(
	stat_name: StringName, base_value: float, modifiers: Array[StatModifier]
) -> float:
	var flat_bonus := 0.0
	var multiplier := 1.0
	for modifier: StatModifier in modifiers:
		if modifier == null:
			continue
		flat_bonus += modifier.flat_modifiers.get(stat_name, 0.0)
		multiplier *= modifier.multipliers.get(stat_name, 1.0)
	return (base_value + flat_bonus) * multiplier
