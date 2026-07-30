class_name PlayerStateMachine extends Node

@export var debug: bool = false
@export_category("References")
@export var player_controller: PlayerController

func _ready() -> void:
	add_to_group("StateMachine")
	if debug or true:
		print("StateMachine _ready, player_controller = ", player_controller)
	_inject_references(self)

func _inject_references(node: Node) -> void:
	for child in node.get_children():
		if child is PlayerState:
			child.player_controller = player_controller
			print("  -> Injected into ", child.name, " = ", player_controller)
		_inject_references(child)

func _process(delta: float) -> void:
	if player_controller.debug or debug:
		player_controller.state_chart.set_expression_property("Velocity", player_controller.velocity)
		# player_controller.state_chart.set_expression_property("Player Hitting Head", player_controller.crouch_check.is_colliding())
		player_controller.state_chart.set_expression_property("Is Sliding?", player_controller.is_sliding)
		player_controller.state_chart.set_expression_property("Slide Power :", player_controller.slide_modifier)
		player_controller.state_chart.set_expression_property("Looking At :", player_controller.interaction_raycast.current_object)
		player_controller.state_chart.set_expression_property("Max Velocity", player_controller._current_max_velocity)
		player_controller.state_chart.set_expression_property("Step Status", player_controller.step_handler.step_status)
		player_controller.state_chart.set_expression_property("Camera Rotation", player_controller.cam_effects.rotation)
		
