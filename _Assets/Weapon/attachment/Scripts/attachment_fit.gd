class_name AttachmentFit extends Resource
## Per-weapon adjustment for ONE attachment. Add these to
## WeaponModel.attachment_fits on the weapon's scene - the Attachment resource
## itself is never touched, so it stays correct on every other weapon.

@export var attachment: Attachment
## Set true to forbid this attachment on this weapon.
@export var incompatible: bool = false

@export_group("Model Adjustment (relative to socket + attachment default)")
@export var position_offset: Vector3 = Vector3.ZERO
## Radians (same as Attachment.model_rotation).
@export var rotation_offset: Vector3 = Vector3.ZERO
@export var scale_multiplier: Vector3 = Vector3.ONE

@export_group("ADS")
## Fine-tune after the automatic sight alignment (weapon-model parent space,
## same space the debug ADS tuner edits).
@export var ads_offset: Vector3 = Vector3.ZERO
