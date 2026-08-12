class_name EnemyShootComponent
extends BaseShootingComponent

@export var aim_raycast: RayCast3D

func _execute_shot() -> void:
	aim_raycast.force_raycast_update()

	if aim_raycast.is_colliding():
		var hit_target = aim_raycast.get_collider()

		if hit_target.is_in_group("player"):
			var health_component = hit_target.get_node_or_null("HealthComponent")
			if health_component != null:
				health_component.take_damage(weapon.damage, self)