class_name PlayerBuildResolver extends Node

signal build_changed

@export_range(0, 100) var starting_skill_points: int = 6
@export var player_stats: PlayerStats
@export var perk_decks: Array[PerkDeckData] = []
@export var skill_nodes: Array[SkillNodeData] = []

var perk_slots: Array[PerkDeckData] = [null, null, null]
var purchased_skill_ids: Array[StringName] = []


func _ready() -> void:
	if perk_decks.is_empty():
		perk_decks = _make_demo_decks()
	if skill_nodes.is_empty():
		skill_nodes = _make_demo_skills()
	_refresh_player_stats()


func bind_player_stats(stats: PlayerStats) -> void:
	player_stats = stats
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
	if role_deck == null:
		return null
	return role_deck.role_gadget_scene


func get_unspent_skill_points() -> int:
	var spent := 0
	for skill_id: StringName in purchased_skill_ids:
		var skill := get_skill_node(skill_id)
		if skill != null:
			spent += skill.point_cost
	return maxi(0, starting_skill_points - spent)


func get_skill_node(node_id: StringName) -> SkillNodeData:
	for skill: SkillNodeData in skill_nodes:
		if skill != null and skill.node_id == node_id:
			return skill
	return null


func is_skill_purchased(node_id: StringName) -> bool:
	return purchased_skill_ids.has(node_id)


func can_purchase_skill(node_id: StringName) -> bool:
	var skill := get_skill_node(node_id)
	if skill == null or is_skill_purchased(node_id):
		return false
	if get_unspent_skill_points() < skill.point_cost:
		return false
	for prerequisite_id: StringName in skill.prerequisite_ids:
		if not is_skill_purchased(prerequisite_id):
			return false
	return true


func purchase_skill(node_id: StringName) -> bool:
	if not can_purchase_skill(node_id):
		return false
	purchased_skill_ids.append(node_id)
	_refresh_player_stats()
	return true


func reset_build() -> void:
	perk_slots = [null, null, null]
	purchased_skill_ids.clear()
	_refresh_player_stats()


func _refresh_player_stats() -> void:
	var perk_modifiers: Array[StatModifier] = []
	var skill_modifiers: Array[StatModifier] = []
	var seen_decks: Dictionary = {}

	for deck: PerkDeckData in perk_slots:
		if deck == null:
			continue
		var deck_tier := get_deck_tier(deck.deck_id)
		var applied_tier := int(seen_decks.get(deck.deck_id, 0)) + 1
		if applied_tier <= deck_tier:
			perk_modifiers.append_array(deck.get_modifiers_for_tier(applied_tier))
			seen_decks[deck.deck_id] = applied_tier

	for skill_id: StringName in purchased_skill_ids:
		var skill := get_skill_node(skill_id)
		if skill != null:
			skill_modifiers.append_array(skill.stat_modifiers)

	if player_stats != null:
		player_stats.set_build_modifiers(perk_modifiers, skill_modifiers)
	build_changed.emit()


func _make_demo_decks() -> Array[PerkDeckData]:
	var result: Array[PerkDeckData] = []
	var disruptor := _make_deck(
		&"disruptor",
		"DISRUPTOR / HACKER",
		"CONTROL",
		"Mini ECM Pulse",
		"Break enemy tracking and create openings.",
		"Mini ECM hook enabled; disrupted-target tracking pressure is represented by a rule flag.",
		"Unlocks the next disruption combat hook.",
		"Disrupted targets take increased damage."
	)
	disruptor.tier_1_modifiers.append(
		_make_modifier({}, {}, [&"mini_ecm_unlocked", &"disrupted_target_tracking"])
	)
	disruptor.tier_2_modifiers.append(_make_modifier({}, {}, [&"disruptor_extra_charge"]))
	disruptor.tier_3_modifiers.append(
		_make_modifier({}, {}, [&"disrupted_target_bonus_damage", &"disrupted_takedown_armor"])
	)
	result.append(disruptor)

	var breacher := _make_deck(
		&"breacher",
		"BREACHER / SHOCK",
		"IMPACT",
		"Concussion Charge",
		"Stagger enemies and capitalize on impact windows.",
		"Concussion Charge hook enabled with increased impact.",
		"Unlocks the armor-recovery-on-stagger hook.",
		"Stagger follow-ups gain a critical hit bonus."
	)
	breacher.tier_1_modifiers.append(
		_make_modifier({"impact_multiplier": 0.15}, {}, [&"concussion_charge_unlocked"])
	)
	breacher.tier_2_modifiers.append(_make_modifier({}, {}, [&"stagger_armor_recovery"]))
	breacher.tier_3_modifiers.append(_make_modifier({}, {}, [&"stagger_crit_followup"]))
	result.append(breacher)

	var skirmisher := _make_deck(
		&"skirmisher",
		"SKIRMISHER / PHANTOM",
		"MOBILITY",
		"Sensor Disruptor",
		"Use movement to evade and create counter-attack windows.",
		"Moving dodge and swiftness-to-crit hooks enabled.",
		"Unlocks a dodge/crit momentum hook.",
		"Unlocks a mobile overdrive combat hook."
	)
	skirmisher.tier_1_modifiers.append(
		_make_modifier(
			{}, {}, [&"dodge_enabled", &"crit_swiftness_enabled", &"sensor_disruptor_unlocked"]
		)
	)
	skirmisher.tier_2_modifiers.append(_make_modifier({}, {}, [&"dodge_crit_momentum"]))
	skirmisher.tier_3_modifiers.append(_make_modifier({}, {}, [&"mobile_overdrive"]))
	result.append(skirmisher)

	var warden := _make_deck(
		&"warden",
		"WARDEN / BULWARK",
		"DEFENSE",
		"Aegis Beacon",
		"Hold ground with armor and damage mitigation.",
		"Aegis hook enabled; adds armor and mitigation.",
		"Unlocks faster armor recovery after stagger.",
		"Adds a defensive capstone."
	)
	warden.tier_1_modifiers.append(
		_make_modifier(
			{"max_armor": 20.0, "damage_mitigation": 0.05}, {}, [&"aegis_beacon_unlocked"]
		)
	)
	warden.tier_2_modifiers.append(
		_make_modifier({"armor_regeneration_delay": -0.5}, {}, [&"stagger_armor_recovery"])
	)
	warden.tier_3_modifiers.append(
		_make_modifier({"max_armor": 30.0}, {}, [&"objective_hold_sustain"])
	)
	result.append(warden)
	return result


func _make_demo_skills() -> Array[SkillNodeData]:
	return [
		_make_skill(
			&"agility_crit",
			"Swiftness Crit Conversion",
			SkillNodeData.Branch.AGILITY,
			2,
			"Converts high Swiftness into additional critical chance.",
			[_make_modifier({}, {}, [&"crit_swiftness_enabled"])]
		),
		_make_skill(
			&"agility_footwork",
			"Kinetic Footwork",
			SkillNodeData.Branch.AGILITY,
			2,
			"Improves stamina efficiency and active dodge.",
			[_make_modifier({"stamina_drain_multiplier": 0.9}, {}, [&"dodge_enabled"])],
			[&"agility_crit"]
		),
		_make_skill(
			&"agility_handling",
			"Fluid Handling",
			SkillNodeData.Branch.AGILITY,
			2,
			"Improves weapon handling and reload speed.",
			[_make_modifier({"weapon_handling": 0.15}, {"reload_speed": 1.05})],
			[&"agility_footwork"]
		),
		_make_skill(
			&"armor_plating",
			"Reinforced Plating",
			SkillNodeData.Branch.ARMOR,
			2,
			"Increases maximum armor.",
			[_make_modifier({"max_armor": 15.0})]
		),
		_make_skill(
			&"armor_impact",
			"Concussive Impact",
			SkillNodeData.Branch.ARMOR,
			2,
			"Increases impact power and follow-up damage.",
			[_make_modifier({"impact_multiplier": 0.2}, {}, [&"stagger_followup_bonus"])],
			[&"armor_plating"]
		),
		_make_skill(
			&"field_objective",
			"Objective Specialist",
			SkillNodeData.Branch.FIELDCRAFT,
			1,
			"Enables objective interaction speed bonuses when objective hooks are connected.",
			[_make_modifier({}, {}, [&"objective_specialist"])]
		),
		_make_skill(
			&"field_recovery",
			"Suppression & Recovery",
			SkillNodeData.Branch.FIELDCRAFT,
			2,
			"Unlocks recovery hooks for high-pressure objective phases.",
			[_make_modifier({"armor_regeneration_rate": 1.0}, {}, [&"suppression_recovery"])],
			[&"field_objective"]
		),
	]


func _make_deck(
	deck_id: StringName,
	title: String,
	tag: String,
	gadget: String,
	role_summary: String,
	tier_1_summary: String,
	tier_2_summary: String,
	tier_3_summary: String
) -> PerkDeckData:
	var deck := PerkDeckData.new()
	deck.deck_id = deck_id
	deck.display_name = title
	deck.archetype_tag = tag
	deck.signature_gadget_name = gadget
	deck.role_summary = role_summary
	deck.tier_1_summary = tier_1_summary
	deck.tier_2_summary = tier_2_summary
	deck.tier_3_summary = tier_3_summary
	return deck


func _make_skill(
	node_id: StringName,
	title: String,
	branch: SkillNodeData.Branch,
	point_cost: int,
	description: String,
	modifiers: Array[StatModifier],
	prerequisites: Array[StringName] = []
) -> SkillNodeData:
	var skill := SkillNodeData.new()
	skill.node_id = node_id
	skill.display_name = title
	skill.branch = branch
	skill.point_cost = point_cost
	skill.description = description
	skill.stat_modifiers = modifiers
	skill.prerequisite_ids = prerequisites
	return skill


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
