class_name PlayerBuildResolver extends Node

signal build_changed
signal signature_cooldown_changed(remaining: float, maximum: float)

const SKILLS_PER_TIER: int = 2
const LINK_META: StringName = &"perk_link_until"

@export_range(0, 100) var starting_skill_points: int = 18
@export var player_stats: PlayerStats
@export var player: PlayerController
@export var perk_decks: Array[PerkDeckData] = []
@export var skill_nodes: Array[SkillNodeData] = []

var perk_slots: Array[PerkDeckData] = [null, null, null]
var purchased_skill_ranks: Dictionary = {}
var signature_cooldown_left: float = 0.0
var _signature_cooldown_max: float = 0.0
var _temporary_stat_modifiers: Array[StatModifier] = []
var _temporary_modifier_time: float = 0.0


func _ready() -> void:
	add_to_group(&"player_build_resolver")
	if perk_decks.is_empty():
		perk_decks = _make_deck_roster()
	if skill_nodes.is_empty():
		skill_nodes = _make_demo_skills()
	_bind_player()
	_connect_combat_events()
	_refresh_player_stats()
	call_deferred("_bind_player_after_ready")


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if signature_cooldown_left > 0.0:
		signature_cooldown_left = maxf(signature_cooldown_left - delta, 0.0)
		signature_cooldown_changed.emit(signature_cooldown_left, _signature_cooldown_max)
	if _temporary_modifier_time > 0.0:
		_temporary_modifier_time = maxf(_temporary_modifier_time - delta, 0.0)
		if _temporary_modifier_time == 0.0:
			_temporary_stat_modifiers.clear()
			_refresh_player_stats()


func bind_player_stats(stats: PlayerStats) -> void:
	player_stats = stats
	_refresh_player_stats()


func bind_player(new_player: PlayerController) -> void:
	player = new_player
	if is_instance_valid(player):
		player_stats = player.player_stats
	_refresh_player_stats()


func select_perk(slot: int, deck_id: StringName) -> bool:
	if slot < 0 or slot >= perk_slots.size():
		return false
	if slot > 0 and perk_slots[slot - 1] == null:
		return false
	var deck := get_deck(deck_id)
	if deck == null:
		return false
	perk_slots[slot] = deck
	_refresh_player_stats()
	return true


func clear_perk_slot(slot: int) -> void:
	if slot < 0 or slot >= perk_slots.size():
		return
	for index: int in range(slot, perk_slots.size()):
		perk_slots[index] = null
	_refresh_player_stats()


func get_deck(deck_id: StringName) -> PerkDeckData:
	for deck: PerkDeckData in perk_decks:
		if deck != null and deck.deck_id == deck_id:
			return deck
	return null


func get_slot_deck(slot: int) -> PerkDeckData:
	if slot < 0 or slot >= perk_slots.size():
		return null
	return perk_slots[slot]


func get_deck_tier(deck_id: StringName) -> int:
	var tier := 0
	for deck: PerkDeckData in perk_slots:
		if deck != null and deck.deck_id == deck_id:
			tier += 1
	return tier


func get_slot_tier(slot: int) -> int:
	var deck := get_slot_deck(slot)
	if deck == null:
		return 0
	var tier := 0
	for index: int in range(slot + 1):
		var earlier_deck := perk_slots[index]
		if earlier_deck != null and earlier_deck.deck_id == deck.deck_id:
			tier += 1
	return tier


func get_active_gadget_name() -> String:
	var role_deck := perk_slots[0]
	if role_deck == null:
		return "Select a Slot I role deck"
	return role_deck.signature_gadget_name


func get_active_gadget_scene() -> PackedScene:
	var role_deck := perk_slots[0]
	return role_deck.role_gadget_scene if role_deck != null else null


func activate_signature(user: PlayerController = null) -> bool:
	if user != null:
		bind_player(user)
	if not is_instance_valid(player):
		_bind_player()
	if not is_instance_valid(player) or perk_slots[0] == null:
		return false
	if signature_cooldown_left > 0.0:
		return false

	var deck: PerkDeckData = perk_slots[0]
	var tier: int = get_deck_tier(deck.deck_id)
	var radius: float = deck.gadget_radius * (1.0 + 0.25 * float(maxi(tier - 1, 0)))
	_apply_signature_effect(deck, tier, radius)
	signature_cooldown_left = maxf(deck.gadget_cooldown * (1.0 - 0.15 * float(tier - 1)), 1.0)
	_signature_cooldown_max = signature_cooldown_left
	signature_cooldown_changed.emit(signature_cooldown_left, _signature_cooldown_max)
	EventBus.on_gadget_activated.emit(player, deck.deck_id)
	return true


func get_unspent_skill_points() -> int:
	return maxi(0, starting_skill_points - _get_spent_skill_points())


func get_skill_node(node_id: StringName) -> SkillNodeData:
	for skill: SkillNodeData in skill_nodes:
		if skill != null and skill.node_id == node_id:
			return skill
	return null


func get_skill_rank(node_id: StringName) -> int:
	return int(purchased_skill_ranks.get(node_id, 0))


func get_skill_point_cost_next_rank(node_id: StringName) -> int:
	var skill := get_skill_node(node_id)
	if skill == null:
		return 0
	match get_skill_rank(node_id):
		0:
			return skill.basic_point_cost
		1:
			return skill.ace_point_cost
	return 0


func is_skill_tier_unlocked(branch: SkillNodeData.Branch, tier: int) -> bool:
	if tier <= 1:
		return true
	if _has_basic_skill_in_tier(branch, tier - 1):
		return true
	return tier >= 3 and _has_aced_tier(branch, tier - 2)


func can_purchase_skill_rank(node_id: StringName) -> bool:
	var skill := get_skill_node(node_id)
	if skill == null or get_skill_rank(node_id) >= 2:
		return false
	if get_unspent_skill_points() < get_skill_point_cost_next_rank(node_id):
		return false
	if not is_skill_tier_unlocked(skill.branch, skill.tier):
		return false
	for prerequisite_id: StringName in skill.prerequisite_ids:
		if get_skill_rank(prerequisite_id) == 0:
			return false
	return true


func purchase_skill_rank(node_id: StringName) -> bool:
	if not can_purchase_skill_rank(node_id):
		return false
	purchased_skill_ranks[node_id] = get_skill_rank(node_id) + 1
	_refresh_player_stats()
	return true


func reset_build() -> void:
	perk_slots = [null, null, null]
	purchased_skill_ranks.clear()
	signature_cooldown_left = 0.0
	_temporary_modifier_time = 0.0
	_temporary_stat_modifiers.clear()
	_refresh_player_stats()


func _bind_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as PlayerController
	if is_instance_valid(player):
		player_stats = player.player_stats


func _bind_player_after_ready() -> void:
	_bind_player()
	_refresh_player_stats()


func _connect_combat_events() -> void:
	var connections: Array[Array] = [
		[EventBus.on_hit_dealt, _on_hit_dealt],
		[EventBus.on_crit_hit, _on_crit_hit],
		[EventBus.on_armor_broken, _on_armor_broken],
		[EventBus.on_enemy_stumbled, _on_enemy_stumbled],
		[EventBus.on_enemy_fallen, _on_enemy_fallen],
		[EventBus.on_enemy_killed, _on_enemy_killed],
		[EventBus.on_damage_taken, _on_damage_taken],
		[EventBus.on_armor_regen_started, _on_armor_regen_started],
		[EventBus.on_bullet_time_toggled, _on_bullet_time_toggled],
		[EventBus.on_dive_or_slide, _on_dive_or_slide],
		[EventBus.on_vault, _on_vault],
		[EventBus.on_prop_thrown, _on_prop_thrown],
	]
	for connection: Array in connections:
		var event_signal: Signal = connection[0]
		var callback: Callable = connection[1]
		if not event_signal.is_connected(callback):
			event_signal.connect(callback)


func _refresh_player_stats() -> void:
	var perk_modifiers: Array[StatModifier] = []
	var skill_modifiers: Array[StatModifier] = []
	var resolved_deck_tiers: Dictionary = {}

	for slot: int in range(perk_slots.size()):
		var deck := perk_slots[slot]
		if deck == null:
			continue
		var tier: int = int(resolved_deck_tiers.get(deck.deck_id, 0)) + 1
		resolved_deck_tiers[deck.deck_id] = tier
		perk_modifiers.append_array(deck.get_modifiers_for_tier(tier))

	for skill: SkillNodeData in skill_nodes:
		if skill == null:
			continue
		var rank := get_skill_rank(skill.node_id)
		if rank >= 1:
			skill_modifiers.append_array(skill.basic_stat_modifiers)
		if rank >= 2:
			skill_modifiers.append_array(skill.ace_stat_modifiers)
	perk_modifiers.append_array(_temporary_stat_modifiers)

	if is_instance_valid(player_stats):
		player_stats.set_build_modifiers(perk_modifiers, skill_modifiers)
	build_changed.emit()


func _apply_signature_effect(deck: PerkDeckData, tier: int, radius: float) -> void:
	var enemies := _get_enemies_in_radius(radius)
	match deck.signature_effect:
		&"momentum_dash":
			var direction: Vector3 = -player.global_transform.basis.z
			player.velocity.x += direction.x * (5.0 + float(tier))
			player.velocity.z += direction.z * (5.0 + float(tier))
			player.increase_tiredness(-18.0)
			player_stats.notify_slide_or_vault()
			EventBus.on_objective_tick.emit(player, null)
		&"objective_lock_field":
			for enemy: BaseEnemy in enemies:
				_apply_enemy_suppression(enemy, 0.35 + 0.1 * float(tier))
			EventBus.on_objective_tick.emit(player, null)
		&"disruption_pulse":
			for enemy: BaseEnemy in enemies:
				_apply_enemy_suppression(enemy, 0.45 + 0.1 * float(tier))
				_damage_enemy(enemy, 8.0, 0.6)
		&"stumble_inversion":
			for enemy: BaseEnemy in enemies:
				_damage_enemy(enemy, 35.0 + 5.0 * float(tier - 1), 1.5)
		&"tempo_pin":
			for enemy: BaseEnemy in enemies:
				_apply_enemy_suppression(enemy, 0.5 + 0.1 * float(tier))
		&"sympathetic_link":
			if not enemies.is_empty():
				enemies[0].set_meta(LINK_META, Time.get_ticks_msec() + 8000 + tier * 2000)
		&"breach_ram":
			var direction: Vector3 = -player.global_transform.basis.z
			player.velocity.x += direction.x * (8.0 + 2.0 * float(tier))
			player.velocity.z += direction.z * (8.0 + 2.0 * float(tier))
			for enemy: BaseEnemy in enemies:
				_damage_enemy(enemy, 35.0, 1.5)
		&"armor_sunder":
			for enemy: BaseEnemy in enemies:
				_damage_enemy(enemy, 20.0, 1.2, 0.75)
		&"execution_reap":
			for enemy: BaseEnemy in enemies:
				if enemy.is_stumbling or enemy.is_broken():
					_damage_enemy(enemy, 100.0 + 25.0 * float(tier - 1), 1.0)
		&"rapid_regen":
			_restore_player_armor(12.0 + 4.0 * float(tier - 1))
		&"aegis_bastion":
			_restore_player_armor(8.0 + 4.0 * float(tier - 1))
			for enemy: BaseEnemy in enemies:
				_apply_enemy_suppression(enemy, 0.25)
		&"damage_inversion":
			player.increase_tiredness(-25.0)
			_restore_player_armor(6.0)
		&"opening_sight":
			_apply_temporary_modifier(
				_make_modifier({"crit_chance": 0.12 + 0.04 * float(tier - 1)}), 3.0 + float(tier)
			)
		&"phantom_slip":
			player_stats.notify_slide_or_vault()
			player.increase_tiredness(-12.0)
			_apply_temporary_modifier(
				_make_modifier({"dodge_chance": 0.12, "crit_chance": 0.08}), 2.0 + float(tier)
			)


func _get_enemies_in_radius(radius: float) -> Array[BaseEnemy]:
	var result: Array[BaseEnemy] = []
	var seen: Dictionary = {}
	for enemy_variant: Variant in get_tree().get_nodes_in_group(&"normal_enemies"):
		var enemy := enemy_variant as BaseEnemy
		if enemy == null or enemy.is_dead or seen.has(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) > radius:
			continue
		seen[enemy] = true
		result.append(enemy)
	return result


func _apply_enemy_suppression(enemy: BaseEnemy, amount: float) -> void:
	if enemy.morale == null:
		return
	enemy.morale.shock = clampf(enemy.morale.shock + amount, 0.0, 1.0)
	enemy.morale.fear = clampf(enemy.morale.fear + amount * 0.5, 0.0, 1.0)


func _damage_enemy(
	enemy: BaseEnemy, damage: float, impact: float, armor_penetration: float = 0.0
) -> void:
	var health: HealthComponent = enemy.health_component
	if health == null or not health.is_alive:
		return
	var info := DamageInfo.new(damage, player, "perk")
	info.impact_multiplier = impact
	info.armor_penetration = armor_penetration
	info.impact_position = enemy.global_position + Vector3.UP
	info.impact_direction = (enemy.global_position - player.global_position).normalized()
	health.take_damage_with_info(info)


func _restore_player_armor(amount: float) -> void:
	if not is_instance_valid(player):
		return
	var health: HealthComponent = player.health_component
	if health == null or amount <= 0.0:
		return
	var previous: float = health.current_armor
	health.current_armor = minf(health.armor_value, previous + amount)
	if health.current_armor != previous:
		health.armor_changed.emit(health.current_armor, health.armor_value)


func _apply_temporary_modifier(modifier: StatModifier, duration: float) -> void:
	_temporary_stat_modifiers = [modifier]
	_temporary_modifier_time = duration
	_refresh_player_stats()


func _restore_focus(amount: float) -> void:
	if not is_instance_valid(player):
		return
	var bullet_time := player.get_node_or_null("Component/BulletTime") as BulletTime
	if bullet_time != null:
		bullet_time.add_focus(amount)


func _on_hit_dealt(attacker: Node, target: Node, _damage: float) -> void:
	if attacker != player or target == null:
		return
	if get_deck_tier(&"DECK_06") > 0 and target is BaseEnemy:
		target.set_meta(LINK_META, Time.get_ticks_msec() + 8000)
	if target.has_meta(LINK_META) and int(target.get_meta(LINK_META)) >= Time.get_ticks_msec():
		var target_health := _find_health(target)
		if target_health != null:
			target_health.take_damage_with_info(DamageInfo.new(3.0, player, "linked"))
		if get_deck_tier(&"DECK_06") >= 2:
			_restore_focus(1.0)


func _on_crit_hit(attacker: Node, target: Node, _damage: float) -> void:
	if attacker != player:
		return
	if get_deck_tier(&"DECK_03") > 0:
		_restore_player_armor(2.0 + get_deck_tier(&"DECK_03"))
	if get_deck_tier(&"DECK_09") > 0:
		_restore_focus(1.0)
	if get_deck_tier(&"DECK_02") >= 3 and target is BaseEnemy:
		_restore_focus(2.0)
		var enemy := target as BaseEnemy
		if enemy is NormalEnemy:
			(enemy as NormalEnemy).stumble_cooldown_left = maxf(
				(enemy as NormalEnemy).stumble_cooldown_left - 0.25, 0.0
			)
		if enemy.morale != null:
			enemy.morale.shock = clampf(enemy.morale.shock + 0.1, 0.0, 1.0)
	if target is BaseEnemy and (target as BaseEnemy).is_broken():
		if get_deck_tier(&"DECK_02") > 0:
			_restore_focus(2.0)


func _on_armor_broken(target: Node, attacker: Node) -> void:
	if attacker != player:
		return
	if get_deck_tier(&"DECK_11") > 0 and target is BaseEnemy:
		_apply_enemy_suppression(target as BaseEnemy, 0.25)
		if get_deck_tier(&"DECK_11") >= 3:
			_damage_enemy(target as BaseEnemy, 10.0, 4.0)
	if get_deck_tier(&"DECK_04") > 0:
		_restore_player_armor(4.0)
	if get_deck_tier(&"DECK_11") >= 3:
		_restore_player_armor(4.0)


func _on_enemy_stumbled(enemy: Node, attacker: Node) -> void:
	if attacker != player:
		return
	if get_deck_tier(&"DECK_03") > 0:
		_restore_player_armor(3.0)
	if (
		get_deck_tier(&"DECK_07") > 0
		or get_deck_tier(&"DECK_10") > 0
		or get_deck_tier(&"DECK_12") >= 2
	):
		_restore_focus(2.0)
	if get_deck_tier(&"DECK_06") >= 2 and enemy is BaseEnemy:
		for nearby: BaseEnemy in _get_enemies_in_radius(6.0):
			if nearby != enemy:
				_apply_enemy_suppression(nearby, 0.12)
	if get_deck_tier(&"DECK_13") > 0 and enemy is BaseEnemy and (enemy as BaseEnemy).is_broken():
		_apply_temporary_modifier(
			_make_modifier({"damage_modifier": 0.08 * float(get_deck_tier(&"DECK_13"))}), 2.0
		)


func _on_enemy_fallen(enemy: Node, attacker: Node) -> void:
	if attacker != player or not enemy is BaseEnemy:
		return
	var fallen_enemy := enemy as BaseEnemy
	if get_deck_tier(&"DECK_10") >= 3:
		for nearby: BaseEnemy in _get_enemies_in_radius(6.0):
			if nearby != fallen_enemy:
				_apply_enemy_suppression(nearby, 0.2)
				_damage_enemy(nearby, 10.0, 0.75)
	if get_deck_tier(&"DECK_07") >= 3:
		for nearby: BaseEnemy in _get_enemies_in_radius(5.0):
			if nearby != fallen_enemy:
				_damage_enemy(nearby, 10.0, 0.75)


func _on_enemy_killed(enemy: Node, attacker: Node) -> void:
	if attacker != player:
		return
	if get_deck_tier(&"DECK_13") > 0:
		_restore_focus(5.0 + float(get_deck_tier(&"DECK_13")) * 2.0)
		_restore_player_armor(3.0)
	if get_deck_tier(&"DECK_06") >= 3:
		_restore_focus(4.0)
	if get_deck_tier(&"DECK_13") >= 2:
		for nearby: BaseEnemy in _get_enemies_in_radius(6.0):
			if nearby != enemy:
				_apply_enemy_suppression(nearby, 0.2)
	if get_deck_tier(&"DECK_06") >= 3 and enemy != null:
		for nearby: BaseEnemy in _get_enemies_in_radius(6.0):
			if nearby != enemy:
				_apply_enemy_suppression(nearby, 0.2)


func _on_damage_taken(target: Node, damage: float, _armor_damage: float) -> void:
	if target != player:
		return
	var grit_tier: int = get_deck_tier(&"DECK_08")
	if grit_tier > 0:
		for enemy: BaseEnemy in _get_enemies_in_radius(3.0):
			_apply_enemy_suppression(enemy, 0.08)
	if grit_tier >= 2 and damage >= 20.0:
		player.increase_tiredness(-3.0 * float(grit_tier))
	if grit_tier >= 3 and damage >= 35.0:
		_apply_temporary_modifier(_make_modifier({"crit_chance": 0.05}), 2.0)


func _on_armor_regen_started(target: Node) -> void:
	if target == player and get_deck_tier(&"DECK_03") >= 3:
		_apply_temporary_modifier(_make_modifier({"damage_modifier": 0.08}), 3.0)


func _on_bullet_time_toggled(user: Node, active: bool) -> void:
	if user != player or active or get_deck_tier(&"DECK_12") == 0:
		return
	for enemy: BaseEnemy in _get_enemies_in_radius(8.0):
		_apply_enemy_suppression(enemy, 0.25)
	_restore_focus(3.0 * float(get_deck_tier(&"DECK_12")))


func _on_dive_or_slide(user: Node) -> void:
	if user != player:
		return
	var momentum_tier: int = get_deck_tier(&"DECK_00")
	if momentum_tier > 0:
		_restore_focus(2.0)
		if momentum_tier >= 2:
			player.increase_tiredness(-5.0)
		EventBus.on_objective_tick.emit(player, null)
		if momentum_tier >= 3:
			_apply_temporary_modifier(
				_make_modifier({"crit_chance": 0.05, "movement_speed": 0.05}), 2.0
			)
	var breacher_tier: int = get_deck_tier(&"DECK_07")
	if breacher_tier > 0:
		for enemy: BaseEnemy in _get_enemies_in_radius(2.5):
			_damage_enemy(enemy, 10.0 + 5.0 * float(breacher_tier), 1.5)


func _on_vault(user: Node) -> void:
	if user == player and get_deck_tier(&"DECK_00") > 0:
		_restore_focus(2.0)


func _on_prop_thrown(user: Node, _prop: Node) -> void:
	if user == player and get_deck_tier(&"DECK_06") > 0:
		for enemy: BaseEnemy in _get_enemies_in_radius(6.0):
			_apply_enemy_suppression(enemy, 0.15)


func _find_health(target: Node) -> HealthComponent:
	var current: Node = target
	while current != null:
		if current is HealthComponent:
			return current as HealthComponent
		var health := current.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			return health
		current = current.get_parent()
	return null


func _has_basic_skill_in_tier(branch: SkillNodeData.Branch, tier: int) -> bool:
	for skill: SkillNodeData in skill_nodes:
		if skill != null and skill.branch == branch and skill.tier == tier:
			if get_skill_rank(skill.node_id) >= 1:
				return true
	return false


func _has_aced_tier(branch: SkillNodeData.Branch, tier: int) -> bool:
	var found := 0
	for skill: SkillNodeData in skill_nodes:
		if skill != null and skill.branch == branch and skill.tier == tier:
			found += 1 if get_skill_rank(skill.node_id) >= 2 else 0
	return found >= SKILLS_PER_TIER


func _get_spent_skill_points() -> int:
	var spent := 0
	for node_id: StringName in purchased_skill_ranks:
		var skill := get_skill_node(node_id)
		if skill == null:
			continue
		var rank := get_skill_rank(node_id)
		if rank >= 1:
			spent += skill.basic_point_cost
		if rank >= 2:
			spent += skill.ace_point_cost
	return spent


func _make_deck_roster() -> Array[PerkDeckData]:
	var decks: Array[PerkDeckData] = []
	var deck: PerkDeckData

	deck = _make_deck(&"DECK_00", "Momentum Runner", "Zero-Cooldown Dive Phase", &"momentum_dash")
	deck.tier_1_modifiers.append(
		_make_modifier({"swiftness": 8.0, "stamina_drain_multiplier": -0.1})
	)
	deck.tier_1_modifiers.append(
		_make_modifier({}, {}, [&"dive_no_cooldown", &"dive_tiredness_free"])
	)
	deck.tier_2_modifiers.append(_make_modifier({"stamina_drain_multiplier": -0.1}))
	deck.tier_2_modifiers.append(
		_make_modifier({}, {}, [&"dive_momentum_extended", &"carry_swiftness"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"movement_chain_crit", &"objective_progress_bonus"])
	)
	decks.append(deck)

	deck = _make_deck(
		&"DECK_01", "Disruption Emitter", "Aim & Morale Scramble", &"disruption_pulse"
	)
	deck.tier_1_modifiers.append(
		_make_modifier({}, {}, [&"disruption_unlocked", &"enemy_aim_scramble"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier({}, {}, [&"disruption_extra_charge", &"disruption_recharge_on_stagger"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"disrupted_target_bonus_damage", &"broken_token_priority_reduced"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_02", "Precision & Bullet Time", "Opening Sight", &"opening_sight")
	deck.tier_1_modifiers.append(
		_make_modifier({"crit_chance": 0.03}, {}, [&"crit_while_aiming", &"crit_while_bullet_time"])
	)
	deck.tier_2_modifiers.append(_make_modifier({"crit_multiplier": 0.25}, {}, [&"aim_steadiness"]))
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"crit_extends_disruption", &"crit_refunds_focus"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_03", "Regen Accelerator", "Rapid Regen Cycle", &"rapid_regen")
	deck.tier_1_modifiers.append(
		_make_modifier({"armor_regeneration_delay": -0.75, "armor_regeneration_rate": 1.0})
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"armor_regeneration_rate": 1.5}, {}, [&"armor_pulse_on_stumble"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"armor_cycle_damage_buff", &"armor_cycle_stagger_resist"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_04", "Mount & Hold Bastion", "Aegis Bastion", &"aegis_bastion")
	deck.tier_1_modifiers.append(
		_make_modifier({"max_armor": 20.0, "damage_mitigation": 0.05}, {}, [&"mounted_poise"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier(
			{"recoil_stability": 0.9, "armor_regeneration_delay": -0.4}, {}, [&"anchored_poise"]
		)
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"hold_ground_counter_stagger", &"objective_protection"])
	)
	decks.append(deck)

	deck = _make_deck(
		&"DECK_05", "Objective Bastion", "Objective Lock Field", &"objective_lock_field"
	)
	deck.tier_1_modifiers.append(
		_make_modifier({"objective_interaction_speed": 0.15}, {}, [&"objective_lock_field"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"damage_mitigation": 0.05}, {}, [&"objective_interact_armor"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({"objective_interaction_speed": 0.2}, {}, [&"objective_kill_focus_refund"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_06", "Link & Follow-Up", "Sympathetic Link", &"sympathetic_link")
	deck.tier_1_modifiers.append(_make_modifier({}, {}, [&"sympathetic_link"]))
	deck.tier_2_modifiers.append(
		_make_modifier({"weapon_handling": 0.1}, {}, [&"link_shock_spread"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"linked_kill_chain_shock", &"linked_kill_focus_refund"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_07", "Kinetic Breacher", "Breach Ram", &"breach_ram")
	deck.tier_1_modifiers.append(
		_make_modifier({"impact_multiplier": 0.2, "dive_speed": 1.1}, {}, [&"breach_ram"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"dive_land_slide": 1.2}, {}, [&"dive_stagger_protection"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"breach_burst_damage", &"breach_area_stumble"])
	)
	decks.append(deck)

	deck = _make_deck(
		&"DECK_08", "Grit & Poise", "Damage / Resource Inversion", &"damage_inversion"
	)
	deck.tier_1_modifiers.append(
		_make_modifier(
			{"fall_damage_scale": 0.8, "stamina_drain_multiplier": -0.1}, {}, [&"stagger_poise"]
		)
	)
	deck.tier_2_modifiers.append(
		_make_modifier({}, {}, [&"heavy_hit_tiredness_recovery", &"stumble_to_poise"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"pressure_stagger_pulse", &"next_burst_crit"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_09", "Flank & Swiftness Crit", "Phantom Slip", &"phantom_slip")
	deck.tier_1_modifiers.append(
		_make_modifier({}, {}, [&"dodge_enabled", &"crit_swiftness_enabled", &"phantom_slip"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"spread_multiplier": 0.9}, {}, [&"flank_awareness_break"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({"damage_modifier": 0.1}, {}, [&"moving_crit_cooldown"])
	)
	decks.append(deck)

	deck = _make_deck(
		&"DECK_10", "Ragdoll / Stumble Driver", "Physics Stumble Inversion", &"stumble_inversion"
	)
	deck.tier_1_modifiers.append(
		_make_modifier({"impact_multiplier": 0.25}, {}, [&"stumble_intensity_bonus"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier(
			{}, {}, [&"lower_fall_threshold", &"shorter_stumble_immunity", &"ragdoll_impulse_bonus"]
		)
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"stumble_morale_fear", &"ragdoll_collision_damage"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_11", "Armor Breaker", "Armor Sunder", &"armor_sunder")
	deck.tier_1_modifiers.append(
		_make_modifier({"armor_penetration_bonus": 0.15}, {}, [&"armor_sunder"])
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"armor_penetration_bonus": 0.15}, {}, [&"burst_armor_shred"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"armor_break_knockdown", &"armor_break_defense"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_12", "Tempo & Token Suppressor", "Token & Tempo Pin", &"tempo_pin")
	deck.tier_1_modifiers.append(
		_make_modifier(
			{"bullet_time_drain_multiplier": -0.1},
			{},
			[&"token_priority_reduced", &"tempo_suppression"]
		)
	)
	deck.tier_2_modifiers.append(
		_make_modifier({"bullet_time_regen_multiplier": 0.15}, {}, [&"stagger_focus_refund"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"bullet_time_exit_slow", &"broken_spread_penalty"])
	)
	decks.append(deck)

	deck = _make_deck(&"DECK_13", "Execution Reaver", "Execution Reap", &"execution_reap")
	deck.tier_1_modifiers.append(
		_make_modifier(
			{"damage_modifier": 0.08}, {}, [&"impaired_target_damage", &"execution_resource_refund"]
		)
	)
	deck.tier_2_modifiers.append(
		_make_modifier({}, {}, [&"execution_focus_armor_refund", &"execution_morale_fear"])
	)
	deck.tier_3_modifiers.append(
		_make_modifier(
			{"damage_modifier": 0.1}, {}, [&"execution_chain_damage", &"execution_chain_sustain"]
		)
	)
	decks.append(deck)

	return decks


func _make_demo_skills() -> Array[SkillNodeData]:
	var result: Array[SkillNodeData] = []
	var titles: Array = [
		[
			["Kinetic Conditioning", "Swiftness Training"],
			["Evasive Footwork", "Efficient Sprint"],
			["Fluid Handling", "Concentrated Aim"],
			["Quickdraw Specialist", "Mobile Overdrive"],
		],
		[
			["Reinforced Plating", "Armor Recovery"],
			["Concussive Impact", "Rapid Regeneration"],
			["Heavy Weapon Discipline", "Objective Guard"],
			["Unyielding", "Last Stand"],
		],
		[
			["Objective Specialist", "Tactical Economy"],
			["Suppression Recovery", "Field Repair"],
			["Combat Logistics", "Fast Interaction"],
			["Mission Control", "Team Sustain"],
		],
	]
	var descriptions: Array = [
		[
			"Improves stamina efficiency and loadout swiftness.",
			"Improves armor sustain and impact response.",
			"Improves objective utility and combat recovery.",
		],
		[
			"Gain an additional stat bonus when this node is Aced.",
			"Gain an additional stat bonus when this node is Aced.",
			"Gain an additional stat bonus when this node is Aced.",
		],
		[
			"Builds on lower-tier mobility and handling.",
			"Builds on lower-tier armor and stagger tuning.",
			"Builds on lower-tier fieldcraft utility.",
		],
		[
			"Tier 4 specialization node.",
			"Tier 4 specialization node.",
			"Tier 4 specialization node.",
		],
	]
	for branch: int in range(3):
		for tier: int in range(4):
			for choice: int in range(SKILLS_PER_TIER):
				var node_id := StringName("skill_%d_%d_%d" % [branch, tier + 1, choice + 1])
				var skill := SkillNodeData.new()
				skill.node_id = node_id
				skill.display_name = titles[branch][tier][choice]
				skill.branch = branch as SkillNodeData.Branch
				skill.tier = tier + 1
				skill.basic_point_cost = 1
				skill.ace_point_cost = 2
				skill.description = descriptions[min(tier, descriptions.size() - 1)][branch]
				skill.basic_stat_modifiers = [_skill_modifier(branch, tier + 1, choice, false)]
				skill.ace_stat_modifiers = [_skill_modifier(branch, tier + 1, choice, true)]
				result.append(skill)
	return result


func _skill_modifier(branch: int, tier: int, choice: int, ace: bool) -> StatModifier:
	var modifier := StatModifier.new()
	var scale: float = 1.5 if ace else 1.0
	match branch:
		SkillNodeData.Branch.AGILITY:
			match tier:
				1:
					if choice == 0:
						modifier.multipliers[&"stamina_drain_multiplier"] = 0.9 if not ace else 0.75
					else:
						modifier.flat_modifiers[&"swiftness"] = 6.0 * scale
				2:
					if choice == 0:
						modifier.flat_modifiers[&"dodge_chance"] = 0.04 * scale
						modifier.rule_flags.append(&"dodge_enabled")
					else:
						modifier.multipliers[&"reload_speed"] = 0.95 if not ace else 0.85
				3:
					if choice == 0:
						modifier.flat_modifiers[&"weapon_handling"] = 0.1 * scale
					else:
						modifier.multipliers[&"spread_multiplier"] = 0.9 if not ace else 0.75
						modifier.multipliers[&"recoil_stability"] = 0.95 if not ace else 0.85
				4:
					modifier.rule_flags.append(
						&"agility_overdrive" if choice == 0 else &"mobile_crit"
					)
					modifier.flat_modifiers[&"movement_speed"] = 0.05 * scale
		SkillNodeData.Branch.ARMOR:
			match tier:
				1:
					if choice == 0:
						modifier.flat_modifiers[&"max_armor"] = 10.0 * scale
					else:
						modifier.flat_modifiers[&"armor_regeneration_delay"] = -0.25 * scale
				2:
					if choice == 0:
						modifier.flat_modifiers[&"impact_multiplier"] = 0.15 * scale
					else:
						modifier.flat_modifiers[&"armor_regeneration_rate"] = 1.0 * scale
				3:
					if choice == 0:
						modifier.multipliers[&"recoil_stability"] = 0.9 if not ace else 0.75
					else:
						modifier.flat_modifiers[&"objective_interaction_speed"] = 0.1 * scale
				4:
					if choice == 0:
						modifier.flat_modifiers[&"damage_mitigation"] = 0.03 * scale
					else:
						modifier.multipliers[&"fall_damage_scale"] = 0.9 if not ace else 0.75
		SkillNodeData.Branch.FIELDCRAFT:
			match tier:
				1:
					if choice == 0:
						modifier.flat_modifiers[&"objective_interaction_speed"] = 0.15 * scale
					else:
						modifier.multipliers[&"ammo_pickup_multiplier"] = 1.1 if not ace else 1.25
				2:
					if choice == 0:
						modifier.flat_modifiers[&"armor_regeneration_rate"] = 0.5 * scale
					else:
						modifier.rule_flags.append(&"field_repair")
				3:
					if choice == 0:
						modifier.flat_modifiers[&"bullet_time_regen_multiplier"] = 0.1 * scale
					else:
						modifier.flat_modifiers[&"objective_interaction_speed"] = 0.1 * scale
				4:
					modifier.rule_flags.append(
						&"mission_control" if choice == 0 else &"team_sustain"
					)
					modifier.flat_modifiers[&"armor_regeneration_rate"] = 0.5 * scale
	return modifier


func _make_deck(
	deck_id: StringName, title: String, signature: String, effect: StringName
) -> PerkDeckData:
	var deck := PerkDeckData.new()
	deck.deck_id = deck_id
	deck.display_name = title
	deck.archetype_tag = String(deck_id)
	deck.signature_gadget_name = signature
	deck.signature_effect = effect
	deck.role_summary = title
	deck.tier_1_summary = "Signature rule-breaker and core hook."
	deck.tier_2_summary = "Support upgrade or cross-pick escalation."
	deck.tier_3_summary = "Payoff and capstone interaction."
	deck.gadget_cooldown = 20.0
	deck.gadget_radius = 6.0
	return deck


func _make_modifier(
	flat: Dictionary = {}, multipliers: Dictionary = {}, flags: Array[StringName] = []
) -> StatModifier:
	var modifier := StatModifier.new()
	for stat_name: Variant in flat:
		modifier.flat_modifiers[StringName(stat_name)] = float(flat[stat_name])
	for stat_name: Variant in multipliers:
		modifier.multipliers[StringName(stat_name)] = float(multipliers[stat_name])
	modifier.rule_flags.append_array(flags)
	return modifier
