class_name Weapon extends Resource

enum WeaponType {
    PISTOL,
    RIFLE,
    SMG,
    SHOTGUN,
    SNIPER,
    HEAVY
}

enum WeaponFireMode {
    SEMI_AUTO,
    FULL_AUTO,
    BURST
}

enum WeaponAmmoType {
    LIGHT,
    MEDIUM,
    HEAVY
}

@export_category("Weapon Stats")
@export var weapon_name: String = "Weapon"
@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var damage: float = 10.0
@export var max_ammo: int = 7
@export_group("Fire Control")
@export var fire_rate_rpm: float = 600.0
@export var fire_rate: float = 0.1 # Legacy seconds-per-shot fallback.
@export var burst_shot_count: int = 3
@export var recoil: float = 1.0
@export var shoot_range: float = 100.0
@export var accuracy: float = 1.0
@export var reload_time: float = 2.0
@export var fire_mode: WeaponFireMode = WeaponFireMode.SEMI_AUTO
@export var can_change_fire_mode: bool = false
@export var has_burst_mode: bool = false
@export var ammo_type: WeaponAmmoType = WeaponAmmoType.LIGHT


@export_category("Weapon Model")
@export var weapon_model: PackedScene
@export var weapon_position: Vector3 = Vector3(0.2, -0.2, -0.3)
@export_group("Other Model Setting")
@export var weapon_rotation: Vector3 = Vector3(0, 0, 0)
@export var weapon_scale: Vector3 = Vector3(1, 1, 1)

