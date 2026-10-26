class_name EnemyShootingComponent
extends BaseShootingComponent

var current_ammo: int = 0
var reload_timer: float = 0.0

var _ray_exclusions: Array[RID] = []

func _ready() -> void:
	if weapon_data == null:
		push_error("%s has no weapon_data assigned; enemy cannot shoot." % get_path())
		return
	current_ammo = maxi(weapon_data.mags_ammo, 1)

func _process(delta: float) -> void:
	super._process(delta) # CRITICAL: Tells the base script to process the fire_timer!
	
	if reload_timer > 0.0:
		reload_timer = maxf(reload_timer - delta, 0.0)
		if reload_timer == 0.0:
			current_ammo = maxi(weapon_data.mags_ammo, 1)

# Our own ragdoll bones are separate bodies; without excluding them the shot hits our own arm.
func _get_ray_exclusions() -> Array[RID]:
	if _ray_exclusions.is_empty() and shooter_body:
		_collect_colliders(shooter_body)
	return _ray_exclusions

func _collect_colliders(node: Node) -> void:
	if node is CollisionObject3D:
		_ray_exclusions.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_colliders(child)

# Overrides the virtual function in the base script
func _handle_ammo_consumption() -> bool:
	if weapon_data == null:
		push_error("%s cannot fire without weapon_data." % get_path())
		return false
	if reload_timer > 0.0:
		return false
		
	if current_ammo <= 0:
		var r_time = weapon_data.get("reload_time")
		reload_timer = r_time if r_time != null else 2.0
		return false
		
	current_ammo -= 1
	return true # Yes, ammo is consumed, allow the shot!