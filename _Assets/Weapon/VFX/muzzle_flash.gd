class_name MuzzleFlash extends Node3D
## Simple muzzle effect: a short flash, a light flick, muzzle gas and ejection port gas.

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var flash_chance: float = 1.0
## Flash quad (muzzle_flash.gdshader), one-shot
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
var _muzzle_gas_enabled: bool = true
var _ejection_gas_enabled: bool = true
var _eject_on_fire: bool = true


func _ready() -> void:
	if particles:
		particles.one_shot = true
		particles.emitting = false
	if light:
		light.light_energy = 0.0


func configure(weapon: Weapon) -> void:
	enabled = weapon.is_muzzle_flash_enabled
	_muzzle_gas_enabled = weapon.barrel_smoke_enabled
	_ejection_gas_enabled = weapon.ejection_smoke_enabled
	_eject_on_fire = weapon.eject_smoke_on_fire

	if particles:
		particles.scale = Vector3.ONE * weapon.muzzle_flash_scale
		particles.set_instance_shader_parameter("flash_color", weapon.muzzle_light_color)
		particles.set_instance_shader_parameter("intensity", weapon.muzzle_flash_intensity * flash_strength)
		particles.set_instance_shader_parameter("spikes", float(weapon.muzzle_flash_spikes))

	if muzzle_gas:
		muzzle_gas.set_look(weapon.barrel_smoke_color, weapon.barrel_smoke_scale)
	if ejection_gas:
		ejection_gas.set_look(weapon.ejection_smoke_color, weapon.ejection_smoke_scale)


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


func _exit_tree() -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
