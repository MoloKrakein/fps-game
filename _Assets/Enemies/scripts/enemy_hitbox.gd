class_name EnemyHitbox
extends PhysicalBone3D
## Damage region of an enemy, placed on its PhysicalBone3D nodes (so it follows the animation and the
## ragdoll). There are two ways in:
##
## - apply_weapon_hit(): used by HitResolver (the player's hitscan and projectiles). The head gets the
##   weapon's own headshot_multiplier, so weapon / perk modifiers still count.
## - take_damage(): same signature as HealthComponent, used by BaseShootingComponent (enemy and turret
##   shots). The head bone is in the "head" group there, which makes the component apply the multiplier.
##
## In both cases damage_multiplier scales the region (limbs hurt less), the DamageInfo is marked as a
## headshot for the head, and it carries the exact impact point, direction and bone name so the hit
## reaction (flinch, stumble, death push) can react to where it landed.
## Allies never hurt each other, but their bullets are still stopped by the body.
## Shots at a corpse push the bone.

@export var region: StringName = &"torso"
@export var damage_multiplier: float = 1.0
@export var is_head: bool = false
## Leg hits make the enemy much more likely to fall over.
@export var is_leg: bool = false
## Velocity change (m/s) when a dead body is shot.
@export var corpse_impulse: float = 6.0

var _enemy: BaseEnemy
var _hit_position: Vector3 = Vector3.INF
var _hit_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if is_head:
		add_to_group("head")
	var node: Node = get_parent()
	while node != null and not (node is BaseEnemy):
		node = node.get_parent()
	_enemy = node as BaseEnemy


#region Weapon entry points

## Hit from the player's weapons. Returns { headshot, damage, position }.
func apply_weapon_hit(
		damage_amount: float,
		attacker: Node3D,
		hit_position: Vector3,
		hit_direction: Vector3,
		headshot_multiplier: float = 1.0,
		armor_penetration: float = 0.0
) -> Dictionary:
	var outcome: Dictionary = {"headshot": false, "damage": 0.0, "position": hit_position}
	if _enemy == null or _is_friendly(attacker):
		return outcome

	if _enemy.is_dead:
		_push_corpse(hit_direction, hit_position)
		return outcome

	var final_damage: float = damage_amount * damage_multiplier
	if is_head:
		final_damage *= maxf(headshot_multiplier, 1.0)
	outcome["headshot"] = is_head
	outcome["damage"] = final_damage
	_submit(final_damage, attacker, is_head, false, armor_penetration, hit_position, hit_direction)
	return outcome


## Called by BaseShootingComponent right before take_damage() with the exact impact data.
func set_hit_context(hit_position: Vector3, hit_direction: Vector3) -> void:
	_hit_position = hit_position
	_hit_direction = hit_direction


func take_damage(damage_amount: float, source: Node3D = null, is_headshot: bool = false, is_crit: bool = false, armor_penetration: float = 0.0) -> void:
	var hit_position: Vector3 = _hit_position
	var hit_direction: Vector3 = _hit_direction
	_hit_position = Vector3.INF
	_hit_direction = Vector3.ZERO

	if _enemy == null or _is_friendly(source):
		return

	if hit_direction == Vector3.ZERO and source != null:
		hit_direction = (global_position - source.global_position).normalized()

	if _enemy.is_dead:
		_push_corpse(hit_direction, hit_position)
		return

	_submit(damage_amount * damage_multiplier, source, is_headshot or is_head, is_crit, armor_penetration, hit_position, hit_direction)

#endregion


## Makes the collision shape bigger or smaller (e.g. a forgiving head). Works on a per-enemy copy of
## the shape, so other enemies sharing the scene resource are not affected.
func inflate_shape(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	for child in get_children():
		var collision_shape: CollisionShape3D = child as CollisionShape3D
		if collision_shape == null or collision_shape.shape == null:
			continue
		var shape: Shape3D = collision_shape.shape.duplicate() as Shape3D
		if shape is CapsuleShape3D:
			(shape as CapsuleShape3D).radius *= factor
			(shape as CapsuleShape3D).height *= factor
		elif shape is SphereShape3D:
			(shape as SphereShape3D).radius *= factor
		elif shape is BoxShape3D:
			(shape as BoxShape3D).size *= factor
		collision_shape.shape = shape


func _submit(
		final_damage: float,
		source: Node3D,
		headshot: bool,
		crit: bool,
		armor_penetration: float,
		hit_position: Vector3,
		hit_direction: Vector3
) -> void:
	var info: DamageInfo = DamageInfo.new(final_damage, source, "bullet")
	info.is_headshot = headshot
	info.is_critical = crit
	info.armor_penetration = armor_penetration
	info.impact_direction = hit_direction if hit_direction != Vector3.ZERO else Vector3.FORWARD
	info.impact_position = hit_position if hit_position.is_finite() else global_position
	info.set_meta(&"hit_region", region)
	info.set_meta(&"hit_leg", is_leg)
	#info.set_meta(&"hit_bone", StringName(bone_name))
	_enemy.health_component.take_damage_with_info(info)


func _is_friendly(source: Node) -> bool:
	if source == null:
		return false
	var shooter: Variant = source.get(&"shooter_body")
	return shooter is BaseEnemy


func _push_corpse(hit_direction: Vector3, hit_position: Vector3) -> void:
	if hit_direction == Vector3.ZERO:
		return
	var offset: Vector3 = Vector3.ZERO
	if hit_position.is_finite():
		offset = hit_position - global_position
	apply_impulse(hit_direction * corpse_impulse * mass, offset)
