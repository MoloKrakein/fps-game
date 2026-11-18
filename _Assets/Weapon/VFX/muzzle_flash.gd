class_name MuzzleFlash extends Node3D
## Simple muzzle effect: a short flash, a light flick, and the muzzle blast (gas leaving with the bullet).
## Sparks, barrel haze and ejection smoke are removed for now.

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var flash_chance: float = 1.0
## Flash quad (muzzle_flash.gdshader), one-shot
@export var particles: GPUParticles3D
## Muzzle blast puffs (muzzle_blast.gdshader), one-shot. The second emitter is optional:
## shots alternate between the two so a fast burst does not cut the previous puff short.
@export var blast_particles: GPUParticles3D
@export var blast_particles_alt: GPUParticles3D
@export var light: OmniLight3D

@export_group("Flash")
## Multiplies the weapon's flash intensity. Lower = more subtle.
@export_range(0.0, 2.0, 0.05) var flash_strength: float = 0.4

@export_group("Blast")
## Peak alpha of the blast puff
@export_range(0.0, 1.0, 0.01) var blast_opacity: float = 0.14
## Seconds after the flash before the blast starts
@export var blast_delay: float = 0.008

var _light_tween: Tween
var _blast_enabled: bool = true
var _use_alt_blast: bool = false


func _ready() -> void:
	for particle: GPUParticles3D in _one_shot_emitters():
		particle.one_shot = true
		particle.emitting = false
	if blast_particles:
		blast_particles.local_coords = false
	if blast_particles_alt:
		blast_particles_alt.local_coords = false
	if light:
		light.light_energy = 0.0


func configure(weapon: Weapon) -> void:
	enabled = weapon.is_muzzle_flash_enabled
	_blast_enabled = weapon.barrel_smoke_enabled

	if particles:
		particles.scale = Vector3.ONE * weapon.muzzle_flash_scale
		particles.set_instance_shader_parameter("flash_color", weapon.muzzle_light_color)
		particles.set_instance_shader_parameter("intensity", weapon.muzzle_flash_intensity * flash_strength)
		particles.set_instance_shader_parameter("spikes", float(weapon.muzzle_flash_spikes))

	for particle: GPUParticles3D in _blast_emitters():
		particle.set_instance_shader_parameter("blast_color", weapon.barrel_smoke_color)
		particle.set_instance_shader_parameter("size_mult", weapon.barrel_smoke_scale)
		particle.set_instance_shader_parameter("blast_opacity", blast_opacity)


## Old entry point, kept so existing callers keep working.
func flash(color: Color, energy: float, duration: float) -> void:
	trigger(color, energy, duration)


func trigger(color: Color, energy: float, duration: float) -> void:
	if not enabled:
		return
	var show_flash: bool = randf() <= clampf(flash_chance, 0.0, 1.0)
	if show_flash and particles:
		particles.restart()

	if _blast_enabled:
		_play_blast()

	if show_flash and light:
		light.light_color = color
		light.light_energy = energy
		if _light_tween and _light_tween.is_valid():
			_light_tween.kill()
		_light_tween = create_tween().bind_node(self)
		_light_tween.tween_property(light, "light_energy", 0.0, duration)


## Kept so older calls do not break. The ejection port smoke is removed for now.
func eject_smoke() -> void:
	pass


func _play_blast() -> void:
	var emitter: GPUParticles3D = blast_particles
	if _use_alt_blast and blast_particles_alt != null:
		emitter = blast_particles_alt
	_use_alt_blast = not _use_alt_blast
	if emitter == null:
		return
	if blast_delay <= 0.0:
		emitter.restart()
		return
	var tween: Tween = create_tween().bind_node(self)
	tween.tween_interval(blast_delay)
	tween.tween_callback(emitter.restart)


func _blast_emitters() -> Array[GPUParticles3D]:
	var all: Array[GPUParticles3D] = []
	if blast_particles != null:
		all.append(blast_particles)
	if blast_particles_alt != null:
		all.append(blast_particles_alt)
	return all


func _one_shot_emitters() -> Array[GPUParticles3D]:
	var all: Array[GPUParticles3D] = _blast_emitters()
	if particles != null:
		all.append(particles)
	return all


func _exit_tree() -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
