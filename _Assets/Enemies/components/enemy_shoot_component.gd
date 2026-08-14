class_name EnemyShootingComponent
extends Node3D

# --- Exported Resources ---
@export var weapon_data: Weapon # Reuses the exact same resource as the player
@export var aim_raycast: RayCast3D 
@export var attack_range: float = 8.0

# --- State Variables ---
var current_ammo: int = 0
var fire_timer: float = 0.0
var reload_timer: float = 0.0

#region Lifecycle
func _ready() -> void:
	if weapon_data != null:
		current_ammo = weapon_data.mags_ammo

func _process(delta: float) -> void:
	# Tick down fire rate cooldown
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
		
	# Tick down reload delay
	if reload_timer > 0.0:
		reload_timer = maxf(reload_timer - delta, 0.0)
		# Once the timer hits exactly 0, refill the magazine instantly
		if reload_timer == 0.0:
			_finish_reload()
#endregion

#region Core Logic
## Called constantly by the Enemy AI script during the "Attack" state.
func fire() -> void:
	if weapon_data == null or not is_instance_valid(aim_raycast):
		return
		
	# Block shooting if we are on cooldown or currently reloading
	if fire_timer > 0.0 or reload_timer > 0.0:
		return

	# If the magazine is empty, trigger the reload delay and stop shooting
	if current_ammo <= 0:
		_start_reload()
		return
	
	print("Enemy shooting at player!")	
	# If we pass all checks, actually shoot
	_execute_shot()

func _start_reload() -> void:
	# Set the timer using the weapon resource's reload time
	reload_timer = weapon_data.reload_time 
	# Optional: Emit a signal here if you want the AI script to play a reload animation

func _finish_reload() -> void:
	# Refill magazine (Infinite reserve ammo means we just reset the int)
	current_ammo = weapon_data.mags_ammo

func _execute_shot() -> void:
	current_ammo -= 1
	fire_timer = 60.0 / weapon_data.fire_rate 
	
	print("Enemy Pulled the Trigger! Ammo left: ", current_ammo) # <--- ADD THIS
	
	aim_raycast.force_raycast_update()
	
	if aim_raycast.is_colliding():
		var hit_target = aim_raycast.get_collider()
		print("Enemy hit: ", hit_target.name) # <--- ADD THIS
		
		if hit_target.is_in_group("player") and hit_target.has_method("take_damage"):
			hit_target.take_damage(weapon_data.damage)
#endregion