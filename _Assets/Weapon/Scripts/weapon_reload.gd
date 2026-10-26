class_name WeaponReload extends RefCounted
## Ammo transfer and reload input handling:
## double-tap reload (dump the magazine), shell-by-shell reloads and queued shells.
##
## `is_reloading` stays on WeaponController because the state chart drives it.

## Second reload press inside this window dumps the magazine and reloads.
const DOUBLE_TAP_WINDOW: float = 0.28

var ctrl: WeaponController

var weapon: Weapon:
	get:
		return ctrl.current_weapon
var weapon_data: WeaponData:
	get:
		return ctrl.active_weapon_data

var _tap_pending: bool = false
var _tap_timer: float = 0.0
var _queued_shell_reloads: int = 0


func _init(controller: WeaponController) -> void:
	ctrl = controller


## Call every frame: resolves a single reload tap once the double-tap window closes.
func process(delta: float) -> void:
	if not _tap_pending:
		return

	_tap_timer -= delta
	if _tap_timer <= 0.0:
		_tap_pending = false
		if not ctrl.is_reloading:
			ctrl.send_state_event("onReload")


#region Input
func request_reload() -> void:
	if weapon != null and weapon.is_reload_per_bullet:
		_cancel_double_tap()
		if ctrl.is_reloading:
			_queued_shell_reloads += 1
		else:
			ctrl.send_state_event("onReload")
		return

	if _tap_pending:
		_cancel_double_tap()
		dump_magazine_and_reload()
		return

	_tap_pending = true
	_tap_timer = DOUBLE_TAP_WINDOW


func _cancel_double_tap() -> void:
	_tap_pending = false
	_tap_timer = 0.0


func dump_magazine_and_reload() -> void:
	if not can_reload():
		return

	# Dumping the magazine does not eject a round already in the chamber,
	# so is_loaded is left untouched.
	weapon_data.ammo_in_magazine = 0
	ctrl.update_weapon_ui()
	ctrl.send_state_event("onReload")


## Called by the state chart when a reload step ends.
func finish_reload_step() -> void:
	ctrl.is_reloading = false
	if _queued_shell_reloads > 0 and can_reload():
		_queued_shell_reloads -= 1
		ctrl.send_state_event("onReload")
#endregion


#region Ammo transfer
func can_reload() -> bool:
	if weapon == null or weapon_data == null:
		print("No weapon or weapon data available.")
		return false

	if weapon_data.reserve_ammo <= 0:
		print("No reserve ammo left to reload.")
		return false

	if weapon_data.ammo_in_magazine == weapon.get_calculated_magazine_capacity():
		print("Magazine is already full.")
		return false

	return true


func execute_reload() -> void:
	if not can_reload():
		return

	ctrl.reset_trigger()

	if weapon.is_reload_per_bullet:
		reload_single_round()
	else:
		reload_magazine()


func get_single_round_reload_time() -> float:
	if weapon == null:
		return 0.0

	var mag_capacity: int = weapon.get_calculated_magazine_capacity()
	if mag_capacity <= 0:
		return 0.0

	return weapon.reload_time / float(mag_capacity)


## Loads one round (shotgun-style). The chamber is not touched: if it was empty,
## the player still has to rack/pump before the gun can fire.
func reload_single_round() -> void:
	if not can_reload():
		return

	if weapon_data.ammo_in_magazine >= weapon.get_calculated_magazine_capacity():
		return

	weapon_data.ammo_in_magazine += 1
	weapon_data.reserve_ammo -= 1
	_sync_open_bolt_flag()
	ctrl.update_weapon_ui()


## Loads the whole magazine at once.
## Tactical reload (round in the chamber): the chambered round stays, so you end up with capacity + 1.
## Empty reload (chamber empty): the chamber stays empty until the player racks the slide.
func reload_magazine() -> void:
	if not can_reload():
		return

	var mag_capacity: int = weapon.get_calculated_magazine_capacity()
	if weapon_data.ammo_in_magazine >= mag_capacity:
		return

	var needed: int = mag_capacity - weapon_data.ammo_in_magazine
	var transfer: int = mini(needed, weapon_data.reserve_ammo)

	weapon_data.ammo_in_magazine += transfer
	weapon_data.reserve_ammo -= transfer
	_sync_open_bolt_flag()
	ctrl.update_weapon_ui()


## Open-bolt guns have no separate chamber; is_loaded just mirrors "has rounds" for the HUD.
func _sync_open_bolt_flag() -> void:
	if weapon.is_open_bolt:
		weapon_data.is_loaded = weapon_data.ammo_in_magazine > 0
#endregion