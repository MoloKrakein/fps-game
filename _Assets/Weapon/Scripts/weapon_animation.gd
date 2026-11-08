class_name WeaponAnimation extends Node
@export var weapon_animation_tree: AnimationTree
@export var weapon_bolt_time: float = 0.5
@export var animation_player: AnimationPlayer
@export_category("Other Tweaks")
@export var reload_animation_name: String = "Reload"
@export var fire_animation_name: String = "Fire"
@export var rack_animation_name: String = "Rack"
@export var equip_animation_name: String = "Equip"
@export var idle_animation_name: String = "Idle"
@export var empty_animation_name: String = "Empty"
@export var loaded_animation_name: String = "Loaded"
@export var empty_reload_animation_name: String = "Reload_Empty"
@export var loaded_reload_animation_name: String = "Reload"

func _ready() -> void:
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")

func play_animation(animation_name: String) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot play animation.")
		return

	match _resolve_animation_key(animation_name):
		"Fire":
			weapon_animation_tree.set("parameters/FireOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Reload":
			weapon_animation_tree.set("parameters/ReloadOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Rack":
			weapon_animation_tree.set("parameters/RackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Idle":
			weapon_animation_tree.set("parameters/Idle/active", true)
		"Equip":
			weapon_animation_tree.set("parameters/EquipOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"Empty":
			set_bolt_position(true)
		"Loaded":
			set_bolt_position(false)
		_:
			print("Animation name not recognized: ", animation_name)


func reload_weapon_animation(reload_type: String = "empty_reload") -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot play reload animation.")
		return
	
	match _resolve_reload_key(reload_type):
		"empty_reload":
			weapon_animation_tree.set("parameters/ReloadBlend/blend_amount", 1.0)
			weapon_animation_tree.set("parameters/ReloadOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		"loaded_reload":
			weapon_animation_tree.set("parameters/ReloadBlend/blend_amount", 0.0)
			weapon_animation_tree.set("parameters/ReloadOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_:
			print("Reload animation name not recognized: ", reload_type)

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

# blend for reload for determining it is empty reload or not
func set_reload_blend(blend_value: float) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot set reload blend.")
		return
	weapon_animation_tree.set("parameters/ReloadBlend/blend_amount", blend_value)

func get_animation_length(animation_name: String) -> float:
	if animation_player == null:
		print("AnimationPlayer is not assigned. Cannot get animation length.")
		return 0.0
	
	var resolved_name: String = _resolve_model_animation_name(animation_name)
	var animation: Animation = animation_player.get_animation(resolved_name)
	if animation == null and _is_reload_variant(animation_name):
		var fallback_name: String = reload_animation_name
		animation = animation_player.get_animation(fallback_name)
		if animation != null:
			print("Reload animation not found: ", resolved_name, ". Using base reload animation: ", fallback_name)
	if animation == null:
		print("Animation not found: ", resolved_name)
		return 0.0

	return animation.length

func _resolve_animation_key(animation_name: String) -> String:
	if animation_name == fire_animation_name:
		return "Fire"
	if animation_name == reload_animation_name:
		return "Reload"
	if animation_name == rack_animation_name:
		return "Rack"
	if animation_name == idle_animation_name:
		return "Idle"
	if animation_name == equip_animation_name:
		return "Equip"
	if animation_name == empty_animation_name:
		return "Empty"
	if animation_name == loaded_animation_name:
		return "Loaded"
	return animation_name

func _resolve_reload_key(reload_type: String) -> String:
	if reload_type == empty_reload_animation_name:
		return "empty_reload"
	if reload_type == loaded_reload_animation_name:
		return "loaded_reload"
	return reload_type

func _resolve_model_animation_name(animation_name: String) -> String:
	if animation_name == "empty_reload":
		return empty_reload_animation_name
	if animation_name == "loaded_reload":
		return loaded_reload_animation_name
	if animation_name == "Reload":
		return reload_animation_name
	if animation_name == "Fire":
		return fire_animation_name
	if animation_name == "Rack":
		return rack_animation_name
	if animation_name == "Idle":
		return idle_animation_name
	if animation_name == "Equip":
		return equip_animation_name
	if animation_name == "Empty":
		return empty_animation_name
	if animation_name == "Loaded":
		return loaded_animation_name
	return animation_name

func _is_reload_variant(animation_name: String) -> bool:
	return animation_name == "empty_reload" or animation_name == "loaded_reload"
