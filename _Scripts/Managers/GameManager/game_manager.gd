class_name GameManager extends Node

@export var is_debug_mode: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if is_debug_mode:
		if event.is_action("dev_exit"):
			get_tree().quit()
		if event.is_action("dev_reload"):
			get_tree().reload_current_scene()
