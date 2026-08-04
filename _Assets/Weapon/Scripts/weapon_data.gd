class_name WeaponData extends Resource

# Export the weapon. Call `initialize()` after assigning at runtime.
@export var weapon:Weapon
@export var is_unlocked:bool = false

@export var initialized: bool = false

@export var ammo_in_magazine:int = 0
@export var reserve_ammo:int = 0
@export var current_fire_mode: int = 0
@export var is_loaded: bool = false


func _init() -> void:
	# If the resource was created with `weapon` already set in the file, initialize now.
	if weapon and not initialized:
		_init_from_weapon()


func initialize(weapon_ref:Weapon) -> void:
	# Call this from code when creating the Resource at runtime.
	weapon = weapon_ref
	if not initialized:
		_init_from_weapon()
		print("WeaponData initialized from weapon: ", weapon.weapon_name, " ammo_in_magazine: ", ammo_in_magazine, " reserve_ammo: ", reserve_ammo, " current_fire_mode: ", current_fire_mode, " is_loaded: ", is_loaded)



func _init_from_weapon() -> void:
	if not weapon:
		return

	# Only set defaults if this WeaponData hasn't been initialized yet.
	if initialized:
		return

	ammo_in_magazine = weapon.mags_ammo
	reserve_ammo = weapon.max_ammo
	current_fire_mode = weapon.fire_mode
	is_loaded = ammo_in_magazine > 0
	initialized = true
