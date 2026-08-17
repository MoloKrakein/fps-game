class_name EnemyShootingComponent
extends BaseShootingComponent

var current_ammo: int = 0
var reload_timer: float = 0.0

func _ready() -> void:
	if weapon_data: current_ammo = weapon_data.mags_ammo

func _process(delta: float) -> void:
	super._process(delta) # CRITICAL: Tells the base script to process the fire_timer!
	
	if reload_timer > 0.0:
		reload_timer = maxf(reload_timer - delta, 0.0)
		if reload_timer == 0.0:
			current_ammo = weapon_data.mags_ammo

# Overrides the virtual function in the base script
func _handle_ammo_consumption() -> bool:
	if reload_timer > 0.0:
		return false
		
	if current_ammo <= 0:
		var r_time = weapon_data.get("reload_time")
		reload_timer = r_time if r_time != null else 2.0
		return false
		
	current_ammo -= 1
	return true # Yes, ammo is consumed, allow the shot!