class_name WeaponModel extends Node3D

@export_category("Socket")
@export var muzzle_socket: Node3D
@export var ejection_socket: Node3D

@export_category("Attachment Sockets (Additive)")
@export var optic_socket: Marker3D
@export var underbarrel_socket: Marker3D
@export var muzzle_socket_attachment: Marker3D

@export_category("Replaceable Attachment Sockets")
@export var stock_socket: Marker3D
@export var grip_socket: Marker3D
@export var magazine_socket: Marker3D

@export_category("Mesh Components")
@export var builtin_iron_sight_mesh: Array[MeshInstance3D]

@export_category("Default Base Mesh (Replaceable)")
@export var default_stock_mesh: MeshInstance3D
@export var default_grip_mesh: MeshInstance3D
@export var default_magazine_mesh: MeshInstance3D

@export_category("Attachment Fitting (per weapon)")
## Where the eye lines up when aiming with the built-in iron sights.
## Put a Marker3D at the rear sight; optics are aligned relative to it.
@export var iron_sight_point: Marker3D
## Per-weapon tweaks for individual attachments. Leave empty if the socket
## placement already looks right - this is only for exceptions.
@export var attachment_fits: Array[AttachmentFit] = []

@export_category("UI Components")
@export var ammo_display: Node3D

# slot -> spawned attachment instance (so we can find sight points etc.)
var _instances: Dictionary = {}


func set_ammo_display_visible(is_visible: bool) -> void:
	if ammo_display != null:
		ammo_display.visible = is_visible


func update_ammo_display(current_ammo: int, reserved_ammo: int, reload_time: float) -> void:
	if ammo_display == null:
		return
	var ammo_ui: AmmoUI = ammo_display.get_node_or_null("GUI/SubViewport/Control") as AmmoUI
	if ammo_ui != null:
		ammo_ui.set_ammo_values(current_ammo, reserved_ammo, reload_time)


#region Attachment queries
func get_socket_for_slot(slot: Attachment.AttachmentSlot) -> Node3D:
	match slot:
		Attachment.AttachmentSlot.OPTIC: return optic_socket
		Attachment.AttachmentSlot.UNDERBARREL: return underbarrel_socket
		Attachment.AttachmentSlot.MUZZLE: return muzzle_socket_attachment
		Attachment.AttachmentSlot.STOCK: return stock_socket
		Attachment.AttachmentSlot.GRIP: return grip_socket
		Attachment.AttachmentSlot.MAGAZINE: return magazine_socket
	return null


func get_fit(att: Attachment) -> AttachmentFit:
	for fit: AttachmentFit in attachment_fits:
		if fit != null and fit.attachment == att:
			return fit
	return null


## A weapon accepts an attachment when it has a socket for the slot and the fit
## (if any) doesn't forbid it.
func can_accept(att: Attachment) -> bool:
	if att == null or get_socket_for_slot(att.attachment_slot) == null:
		return false
	var fit := get_fit(att)
	return fit == null or not fit.incompatible


func get_attachment_instance(slot: Attachment.AttachmentSlot) -> Node3D:
	var inst: Node3D = _instances.get(slot) as Node3D
	return inst if is_instance_valid(inst) else null


## Eye-alignment point of whatever is in `slot`, in THIS model's local space.
## Returns false in `found` when the attachment has no sight point.
func get_sight_point_local(att: Attachment) -> Dictionary:
	var inst := get_attachment_instance(att.attachment_slot)
	if inst == null:
		return {}
	var marker := inst.find_child(String(att.sight_point_name), true, false) as Node3D
	if marker == null:
		return {}
	return {"position": global_transform.affine_inverse() * marker.global_position}


func get_iron_sight_point_local() -> Dictionary:
	if iron_sight_point == null:
		return {}
	return {"position": global_transform.affine_inverse() * iron_sight_point.global_position}
#endregion


#region Attachment handling
## Single entry point: show `attachment` in its slot, or clear the slot with null.
func set_attachment(slot: Attachment.AttachmentSlot, attachment: Attachment) -> void:
	var socket := get_socket_for_slot(slot)
	if socket == null:
		push_warning("%s has no socket for slot %s." % [name, str(slot)])
		return

	_clear_socket(socket)
	_instances.erase(slot)

	# Built-in meshes that the attachment replaces / hides.
	match slot:
		Attachment.AttachmentSlot.OPTIC:
			for mesh in builtin_iron_sight_mesh:
				mesh.visible = attachment == null
		Attachment.AttachmentSlot.STOCK:
			_set_visible(default_stock_mesh, attachment == null)
		Attachment.AttachmentSlot.GRIP:
			_set_visible(default_grip_mesh, attachment == null)
		Attachment.AttachmentSlot.MAGAZINE:
			_set_visible(default_magazine_mesh, attachment == null)

	if attachment == null:
		return

	var instance := _spawn_attachment_instance(socket, attachment)
	if instance:
		_instances[slot] = instance


# Kept so any other script that still calls the old API keeps working.
func apply_additive_attachment(slot: Attachment.AttachmentSlot, attachment: Attachment) -> void:
	set_attachment(slot, attachment)


func apply_replaceable_attachment(slot: Attachment.AttachmentSlot, attachment: Attachment) -> void:
	set_attachment(slot, attachment)


func _set_visible(node: Node3D, value: bool) -> void:
	if node:
		node.visible = value


func _clear_socket(socket: Node3D) -> void:
	# remove_child first so the old node can't clash with the new one's name
	# or be found by find_child() while it waits to be freed.
	for child in socket.get_children():
		socket.remove_child(child)
		child.queue_free()


func _spawn_attachment_instance(socket: Node3D, attachment: Attachment) -> Node3D:
	if attachment.attachment_model == null:
		push_warning("Attachment model is not assigned for %s." % attachment.attachment_name)
		return null

	var instance := attachment.attachment_model.instantiate() as Node3D
	if instance == null:
		push_warning("Attachment model root must be Node3D for %s." % attachment.attachment_name)
		return null
	socket.add_child(instance)
	instance.name = attachment.attachment_name

	# final local transform = per-weapon fit  *  attachment default
	var default_xf := Transform3D(Basis.from_euler(attachment.model_rotation), attachment.model_position)
	var fit_xf := Transform3D.IDENTITY
	var fit_scale := Vector3.ONE
	var fit := get_fit(attachment)
	if fit != null:
		fit_xf = Transform3D(Basis.from_euler(fit.rotation_offset), fit.position_offset)
		fit_scale = fit.scale_multiplier
	var xf := fit_xf * default_xf
	instance.position = xf.origin
	instance.rotation = xf.basis.get_euler()

	# Skeleton sockets can have their own import scale. Compensate for it so
	# attachment scale remains relative to the weapon model scale.
	var socket_scale := socket.global_transform.basis.get_scale()
	var weapon_scale := global_transform.basis.get_scale()
	instance.scale = Vector3(
		_safe_scale_ratio(weapon_scale.x, socket_scale.x) * attachment.model_scale.x * fit_scale.x,
		_safe_scale_ratio(weapon_scale.y, socket_scale.y) * attachment.model_scale.y * fit_scale.y,
		_safe_scale_ratio(weapon_scale.z, socket_scale.z) * attachment.model_scale.z * fit_scale.z
	)
	return instance


func _safe_scale_ratio(numerator: float, denominator: float) -> float:
	if is_zero_approx(denominator):
		return numerator
	return numerator / denominator
#endregion
