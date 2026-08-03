class_name WeaponManager extends Node

@export var weapons: Dictionary[int, WeaponData] = {}
@export var player: PlayerController

var current_weap_slot: int = 0

func _ready() -> void:
	add_to_group("weapon_manager")

	for i in range(1, 10):
		var action_name = "equip_weapon_" + str(i)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key_event = InputEventKey.new()
			key_event.keycode = KEY_1 + (i - 1)  # KEY_1 corresponds to the first weapon slot
			InputMap.action_add_event(action_name, key_event)

func _unhandled_input(event: InputEvent) -> void:
	for i in range(1, 10):
		var action_name = "equip_weapon_" + str(i)
		if event.is_action_pressed(action_name):
			equip_weapon(i)


func equip_weapon(slot: int) -> void:
	var weapon_data = weapons.get(slot)

	if weapon_data and weapon_data.is_unlocked:
		current_weap_slot = slot
		player.equip_weapon(weapon_data.weapon)


func use_ammo(slot: int, amount: int) -> void:
	if slot in weapons:
		weapons[slot].ammo_in_magazine = max(0,weapons[slot].ammo_in_magazine - amount)
		weapons[slot].reserve_ammo = max(0,weapons[slot].reserve_ammo - amount)


func get_current_ammo() -> int:
	return weapons[current_weap_slot].ammo_in_magazine if current_weap_slot in weapons else 0