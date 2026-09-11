@tool
class_name TriggerVolume extends Area3D


@export var targets: Array[String] = []
@export var trigger_once: bool = false
@export var trigger_on_exit: bool = true
@export var delay: float = 0.0

var has_triggered: bool = false

func _func_godot_apply_properties(entity_properties: Dictionary) -> void:
	var target_string = entity_properties.get("target", "") as String
	if target_string != "":
		var split_targets = target_string.split(",",false)
		targets.clear()
		for target in split_targets:
			targets.append(target.strip_edges())


	trigger_once = entity_properties.get("trigger_once", false) as bool
	trigger_on_exit = entity_properties.get("trigger_on_exit", true) as bool
	delay = entity_properties.get("delay", 0.0) as float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if trigger_once and has_triggered:
		return
	

	if body is PlayerController or body.is_in_group("player"):
		has_triggered = true

		if delay > 0.0:
			await get_tree().create_timer(delay).timeout

		_activate_targets(body)


func _on_body_exited(body: Node3D) -> void:
	if not trigger_on_exit:
		return

	if body is PlayerController or body.is_in_group("player"):
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout

		_deactivate_targets(body)


func _activate_targets(player: Node3D) -> void:
	if targets.is_empty():
		return
	
	var entities = get_tree().get_nodes_in_group("map_entities")

	for target_name in targets:
		for entity in entities:
			if entity.has_method("get_targetname") and entity.get_targetname() == target_name:
				if entity.has_method("on_trigger"):
					entity.on_trigger(player)

				elif entity.has_method("on_triggered"):
					entity.on_triggered()


func _deactivate_targets(player: Node3D) -> void:
	if targets.is_empty():
		return
	
	var entities = get_tree().get_nodes_in_group("map_entities")

	for target_name in targets:
		for entity in entities:
			if entity.has_method("get_targetname") and entity.get_targetname() == target_name:
				if entity.has_method("on_deactivate"):
					entity.on_deactivate(player)
			
			elif entity.has_method("on_deactivated"):
					entity.on_deactivated()

