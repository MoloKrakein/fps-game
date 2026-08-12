class_name BaseShootingComponent extends Node3D

# signals
signal weapon_fired
signal out_of_ammo
signal weapon_reloaded


@export var weapon: Weapon


var current_ammo: int
var reserve_ammo: int
var fire_timer: Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_initialize_weapon()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fire_timer != null and fire_timer.is_stopped() == false:
		fire_timer.wait_time = weapon.get_fire_interval_seconds()

func _initialize_weapon() -> void:
	if weapon == null:
		push_error("Weapon is not assigned to BaseShootingComponent.")
		return

	current_ammo = weapon.mags_ammo
	reserve_ammo = weapon.max_ammo
	fire_timer = Timer.new()
	fire_timer.one_shot = true
	add_child(fire_timer)
