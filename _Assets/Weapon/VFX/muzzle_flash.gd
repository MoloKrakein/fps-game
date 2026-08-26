class_name MuzzleFlash extends Node3D
@export var enabled: bool = true
@export var particles: GPUParticles3D
@export var light: OmniLight3D

var _light_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if particles:
		particles.one_shot = true
		particles.emitting = false
	if light:
		light.light_energy = 0.0


func configure(weapon: Weapon) -> void:
	enabled = weapon.is_muzzle_flash_enabled
	if not particles:
		return
	if weapon.muzzle_process_material:
		particles.process_material = weapon.muzzle_process_material
	if weapon.muzzle_flash_mesh:
		particles.draw_pass_1 = weapon.muzzle_flash_mesh

	particles.scale = Vector3.ONE * weapon.muzzle_flash_scale

func flash(color: Color, energy: float, duration: float) -> void:
	if not enabled or not light or not particles:
		return

	particles.restart()

	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	light.light_color = color
	light.light_energy = energy
	_light_tween = create_tween().bind_node(self)
	_light_tween.tween_property(light, "light_energy", 0.0, duration)
func _exit_tree() -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
