class_name GrabController extends Node

@export var interaction_ray: RayCast3D
@export var hold_position: Marker3D
@export var interaction_state_chart: StateChart
@export var cam: Camera3D

var held_object: BaseGrabProp = null
var object_weight: float = 0.0


func try_grab() -> void:
	if held_object:
		return
	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider()
		if target is BaseGrabProp:
			held_object = target
			object_weight = held_object.get_weight()
			held_object.grab(hold_position)
			interaction_state_chart.send_event("onGrab")
			if not held_object.force_dropped.is_connected(_on_prop_force_dropped):
				held_object.force_dropped.connect(_on_prop_force_dropped)
		else:
			interaction_state_chart.send_event("onDrop")
			print("Target is not a BaseGrabProp: ", target)

func try_throw() -> void:
	if held_object:
		var throw_direction: Vector3 = -cam.global_transform.basis.z.normalized()
		var obj_throw: BaseGrabProp = held_object
		try_drop()
		obj_throw.throw(throw_direction)

func try_drop() -> void:
	if held_object:
		if held_object.force_dropped.is_connected(_on_prop_force_dropped):
			held_object.force_dropped.disconnect(_on_prop_force_dropped)
		held_object.drop()
		held_object = null
		object_weight = 0.0
		interaction_state_chart.send_event("onDrop")

# State Chart Callbacks

func _on_empty_hands_state_entered() -> void:
	if held_object:
		print("entering empty hands state...")
		if held_object.force_dropped.is_connected(_on_prop_force_dropped):
			held_object.force_dropped.disconnect(_on_prop_force_dropped)
		held_object.drop()
		held_object = null
		object_weight = 0.0


func _on_throwing_prop_state_entered() -> void:
	if held_object:
		print("entering throwing prop state...")
		var throw_direction: Vector3 = -cam.global_transform.basis.z.normalized()
		var obj_throw: BaseGrabProp = held_object
		if obj_throw.force_dropped.is_connected(_on_prop_force_dropped):
			obj_throw.force_dropped.disconnect(_on_prop_force_dropped)
		obj_throw.throw(throw_direction)
		held_object = null
		object_weight = 0.0
	interaction_state_chart.send_event("onDrop")


func _on_holding_prop_state_entered() -> void:
	if interaction_ray.is_colliding():
		print("Entering holding prop state...")
		var target: Object = interaction_ray.get_collider()
		if target is BaseGrabProp:
			held_object = target
			object_weight = held_object.get_weight()
			held_object.grab(hold_position)
		else:
			interaction_state_chart.send_event("onDrop")

func _on_prop_force_dropped() -> void:
	try_drop()
