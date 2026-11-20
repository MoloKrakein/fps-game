class_name WeaponSoundProfile
extends Resource
## Every sound one weapon makes. Assign it to Weapon.sound_profile.
## Mechanical sounds (bolt, magazine, rack) get added here later as more SoundEventDef slots.

@export_group("Firing")
## The close "bang". Give it several takes and a little pitch / volume jitter.
@export var fire: SoundEventDef
## Optional second layer played with the shot: the tail / echo. Lets the bang stay punchy.
@export var fire_tail: SoundEventDef
## Click when the trigger is pulled on an empty weapon.
@export var dry_fire: SoundEventDef
