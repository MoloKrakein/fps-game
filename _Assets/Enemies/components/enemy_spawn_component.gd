class_name EnemySpawnComponent extends Node3D

@export_category("Spawning")
@export var enemy_scene: PackedScene
@export_range(0.01, 3600.0, 0.01, "or_greater", "suffix:s") var spawn_interval_seconds: float = 1.0
@export_range(1, 100, 1) var enemies_per_spawn: int = 1
@export_range(0, 1000, 1) var max_alive: int = 0
@export var auto_spawn: bool = true

var _elapsed_seconds: float = 0.0
var _spawned_enemies: Array[Node3D] = []


func _ready() -> void:
	if spawn_interval_seconds <= 0.0:
		push_error("EnemySpawnComponent spawn interval must be greater than zero.")
		auto_spawn = false
	elif auto_spawn and enemy_scene == null:
		push_error("EnemySpawnComponent requires an enemy scene for automatic spawning.")
		auto_spawn = false


func _process(delta: float) -> void:
	if not auto_spawn:
		return

	_elapsed_seconds += delta
	while _elapsed_seconds >= spawn_interval_seconds:
		_elapsed_seconds -= spawn_interval_seconds
		spawn_now()


func spawn_now() -> void:
	if enemy_scene == null:
		push_error("EnemySpawnComponent requires an enemy scene.")
		return

	_prune_spawned_enemies()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		push_error("EnemySpawnComponent requires an active scene to spawn into.")
		return

	for _i in range(enemies_per_spawn):
		if max_alive > 0 and _spawned_enemies.size() >= max_alive:
			return

		var instance: Node = enemy_scene.instantiate()
		if not (instance is Node3D):
			push_error("EnemySpawnComponent scene root must be a Node3D.")
			instance.free()
			return

		var enemy := instance as Node3D
		scene_root.add_child(enemy)
		enemy.global_position = global_position
		_spawned_enemies.append(enemy)


func _prune_spawned_enemies() -> void:
	for index in range(_spawned_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_spawned_enemies[index]):
			_spawned_enemies.remove_at(index)
