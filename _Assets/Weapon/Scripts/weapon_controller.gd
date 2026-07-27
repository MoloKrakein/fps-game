class_name WeaponController extends Node

@export var current_weapon: Weapon
@export var weapon_model_parent: Node3D
@export var weapon_state_chart: StateChart

var current_weapon_model: Node3D
var current_ammo: int
var fire_timer: float = 0.0


var current_fire_mode: Weapon.WeaponFireMode
var shots_fired_this_trigger: int = 0

func _ready() -> void:
    if current_weapon != null:
        spawn_weapon_model(current_weapon)
        current_ammo = current_weapon.max_ammo
        current_fire_mode = current_weapon.fire_mode

func _process(delta: float) -> void:
    if fire_timer > 0.0:
        fire_timer -= delta

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


func spawn_weapon_model(weapon: Weapon) -> void:
    if current_weapon_model != null:
        current_weapon_model.queue_free()

    if current_weapon.weapon_model:
        current_weapon_model = current_weapon.weapon_model.instantiate()
        weapon_model_parent.add_child(current_weapon_model)
        current_weapon_model.position = current_weapon.weapon_position
        current_weapon_model.rotation = current_weapon.weapon_rotation
        current_weapon_model.scale = current_weapon.weapon_scale

func is_burst_fire() -> bool:
    if current_fire_mode == Weapon.WeaponFireMode.BURST:
        if shots_fired_this_trigger > 0 and shots_fired_this_trigger < 3:
            return true
    return false

func reset_trigger() -> void:
    shots_fired_this_trigger = 0

func can_fire() -> bool:
    var has_ammo_and_time = (current_ammo > 0 and fire_timer <= 0.0)
    if not has_ammo_and_time:
        return false
    match current_fire_mode:
        Weapon.WeaponFireMode.SEMI_AUTO:
            return shots_fired_this_trigger < 1
        Weapon.WeaponFireMode.BURST:
            return shots_fired_this_trigger < 3
        Weapon.WeaponFireMode.FULL_AUTO:
            return true
            
    return false

func fire_weapon() -> void:
    if can_fire():
        current_ammo -= 1
        fire_timer = current_weapon.fire_rate
        print("Fired weapon: %s, Remaining ammo: %d" % [current_weapon.weapon_name, current_ammo])