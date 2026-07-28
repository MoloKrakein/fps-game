class_name WeaponController extends Node

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart

var current_weapon_model: Node3D
var current_ammo: int
var fire_timer: float = 0.0

var current_fire_mode: Weapon.WeaponFireMode
var shots_fired_this_trigger: int = 0
var trigger_held: bool = false
var burst_shots_remaining: int = 0

const DEFAULT_BURST_SHOTS_PER_TRIGGER: int = 3

func _ready() -> void:
    if current_weapon != null:
        spawn_weapon_model(current_weapon)
        current_ammo = current_weapon.max_ammo
        current_fire_mode = current_weapon.fire_mode

func _process(delta: float) -> void:
    if fire_timer > 0.0:
        fire_timer = maxf(fire_timer - delta, 0.0)

func get_fire_rate_rpm() -> float:
    if current_weapon == null:
        return 0.0

    if current_weapon.fire_rate_rpm > 0.0:
        return current_weapon.fire_rate_rpm

    if current_weapon.fire_rate > 0.0:
        return 60.0 / current_weapon.fire_rate

    return 0.0

func get_fire_interval_seconds() -> float:
    var rpm := get_fire_rate_rpm()
    if rpm <= 0.0:
        return 0.0
    return 60.0 / rpm

func get_burst_shot_count() -> int:
    if current_weapon == null:
        return DEFAULT_BURST_SHOTS_PER_TRIGGER

    if current_weapon.burst_shot_count > 0:
        return current_weapon.burst_shot_count

    return DEFAULT_BURST_SHOTS_PER_TRIGGER

func start_trigger() -> void:
    trigger_held = true
    if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
        burst_shots_remaining = get_burst_shot_count()

func stop_trigger() -> void:
    trigger_held = false
    if current_fire_mode != Weapon.WeaponFireMode.BURST:
        reset_trigger()

func toggle_fire_mode() -> void:
    if not current_weapon.can_change_fire_mode:
        return
    match current_fire_mode:
        Weapon.WeaponFireMode.SEMI_AUTO:
            if current_weapon.has_burst_mode:
                current_fire_mode = Weapon.WeaponFireMode.BURST
            else:
                current_fire_mode = Weapon.WeaponFireMode.FULL_AUTO
        Weapon.WeaponFireMode.BURST:
            current_fire_mode = Weapon.WeaponFireMode.FULL_AUTO
        Weapon.WeaponFireMode.FULL_AUTO:
            current_fire_mode = Weapon.WeaponFireMode.SEMI_AUTO

    reset_trigger()


func spawn_weapon_model(weapon: Weapon) -> void:
    if current_weapon_model != null:
        current_weapon_model.queue_free()

    if weapon != null and weapon.weapon_model:
        current_weapon_model = weapon.weapon_model.instantiate()
        weapon_model_parent.add_child(current_weapon_model)
        current_weapon_model.position = weapon.weapon_position
        current_weapon_model.rotation = weapon.weapon_rotation
        current_weapon_model.scale = weapon.weapon_scale

func is_burst_fire() -> bool:
    return current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining > 0 and burst_shots_remaining < get_burst_shot_count()

func reset_trigger() -> void:
    shots_fired_this_trigger = 0
    burst_shots_remaining = 0

func can_fire() -> bool:
    if current_weapon == null:
        return false

    if current_ammo <= 0 or fire_timer > 0.0:
        return false

    match current_fire_mode:
        Weapon.WeaponFireMode.SEMI_AUTO:
            return trigger_held and shots_fired_this_trigger < 1
        Weapon.WeaponFireMode.BURST:
            return burst_shots_remaining > 0
        Weapon.WeaponFireMode.FULL_AUTO:
            return trigger_held

    return false

func fire_weapon() -> void:
    if can_fire():
        current_ammo -= 1
        fire_timer = get_fire_interval_seconds()

        match current_fire_mode:
            Weapon.WeaponFireMode.SEMI_AUTO:
                shots_fired_this_trigger = 1
            Weapon.WeaponFireMode.BURST:
                if burst_shots_remaining <= 0:
                    burst_shots_remaining = get_burst_shot_count()
                burst_shots_remaining -= 1
                shots_fired_this_trigger += 1
            Weapon.WeaponFireMode.FULL_AUTO:
                pass

        if current_fire_mode == Weapon.WeaponFireMode.BURST and burst_shots_remaining <= 0:
            trigger_held = false

        print("Fired weapon: %s, Remaining ammo: %d" % [current_weapon.weapon_name, current_ammo])