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
	HEAVY,
	EXPLOSIVE
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
@export var recoil_fov_punch: float = -0.5

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
@export_group("Explosive Ammo")
## Explosive weapons detonate their projectile on the first collision.
@export var explosion_radius: float = 4.0
@export var explosion_damage: float = 80.0
@export_range(0.0, 1.0, 0.01) var explosion_falloff: float = 1.0
@export var explosion_force: float = 8.0
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
@export var aim_lag_amount: float = 0.5
@export_group("Handling")
## 0 = light and agile (pistol), 1 = heavy (LMG). Drives sway/lag spring frequency,
## overshoot, amplitudes and ADS time. 0.5 keeps the old neutral feel.
@export_range(0.0, 1.0, 0.05) var handling_weight: float = 0.5
## Seconds to raise/lower the sights. 0 = derive from handling_weight.
@export var ads_time_override: float = 0.0
@export_group("Aiming ADS")
@export var aim_ADS_position: Vector3 = Vector3(0, 0, 0)
@export var aim_ADS_rotation: Vector3 = Vector3(0, 0, 0)
@export_group("Aiming Canted Sight")
@export var canted_sight_fov: float = 70.0
@export var canted_sight_position: Vector3 = Vector3(0, 0, 0)
@export var canted_sight_rotation: Vector3 = Vector3(0, 0, 0)

@export_group("Particle Effects")
@export_category("Muzzle Effect")
@export var is_muzzle_flash_enabled: bool = true
@export var muzzle_process_material: ParticleProcessMaterial
@export var muzzle_flash_mesh: Mesh
@export var muzzle_light_color: Color = Color(1, 0.8, 0.5)
@export var muzzle_light_energy: float = 2.0
@export var muzzle_light_duration: float = 0.05
@export var muzzle_flash_scale: float = 0.2

@export_group("Shader VFX")
@export var muzzle_flash_intensity: float = 8.0
@export_range(3, 12) var muzzle_flash_spikes: int = 6
@export_range(0.0, 1.0, 0.05) var spark_amount_ratio: float = 1.0
@export var spark_color: Color = Color(1.0, 0.7, 0.25)
@export var barrel_smoke_enabled: bool = true
@export var barrel_smoke_color: Color = Color(0.72, 0.72, 0.74, 1.0)
@export var barrel_smoke_scale: float = 1.0
@export var ejection_smoke_enabled: bool = true
@export var ejection_smoke_color: Color = Color(0.8, 0.8, 0.82, 0.8)
@export var ejection_smoke_scale: float = 1.0
## Set to false for bolt-action and pump weapons; call MuzzleFlash.eject_smoke()
## when the case is actually ejected.
@export var eject_smoke_on_fire: bool = true



@export_category("Weapon Model")
@export var ammo_display_offset: Vector3 = Vector3(0, 0, 0.5)
@export_group("Model Setting")
@export var weapon_model: PackedScene
@export var projectile_scene: PackedScene
@export var bullet_case_scene: PackedScene
@export var alive_bullet_scene: PackedScene
## Optional casing behavior profile. Leave empty to use the legacy ejection impulse.
@export var casing_profile: CasingEjectionProfile
@export_group("Other Model Setting")
@export var weapon_position: Vector3 = Vector3(0.2, -0.2, -0.3)
@export var weapon_rotation: Vector3 = Vector3(0, 0, 0)
@export var weapon_scale: Vector3 = Vector3(1, 1, 1)
@export var bullet_case_scale: Vector3 = Vector3(1, 1, 1)

@export_group("Running Aim Handling")
## Multipliers used only while sprinting and aiming at the same time.
@export_range(1.0, 5.0, 0.05) var running_aim_recoil_multiplier: float = 2.0
@export_range(1.0, 5.0, 0.05) var running_aim_sway_multiplier: float = 2.25
@export_range(1.0, 5.0, 0.05) var running_aim_bob_multiplier: float = 1.75
@export_range(1.0, 5.0, 0.05) var running_aim_lag_multiplier: float = 1.8
@export_range(1.0, 5.0, 0.05) var running_aim_tilt_multiplier: float = 1.6

@export_group("Tactical Sprint")
@export var override_tactical_sprint_pose: bool = false
@export var tactical_sprint_position_offset: Vector3 = Vector3.ZERO
@export var tactical_sprint_rotation_offset: Vector3 = Vector3.ZERO
@export_range(0.0, 3.0, 0.01) var tactical_sprint_motion_multiplier: float = 1.0



const METERS_PER_WORLD_UNIT: float = 1.0
var stats_component: PlayerStats
var active_attachments: Dictionary = {}
var active_weapon_data_ref: WeaponData = null

func get_muzzle_velocity_mps() -> float:
	return maxf(projectile_speed / METERS_PER_WORLD_UNIT, 0.0)

func get_muzzle_velocity_kmh() -> float:
	return get_muzzle_velocity_mps() * 3.6

func get_ads_time() -> float:
	if ads_time_override > 0.0:
		return ads_time_override
	return lerpf(0.12, 0.30, handling_weight)

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


# Dynamic Stats getters, these can be used to modify the weapon's attributes based on player stats or other game mechanics.

func get_calculated_damage() -> float:
	var final_damage: float = damage
	if stats_component:
		final_damage *= stats_component.get_stat("damage_modifier", 1.0)

	if active_weapon_data_ref and active_weapon_data_ref.equipped_attachment_data:
		for slot in active_weapon_data_ref.equipped_attachment_data:
			var att = active_weapon_data_ref.equipped_attachment_data[slot]
			if att:
				final_damage += att.damage_bonus

	return max(final_damage, 0.0)

func get_calculated_accuracy() -> float:
	var final_accuracy: float = accuracy
	if active_weapon_data_ref and active_weapon_data_ref.equipped_attachment_data:
		for att: Attachment in active_weapon_data_ref.equipped_attachment_data.values():
			if att:
				final_accuracy += att.accuracy_bonus
	return clampf(final_accuracy, 0.0, 100.0)

func get_calculated_magazine_capacity() -> int:
	var final_capacity: int = mags_ammo
	if active_weapon_data_ref and active_weapon_data_ref.equipped_attachment_data:
		for att: Attachment in active_weapon_data_ref.equipped_attachment_data.values():
			if att:
				final_capacity += att.ammo_capacity_bonus
	return maxi(final_capacity, 0)

func get_calculated_recoil() -> float:
	var final_recoil: float = recoil_cam_pitch
	if stats_component:
		final_recoil *= stats_component.get_stat("recoil_stability", 1.0)

	# --- ADD THIS: Apply Attachment Recoil Multipliers ---
	if active_weapon_data_ref and active_weapon_data_ref.equipped_attachment_data:
		for slot in active_weapon_data_ref.equipped_attachment_data:
			var att = active_weapon_data_ref.equipped_attachment_data[slot]
			if att and "recoil_multiplier" in att:
				final_recoil *= att.recoil_multiplier

	return max(final_recoil, 0.0)

func get_calculated_reload_speed() -> float:
	var final_reload_speed:float = reload_time
	if stats_component:
		# reload speed multiplier (example: 0.8 means 20% faster reload, 1.2 means 20% slower reload)
		final_reload_speed *= stats_component.get_stat("reload_speed", 1.0)

	if active_weapon_data_ref and active_weapon_data_ref.equipped_attachment_data:
		for slot in active_weapon_data_ref.equipped_attachment_data:
			var att = active_weapon_data_ref.equipped_attachment_data[slot]
			if att and "reload_time_multiplier" in att:
				final_reload_speed *= att.reload_time_multiplier
	return max(final_reload_speed, 0.0)

# stats related functions, these can be used to modify the weapon's attributes based on player stats or other game mechanics.

# func get_calculated_damage() -> float:
# 	var final_damage: float = damage
# 	# Apply
