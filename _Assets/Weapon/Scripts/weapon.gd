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
@export_range(0, 100) var headshot_multiplier: float = 2.0
@export_range(0, 100) var armor_penetration: float = 0.0
@export var crit_rate: float = 0.0
@export var crit_damage: float = 0.0
@export var mags_ammo: int = 7
@export var max_ammo: int = 90
# @export var ammo_per_clip: int = 7 #for future use, if we want to implement a reload system with clips
@export var is_hitscan: bool = true
# shotgun / revolver reload per bullet, other weapons reload all bullets at once
@export var is_reload_per_bullet: bool = false

@export_group("Recoil Control")
@export var recoil_cam_pitch: float = 1.0
@export var recoil_cam_yaw: float = 0.25
@export var recoil_cam_roll: float = 0.0
@export var recoil_cam_recovery_speed: float = 5.0
@export var recoil_weapon_kick: float = 0.02
@export var recoil_weapon_rise: float = 8.0

@export_group("Fire Control")
@export var fire_rate_rpm: float = 600.0
@export var fire_rate: float = 0.1 # Legacy seconds-per-shot fallback.
@export var burst_shot_count: int = 3
@export var shoot_range: float = 100.0
@export_range(0,100) var accuracy: float = 100
@export_range(0, 1) var spread_angle: float = 0.0
@export var pellet_count: int = 1
@export var reload_time: float = 2.0
@export var fire_mode: WeaponFireMode = WeaponFireMode.SEMI_AUTO
@export var can_change_fire_mode: bool = false
@export var has_burst_mode: bool = false
@export var is_open_bolt: bool = false
@export var ammo_type: WeaponAmmoType = WeaponAmmoType.LIGHT
@export var projectile_speed: float = 50.0
# @export var is_projectile_tracer: bool = false

@export_category("Aiming")
@export var aim_fov: float = 60.0
@export var aim_sensitivity: float = 0.5
@export var vertical_lag_multiplier: float = 1.0
@export_range(0, 100) var aim_accuracy_modifier: float = 0.5 # higher value means more accurate when aiming down sights
@export var aim_sway: float = 0.5
@export var aim_recoil_reduction: float = 0.5
@export_group("Aim Visuals")
@export var aim_sway_amount: float = 0.5
@export var aim_tilt_amount: float = 0.5
@export_group("Aiming ADS")
@export var aim_ADS_position: Vector3 = Vector3(0, 0, 0)
@export var aim_ADS_rotation: Vector3 = Vector3(0, 0, 0)
@export_group("Aiming Canted Sight")
@export var canted_sight_fov: float = 70.0
@export var canted_sight_position: Vector3 = Vector3(0, 0, 0)
@export var canted_sight_rotation: Vector3 = Vector3(0, 0, 0)


@export_category("Weapon Model")
@export_group("Model Setting")
@export var weapon_model: PackedScene
@export var projectile_scene: PackedScene
@export var bullet_case_scene: PackedScene
@export_group("Other Model Setting")
@export var weapon_position: Vector3 = Vector3(0.2, -0.2, -0.3)
@export var weapon_rotation: Vector3 = Vector3(0, 0, 0)
@export var weapon_scale: Vector3 = Vector3(1, 1, 1)


const METERS_PER_WORLD_UNIT: float = 1.0


func get_muzzle_velocity_mps() -> float:
	return maxf(projectile_speed / METERS_PER_WORLD_UNIT, 0.0)

func get_muzzle_velocity_kmh() -> float:
	return get_muzzle_velocity_mps() * 3.6

func get_fire_rate_rpm() -> float:

	if fire_rate_rpm > 0.0:
		return fire_rate_rpm

	if fire_rate > 0.0:
		return 60.0 / fire_rate

	return 0.0

func get_fire_interval_seconds() -> float:
	var rpm := get_fire_rate_rpm()
	if rpm <= 0.0:
		return 0.0
	return 60.0 / rpm
