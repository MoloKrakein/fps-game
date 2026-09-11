@tool
class_name MovingPlatform extends AnimatableBody3D

@export_category("References")
@export var move_speed: float = 2.0
@export var wait_time: float = 1.0
@export_category("Coordinates")
# @export var is_using_coordinates: bool = false
@export var start_position: Vector3 = Vector3.ZERO
@export var end_position: Vector3 = Vector3.ZERO
@export_category("Dirrection")
@export var move_direction: Vector3 = Vector3(0, 1, 0)
@export var move_distance: float = 5.0

@export var loop: bool = true

var platform_tween: Tween

# using func_godot addon
func _func_godot_apply_properties(entity_properties: Dictionary) -> void:
	# if entity_properties.has("move_speed"):
	move_speed = entity_properties["move_speed"] as float
	# if entity_properties.has("wait_time"):
	wait_time = entity_properties["wait_time"] as float
	# if entity_properties.has("start_position"):
	start_position = entity_properties["start_position"] as Vector3
	# if entity_properties.has("end_position"):
	end_position = entity_properties["end_position"] as Vector3


func _ready() -> void:
	if not Engine.is_editor_hint():
		if start_position == Vector3.ZERO and end_position == Vector3.ZERO:
			start_position = global_position
			end_position = global_position + (move_direction.normalized() * move_distance)
		_start_movement()
		
func _start_movement() -> void:
	platform_tween = create_tween()
	if loop:
		platform_tween.set_loops()

	platform_tween.tween_interval(wait_time)
	platform_tween.tween_property(self, "global_position", end_position, move_speed)
	platform_tween.tween_interval(wait_time)
	platform_tween.tween_property(self, "global_position", start_position, move_speed)

		
