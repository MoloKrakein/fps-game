class_name SquadOrder
extends RefCounted
## What the squad coordinator currently wants one enemy to do.
## The coordinator rewrites these in place a few times per second.

## &"attack" (holds an attack token), &"cover" (waiting its turn), &"flank" (the one flanker), &"none"
var role: StringName = &"none"
var destination: Vector3 = Vector3.ZERO
var has_destination: bool = false
## Only enemies holding an attack token may shoot.
var may_fire: bool = false
var speed_scale: float = 1.0
## Where the squad believes the target is (may be a last-known position).
var aim_position: Vector3 = Vector3.ZERO
var issued_at: float = -100.0


func is_fresh(max_age: float = 2.0) -> bool:
	return has_destination and (Time.get_ticks_msec() / 1000.0 - issued_at) <= max_age


func clear() -> void:
	role = &"none"
	has_destination = false
	may_fire = false
	speed_scale = 1.0
