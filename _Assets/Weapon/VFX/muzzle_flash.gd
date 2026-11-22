class_name MuzzleFlash extends Node3D
## Simple muzzle effect: a short flash, a light flick, muzzle gas and ejection port gas.
## All of it is plain particles with sprite sheets, so there are no custom shaders to maintain.

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var flash_chance: float = 1.0
## Flash quad (StandardMaterial3D, additive, 2x2 flipbook). One-shot.
@export var particles: GPUParticles3D
## Gas at the muzzle (GasBurst). Set its mode to Forward, Expand, Side or Custom.
@export var muzzle_gas: GasBurst
## Gas at the ejection port (GasBurst), usually under the EjectionPort node.
@export var ejection_gas: GasBurst
@export var light: OmniLight3D

@export_group("Flash")
## Multiplies the weapon's flash intensity. Lower = more subtle.
@export_range(0.0, 2.0, 0.05) var flash_strength: float = 0.4

var _light_tween: Tween
var _flash_material: ParticleProcessMaterial
var _muzzle_gas_enabled: bool = true
var _ejection_gas_enabled: bool = true
var _eject_on_fire: bool = true


func _ready() -> void:
	_discover_emitters()
	if particles:
		particles.one_shot = true
		particles.emitting = false
		if particles.process_material is ParticleProcessMaterial:
			_flash_material = (particles.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			_flash_material.angle_min = 0.0
			_flash_material.angle_max = 360.0
			_flash_material.anim_speed_min = 0.0          # a random frame of the sheet, not an animation
			_flash_material.anim_speed_max = 0.0
			_flash_material.anim_offset_min = 0.0
			_flash_material.anim_offset_max = 1.0
			_flash_material.color_ramp = VfxCurves.flash_ramp()
			_flash_material.scale_curve = VfxCurves.grow_curve(0.8)
			particles.process_material = _flash_material
	if light:
		light.light_energy = 0.0


func configure(weapon: Weapon) -> void:
	enabled = weapon.is_muzzle_flash_enabled
	_muzzle_gas_enabled = weapon.barrel_smoke_enabled
	_ejection_gas_enabled = weapon.ejection_smoke_enabled
	_eject_on_fire = weapon.eject_smoke_on_fire
	_discover_emitters()

	if particles:
		particles.scale = Vector3.ONE * weapon.muzzle_flash_scale
		if _flash_material:
			var c: Color = weapon.muzzle_light_color
			var k: float = weapon.muzzle_flash_intensity * flash_strength
			_flash_material.color = Color(c.r * k, c.g * k, c.b * k, 1.0)   # above 1 on purpose, so Glow picks it up

	var model_scale: float = maxf(
		maxf(absf(weapon.weapon_scale.x), absf(weapon.weapon_scale.y)),
		absf(weapon.weapon_scale.z)
	)
	model_scale = clampf(model_scale, 0.05, 10.0)
	if muzzle_gas:
		muzzle_gas.set_look(
			weapon.barrel_smoke_color,
			weapon.barrel_smoke_scale / model_scale
		)
	if ejection_gas:
		var world_size: float = weapon.ejection_smoke_scale / model_scale
		ejection_gas.set_look(weapon.ejection_smoke_color, world_size)
		ejection_gas.set_motion(
			weapon.ejection_gas_duration,
			weapon.ejection_gas_tempo,
			weapon.ejection_gas_reach,
			weapon.ejection_gas_spread_degrees,
			weapon.ejection_gas_upward_lift,
			weapon.ejection_gas_puffs,
			weapon.ejection_gas_delay,
			weapon.ejection_gas_opacity
		)


## Old entry point, kept so existing callers keep working.
func flash(color: Color, energy: float, duration: float) -> void:
	trigger(color, energy, duration)


func trigger(color: Color, energy: float, duration: float) -> void:
	if not enabled:
		return
	var show_flash: bool = randf() <= clampf(flash_chance, 0.0, 1.0)
	if show_flash and particles:
		particles.restart()

	if muzzle_gas and _muzzle_gas_enabled:
		muzzle_gas.play()
	if _eject_on_fire:
		eject_smoke()

	if show_flash and light:
		light.light_color = color
		light.light_energy = energy
		if _light_tween and _light_tween.is_valid():
			_light_tween.kill()
		_light_tween = create_tween().bind_node(self)
		_light_tween.tween_property(light, "light_energy", 0.0, duration)


## Call when the case leaves the weapon (bolt / pump weapons: set eject_smoke_on_fire to false).
func eject_smoke() -> void:
	if ejection_gas and _ejection_gas_enabled:
		ejection_gas.play()


func _discover_emitters() -> void:
	if muzzle_gas == null:
		for node in find_children("*", "GasBurst", true, false):
			if node.name != &"EjectionGas" and node.is_inside_tree():
				muzzle_gas = node as GasBurst
				break
	if ejection_gas == null:
		var root := get_parent()
		while root != null and root.get_parent() != null:
			var found := root.find_child("EjectionGas", true, false) as GasBurst
			if found:
				ejection_gas = found
				break
			root = root.get_parent()


func _exit_tree() -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
