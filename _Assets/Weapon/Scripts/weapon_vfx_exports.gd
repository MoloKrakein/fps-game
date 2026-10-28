# Paste into weapon.gd, e.g. right after the existing "Muzzle Effects" exports.
# Everything above (muzzle_process_material, muzzle_flash_mesh, muzzle_light_*, muzzle_flash_scale) stays as is.

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
## false for bolt-action / pump weapons: call MuzzleFlash.eject_smoke() when the case is ejected
@export var eject_smoke_on_fire: bool = true
