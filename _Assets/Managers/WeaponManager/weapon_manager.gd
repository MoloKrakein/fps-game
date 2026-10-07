class_name WeaponManager extends Node

@export var weapons: Dictionary[int, WeaponData] = {}
@export var player: PlayerController

var current_weap_slot: int = 1

func _ready() -> void:
	add_to_group("weapon_manager")
	Manager.weapon_manager = self
	_make_weapon_data_instances_unique()

	for i in range(1, 10):
		var action_name = "equip_weapon_" + str(i)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key_event = InputEventKey.new()
			key_event.keycode = KEY_1 + (i - 1)  # KEY_1 corresponds to the first weapon slot
			InputMap.action_add_event(action_name, key_event)
	# call_deferred("initialize_starting_weapon",1)

	player.weapon_controller.initialize_weapon_data(weapons.get(current_weap_slot))

func _make_weapon_data_instances_unique() -> void:
	for slot: int in weapons:
		var weapon_data: WeaponData = weapons[slot]
		if weapon_data == null:
			continue

		# The weapon definition is immutable shared configuration. Only the
		# per-slot runtime state needs to be a unique resource instance.
		weapons[slot] = weapon_data.duplicate(false) as WeaponData


func _unhandled_input(event: InputEvent) -> void:
	for i in range(1, 10):
		var action_name = "equip_weapon_" + str(i)
		if event.is_action_pressed(action_name):
			equip_weapon(i)


func equip_weapon(slot: int) -> void:
	var weapon_data = weapons.get(slot)
	if player.weapon_controller.is_reloading or player.weapon_controller.is_aiming:
		return
	if weapon_data and weapon_data.is_unlocked:
		current_weap_slot = slot
		player.weapon_controller.switch_weapon(weapon_data)
		EventBus.weapon_ammo_changed.emit(weapon_data.ammo_in_magazine, weapon_data.reserve_ammo)
		


func use_ammo(slot: int, amount: int = 1) -> void:
	if slot not in weapons or amount <= 0:
		return

	# Reserve ammo is transferred into the magazine during reload, not when a
	# shot is fired. Deducting both here makes one shot consume two rounds.
	weapons[slot].ammo_in_magazine = max(0, weapons[slot].ammo_in_magazine - amount)


func get_current_ammo() -> int:
	return weapons[current_weap_slot].ammo_in_magazine if current_weap_slot in weapons else 0

func get_reserve_ammo() -> int:
	return weapons[current_weap_slot].reserve_ammo if current_weap_slot in weapons else 0

func get_current_weapon_data() -> WeaponData:
	return weapons[current_weap_slot] if current_weap_slot in weapons else null

func get_is_loaded() -> bool:
	return weapons[current_weap_slot].is_loaded if current_weap_slot in weapons else false

func unlock_weapon(slot: int, weapon_resource: Weapon) -> void:
	if slot in weapons:
		weapons[slot].weapon = weapon_resource
		weapons[slot].is_unlocked = true
		weapons[slot].fire_mode = weapon_resource.fire_mode
		weapons[slot].reserve_ammo = weapon_resource.max_ammo
		EventBus.weapon_ammo_changed.emit(weapons[slot].ammo_in_magazine, weapons[slot].reserve_ammo)

# func initialize_starting_weapon(weapon_data: WeaponData) -> void:
# 	for slot in range(1, 10):
# 		if weapons.has(slot) and weapons[slot].is_unlocked:
# 			equip_weapon(slot)
