class_name ArmorRigResource extends Resource

@export var rig_name: String = "Armor Rig"
@export_range(0.0, 100.0, 0.1) var loadout_weight: float = 0.0
@export_range(0.0, 180.0, 1.0) var armor_value: float = 50.0
@export var stat_modifiers: Array[StatModifier] = []
