class_name WeaponModel extends Node3D

@export_category("Socket")
@export var muzzle_socket: Node3D
@export var ejection_socket: Node3D

@export_category("Attachment Sockets (Additive)")
@export var optic_socket: Marker3D
@export var underbarrel_socket: Marker3D
@export var muzzle_socket_attachment: Marker3D
@export var underbarrel_socket_attachment: Marker3D

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

# @export_category("Attachment Models")
# # Optic have array of models because some optics have multiple models (like a scope with a lens cover)
# @export var optic_model: Array[MeshInstance3D]
# @export var underbarrel_model: MeshInstance3D
# @export var magazine_model: MeshInstance3D
# @export var stock_model: MeshInstance3D
# @export var grip_model: MeshInstance3D

@export_category("UI Components")
@export var ammo_display: AmmoUI


func update_ammo_display(current_ammo: int, reserved_ammo: int, reload_time: float) -> void:
    if ammo_display:
        ammo_display.set_ammo_values(current_ammo, reserved_ammo, reload_time)

# Attachment Handling

func apply_additive_attachment(slot: Attachment.AttachmentSlot, attachment: Attachment) -> void:
    var socket: Node3D = null

    match slot:
        Attachment.AttachmentSlot.OPTIC:
            socket = optic_socket
            if builtin_iron_sight_mesh != null:
                for mesh in builtin_iron_sight_mesh:
                    mesh.visible = attachment == null

        Attachment.AttachmentSlot.UNDERBARREL:
            socket = underbarrel_socket
        Attachment.AttachmentSlot.MUZZLE:
            socket = muzzle_socket_attachment
        _:
            push_warning("Attachment slot not supported for additive attachment: %s" % str(slot))
            return

    if socket != null:
        for child in socket.get_children():
            child.queue_free()

        if attachment:
            _spawn_attachment_instance(socket, attachment)

func apply_replaceable_attachment(slot: Attachment.AttachmentSlot, attachment: Attachment) -> void:
    match slot:
        Attachment.AttachmentSlot.STOCK:
            if default_stock_mesh:
                default_stock_mesh.visible = (attachment == null)
            _spawn_replacement_mesh(stock_socket, attachment, "Custom Stock")
        Attachment.AttachmentSlot.GRIP:
            if default_grip_mesh:
                default_grip_mesh.visible = (attachment == null)
            _spawn_replacement_mesh(grip_socket, attachment, "Custom Grip")
        Attachment.AttachmentSlot.MAGAZINE:
            if default_magazine_mesh:
                default_magazine_mesh.visible = (attachment == null)
            _spawn_replacement_mesh(magazine_socket, attachment, "Custom Magazine")

func _spawn_replacement_mesh(parent_node: Node3D, attachment: Attachment, group_name: String) -> void:
    if parent_node == null:
        push_warning("Attachment socket is not assigned for %s." % group_name)
        return

    for child in parent_node.get_children():
        child.queue_free()

    if attachment:
        var instance := _spawn_attachment_instance(parent_node, attachment)
        if instance:
            instance.name = group_name

func _spawn_attachment_instance(socket: Node3D, attachment: Attachment) -> Node3D:
    if attachment.attachment_model == null:
        push_warning("Attachment model is not assigned for %s." % attachment.attachment_name)
        return null

    var instance := attachment.attachment_model.instantiate() as Node3D
    if instance == null:
        push_warning("Attachment model root must be Node3D for %s." % attachment.attachment_name)
        return null
    socket.add_child(instance)

    instance.position = attachment.model_position
    instance.rotation = attachment.model_rotation

    # Skeleton sockets can have their own import scale. Compensate for it so
    # attachment scale remains relative to the weapon model scale.
    var socket_scale := socket.global_transform.basis.get_scale()
    var weapon_scale := global_transform.basis.get_scale()
    instance.scale = Vector3(
        _safe_scale_ratio(weapon_scale.x, socket_scale.x) * attachment.model_scale.x,
        _safe_scale_ratio(weapon_scale.y, socket_scale.y) * attachment.model_scale.y,
        _safe_scale_ratio(weapon_scale.z, socket_scale.z) * attachment.model_scale.z
    )
    return instance

func _safe_scale_ratio(numerator: float, denominator: float) -> float:
    if is_zero_approx(denominator):
        return numerator
    return numerator / denominator
