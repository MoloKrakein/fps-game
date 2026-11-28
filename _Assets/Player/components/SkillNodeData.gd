class_name SkillNodeData extends Resource

enum Branch { AGILITY, ARMOR, FIELDCRAFT }

@export var node_id: StringName
@export var display_name: String = ""
@export var branch: Branch = Branch.AGILITY
@export_range(1, 4) var tier: int = 1
@export_range(1, 99) var basic_point_cost: int = 1
@export_range(1, 99) var ace_point_cost: int = 2
@export var prerequisite_ids: Array[StringName] = []
@export_multiline var description: String = ""
@export var basic_stat_modifiers: Array[StatModifier] = []
@export var ace_stat_modifiers: Array[StatModifier] = []
