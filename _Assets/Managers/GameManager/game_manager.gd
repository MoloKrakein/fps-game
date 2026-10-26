class_name GameManager extends Node

const SOUND_ENGINE_SCRIPT: Script = preload("res://_Assets/Audio/sound_engine.gd")

@export var is_debug_mode: bool = false

var sound_engine: Node


func _ready() -> void:
	sound_engine = SOUND_ENGINE_SCRIPT.new()
	sound_engine.name = &"SoundEngine"
	add_child(sound_engine)


func _unhandled_input(event: InputEvent) -> void:
	if is_debug_mode:
		if event.is_action("dev_exit"):
			get_tree().quit()
		if event.is_action("dev_reload"):
			get_tree().reload_current_scene()
