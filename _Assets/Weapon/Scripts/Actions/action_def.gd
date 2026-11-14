class_name ActionDef extends Resource
## Everything one weapon action needs, in ONE resource: which clip plays, how it
## fades, and the events inside it. Lives in WeaponAnimation.actions, so it is stored
## per weapon scene and survives re-importing the Blender file.
##
## The AnimationTree never contains per-action nodes or clip names. WeaponAnimation
## writes the clip and the fades into the single ActionLayer right before an action plays.
##
## Action ids used by the code: &"rack", &"empty_reload", &"loaded_reload", &"equip".
## An action with no ActionDef uses make_default(), so weapons can be migrated one at a time.

@export var id: StringName = &""

@export_group("Visual")
## Which clip plays: one of ClipResolver.ROLE_*. Leave empty to use the default for this id.
## If the weapon has no clip for the role yet, the visual is skipped and gameplay still runs.
@export var clip_role: StringName = &""
## The clip is blended with the rest pose during its FIRST `fade_in` seconds and its LAST
## `fade_out` seconds. A part that is teleported inside those windows (a magazine swap,
## a bone that jumps) is blended too, so you see it slide for a few frames instead of
## popping. For clips that teleport parts near the start or end, set both to 0.
@export_range(0.0, 1.0, 0.01, "suffix:s") var fade_in: float = 0.1
@export_range(0.0, 1.0, 0.01, "suffix:s") var fade_out: float = 0.15

@export_group("Events")
## Moments inside the action as 0..1 fractions (see ActionEvent).
@export var events: Array[ActionEvent] = []


const _DEFAULTS: Dictionary = {
	&"rack": {
		"role": ClipResolver.ROLE_RACK, "fade_in": 0.05, "fade_out": 0.1,
		"events": {&"pull": 0.0, &"peak": 0.45, &"release": 0.55, &"closed": 1.0},
	},
	&"empty_reload": {
		"role": ClipResolver.ROLE_RELOAD_EMPTY, "fade_in": 0.1, "fade_out": 0.15,
		"events": {},
	},
	&"loaded_reload": {
		"role": ClipResolver.ROLE_RELOAD_LOADED, "fade_in": 0.1, "fade_out": 0.15,
		"events": {},
	},
	&"equip": {
		"role": ClipResolver.ROLE_EQUIP, "fade_in": 0.0, "fade_out": 0.12,
		"events": {},
	},
}


## The clip role to play: the explicit one, or the default for this id.
func get_clip_role() -> StringName:
	if clip_role != &"":
		return clip_role
	var spec: Dictionary = _DEFAULTS.get(id, {})
	return StringName(spec.get("role", &""))


static func make_default(action_id: StringName) -> ActionDef:
	var def: ActionDef = ActionDef.new()
	def.id = action_id

	var spec: Dictionary = _DEFAULTS.get(action_id, {})
	if spec.is_empty():
		return def

	def.clip_role = StringName(spec["role"])
	def.fade_in = float(spec["fade_in"])
	def.fade_out = float(spec["fade_out"])

	var fractions: Dictionary = spec["events"]
	for key: StringName in fractions:
		var ev: ActionEvent = ActionEvent.new()
		ev.event_name = key
		ev.fraction = float(fractions[key])
		def.events.append(ev)
	return def