class_name Attachment extends Resource

enum AttachmentSlot {
    OPTIC,
    MUZZLE,
    UNDERBARREL,
    MAGAZINE,
    STOCK,
    GRIP
}
enum AttachmentType {
    ADDITIVE,
    REPLACEABLE
}


@export_category("Attachment Stats")
@export var attachment_name: String = "Attachment"
@export var attachment_slot: AttachmentSlot = AttachmentSlot.OPTIC
@export var attachment_model: PackedScene
@export var attachment_type: AttachmentType = AttachmentType.ADDITIVE
@export_group("Others Settings")
@export var attachment_icon: Texture2D
@export var model_position: Vector3 = Vector3.ZERO
@export var model_rotation: Vector3 = Vector3.ZERO
@export var model_scale: Vector3 = Vector3.ONE

@export_category("Attachment Stats Modifiers")
@export var accuracy_bonus: float = 0.0             #Flat bonus / penalty to accuracy
@export var recoil_multiplier: float = 1.0          #Multiplier to recoil values (1.0 = no change, <1.0 = less recoil, >1.0 = more recoil)
@export var damage_bonus: float = 0.0               #Flat bonus / penalty to damage
@export var reload_time_multiplier: float = 1.0          #Multiplier to reload time (1.0 = no change, <1.0 = faster reload, >1.0 = slower reload)
@export var ammo_capacity_bonus: int = 0                #Flat bonus / penalty to ammo capacity

@export_category("Attachment Overrides")
@export var is_optic: bool = false
@export var override_ads_position: Vector3 = Vector3.ZERO
@export var override_ads_rotation: Vector3 = Vector3.ZERO
@export var override_ads_fov: float = 0.0