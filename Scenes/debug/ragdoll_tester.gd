extends Node3D

@export var ragdoll_skeleton: PhysicalBoneSimulator3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ragdoll_skeleton.physical_bones_start_simulation()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
