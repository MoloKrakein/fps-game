class_name WeaponAttachments extends RefCounted
## Attachment data (stored on WeaponData), their models on the WeaponModel,
## combined stat modifiers, and the ADS alignment optics provide.

signal changed  ## emitted after equip / unequip / mount_all

var ctrl: WeaponController

var _stats_dirty: bool = true
var _accuracy_bonus: float = 0.0
var _damage_bonus: float = 0.0
var _ammo_capacity_bonus: int = 0
var _recoil_multiplier: float = 1.0
var _reload_time_multiplier: float = 1.0
var _muzzle_energy_multiplier: float = 1.0


func _init(controller: WeaponController) -> void:
	ctrl = controller


#region Equip / unequip
func can_equip(att: Attachment) -> bool:
	if att == null or ctrl.active_weapon_data == null:
		return false
	if ctrl.current_weapon_model is WeaponModel:
		return (ctrl.current_weapon_model as WeaponModel).can_accept(att)
	return true  # no model yet: data can still be stored, mount_all() validates later


func equip(att: Attachment) -> bool:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or att == null:
		print("Cannot equip attachment: active_weapon_data or att is null.")
		return false
	if not can_equip(att):
		push_warning("%s can't be fitted to this weapon." % att.attachment_name)
		return false

	data.equipped_attachment_data[att.attachment_slot] = att
	_show(att.attachment_slot, att)
	_stats_dirty = true
	changed.emit()
	return true


func unequip(slot: Attachment.AttachmentSlot) -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or not data.equipped_attachment_data.has(slot):
		return

	data.equipped_attachment_data.erase(slot)
	_show(slot, null)
	_stats_dirty = true
	changed.emit()


## Re-creates every equipped attachment's model, e.g. after a new weapon model spawns.
func mount_all() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or ctrl.current_weapon_model is not WeaponModel:
		return

	var model := ctrl.current_weapon_model as WeaponModel
	for slot: Attachment.AttachmentSlot in data.equipped_attachment_data.keys():
		var att: Attachment = data.equipped_attachment_data[slot]
		if att == null:
			continue
		if model.can_accept(att):
			model.set_attachment(slot, att)
		else:
			# Saved loadout contains something this weapon can't take: drop it.
			data.equipped_attachment_data.erase(slot)
	_stats_dirty = true
	changed.emit()


func get_equipped_in_slot(slot: Attachment.AttachmentSlot) -> Attachment:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		return null
	return data.equipped_attachment_data.get(slot) as Attachment


func _show(slot: Attachment.AttachmentSlot, att: Attachment) -> void:
	if ctrl.current_weapon_model is WeaponModel:
		(ctrl.current_weapon_model as WeaponModel).set_attachment(slot, att)


# Old public names, kept so existing callers keep working.
func spawn_model(att: Attachment) -> void:
	_show(att.attachment_slot, att)


func remove_model(att: Attachment) -> void:
	_show(att.attachment_slot, null)
#endregion


#region Stats (same maths as before: flat bonuses add, multipliers multiply)
func get_accuracy_bonus() -> float:
	_refresh_stats()
	return _accuracy_bonus


func get_damage_bonus() -> float:
	_refresh_stats()
	return _damage_bonus


func get_ammo_capacity_bonus() -> int:
	_refresh_stats()
	return _ammo_capacity_bonus


func get_recoil_multiplier() -> float:
	_refresh_stats()
	return _recoil_multiplier


func get_reload_time_multiplier() -> float:
	_refresh_stats()
	return _reload_time_multiplier


func get_muzzle_flash_energy_multiplier() -> float:
	_refresh_stats()
	return _muzzle_energy_multiplier


func _refresh_stats() -> void:
	if not _stats_dirty:
		return
	var list := _equipped()
	_accuracy_bonus = Attachment.sum_float(list, &"accuracy_bonus")
	_damage_bonus = Attachment.sum_float(list, &"damage_bonus")
	_ammo_capacity_bonus = int(Attachment.sum_float(list, &"ammo_capacity_bonus"))
	_recoil_multiplier = Attachment.product_float(list, &"recoil_multiplier")
	_reload_time_multiplier = Attachment.product_float(list, &"reload_time_multiplier")
	_muzzle_energy_multiplier = Attachment.product_float(list, &"muzzle_flash_energy_multiplier")
	_stats_dirty = false
#endregion


#region ADS
## Optics are aligned automatically: the optic's SightPoint is moved onto the
## same spot the weapon's iron sights use, so any optic works on any weapon.
## Falls back to the old absolute overrides only when no SightPoint exists.

func get_ads_position() -> Vector3:
	if ctrl.current_weapon == null:
		return Vector3.ZERO
	var base: Vector3 = ctrl.current_weapon.aim_ADS_position
	var optic := get_equipped_in_slot(Attachment.AttachmentSlot.OPTIC)
	if optic == null:
		return base

	var model := ctrl.current_weapon_model as WeaponModel
	var fit_offset := Vector3.ZERO
	if model != null:
		var fit := model.get_fit(optic)
		if fit != null:
			fit_offset = fit.ads_offset

		var sight := model.get_sight_point_local(optic)
		var iron := model.get_iron_sight_point_local()
		if not sight.is_empty() and not iron.is_empty():
			# model-local delta -> parent space using the ADS rotation + model scale
			var basis := Basis.from_euler(get_ads_rotation()).scaled(ctrl.current_weapon.weapon_scale)
			return base + basis * (iron.position - sight.position) + fit_offset

	if optic.override_ads_position != Vector3.ZERO:   # legacy fallback
		return optic.override_ads_position + fit_offset
	return base + fit_offset


func get_ads_rotation() -> Vector3:
	if ctrl.current_weapon == null:
		return Vector3.ZERO
	var optic := get_equipped_in_slot(Attachment.AttachmentSlot.OPTIC)
	if optic != null and optic.override_ads_rotation != Vector3.ZERO:   # legacy fallback
		return optic.override_ads_rotation
	return ctrl.current_weapon.aim_ADS_rotation


func get_ads_fov() -> float:
	if ctrl.current_weapon == null:
		return 0.0
	var optic := get_equipped_in_slot(Attachment.AttachmentSlot.OPTIC)
	if optic != null and optic.override_ads_fov > 0.0:
		return optic.override_ads_fov
	return ctrl.current_weapon.aim_fov
#endregion


func _equipped() -> Array[Attachment]:
	var result: Array[Attachment] = []
	var data: WeaponData = ctrl.active_weapon_data
	if data and data.equipped_attachment_data:
		for att: Attachment in data.equipped_attachment_data.values():
			if att:
				result.append(att)
	return result