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

func apply_additive_attachment(slot: Attachment.AttachmentSlot, att_scene: PackedScene) -> void:
    var socket: Node3D = null

    match slot:
        Attachment.AttachmentSlot.OPTIC:
            socket = optic_socket
            if builtin_iron_sight_mesh != null:
                for mesh in builtin_iron_sight_mesh:
                    mesh.visible = false

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

        # spawn new attachment model
        if att_scene:
            var instance = att_scene.instantiate()
            socket.add_child(instance)
            instance.position = Vector3.ZERO
            instance.rotation = Vector3.ZERO

func apply_replaceable_attachment(slot: Attachment.AttachmentSlot, att_scene: PackedScene) -> void:
    match slot:
        Attachment.AttachmentSlot.STOCK:
            if default_stock_mesh:
                default_stock_mesh.visible = (att_scene == null)
            _spawn_replacement_mesh(stock_socket, att_scene, "Custom Stock")
        Attachment.AttachmentSlot.GRIP:
            if default_grip_mesh:
                default_grip_mesh.visible = (att_scene == null)
            _spawn_replacement_mesh(grip_socket, att_scene, "Custom Grip")
        Attachment.AttachmentSlot.MAGAZINE:
            if default_magazine_mesh:
                default_magazine_mesh.visible = (att_scene == null)
            _spawn_replacement_mesh(magazine_socket, att_scene, "Custom Magazine")

func _spawn_replacement_mesh(parent_node: Node3D, att_scene: PackedScene, group_name: String) -> void:
    for child in parent_node.get_children():
        child.queue_free()

    if att_scene:
        var instance = att_scene.instantiate()
        parent_node.add_child(instance)
        instance.name = group_name
        instance.position = Vector3.ZERO
        instance.rotation = Vector3.ZERO
