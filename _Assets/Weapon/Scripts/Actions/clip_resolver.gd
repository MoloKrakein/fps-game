class_name ClipResolver extends RefCounted
## Finds animation clips and skeleton bones by ROLE instead of by exact name,
## so different animators can name things differently.
##
## Matching ignores case, spaces, "_", "-" and prefixes/suffixes. "Pistol_ReloadDry_01",
## "reload-dry" and "RELOADDRY" all normalize to something containing "reloaddry".
## For each role the tokens are tried in order. Among the clips that contain a token
## (and none of the banned words) the SHORTEST name wins, i.e. the closest to the token.
##
## To support a new naming habit, add a token to RULES below. That is the only place.

const ROLE_IDLE: StringName = &"idle"
const ROLE_RELOAD_LOADED: StringName = &"reload_loaded"
const ROLE_RELOAD_EMPTY: StringName = &"reload_empty"
const ROLE_RACK: StringName = &"rack"
const ROLE_EQUIP: StringName = &"equip"
const ROLE_SLIDE_OPEN: StringName = &"slide_open"
const ROLE_SLIDE_CLOSED: StringName = &"slide_closed"

## Roles every weapon is expected to provide. ROLE_IDLE is not listed: the OneShot action
## layer plays over the rest pose, so no idle clip is needed (the rule stays for weapons
## that still use a state-machine tree).
const ALL_ROLES: Array[StringName] = [
	ROLE_RELOAD_LOADED, ROLE_RELOAD_EMPTY, ROLE_RACK,
	ROLE_EQUIP, ROLE_SLIDE_OPEN, ROLE_SLIDE_CLOSED,
]

## Roles the code-driven slide cannot work without.
const CRITICAL_ROLES: Array[StringName] = [ROLE_SLIDE_OPEN, ROLE_SLIDE_CLOSED]

## role -> { "tokens": [...in priority order...], "banned": [...] }
const RULES: Dictionary = {
	&"idle": {
		"tokens": ["idle", "normalpose", "default", "neutral"],
		"banned": [],
	},
	&"reload_loaded": {
		"tokens": ["reloadloaded", "reloadtactical", "tacticalreload", "tacreload", "reloadfull", "reloadmag", "magchange", "reload"],
		"banned": ["empty", "dry"],
	},
	&"reload_empty": {
		"tokens": ["reloadempty", "emptyreload", "reloaddry", "dryreload", "reloadfromempty", "reloadlocked"],
		"banned": [],
	},
	&"rack": {
		"tokens": ["rack", "charge", "chamber", "pullslide", "cock"],
		"banned": ["reload", "unrack"],
	},
	&"equip": {
		"tokens": ["equip", "draw", "pullout", "deploy", "ready"],
		"banned": ["unequip", "holster"],
	},
	&"slide_open": {
		"tokens": ["openbolt", "boltopen", "slideopen", "openslide", "lockback", "slidelock", "slideback", "boltback"],
		"banned": [],
	},
	&"slide_closed": {
		"tokens": ["closebolt", "closedbolt", "boltclose", "boltclosed", "slideclose", "closeslide", "slideclosed", "closedslide", "slideforward", "boltforward", "slidereturn", "boltreturn"],
		"banned": [],
	},
}

## Bone name tokens that identify the slide / bolt bone(s).
const SLIDE_BONE_TOKENS: Array[String] = ["slider", "slide", "bolt", "carrier"]


## lowercase, letters and digits only
static func normalize(text: String) -> String:
	var out: String = ""
	for ch: String in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## Returns the clip name for `role`, or "" when nothing matches.
## `explicit` (set in WeaponClipMap) wins over auto-detection; if it names a clip that
## does not exist the result is "" so the problem is reported, not silently ignored.
static func resolve_clip(role: StringName, clip_names: PackedStringArray, explicit: String = "") -> String:
	if explicit != "":
		return explicit if clip_names.has(explicit) else ""

	var rule: Dictionary = RULES.get(role, {})
	if rule.is_empty():
		return ""
	var tokens: Array = rule["tokens"]
	var banned: Array = rule["banned"]

	for token: String in tokens:
		var best: String = ""
		for clip: String in clip_names:
			var n: String = normalize(clip)
			if not n.contains(token):
				continue
			if _contains_any(n, banned):
				continue
			if best == "" or n.length() < normalize(best).length():
				best = clip
		if best != "":
			return best
	return ""


## Slide bone names: explicit list if given, otherwise every bone whose name contains a slide token.
static func resolve_slide_bones(bone_names: PackedStringArray, explicit: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not explicit.is_empty():
		for bone: String in explicit:
			if bone_names.has(bone):
				found.append(bone)
		return found

	for bone: String in bone_names:
		if _contains_any(normalize(bone), SLIDE_BONE_TOKENS):
			found.append(bone)
	return found


static func _contains_any(text: String, words: Array) -> bool:
	for w: String in words:
		if text.contains(w):
			return true
	return false