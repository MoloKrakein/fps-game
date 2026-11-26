class_name WeaponClipMap extends Resource
## OPTIONAL per-weapon overrides for clip and bone names.
## Every field left empty is auto-detected by ClipResolver, so most weapons need no
## map at all. Use one only when auto-detect picks the wrong clip, or reports a
## clip as missing, for example when an animator used an unusual name.
##
## One map can be shared by every weapon from the same animator.

@export_group("Clip names (empty = auto-detect)")
@export var idle: String = ""
@export var reload_loaded: String = ""
@export var reload_empty: String = ""
## Optional. Empty = auto-detect, and a weapon with no quick reload clip uses its empty reload.
@export var reload_quick: String = ""
## Optional two-step rack clips for charging-handle guns. Empty = auto-detect, and without them the rack clip is used.
@export var rack_hold: String = ""
@export var rack_release: String = ""
@export var rack: String = ""
@export var equip: String = ""
@export var slide_open: String = ""
@export var slide_closed: String = ""

@export_group("Skeleton (empty = auto-detect)")
## Bone(s) moved by the code-driven slide. Everything else on the skeleton is
## treated as "body" and comes from the action clips.
@export var slide_bones: PackedStringArray = PackedStringArray()
## The weapon body / root bone(s): the ones that carry the whole weapon. Only used to scale the
## body's motion while reloading in aim down sights (see WeaponActionProfile). Empty = auto-detect
## (a bone named body / root / receiver / frame, otherwise the skeleton's root bone).
@export var body_bones: PackedStringArray = PackedStringArray()


func get_explicit(role: StringName) -> String:
	match role:
		ClipResolver.ROLE_IDLE:
			return idle
		ClipResolver.ROLE_RELOAD_LOADED:
			return reload_loaded
		ClipResolver.ROLE_RELOAD_EMPTY:
			return reload_empty
		ClipResolver.ROLE_RELOAD_QUICK:
			return reload_quick
		ClipResolver.ROLE_RACK_HOLD:
			return rack_hold
		ClipResolver.ROLE_RACK_RELEASE:
			return rack_release
		ClipResolver.ROLE_RACK:
			return rack
		ClipResolver.ROLE_EQUIP:
			return equip
		ClipResolver.ROLE_SLIDE_OPEN:
			return slide_open
		ClipResolver.ROLE_SLIDE_CLOSED:
			return slide_closed
	return ""