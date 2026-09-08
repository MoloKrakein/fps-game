extends Node3D

@export var timer_duration: float = 30.0
@export var force: float = 4.0
@export var chance_of_spawn: float = 0.5

func _ready():
	# get all rigidbody3d children and apply impulse to them
	for child in get_children():
	# give all child BaseGrabProp scripts 
		if child is RigidBody3D:
			# chance of the child rigidbody3d is not spawning
			var chance = randf()
			if chance < chance_of_spawn:
				child.queue_free()
				continue
			var force_direction = Vector3(randf() - 0.5, randf(), randf() - 0.5).normalized()
			child.apply_central_impulse(force_direction * force)
			

	# add timer for 60 seconds to delete the node
	var timer = Timer.new()
	timer.wait_time = timer_duration
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	add_child(timer)
	timer.start()


func _on_timer_timeout():
	queue_free()
