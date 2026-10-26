class_name Attachment extends Resource
## A weapon-agnostic attachment definition.
##
## Rule of thumb: this resource only knows about ITSELF (model, stats, where its
## own sight point is). Anything that depends on WHICH weapon it is mounted on
## (position tweaks, ADS fine-tuning, "not allowed here") lives in an
## AttachmentFit on that weapon's WeaponModel, never in here.

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
## DEFAULT offset from the weapon's socket. Keep this "neutral" (usually zero):
## position the socket on each weapon model instead, and use AttachmentFit for
## per-weapon exceptions.
@export var model_position: Vector3 = Vector3.ZERO
@export var model_rotation: Vector3 = Vector3.ZERO
@export var model_scale: Vector3 = Vector3.ONE

@export_category("Attachment Stats Modifiers")
@export var accuracy_bonus: float = 0.0             # Flat bonus / penalty to accuracy
@export var recoil_multiplier: float = 1.0          # 1.0 = no change, <1.0 = less recoil, >1.0 = more recoil
@export var damage_bonus: float = 0.0               # Flat bonus / penalty to damage
@export var reload_time_multiplier: float = 1.0     # 1.0 = no change, <1.0 = faster reload, >1.0 = slower reload
@export var ammo_capacity_bonus: int = 0            # Flat bonus / penalty to ammo capacity

@export_category("Optic / ADS")
@export var is_optic: bool = false
## Name of a Marker3D inside the attachment scene marking where the eye lines up
## (rear of the scope / centre of the red-dot window). With it, ADS alignment is
## computed automatically on ANY weapon - no per-weapon ADS numbers needed.
@export var sight_point_name: StringName = &"SightPoint"
## 0 = keep the weapon's own ADS FOV.
@export var override_ads_fov: float = 0.0

@export_group("Legacy ADS (fallback only)")
## Old absolute overrides. Only used when the attachment scene has no SightPoint
## marker. These are weapon-specific by nature, so migrate away from them.
@export var override_ads_position: Vector3 = Vector3.ZERO
@export var override_ads_rotation: Vector3 = Vector3.ZERO


## Stat helpers so the maths lives in exactly one place.
static func sum_float(list: Array[Attachment], getter: StringName) -> float:
	var total := 0.0
	for att in list:
		total += att.get(getter)
	return total


static func product_float(list: Array[Attachment], getter: StringName) -> float:
	var total := 1.0
	for att in list:
		total *= att.get(getter)
	return total
