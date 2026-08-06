class_name HealthPickup extends BasePickup

@export var heal_amount: float = 25.0
@export var armor_amount: float = 25.0

func can_pickup(player: PlayerController) -> bool:
	var health_component = player.get_node_or_null("HealthComponent")
	if health_component == null:
		return false

	return health_component.current_health < health_component.max_health or health_component.current_armor < health_component.armor_value

func apply_pickup(player: PlayerController) -> void:
	var health_component = player.get_node_or_null("HealthComponent")
	if health_component == null:
		return

	health_component.heal(heal_amount)
	health_component.current_armor = min(health_component.armor_value, health_component.current_armor + armor_amount)
	print(player.name, " picked up health and armor. Current health: ", health_component.current_health, "/", health_component.max_health, " Current armor: ", health_component.current_armor, "/", health_component.armor_value)
