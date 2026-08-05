class_name HealthComponent extends Node


signal health_changed(new_health: int, max_health: int)
signal damage_taken(damage_amount: int)
signal died()


@export var max_health: float = 100.0
@export var start_max_health: bool = true

var current_health:float
var is_alive: bool = true


func take_damage(damage_amount: float, source: Node3D = null) -> void:
    if not is_alive:
        return

    var actual_damage = max(0.0, damage_amount)
    current_health = max(0.0, current_health - actual_damage)

    damage_taken.emit(actual_damage)
    health_changed.emit(current_health, max_health)

    if current_health <= 0.0:
        _handle_death()

func heal(heal_amount: float) -> void:
    if not is_alive:
        return
    var actual_heal = max(0.0, heal_amount)
    current_health = min(max_health, current_health + actual_heal)
    health_changed.emit(current_health, max_health)

func _handle_death() -> void:
    if not is_alive:
        return
    is_alive = false
    current_health = 0.0
    died.emit()
    print(get_parent().name, " is Died")

func _ready() -> void:
    if start_max_health:
        current_health = max_health