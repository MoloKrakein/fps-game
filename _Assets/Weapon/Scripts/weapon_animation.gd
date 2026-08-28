class_name WeaponAnimation extends Node
@export var weapon_animation_tree: AnimationTree


func _ready():
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")

func play_animation(animation_name: String) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot play animation.")
		return
	
	match animation_name:
		"Fire":
			weapon_animation_tree.set("parameters/BoltOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Reload":
			weapon_animation_tree.set("parameters/Reload/active", true)
		"Idle":
			weapon_animation_tree.set("parameters/Idle/active", true)
		"Empty":
			weapon_animation_tree.set("parameters/OpenBolt/request", true)
		"Loaded":
			weapon_animation_tree.set("parameters/CloseBolt/request", false)
		# if no match, print a warning
		_:
			print("Animation name not recognized: ", animation_name)



func set_trigger_pressed(is_pressed: bool) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot set trigger state.")
		return
	var target = 1.0 if is_pressed else 0.0
	weapon_animation_tree.set("parameters/TriggerBlend/blend_amount", target)