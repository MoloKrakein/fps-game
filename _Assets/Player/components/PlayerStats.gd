class_name PlayerStats extends Node

signal stats_changed(stats: Dictionary)

const BASE_STATS: Dictionary = {
	"max_health": 100.0,
	"max_armor": 50.0,
	"armor_regeneration_rate": 5.0,
	"armor_regeneration_delay": 3.0,
	"damage_mitigation": 0.0,
	"damage_reduction": 0.0,
	"flat_armor_reduction": 0.0,
	"evasion_chance": 0.0,
	"damage_modifier": 1.0,
	"recoil_stability": 1.0,
	"recoil_multiplier": 1.0,
	"reload_speed": 1.0,
	"movement_speed": 1.0,
	"stamina_pool": 100.0,
	"stamina_drain_multiplier": 1.0,
	"stamina_recovery_multiplier": 1.0,
	"dodge_base": 0.0,
	"crit_chance": 0.05,
	"crit_multiplier": 2.0,
	"impact_multiplier": 1.0,
	"weapon_handling": 1.0,
}

@export_category("Base Stats")
@export var base_health: float = 100.0
@export var base_armor: float = 50.0
@export var base_armor_regeneration_delay: float = 3.0
@export var base_armor_regeneration_rate: float = 5.0
@export var armor_rig: ArmorRigResource

@export_category("Skills and Perks")
@export var perk_deck_slots: Array[StatModifier] = []

var stats: Dictionary = {}
var active_flags: Dictionary = {}
var equipped_weapons: Array[WeaponData] = []

var _skill_ranks: Dictionary = {}
var _manual_stat_overrides: Dictionary = {}
var _manual_flags: Dictionary = {}
var _is_sprinting: bool = false
var _is_sliding: bool = false
var _is_vaulting: bool = false
var _post_action_dodge_time: float = 0.0


func _ready() -> void:
	recalculate_stats()


func _process(delta: float) -> void:
	if _post_action_dodge_time <= 0.0:
		return
	_post_action_dodge_time = maxf(0.0, _post_action_dodge_time - delta)
	if _post_action_dodge_time == 0.0:
		recalculate_stats()


func get_stat(stat_name: String, default_value: float = 1.0) -> float:
	return float(stats.get(stat_name, default_value))


func set_stats(stat_name: String, value: float) -> void:
	_manual_stat_overrides[stat_name] = value
	recalculate_stats()


func has_flag(flag_name: String) -> bool:
	return bool(active_flags.get(flag_name, false))


func set_flag(flag_name: String, value: bool) -> void:
	_manual_flags[flag_name] = value
	recalculate_stats()


func set_skill_rank(skill: SkillResource, rank: SkillResource.SkillSet) -> void:
	if skill == null or rank == SkillResource.SkillSet.LOCKED:
		if skill != null:
			_skill_ranks.erase(skill)
	else:
		_skill_ranks[skill] = rank
	recalculate_stats()


func set_perk_deck_slot(slot: int, perk: StatModifier) -> void:
	if slot < 0 or slot >= 3:
		push_warning("Perk deck slot must be between 0 and 2.")
		return
	while perk_deck_slots.size() < 3:
		perk_deck_slots.append(null)
	perk_deck_slots[slot] = perk
	recalculate_stats()


func set_armor_rig(rig: ArmorRigResource) -> void:
	armor_rig = rig
	recalculate_stats()


func set_loadout_weapons(weapon_data_list: Array[WeaponData]) -> void:
	equipped_weapons = weapon_data_list.duplicate()
	recalculate_stats()


func set_action_state(sprinting: bool, sliding: bool, vaulting: bool = false) -> void:
	if _is_sprinting == sprinting and _is_sliding == sliding and _is_vaulting == vaulting:
		return
	_is_sprinting = sprinting
	_is_sliding = sliding
	_is_vaulting = vaulting
	recalculate_stats()


func notify_slide_or_vault() -> void:
	_post_action_dodge_time = 1.5
	recalculate_stats()


func modify_damage(base_damage: float) -> float:
	return base_damage * get_stat("damage_modifier", 1.0)


func modify_recoil(base_recoil: float) -> float:
	return base_recoil * get_stat("recoil_stability", 1.0)


func recalculate_stats() -> void:
	var flat: Dictionary = {}
	var multipliers: Dictionary = {}
	var flags: Dictionary = {}
	var base_values: Dictionary = BASE_STATS.duplicate()
	base_values["max_health"] = base_health
	base_values["max_armor"] = armor_rig.armor_value if armor_rig else base_armor
	base_values["armor_regeneration_delay"] = base_armor_regeneration_delay
	base_values["armor_regeneration_rate"] = base_armor_regeneration_rate

	if armor_rig:
		_collect_modifiers(armor_rig.stat_modifiers, flat, multipliers, flags)

	for slot: int in range(mini(perk_deck_slots.size(), 3)):
		var perk: StatModifier = perk_deck_slots[slot]
		if perk:
			var slot_modifiers: Array[StatModifier] = [perk]
			_collect_modifiers(slot_modifiers, flat, multipliers, flags)

	for skill: SkillResource in _skill_ranks:
		var rank: int = int(_skill_ranks[skill])
		if rank >= SkillResource.SkillSet.BASIC:
			_collect_legacy_effects(skill.basic_stats_changes, skill.basic_rule_flags, flat, flags)
			_collect_modifiers(skill.basic_stat_modifiers, flat, multipliers, flags)
		if rank >= SkillResource.SkillSet.ADVANCED:
			_collect_legacy_effects(
				skill.advanced_stats_changes, skill.advanced_rule_flags, flat, flags
			)
			_collect_modifiers(skill.advanced_stat_modifiers, flat, multipliers, flags)
	flags.merge(_manual_flags, true)

	var resolved: Dictionary = {}
	for stat_name: String in base_values:
		var base_value: float = float(base_values[stat_name])
		resolved[stat_name] = (
			(base_value + float(flat.get(stat_name, 0.0))) * float(multipliers.get(stat_name, 1.0))
		)

	var loadout_weight: float = armor_rig.loadout_weight if armor_rig else 0.0
	for weapon_data: WeaponData in equipped_weapons:
		if weapon_data == null or weapon_data.weapon == null:
			continue
		loadout_weight += weapon_data.weapon.get_loadout_weight(weapon_data)
	var swiftness: float = clampf(
		100.0 - loadout_weight + float(flat.get("swiftness", 0.0)), 0.0, 100.0
	)
	resolved["swiftness"] = swiftness
	resolved["loadout_weight"] = loadout_weight
	resolved["armor_weight"] = armor_rig.loadout_weight if armor_rig else 0.0

	var move_speed: float = lerpf(0.85, 1.20, swiftness / 100.0)
	move_speed = (
		(move_speed + float(flat.get("movement_speed", 0.0)))
		* float(multipliers.get("movement_speed", 1.0))
	)

	var base_dodge: float = (
		float(resolved.get("dodge_base", 0.0))
		+ float(resolved.get("evasion_chance", 0.0))
		+ float(flat.get("dodge_chance", 0.0))
	)
	var dodge_enabled: bool = bool(flags.get("dodge_enabled", false)) or base_dodge > 0.0
	if dodge_enabled:
		base_dodge += maxf(swiftness - 50.0, 0.0) * 0.004
	var idle_dodge: float = base_dodge
	var moving_dodge: float = base_dodge + (0.15 if dodge_enabled else 0.0)
	if _post_action_dodge_time > 0.0:
		idle_dodge += 0.10 if dodge_enabled else 0.0
	var is_moving_dodge: bool = _is_sprinting or _is_sliding or _is_vaulting
	var dodge: float = moving_dodge if is_moving_dodge else idle_dodge
	var dodge_overflow: float = maxf(dodge - 0.55, 0.0)
	resolved["dodge_chance"] = minf(dodge, 0.55)
	resolved["dodge_chance_idle"] = minf(idle_dodge, 0.55)
	resolved["dodge_chance_moving"] = minf(moving_dodge, 0.55)
	move_speed += dodge_overflow * 50.0

	var crit_chance: float = float(resolved.get("crit_chance", 0.05))
	if bool(flags.get("crit_swiftness_enabled", false)):
		crit_chance += maxf(swiftness - 40.0, 0.0) * 0.005
	resolved["crit_chance"] = clampf(crit_chance, 0.0, 0.45)

	resolved["movement_speed"] = move_speed
	resolved["reload_speed"] = maxf(
		0.1, float(resolved.get("reload_speed", 1.0)) - dodge_overflow * 50.0
	)
	resolved["stamina_drain_multiplier"] = maxf(
		0.1,
		(
			float(base_values.get("stamina_drain_multiplier", 1.0))
			+ float(flat.get("stamina_drain_multiplier", 0.0))
			- swiftness * 0.004
		)
	)
	resolved["stamina_drain_multiplier"] *= float(multipliers.get("stamina_drain_multiplier", 1.0))
	resolved["stamina_recovery_multiplier"] = (
		(
			float(base_values.get("stamina_recovery_multiplier", 1.0))
			+ float(flat.get("stamina_recovery_multiplier", 0.0))
			+ swiftness * 0.004
		)
		* float(multipliers.get("stamina_recovery_multiplier", 1.0))
	)

	for stat_name: String in _manual_stat_overrides:
		resolved[stat_name] = _manual_stat_overrides[stat_name]
	for flag_name: Variant in flags:
		active_flags[flag_name] = bool(flags[flag_name])
	for flag_name: Variant in active_flags.keys():
		if not flags.has(flag_name):
			active_flags.erase(flag_name)

	stats = resolved
	stats_changed.emit(stats.duplicate())


func _collect_modifiers(
	modifiers: Array[StatModifier], flat: Dictionary, multipliers: Dictionary, flags: Dictionary
) -> void:
	for modifier: StatModifier in modifiers:
		if modifier == null:
			continue
		for stat_name: StringName in modifier.flat_modifiers:
			var key: String = String(stat_name)
			flat[key] = float(flat.get(key, 0.0)) + modifier.flat_modifiers[stat_name]
		for stat_name: StringName in modifier.multipliers:
			var key: String = String(stat_name)
			multipliers[key] = float(multipliers.get(key, 1.0)) * modifier.multipliers[stat_name]
		for flag_name: StringName in modifier.rule_flags:
			flags[String(flag_name)] = true


func _collect_legacy_effects(
	changes: Dictionary, rule_flags: Array, flat: Dictionary, flags: Dictionary
) -> void:
	for stat_name: Variant in changes:
		var key: String = String(stat_name)
		flat[key] = float(flat.get(key, 0.0)) + float(changes[stat_name])
	for flag_name: Variant in rule_flags:
		flags[String(flag_name)] = true


func reset_stats() -> void:
	_skill_ranks.clear()
	_manual_stat_overrides.clear()
	_manual_flags.clear()
	_is_sprinting = false
	_is_sliding = false
	_is_vaulting = false
	_post_action_dodge_time = 0.0
	recalculate_stats()
