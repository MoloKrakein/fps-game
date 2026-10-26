class_name EnemyHitbox
extends PhysicalBone3D
## Damage region of an enemy, placed on its PhysicalBone3D nodes (so it follows the animation and the
## ragdoll). Bullets that hit it call take_damage() with the same signature as HealthComponent, so
## it plugs into BaseShootingComponent unchanged.
##
## - damage_multiplier scales the incoming damage per region (limbs hurt less).
## - The head bone joins the "head" group: BaseShootingComponent then applies the weapon's own
##   headshot_multiplier (so weapon / perk modifiers still count), and this script marks the
##   DamageInfo as a headshot. Do not also put a big multiplier on the head here.
## - Allies never hurt each other, but their bullets are still stopped by the body.
## - Shots at a corpse push the bone.

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

	var info: DamageInfo = DamageInfo.new(damage_amount * damage_multiplier, source, "bullet")
	info.is_headshot = is_headshot or is_head
	info.is_critical = is_crit
	info.armor_penetration = armor_penetration
	info.impact_direction = hit_direction if hit_direction != Vector3.ZERO else Vector3.FORWARD
	info.impact_position = hit_position if hit_position.is_finite() else global_position
	info.set_meta(&"hit_region", region)
	info.set_meta(&"hit_leg", is_leg)
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
