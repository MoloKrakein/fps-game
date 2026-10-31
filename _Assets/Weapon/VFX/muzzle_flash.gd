class_name MuzzleFlash extends Node3D

@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var flash_chance: float = 1.0
## Muzzle flash quad (muzzle_flash.gdshader)
@export var particles: GPUParticles3D
## Sparks (spark_sim.gdshader + spark_draw.gdshader)
@export var spark_particles: GPUParticles3D
## Barrel haze emitter(s) (smoke_haze.gdshader)
@export var smoke_particles: Array[GPUParticles3D]
## Ejection port smoke emitter (smoke_haze.gdshader)
@export var ejection_smoke: GPUParticles3D
@export var light: OmniLight3D

@export_group("Barrel haze")
## Seconds the haze keeps emitting after each shot. Shots overlap, so it runs while you fire and stops right after.
@export var barrel_smoke_burst: float = 0.1
## Peak alpha of the haze. Keep it low (0.08 - 0.15) for the subtle look.
@export_range(0.0, 1.0, 0.01) var barrel_smoke_opacity: float = 0.12
@export_range(0.05, 3.0, 0.05) var barrel_smoke_thickness: float = 1.0
@export_range(1.0, 4.0, 0.1) var barrel_smoke_stretch: float = 1.8

@export_group("Ejection smoke")
@export var eject_smoke_on_fire: bool = true
@export var ejection_smoke_burst: float = 0.15
@export_range(0.0, 1.0, 0.01) var ejection_smoke_opacity: float = 0.2
@export_range(0.05, 3.0, 0.05) var ejection_smoke_thickness: float = 0.9
@export_range(1.0, 4.0, 0.1) var ejection_smoke_stretch: float = 1.0

@export_group("Heat")
## Sustained fire builds heat, which makes the smoke a little longer and denser.
@export var heat_per_shot: float = 0.2
@export var heat_cool_rate: float = 0.5
@export var max_heat_burst_multiplier: float = 1.5

var _light_tween: Tween
var _smoke_tweens: Dictionary = {}
var _heat: float = 0.0
var _barrel_smoke_enabled: bool = true
var _ejection_smoke_enabled: bool = true


func _ready() -> void:
	if particles:
		particles.one_shot = true
		particles.emitting = false
	if spark_particles:
		spark_particles.one_shot = true
		spark_particles.emitting = false
		spark_particles.local_coords = false
	# Smoke emitters run continuously with amount_ratio 0. A shot raises it for a short
	# time. restart() would delete the smoke that is still floating from earlier shots.
	for particle: GPUParticles3D in _all_smoke():
		particle.one_shot = false
		particle.local_coords = false
		particle.amount_ratio = 0.0
		particle.emitting = true
	if light:
		light.light_energy = 0.0
	set_process(false)


func _process(delta: float) -> void:
	_heat = move_toward(_heat, 0.0, heat_cool_rate * delta)
	if _heat <= 0.0:
		set_process(false)


func configure(weapon: Weapon) -> void:
	enabled = weapon.is_muzzle_flash_enabled
	_barrel_smoke_enabled = weapon.barrel_smoke_enabled
	_ejection_smoke_enabled = weapon.ejection_smoke_enabled
	eject_smoke_on_fire = weapon.eject_smoke_on_fire

	if particles:
		if weapon.muzzle_process_material:
			particles.process_material = weapon.muzzle_process_material
		if weapon.muzzle_flash_mesh:
			particles.draw_pass_1 = weapon.muzzle_flash_mesh
		particles.scale = Vector3.ONE * weapon.muzzle_flash_scale
		particles.set_instance_shader_parameter("flash_color", weapon.muzzle_light_color)
		particles.set_instance_shader_parameter("intensity", weapon.muzzle_flash_intensity)
		particles.set_instance_shader_parameter("spikes", float(weapon.muzzle_flash_spikes))

	if spark_particles:
		spark_particles.amount_ratio = weapon.spark_amount_ratio
		spark_particles.set_instance_shader_parameter("spark_color", weapon.spark_color)

	for particle: GPUParticles3D in _barrel_smoke_particles():
		_set_smoke_look(particle, weapon.barrel_smoke_color, weapon.barrel_smoke_scale,
				barrel_smoke_opacity, barrel_smoke_thickness, barrel_smoke_stretch)
	if ejection_smoke:
		_set_smoke_look(ejection_smoke, weapon.ejection_smoke_color, weapon.ejection_smoke_scale,
				ejection_smoke_opacity, ejection_smoke_thickness, ejection_smoke_stretch)


func _set_smoke_look(particle: GPUParticles3D, color: Color, size: float, opacity: float,
		thickness: float, stretch: float) -> void:
	particle.set_instance_shader_parameter("smoke_color", color)
	particle.set_instance_shader_parameter("size_mult", size)
	particle.set_instance_shader_parameter("smoke_opacity", opacity)
	particle.set_instance_shader_parameter("smoke_thickness", thickness)
	particle.set_instance_shader_parameter("smoke_stretch", stretch)


## Old entry point, kept so existing callers keep working.
func flash(color: Color, energy: float, duration: float) -> void:
	trigger(color, energy, duration)


func trigger(color: Color, energy: float, duration: float) -> void:
	if not enabled:
		return
	var show_flash: bool = randf() <= clampf(flash_chance, 0.0, 1.0)
	if show_flash:
		if particles:
			particles.restart()
		if spark_particles:
			spark_particles.restart()

	_heat = clampf(_heat + heat_per_shot, 0.0, 1.0)
	set_process(true)

	if _barrel_smoke_enabled:
		var burst: float = barrel_smoke_burst * lerpf(1.0, max_heat_burst_multiplier, _heat)
		for particle: GPUParticles3D in _barrel_smoke_particles():
			particle.set_instance_shader_parameter("density", lerpf(0.7, 1.0, _heat))
			_smoke_burst(particle, burst)

	if eject_smoke_on_fire:
		eject_smoke()

	if show_flash and light:
		light.light_color = color
		light.light_energy = energy
		if _light_tween and _light_tween.is_valid():
			_light_tween.kill()
		_light_tween = create_tween().bind_node(self)
		_light_tween.tween_property(light, "light_energy", 0.0, duration)


## Call from the rack / bolt-cycle animation for weapons that eject on cycle
## (set eject_smoke_on_fire to false for those).
func eject_smoke() -> void:
	if ejection_smoke == null or not _ejection_smoke_enabled:
		return
	var burst: float = ejection_smoke_burst * lerpf(1.0, max_heat_burst_multiplier, _heat)
	ejection_smoke.set_instance_shader_parameter("density", lerpf(0.7, 1.0, _heat))
	_smoke_burst(ejection_smoke, burst)


func _smoke_burst(particle: GPUParticles3D, seconds: float) -> void:
	particle.amount_ratio = 1.0
	var old_tween: Tween = _smoke_tweens.get(particle)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween: Tween = create_tween().bind_node(self)
	tween.tween_interval(seconds)
	tween.tween_callback(func() -> void: particle.amount_ratio = 0.0)
	_smoke_tweens[particle] = tween


func _all_smoke() -> Array[GPUParticles3D]:
	var all: Array[GPUParticles3D] = _barrel_smoke_particles()
	if ejection_smoke != null:
		all.append(ejection_smoke)
	return all


func _barrel_smoke_particles() -> Array[GPUParticles3D]:
	var barrel: Array[GPUParticles3D] = []
	for particle: GPUParticles3D in smoke_particles:
		if particle != null:
			barrel.append(particle)
	return barrel


func _exit_tree() -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	for tween: Tween in _smoke_tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
