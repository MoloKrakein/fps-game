class_name WeaponData extends Resource

@export var weapon:Weapon
@export var is_unlocked:bool = false

@export var ammo_in_magazine:int = 0
@export var reserve_ammo:int = 0
@export var is_loaded:bool = false
@export var fire_mode:Weapon.WeaponFireMode = Weapon.WeaponFireMode.SEMI_AUTO

@export var equipped_attachment_data:Dictionary[Attachment.AttachmentSlot, Attachment] = {
    
}
