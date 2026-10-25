class_name EnemySquadCoordinator
extends Node

## Shared tactical blackboard for enemies in one combat encounter.
## It deliberately owns no scene references: enemies register themselves and
## provide their player target when requesting a destination.

@export var cover_ring_radius: float = 8.0
@export var cover_refresh_interval: float = 0.8
@export var flank_angle_degrees: float = 65.0
@export var max_members: int = 12

var members: Array[BaseEnemy] = []
var assignments: Dictionary = {}
var roles: Dictionary = {}
var cover_refresh_timer: float = 0.0
var squad_target: Node3D

func _process(delta: float) -> void:
	cover_refresh_timer = maxf(cover_refresh_timer - delta, 0.0)
	_prune_members()

func register_enemy(enemy: BaseEnemy) -> void:
	if members.has(enemy) or members.size() >= max_members:
		return
	members.append(enemy)
	if is_inside_tree():
		_rebuild_assignments()

func unregister_enemy(enemy: BaseEnemy) -> void:
	members.erase(enemy)
	assignments.erase(enemy)
	roles.erase(enemy)
	if members.is_empty():
		if is_inside_tree():
			var scene_root: Node = get_tree().root
			if scene_root.has_meta(&"enemy_squad_coordinator"):
				var registered: Variant = scene_root.get_meta(&"enemy_squad_coordinator")
				if registered == self:
					scene_root.remove_meta(&"enemy_squad_coordinator")
			queue_free()
		return
	if is_inside_tree():
		_rebuild_assignments()

func set_target(target: Node3D) -> void:
	if squad_target == target:
		return
	squad_target = target
	if is_inside_tree():
		_rebuild_assignments()

func get_role(enemy: BaseEnemy) -> StringName:
	var role_variant: Variant = roles.get(enemy, &"flanker")
	if role_variant is StringName:
		return role_variant as StringName
	return &"flanker"

func get_tactical_destination(enemy: BaseEnemy, target: Node3D) -> Vector3:
	if not is_instance_valid(target):
		return enemy.global_position
	set_target(target)
	if is_inside_tree() and (cover_refresh_timer <= 0.0 or not assignments.has(enemy)):
		_rebuild_assignments()
		cover_refresh_timer = cover_refresh_interval

	var destination_variant: Variant = assignments.get(enemy, enemy.global_position)
	if destination_variant is Vector3:
		return destination_variant as Vector3
	return enemy.global_position

func _prune_members() -> void:
	for index: int in range(members.size() - 1, -1, -1):
		if not is_instance_valid(members[index]):
			members.remove_at(index)
	if members.is_empty() and is_inside_tree():
		queue_free()

func _rebuild_assignments() -> void:
	assignments.clear()
	roles.clear()
	if not is_instance_valid(squad_target):
		return

	var living_members: Array[BaseEnemy] = []
	for member: BaseEnemy in members:
		if is_instance_valid(member) and not member.is_in_group("dead"):
			living_members.append(member)
	members = living_members
	if members.is_empty():
		return

	var center: Vector3 = squad_target.global_position
	var target_angle: float = atan2(
		squad_target.global_position.x - members[0].global_position.x,
		squad_target.global_position.z - members[0].global_position.z
	)
	for index: int in members.size():
		var member: BaseEnemy = members[index]
		var role: StringName = &"flanker"
		var angle_offset: float = 0.0
		if index == 0:
			role = &"suppressor"
			angle_offset = 0.0
		elif index % 2 == 1:
			role = &"left_flanker"
			angle_offset = -deg_to_rad(flank_angle_degrees)
		else:
			role = &"right_flanker"
			angle_offset = deg_to_rad(flank_angle_degrees)

		var candidate: Vector3 = center + Vector3(
			sin(target_angle + angle_offset),
			0.0,
			cos(target_angle + angle_offset)
		) * cover_ring_radius
		roles[member] = role
		assignments[member] = _find_cover_point(member, center, candidate, role)

func _find_cover_point(
	enemy: BaseEnemy,
	target_position: Vector3,
	candidate: Vector3,
	role: StringName
) -> Vector3:
	var direction: Vector3 = candidate - target_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return enemy.global_position
	direction = direction.normalized()

	var candidates: Array[Vector3] = [candidate]
	for distance_scale: float in [0.75, 1.25]:
		candidates.append(target_position + direction * cover_ring_radius * distance_scale)
	for side: float in [-1.0, 1.0]:
		var side_direction: Vector3 = Vector3(-direction.z, 0.0, direction.x) * side
		candidates.append(target_position + (direction * 0.85 + side_direction * 0.35).normalized() * cover_ring_radius)

	for point: Vector3 in candidates:
		var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(
			enemy.get_world_3d().navigation_map,
			point
		)
		if _has_cover_from_target(nav_point, target_position, squad_target):
			return nav_point

	# A suppressor can still hold a firing lane when no cover exists.
	if role == &"suppressor":
		return NavigationServer3D.map_get_closest_point(enemy.get_world_3d().navigation_map, candidate)
	return enemy.global_position

func _has_cover_from_target(point: Vector3, target_position: Vector3, target: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		target_position + Vector3.UP * 1.2,
		point + Vector3.UP * 1.0,
		1
	)
	query.exclude = [target.get_rid()]
	var result: Dictionary = target.get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty()
