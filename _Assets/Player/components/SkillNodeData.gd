class_name SkillNodeData extends Resource

enum Branch { AGILITY, ARMOR, FIELDCRAFT }

@export var node_id: StringName
@export var display_name: String = ""
@export var branch: Branch = Branch.AGILITY
@export_range(1, 3) var tier: int = 1
@export_range(1, 99) var point_cost: int = 1
@export var prerequisite_ids: Array[StringName] = []
@export_multiline var description: String = ""
@export var stat_modifiers: Array[StatModifier] = []
