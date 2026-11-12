class_name HitResolver
extends RefCounted
## Turns a weapon hit (hitscan ray or projectile) into damage on the right thing.
##
## - A hit on an enemy's body capsule is re-cast against its hitbox bones (EnemyHitbox), so the
##   head, torso and limbs each get their own multiplier and the hit reaction knows where it landed.
## - A hit on an EnemyHitbox applies the weapon's headshot multiplier to the head only.
## - Anything else falls back to the HealthComponent found on the collider or one of its parents.
##
## Returns a Dictionary: { handled, flesh, headshot, damage, position }.
## `flesh` is true when an enemy was hit (use it to pick blood instead of a bullet decal).


static func apply_hit(
		collider: Object,
		hit_position: Vector3,
		_hit_normal: Vector3,
		direction: Vector3,
		damage: float,
		attacker: Node3D,
		headshot_multiplier: float = 1.0,
		armor_penetration: float = 0.0
) -> Dictionary:
	var outcome: Dictionary = {
		"handled": false,
		"flesh": false,
		"headshot": false,
		"damage": 0.0,
		"position": hit_position,
	}
	if collider == null or damage <= 0.0:
		return outcome

	var pen: float = clampf(armor_penetration, 0.0, 1.0)
	var refined: Dictionary = _refine(collider, hit_position, direction)
	var target: Object = refined.get("collider", collider)
	outcome["position"] = refined.get("position", hit_position)

	# 1. Precise enemy hitbox (bone).
	var hitbox: EnemyHitbox = target as EnemyHitbox
	if hitbox != null:
		var hit: Dictionary = hitbox.apply_weapon_hit(
			damage, attacker, outcome["position"], direction, headshot_multiplier, pen
		)
		outcome["handled"] = true
		outcome["flesh"] = true
		outcome["headshot"] = hit.get("headshot", false)
		outcome["damage"] = hit.get("damage", 0.0)
		return outcome

	# 2. Anything with a HealthComponent (crates, the enemy capsule when no bone was on the path, ...).
	var health: HealthComponent = _find_health_component(target)
	if health != null:
		health.take_damage(damage, attacker, false, false, pen)
		outcome["handled"] = true
		outcome["damage"] = damage
		outcome["flesh"] = _find_enemy(target) != null
	return outcome


## A coarse collider (the enemy capsule) can hand the shot to its precise hitboxes.
static func _refine(collider: Object, hit_position: Vector3, direction: Vector3) -> Dictionary:
	if collider.has_method(&"resolve_hit") and direction.length_squared() > 0.0001:
		var dir: Vector3 = direction.normalized()
		var result: Dictionary = collider.call(&"resolve_hit", hit_position - dir * 0.3, hit_position + dir * 2.5)
		if not result.is_empty():
			return result
	return {"collider": collider, "position": hit_position}


static func _find_health_component(target: Object) -> HealthComponent:
	var current: Node = target as Node
	while current != null:
		var health: HealthComponent = current as HealthComponent
		if health != null:
			return health
		var child_health: HealthComponent = current.get_node_or_null("HealthComponent") as HealthComponent
		if child_health != null:
			return child_health
		current = current.get_parent()
	return null


static func _find_enemy(target: Object) -> BaseEnemy:
	var current: Node = target as Node
	while current != null:
		if current is BaseEnemy:
			return current as BaseEnemy
		current = current.get_parent()
	return null
