@tool
class_name TriggerableComponent extends Node

@export var targetname: String = ""

func _func_godot_apply_properties(entity_properties: Dictionary) -> void:
	targetname = entity_properties.get("targetname", "") as String

func _ready() -> void:
	call_deferred("_add_to_group")


func _add_to_group() -> void:
	if get_parent():
		get_parent().add_to_group("map_entities")