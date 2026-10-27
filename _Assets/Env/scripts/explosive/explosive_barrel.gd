class_name ExplosiveBarrel extends RigidBody3D
## A barrel that detonates when its health runs out. A short random fuse makes
## neighbouring barrels go off in a ripple instead of all on the same frame.

@export var explosion: ExplosionData
@export var fuse_range: Vector2 = Vector2(0.08, 0.35)
@export var blast_height: float = 0.5

@onready var health: HealthComponent = $HealthComponent

var _armed: bool = false


func _ready() -> void:
	health.died.connect(arm)


func arm() -> void:
	if _armed:
		return
	_armed = true
	await get_tree().create_timer(randf_range(fuse_range.x, fuse_range.y)).timeout
	if not is_inside_tree():
		return
	# attacker is null here; pass the killer in if your death signal provides one.
	Explosion.detonate(self, global_position + Vector3.UP * blast_height, explosion, null)
	queue_free()
