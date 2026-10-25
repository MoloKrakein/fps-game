class_name WeaponAttachments extends RefCounted
## Attachment data (stored on WeaponData), their models on the WeaponModel,
## and the ADS overrides attachments can provide (optics etc.).

var ctrl: WeaponController


func _init(controller: WeaponController) -> void:
	ctrl = controller


#region Equip / unequip
func equip(att: Attachment) -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or att == null:
		print("Cannot equip attachment: active_weapon_data or att is null.")
		return

	data.equipped_attachment_data[att.attachment_slot] = att

	if ctrl.current_weapon_model is WeaponModel:
		spawn_model(att)

	print("Equipped attachment: ", att.attachment_name, " in slot: ", att.attachment_slot)


func unequip(slot: Attachment.AttachmentSlot) -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null:
		print("Cannot unequip attachment: active_weapon_data is null.")
		return

	if not data.equipped_attachment_data.has(slot):
		print("No attachment found in slot: ", slot)
		return

	var att: Attachment = data.equipped_attachment_data[slot]
	if att != null:
		data.equipped_attachment_data.erase(slot)
		remove_model(att)
		print("Unequipped attachment: ", att.attachment_name, " from slot: ", slot)
#endregion


#region Models
func spawn_model(att: Attachment) -> void:
	if att == null or ctrl.current_weapon_model is not WeaponModel:
		print("Cannot spawn attachment model: attachment or weapon model is null.")
		return

	_apply_to_model(att, att)
	print("Spawned attachment model for: ", att.attachment_name)


func remove_model(att: Attachment) -> void:
	if att == null or ctrl.current_weapon_model is not WeaponModel:
		print("Cannot remove attachment model: attachment or weapon model is null.")
		return

	_apply_to_model(att, null)
	print("Removed attachment model for: ", att.attachment_name)


## Re-creates every equipped attachment's model, e.g. after a new weapon model spawns.
func mount_all() -> void:
	var data: WeaponData = ctrl.active_weapon_data
	if data == null or ctrl.current_weapon_model is not WeaponModel:
		return

	for att: Attachment in data.equipped_attachment_data.values():
		if att != null:
			spawn_model(att)


## `installed` is the attachment to show in the slot, or null to clear it.
func _apply_to_model(att: Attachment, installed: Attachment) -> void:
	var model: WeaponModel = ctrl.current_weapon_model
	if att.attachment_type == Attachment.AttachmentType.ADDITIVE:
		model.apply_additive_attachment(att.attachment_slot, installed)
	else:
		model.apply_replaceable_attachment(att.attachment_slot, installed)
#endregion


#region ADS overrides
# The first equipped attachment that overrides a value wins, otherwise the weapon's own value is used.

func get_ads_position() -> Vector3:
	if ctrl.current_weapon == null:
		return Vector3.ZERO
	for att: Attachment in _equipped():
		if att.override_ads_position != Vector3.ZERO:
			return att.override_ads_position
	return ctrl.current_weapon.aim_ADS_position


func get_ads_rotation() -> Vector3:
	if ctrl.current_weapon == null:
		return Vector3.ZERO
	for att: Attachment in _equipped():
		if att.override_ads_rotation != Vector3.ZERO:
			return att.override_ads_rotation
	return ctrl.current_weapon.aim_ADS_rotation


func get_ads_fov() -> float:
	if ctrl.current_weapon == null:
		return 0.0
	for att: Attachment in _equipped():
		if att.override_ads_fov > 0.0:
			return att.override_ads_fov
	return ctrl.current_weapon.aim_fov


func _equipped() -> Array[Attachment]:
	var result: Array[Attachment] = []
	var data: WeaponData = ctrl.active_weapon_data
	if data and data.equipped_attachment_data:
		for att: Attachment in data.equipped_attachment_data.values():
			if att:
				result.append(att)
	return result
#endregion
