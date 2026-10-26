class_name EnemyMoraleComponent
extends Node
## Morale / eagerness of one enemy (0 = broken, 1 = fearless). Drives how it fights:
##
## AGGRESSIVE  closes in, longer bursts, shorter pauses, best accuracy, volunteers to flank.
## STEADY      normal behaviour.
## CAUTIOUS    stays at long range, short bursts, long pauses, worse accuracy, never flanks.
## BROKEN      stops fighting and retreats (the squad gives it a retreat order). It only shoots back
##             when cornered, with very poor accuracy, and rallies once morale recovers.
##
## Morale target = health + courage + squad support - shock - fear.
## - health: more wounded = less eager.
## - courage: a per-enemy personality, so a squad is not uniform.
## - squad support: enemies with allies nearby are braver than lone ones.
## - shock: every hit knocks morale down for a moment, headshots more (decays quickly).
## - fear: nearby allies dying (decays slowly).
## Morale falls fast and recovers slowly, so enemies hesitate before coming back.

signal stance_changed(new_stance: Stance, old_stance: Stance)

enum Stance { AGGRESSIVE, STEADY, CAUTIOUS, BROKEN }

@export var health_component: HealthComponent

@export_group("Personality")
## Added to morale. Brave enemies are positive, timid ones negative.
@export_range(-0.3, 0.3) var courage: float = 0.0
## Randomises courage a little on spawn so enemies are not identical.
@export var randomize_courage: bool = true
@export_range(0.0, 0.3) var courage_variation: float = 0.12

@export_group("Morale model")
## Morale contributed by health: floor + weight * health fraction.
@export_range(0.0, 1.0) var health_floor: float = 0.15
@export_range(0.0, 1.0) var health_weight: float = 0.6
## Constant bonus so a healthy enemy ends up near 0.9.
@export_range(0.0, 0.5) var base_bonus: float = 0.15
## A hit for 100% of max health would add this much shock (scaled by damage / max health).
@export var shock_per_health: float = 1.4
@export var headshot_shock_scale: float = 1.5
@export var shock_decay: float = 0.2
@export var ally_death_fear: float = 0.12
@export var fear_decay: float = 0.03
@export var support_bonus: float = 0.08
@export var alone_penalty: float = 0.08
## Morale drop speed (per second) and recovery speed.
@export var fall_speed: float = 1.5
@export var rise_speed: float = 0.12
## While broken, desperation slowly grows so a badly wounded enemy does not flee forever.
@export var desperation_rate: float = 0.03
@export var desperation_decay: float = 0.01
@export var max_desperation: float = 0.3

@export_group("Stance thresholds")
@export var aggressive_threshold: float = 0.7
@export var steady_threshold: float = 0.45
## Below this, the enemy breaks and retreats...
@export var broken_threshold: float = 0.25
## ...and stays broken until morale has recovered above this.
@export var rally_threshold: float = 0.4

@export_group("Effects per stance (AGGRESSIVE, STEADY, CAUTIOUS, BROKEN)")
## Multiplies weapon spread. Below 1 is more accurate.
@export var accuracy_multipliers: Array[float] = [0.8, 1.0, 1.5, 2.4]
@export var burst_scales: Array[float] = [1.5, 1.0, 0.6, 0.5]
@export var pause_scales: Array[float] = [0.7, 1.0, 1.5, 1.2]
@export var speed_scales: Array[float] = [1.1, 1.0, 0.9, 1.25]
## 0 = prefers the close part of the firing range, 1 = prefers the far part.
@export var range_preferences: Array[float] = [0.0, 0.5, 1.0, 1.0]
## Added to the attack-token score (who gets to shoot next).
@export var token_bonuses: Array[float] = [1.5, 0.0, -1.5, -10.0]
## Scales how long this enemy waits between its turns.
@export var token_cooldown_scales: Array[float] = [0.6, 1.0, 1.5, 2.0]
## Extra spread right after being hit: spread *= 1 + shock * this.
@export var flinch_accuracy_penalty: float = 1.2

var morale: float = 1.0
var stance: Stance = Stance.STEADY
var shock: float = 0.0
var fear: float = 0.0
var desperation: float = 0.0
## Set by the squad coordinator: engaged allies within a few metres.
var allies_nearby: int = 0

var _broken: bool = false


func _ready() -> void:
	if randomize_courage:
		courage = clampf(courage + randf_range(-courage_variation, courage_variation), -0.3, 0.3)
	bind_health(health_component)
	morale = _get_target_morale()
	_update_stance()


func _process(delta: float) -> void:
	shock = maxf(shock - shock_decay * delta, 0.0)
	fear = maxf(fear - fear_decay * delta, 0.0)
	if _broken:
		desperation = minf(desperation + desperation_rate * delta, max_desperation)
	else:
		desperation = maxf(desperation - desperation_decay * delta, 0.0)

	var target_morale: float = _get_target_morale()
	var speed: float = fall_speed if target_morale < morale else rise_speed
	morale = move_toward(morale, target_morale, speed * delta)
	_update_stance()


## Safe to call more than once (used when the component sits in the scene without a reference).
func bind_health(new_health: HealthComponent) -> void:
	health_component = new_health
	if is_instance_valid(health_component) and not health_component.damage_received.is_connected(_on_damage_received):
		health_component.damage_received.connect(_on_damage_received)


#region Queries

func is_broken() -> bool:
	return stance == Stance.BROKEN


func can_flank() -> bool:
	return stance == Stance.AGGRESSIVE or (stance == Stance.STEADY and morale >= 0.6)


func get_accuracy_multiplier() -> float:
	return _pick(accuracy_multipliers, 1.0) * (1.0 + shock * flinch_accuracy_penalty)


func get_burst_scale() -> float:
	return _pick(burst_scales, 1.0)


func get_pause_scale() -> float:
	return _pick(pause_scales, 1.0)


func get_speed_scale() -> float:
	return _pick(speed_scales, 1.0)


func get_range_preference() -> float:
	return _pick(range_preferences, 0.5)


func get_token_bonus() -> float:
	return _pick(token_bonuses, 0.0)


func get_token_cooldown_scale() -> float:
	return _pick(token_cooldown_scales, 1.0)

#endregion


#region Events

## An ally died `distance` metres away.
func on_ally_died(distance: float, max_distance: float = 20.0) -> void:
	var closeness: float = 1.0 - clampf(distance / maxf(max_distance, 0.01), 0.0, 1.0) * 0.5
	fear = minf(fear + ally_death_fear * closeness, 0.5)


func _on_damage_received(info: DamageInfo, applied_damage: float) -> void:
	var max_health: float = maxf(health_component.max_health, 1.0)
	var added: float = applied_damage / max_health * shock_per_health
	if info.is_headshot:
		added *= headshot_shock_scale
	shock = clampf(shock + added, 0.0, 1.0)
	# A hit is felt at once, not after the smoothing delay.
	morale = minf(morale, _get_target_morale())

#endregion


func _get_target_morale() -> float:
	var health_fraction: float = 1.0
	if is_instance_valid(health_component):
		health_fraction = clampf(health_component.current_health / maxf(health_component.max_health, 1.0), 0.0, 1.0)

	var value: float = health_floor + health_weight * health_fraction + base_bonus + courage
	if allies_nearby >= 2:
		value += support_bonus
	elif allies_nearby == 0:
		value -= alone_penalty
	value += desperation
	value -= shock + fear
	return clampf(value, 0.0, 1.0)


func _update_stance() -> void:
	if _broken:
		if morale >= rally_threshold:
			_broken = false
	elif morale < broken_threshold:
		_broken = true

	var new_stance: Stance
	if _broken:
		new_stance = Stance.BROKEN
	elif morale >= aggressive_threshold:
		new_stance = Stance.AGGRESSIVE
	elif morale >= steady_threshold:
		new_stance = Stance.STEADY
	else:
		new_stance = Stance.CAUTIOUS

	if new_stance != stance:
		var old_stance: Stance = stance
		stance = new_stance
		stance_changed.emit(new_stance, old_stance)


func _pick(values: Array[float], fallback: float) -> float:
	var index: int = int(stance)
	return values[index] if index < values.size() else fallback
