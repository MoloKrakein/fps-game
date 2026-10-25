class_name EnemySquadCoordinator
extends Node
## Half-Life 2 style squad brain, shared by every engaged enemy in the level.
##
## - Attack tokens: only a few enemies may shoot at once. The rest wait in cover, then take over
##   when a burst ends (pop out, shoot, pop back).
## - One flanker at a time: after a standoff, one non-attacking enemy walks to a side slot that has
##   line of sight to the player while the others keep the player busy.
## - Slots: attackers get a firing position (line of sight, inside their weapon range),
##   everyone else gets a cover position (no line of sight). Slots are spaced apart.
## - Shared knowledge: if one enemy sees the player, the whole squad knows where they are.
##
## The coordinator owns no scene references. Enemies register themselves and read their
## SquadOrder; it thinks a few times per second, not every frame.

class Member:
	var enemy: BaseEnemy
	var order: SquadOrder = SquadOrder.new()
	var has_token: bool = false
	var token_until: float = 0.0
	var token_blocked_until: float = 0.0
	var last_token_time: float = 0.0
	var fire_position: Vector3 = Vector3.INF
	var fire_time: float = -100.0
	var fire_target: Vector3 = Vector3.INF
	var cover_position: Vector3 = Vector3.INF
	var cover_time: float = -100.0
	var cover_target: Vector3 = Vector3.INF
	var bad_positions: Array[Vector3] = []

@export_group("General")
@export var max_members: int = 24
@export var think_interval: float = 0.25
## Layers that block line of sight and make cover.
@export_flags_3d_physics var world_mask: int = 1
## While someone saw the target this recently, the squad knows its real position.
@export var track_time: float = 3.0

@export_group("Attack tokens")
## Most enemies allowed to shoot at the same time (also capped at about half the squad).
@export var max_attackers: int = 2
@export var token_duration: float = 4.0
## Seconds an enemy must wait after its turn before it may shoot again (if others are waiting).
@export var token_cooldown: float = 2.5

@export_group("Flanking")
@export var flank_enabled: bool = true
@export var flank_min_squad_size: int = 2
## The squad must have been engaged this long before the first flank.
@export var flank_delay: float = 6.0
@export var flank_interval: float = 10.0
@export var flank_angle_degrees: float = 80.0
@export var flank_distance: float = 9.0
@export var flank_timeout: float = 14.0
@export var flank_max_path_length: float = 45.0
@export var flank_arrive_distance: float = 2.0
@export var flank_speed_scale: float = 1.2

@export_group("Slots")
@export var fire_samples: int = 12
@export var cover_samples: int = 16
@export var cover_search_radius: float = 9.0
## Cover is never closer than this to the target.
@export var cover_min_distance: float = 5.0
@export var slot_spacing: float = 2.5
@export var position_refresh: float = 2.5
## A cached slot is dropped when the target moved this far.
@export var retarget_distance: float = 3.5

var members: Array[BaseEnemy] = []
var squad_target: Node3D
var squad_known_position: Vector3 = Vector3.ZERO
var squad_can_see_target: bool = false

var _data: Dictionary = {}
var _taken: Array[Vector3] = []
var _think_timer: float = 0.0
var _engaged_since: float = -1.0

var _flanker: BaseEnemy
var _flank_slot: Vector3 = Vector3.INF
var _flank_deadline: float = 0.0
var _flank_next_allowed: float = 0.0
var _flank_side: float = 1.0
var _bonus_enemy: BaseEnemy
var _bonus_until: float = 0.0


func _process(delta: float) -> void:
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = think_interval
	_prune_members()
	_think()


#region Public API

func register_enemy(enemy: BaseEnemy) -> void:
	if members.has(enemy) or members.size() >= max_members:
		return
	members.append(enemy)
	var member: Member = Member.new()
	member.enemy = enemy
	_data[enemy] = member


func unregister_enemy(enemy: BaseEnemy) -> void:
	members.erase(enemy)
	_data.erase(enemy)
	_taken.clear()
	if enemy == _flanker:
		_end_flank(_now(), false)
	if members.is_empty() and is_inside_tree():
		var scene_root: Node = get_tree().root
		if scene_root.has_meta(&"enemy_squad_coordinator"):
			var registered: Variant = scene_root.get_meta(&"enemy_squad_coordinator")
			if registered == self:
				scene_root.remove_meta(&"enemy_squad_coordinator")
		queue_free()


func set_target(target: Node3D) -> void:
	squad_target = target


func get_role(enemy: BaseEnemy) -> StringName:
	var member: Member = _data.get(enemy) as Member
	return member.order.role if member else &"none"


## Wakes up nearby allies that are not engaged yet.
func alert_nearby(source: BaseEnemy, alert_position: Vector3, radius: float) -> void:
	for other: BaseEnemy in members:
		if other == source or not is_instance_valid(other) or other.is_dead or other.is_engaged:
			continue
		if other.global_position.distance_to(source.global_position) <= radius:
			other.receive_alert(alert_position, source.target)


## An enemy finished its burst: give the token to someone else.
func report_burst_finished(enemy: BaseEnemy) -> void:
	var member: Member = _data.get(enemy) as Member
	if member and member.has_token:
		_release_token(member, _now(), _engaged_count())


## An enemy could not reach its slot: never pick that spot for it again for a while.
func report_stuck(enemy: BaseEnemy) -> void:
	var member: Member = _data.get(enemy) as Member
	if member == null:
		return
	if member.order.has_destination:
		member.bad_positions.append(member.order.destination)
		if member.bad_positions.size() > 6:
			member.bad_positions.pop_front()
	member.fire_position = Vector3.INF
	member.cover_position = Vector3.INF
	if enemy == _flanker:
		_end_flank(_now(), false)

#endregion


#region Thinking

func _think() -> void:
	var now: float = _now()
	var squad: Array[BaseEnemy] = []
	for enemy: BaseEnemy in members:
		if _is_active(enemy):
			squad.append(enemy)

	if squad.is_empty():
		_engaged_since = -1.0
		if _flanker:
			_end_flank(now, false)
		return
	if _engaged_since < 0.0:
		_engaged_since = now

	if not _update_knowledge(squad):
		return
	_update_tokens(squad, now)
	_update_flank(squad, now)

	_taken.clear()
	for enemy: BaseEnemy in squad:
		_issue_order(enemy, now)


func _update_knowledge(squad: Array[BaseEnemy]) -> bool:
	squad_target = null
	var freshest: float = INF
	var known_position: Vector3 = Vector3.ZERO
	for enemy: BaseEnemy in squad:
		if is_instance_valid(enemy.target):
			squad_target = enemy.target
		if enemy.time_since_seen < freshest:
			freshest = enemy.time_since_seen
			known_position = enemy.last_known_target_position
	if squad_target == null:
		return false
	squad_can_see_target = freshest < 1.0
	squad_known_position = squad_target.global_position if freshest <= track_time else known_position
	return true


func _update_tokens(squad: Array[BaseEnemy], now: float) -> void:
	var holders: int = 0
	for enemy: BaseEnemy in squad:
		var member: Member = _data[enemy]
		if not member.has_token:
			continue
		var lost_sight: bool = not enemy.target_visible and enemy.time_since_seen > 2.0
		if now >= member.token_until or enemy.is_incapacitated() or enemy.is_reloading() \
				or not enemy.has_ammo() or lost_sight:
			_release_token(member, now, squad.size())
		else:
			holders += 1

	var limit: int = mini(max_attackers, maxi(1, ceili(squad.size() / 2.0)))
	if holders >= limit:
		return

	var candidates: Array = []
	for enemy: BaseEnemy in squad:
		var member: Member = _data[enemy]
		if member.has_token or now < member.token_blocked_until:
			continue
		if enemy.is_incapacitated() or enemy.is_reloading() or not enemy.has_ammo():
			continue
		# The flanker only gets a turn once it has arrived.
		if enemy == _flanker:
			continue
		candidates.append([_score_token_candidate(member, now), member])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])

	for entry: Array in candidates:
		if holders >= limit:
			break
		var chosen: Member = entry[1]
		chosen.has_token = true
		chosen.token_until = now + token_duration * randf_range(0.8, 1.3)
		holders += 1


func _score_token_candidate(member: Member, now: float) -> float:
	var enemy: BaseEnemy = member.enemy
	var score: float = randf() * 0.5
	var distance: float = enemy.global_position.distance_to(squad_known_position)
	if enemy.target_visible:
		score += 4.0
	if distance <= enemy.attack_range:
		score += 2.0
	else:
		score -= minf((distance - enemy.attack_range) * 0.15, 3.0)
	# Fairness: whoever has waited longest goes first.
	score += minf(now - member.last_token_time, 10.0) * 0.25
	# A flanker that just arrived gets to use its position.
	if enemy == _bonus_enemy and now < _bonus_until:
		score += 3.0
	return score


func _release_token(member: Member, now: float, squad_size: int) -> void:
	member.has_token = false
	member.last_token_time = now
	# A lone enemy should not hide for long between bursts.
	member.token_blocked_until = now + (token_cooldown if squad_size > 1 else 0.4)

#endregion


#region Flanking

func _update_flank(squad: Array[BaseEnemy], now: float) -> void:
	if not flank_enabled:
		return

	if is_instance_valid(_flanker):
		var arrived: bool = _flat_distance(_flanker.global_position, _flank_slot) <= flank_arrive_distance
		if arrived or now >= _flank_deadline or not _is_active(_flanker):
			_end_flank(now, arrived)
		return
	_flanker = null

	if squad.size() < flank_min_squad_size or now < _flank_next_allowed:
		return
	if now - _engaged_since < flank_delay:
		return

	var slot: Vector3 = _find_flank_slot(squad)
	if slot == Vector3.INF:
		_flank_next_allowed = now + 2.0
		return

	# The flanker is the non-attacker closest to the slot.
	var best: BaseEnemy = null
	var best_distance: float = INF
	for enemy: BaseEnemy in squad:
		var member: Member = _data[enemy]
		if member.has_token or enemy.is_incapacitated() or enemy.is_reloading():
			continue
		var distance: float = enemy.global_position.distance_to(slot)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		return

	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		best.get_world_3d().navigation_map, best.global_position, slot, true
	)
	if path.size() < 2 or _path_length(path) > flank_max_path_length:
		_flank_next_allowed = now + 3.0
		return

	_flanker = best
	_flank_slot = slot
	_flank_deadline = now + flank_timeout


func _end_flank(now: float, arrived: bool) -> void:
	if arrived and is_instance_valid(_flanker):
		_bonus_enemy = _flanker
		_bonus_until = now + 4.0
	_flanker = null
	_flank_slot = Vector3.INF
	_flank_next_allowed = now + flank_interval * randf_range(0.8, 1.3)
	_flank_side = -_flank_side


func _find_flank_slot(squad: Array[BaseEnemy]) -> Vector3:
	var target_position: Vector3 = squad_known_position
	var centroid: Vector3 = Vector3.ZERO
	for enemy: BaseEnemy in squad:
		centroid += enemy.global_position
	centroid /= float(squad.size())

	var front: Vector3 = centroid - target_position
	front.y = 0.0
	if front.length_squared() < 1.0:
		front = Vector3.BACK
	front = front.normalized()

	var map: RID = squad[0].get_world_3d().navigation_map
	var aim_height: float = squad[0].target_aim_height
	for side: float in [_flank_side, -_flank_side]:
		for angle_extra: float in [0.0, 18.0, -18.0]:
			var angle: float = deg_to_rad(flank_angle_degrees + angle_extra) * side
			for distance: float in [flank_distance, flank_distance + 3.0, flank_distance - 2.5]:
				var raw: Vector3 = target_position + front.rotated(Vector3.UP, angle) * distance
				var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(map, raw)
				if _flat_distance(nav_point, raw) > 2.5:
					continue
				if not _has_line_of_sight(nav_point, target_position, aim_height):
					continue
				if _is_near_members(nav_point, squad, 3.0):
					continue
				return nav_point
	return Vector3.INF

#endregion


#region Orders and slots

func _issue_order(enemy: BaseEnemy, now: float) -> void:
	var member: Member = _data[enemy]
	var order: SquadOrder = member.order
	order.aim_position = squad_known_position
	order.issued_at = now
	order.speed_scale = 1.0
	order.has_destination = true

	if enemy == _flanker:
		order.role = &"flank"
		order.destination = _flank_slot
		order.may_fire = false
		order.speed_scale = flank_speed_scale
	elif member.has_token:
		order.role = &"attack"
		order.may_fire = true
		order.destination = _get_fire_position(member, now)
	else:
		order.role = &"cover"
		order.may_fire = false
		order.destination = _get_cover_position(member, now)
		if enemy.is_reloading():
			order.speed_scale = 1.1
	_taken.append(order.destination)


func _get_fire_position(member: Member, now: float) -> Vector3:
	var enemy: BaseEnemy = member.enemy
	var here: Vector3 = enemy.global_position
	var distance: float = _flat_distance(here, squad_known_position)
	var in_band: bool = distance >= enemy.min_attack_range and distance <= enemy.attack_range - 0.5

	# Already a good spot: stay and shoot.
	if enemy.target_visible and in_band and not _is_near_any(here, _taken, slot_spacing * 0.6):
		member.fire_position = here
		member.fire_time = now
		member.fire_target = squad_known_position
		return here

	if _cache_valid(member.fire_position, member.fire_target, member.fire_time, now) \
			and not _is_near_any(member.fire_position, _taken, slot_spacing):
		return member.fire_position

	var found: Vector3 = _find_fire_position(member)
	member.fire_position = found
	member.fire_time = now
	member.fire_target = squad_known_position
	return found


func _find_fire_position(member: Member) -> Vector3:
	var enemy: BaseEnemy = member.enemy
	var target_position: Vector3 = squad_known_position
	var low: float = enemy.min_attack_range
	var high: float = maxf(enemy.attack_range - 1.0, low + 1.0)
	var map: RID = enemy.get_world_3d().navigation_map
	var from: Vector3 = enemy.global_position
	# Stay on our own side of the target so we do not run across its field of view.
	var bearing: float = atan2(from.x - target_position.x, from.z - target_position.z)

	var best: Vector3 = Vector3.INF
	var best_score: float = INF
	for i: int in fire_samples:
		var offset: float = deg_to_rad(randf_range(-70.0, 70.0))
		var radius: float = randf_range(low, high)
		var raw: Vector3 = target_position + Vector3(sin(bearing + offset), 0.0, cos(bearing + offset)) * radius
		var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(map, raw)
		if _flat_distance(nav_point, raw) > 2.0:
			continue
		var range_to_target: float = _flat_distance(nav_point, target_position)
		if range_to_target < low or range_to_target > high + 0.5:
			continue
		if not _has_line_of_sight(nav_point, target_position, enemy.target_aim_height):
			continue
		if _is_near_any(nav_point, _taken, slot_spacing) or _is_bad(member, nav_point):
			continue
		var score: float = from.distance_to(nav_point) + absf(range_to_target - (low + high) * 0.5) * 0.3
		if score < best_score:
			best_score = score
			best = nav_point

	if best == Vector3.INF:
		var away: Vector3 = from - target_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.01 else Vector3.BACK
		best = NavigationServer3D.map_get_closest_point(map, target_position + away * high)
	return best


func _get_cover_position(member: Member, now: float) -> Vector3:
	var enemy: BaseEnemy = member.enemy
	var here: Vector3 = enemy.global_position
	var target_position: Vector3 = squad_known_position

	# Already hidden and not too close: stay put.
	if not _has_line_of_sight(here, target_position, enemy.target_aim_height) \
			and _flat_distance(here, target_position) >= cover_min_distance \
			and not _is_near_any(here, _taken, slot_spacing * 0.6):
		member.cover_position = here
		member.cover_time = now
		member.cover_target = target_position
		return here

	if _cache_valid(member.cover_position, member.cover_target, member.cover_time, now) \
			and not _is_near_any(member.cover_position, _taken, slot_spacing):
		return member.cover_position

	var found: Vector3 = _find_cover_position(member)
	member.cover_position = found
	member.cover_time = now
	member.cover_target = target_position
	return found


func _find_cover_position(member: Member) -> Vector3:
	var enemy: BaseEnemy = member.enemy
	var target_position: Vector3 = squad_known_position
	var map: RID = enemy.get_world_3d().navigation_map
	var from: Vector3 = enemy.global_position
	var current_range: float = _flat_distance(from, target_position)
	var max_range: float = enemy.attack_range * 1.8

	var best: Vector3 = Vector3.INF
	var best_score: float = INF
	for i: int in cover_samples:
		var angle: float = randf() * TAU
		var radius: float = randf_range(2.0, cover_search_radius)
		var raw: Vector3 = from + Vector3(sin(angle), 0.0, cos(angle)) * radius
		var nav_point: Vector3 = NavigationServer3D.map_get_closest_point(map, raw)
		if _flat_distance(nav_point, raw) > 2.0:
			continue
		var range_to_target: float = _flat_distance(nav_point, target_position)
		if range_to_target < cover_min_distance or range_to_target > max_range:
			continue
		# Do not run towards the player just to hide.
		if range_to_target < current_range - 3.0:
			continue
		if _has_line_of_sight(nav_point, target_position, enemy.target_aim_height):
			continue
		if _is_near_any(nav_point, _taken, slot_spacing) or _is_bad(member, nav_point):
			continue
		var score: float = from.distance_to(nav_point) + randf() * 0.5
		if score < best_score:
			best_score = score
			best = nav_point

	# No cover around: hold position.
	return best if best != Vector3.INF else from

#endregion


#region Helpers

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _is_active(enemy: BaseEnemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead and enemy.is_engaged


func _engaged_count() -> int:
	var count: int = 0
	for enemy: BaseEnemy in members:
		if _is_active(enemy):
			count += 1
	return count


func _prune_members() -> void:
	for index: int in range(members.size() - 1, -1, -1):
		if not is_instance_valid(members[index]):
			members.remove_at(index)
	for key: Variant in _data.keys():
		if not is_instance_valid(key):
			_data.erase(key)
	if members.is_empty() and is_inside_tree():
		queue_free()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _is_near_any(point: Vector3, points: Array[Vector3], distance: float) -> bool:
	for other: Vector3 in points:
		if _flat_distance(point, other) < distance:
			return true
	return false


func _is_near_members(point: Vector3, squad: Array[BaseEnemy], distance: float) -> bool:
	for enemy: BaseEnemy in squad:
		if _flat_distance(point, enemy.global_position) < distance:
			return true
	return false


func _is_bad(member: Member, point: Vector3) -> bool:
	for bad: Vector3 in member.bad_positions:
		if _flat_distance(point, bad) < 1.5:
			return true
	return false


func _cache_valid(cached: Vector3, cached_for: Vector3, cached_time: float, now: float) -> bool:
	return cached != Vector3.INF \
			and now - cached_time < position_refresh \
			and _flat_distance(cached_for, squad_known_position) < retarget_distance


func _path_length(path: PackedVector3Array) -> float:
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## True when a standing enemy at `point` could see the target (world geometry only).
func _has_line_of_sight(point: Vector3, target_position: Vector3, aim_height: float) -> bool:
	if not is_instance_valid(squad_target):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 1.5,
		target_position + Vector3.UP * aim_height,
		world_mask
	)
	var result: Dictionary = squad_target.get_world_3d().direct_space_state.intersect_ray(query)
	return result.is_empty()

#endregion
