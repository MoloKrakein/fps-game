class_name GrabController extends Node

@export var interaction_ray: RayCast3D
@export var hold_position: Marker3D
@export var interaction_state_chart: StateChart
@export var cam: Camera3D

var held_object: BaseGrabProp = null


func try_grab() -> void:
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target is BaseGrabProp:
			held_object = target
			held_object.grab(hold_position)
			interaction_state_chart.send_event("onGrab")
		else:
			interaction_state_chart.send_event("onDrop")
			print("Target is not a BaseGrabProp: ", target)

func try_throw() -> void:
	if held_object:
		var throw_direction = -cam.global_transform.basis.z.normalized()

		var obj_throw = held_object
		try_drop()
		
		obj_throw.apply_central_impulse(throw_direction * 10.0)

func try_drop() -> void:
	if held_object:
		held_object.drop()
		held_object = null
		interaction_state_chart.send_event("onDrop")

# State Chart Callbacks

func _on_empty_hands_state_entered() -> void:
	if held_object:
		print("entering empty hands state...")
		held_object.drop()
		held_object = null


func _on_throwing_prop_state_entered() -> void:
	if held_object:
		print("entering throwing prop state...")
		var throw_direction = hold_position.global_transform.basis.z.normalized()
		held_object.throw(throw_direction)
		held_object = null
	interaction_state_chart.send_event("onDrop")


func _on_holding_prop_state_entered() -> void:
	if interaction_ray.is_colliding():
		print("Entering holding prop state...")
		var target = interaction_ray.get_collider()
		if target is BaseGrabProp:
			held_object = target
			held_object.grab(hold_position)
			# disable collision between the player and the held object
			# held_object.set_collision_enabled(false)
		else:
			interaction_state_chart.send_event("onDrop")
