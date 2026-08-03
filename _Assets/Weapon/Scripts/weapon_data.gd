class_name WeaponData extends Resource

@export var weapon:Weapon
@export var is_unlocked:bool = false

@export var ammo_in_magazine:int = 0
@export var reserve_ammo:int = 0


func _ready() -> void:
	ammo_in_magazine = weapon.mags_ammo
	reserve_ammo = weapon.max_ammo
