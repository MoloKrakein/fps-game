class_name WeaponData extends Resource

@export var weapon:Weapon
@export var is_unlocked:bool = false

@export var ammo_in_magazine:int = 0
@export var reserve_ammo:int = 0
@export var is_loaded:bool = false
## Pump / bolt-action weapons: the fired case is still in the chamber (is_loaded is false)
## until the player racks. Stored here so it survives weapon switching.
@export var chamber_spent:bool = false
## Open-bolt weapons: the bolt is cocked open and the gun can fire. Racking sets it, and the last
## round clears it. Ignored by closed-bolt weapons and by profiles set to ALWAYS_READY.
@export var bolt_open:bool = true
@export var fire_mode:Weapon.WeaponFireMode = Weapon.WeaponFireMode.SEMI_AUTO

@export var equipped_attachment_data:Dictionary[Attachment.AttachmentSlot, Attachment] = {
    
}