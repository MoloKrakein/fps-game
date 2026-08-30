class_name WeaponAnimation extends Node
@export var weapon_animation_tree: AnimationTree
@export var weapon_bolt_time: float = 0.5

func _ready():
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")

func play_animation(animation_name: String) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot play animation.")
		return
	
	match animation_name:
		"Fire":
			weapon_animation_tree.set("parameters/FireOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Reload":
			weapon_animation_tree.set("parameters/Reload/active", true)
		"Idle":
			weapon_animation_tree.set("parameters/Idle/active", true)
		"Empty":
			set_bolt_position(true)
		"Loaded":
			set_bolt_position(false)
		# if no match, print a warning
		_:
			print("Animation name not recognized: ", animation_name)



func set_trigger_pressed(is_pressed: bool) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot set trigger state.")
		return
	var target = 1.0 if is_pressed else 0.0
	weapon_animation_tree.set("parameters/TriggerBlend/blend_amount", target)

func set_bolt_position(is_open: bool) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot set bolt position.")
		return
	var bolt_tween = create_tween()
	bolt_tween.set_trans(Tween.TRANS_SINE)
	bolt_tween.set_ease(Tween.EASE_OUT)
	bolt_tween.tween_property(weapon_animation_tree, "parameters/BoltPosition/blend_amount", 1.0 if is_open else 0.0, weapon_bolt_time)
	# use for loop to gradually change the blend amount over time
	# for i in range(10):
	# 	var target = 1.0 if is_open else 0.0
	# 	var blend_amount = lerp(weapon_animation_tree.get("parameters/BoltPosition/blend_amount"), target, 0.1)
	# 	weapon_animation_tree.set("parameters/BoltPosition/blend_amount", blend_amount)
	# 	await get_tree().create_timer(weapon_bolt_time / 10).timeout
		
	# weapon_animation_tree.set("parameters/BoltPosition/blend_amount", target)