class_name WeaponAnimation extends Node
## Thin wrapper around the weapon AnimationTree.
## Game timing lives in WeaponActions. This node:
##   - finds the weapon's clips and bones by ROLE (see ClipResolver), so animators can
##     name them differently
##   - plays any action through ONE OneShot layer: right before an action starts it writes
##     the action's clip and fades into the tree, then fires the OneShot
##   - sets the action playback speed (ActionSpeed TimeScale)
##   - writes the slide blend value (BoltPosition), driven by SlideDriver
##
## The tree stays 7 nodes however many actions or naming styles exist:
##   CloseBolt, OpenBolt -> BoltPosition -> ActionLayer (OneShot) -> output
##   ActionClip -> ActionSpeed -> ActionLayer (shot)

## Node names inside the AnimationTree (part of the scene contract).
const NODE_CLOSE_BOLT: StringName = &"CloseBolt"
const NODE_OPEN_BOLT: StringName = &"OpenBolt"
const NODE_ACTION_CLIP: StringName = &"ActionClip"
const NODE_ACTION_LAYER: StringName = &"ActionLayer"

@export var weapon_animation_tree: AnimationTree
@export var animation_player: AnimationPlayer

@export_category("Naming")
## Optional overrides. Leave empty to auto-detect every clip and bone by role.
@export var clip_map: WeaponClipMap

@export_category("Actions")
## Per-weapon action settings: clip role, fades and events (see ActionDef).
@export var actions: Array[ActionDef] = []

@export_category("Tree parameters")
## BoltPosition Blend2: 0 = closed pose, 1 = open pose.
@export var slide_blend_param: String = "parameters/BoltPosition/blend_amount"
## ActionLayer OneShot request.
@export var action_request_param: String = "parameters/ActionLayer/request"
## TimeScale node on the action clip. Scales the playing clip.
@export var action_speed_param: String = "parameters/ActionSpeed/scale"

## role -> resolved clip name ("" = not found)
var _clips: Dictionary = {}
var _warned_roles: Dictionary = {}


func _ready() -> void:
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")
		return
	weapon_animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	resolve_names()


func _process(delta: float) -> void:
	if weapon_animation_tree != null:
		weapon_animation_tree.advance(PlayerTime.real(delta))


#region Name resolution (animator-friendly naming)
## Finds every clip and the slide bone(s) by role. Runs on spawn; call it again after
## changing clip_map in code.
func resolve_names() -> void:
	_clips.clear()

	var available: PackedStringArray = PackedStringArray()
	if animation_player != null:
		available = animation_player.get_animation_list()

	var lines: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var critical_missing: PackedStringArray = PackedStringArray()
	for role: StringName in ClipResolver.ALL_ROLES:
		var explicit: String = clip_map.get_explicit(role) if clip_map != null else ""
		var clip: String = ClipResolver.resolve_clip(role, available, explicit)
		_clips[role] = clip

		if clip == "":
			missing.append(String(role))
			if ClipResolver.CRITICAL_ROLES.has(role):
				critical_missing.append(String(role))
			var why: String = ""
			if explicit != "":
				why = " (clip_map name '%s' does not exist)" % explicit
			lines.append("  %s -> not found yet%s" % [String(role).rpad(14), why])
		else:
			lines.append("  %s -> \"%s\" (%s)" % [String(role).rpad(14), clip, "clip_map" if explicit != "" else "auto"])

	_apply_slide_clips()
	var slide_bones: PackedStringArray = _apply_action_filter()
	if slide_bones.is_empty():
		lines.append("  slide bones    -> NOT FOUND")
	else:
		var explicit_bones: bool = clip_map != null and not clip_map.slide_bones.is_empty()
		lines.append("  slide bones    -> %s (%s)" % [", ".join(slide_bones), "clip_map" if explicit_bones else "auto"])

	_report(lines, critical_missing, slide_bones.is_empty(), available)


func get_clip(role: StringName) -> String:
	return _clips.get(role, "")


func get_clip_length(role: StringName) -> float:
	var clip: String = get_clip(role)
	if clip == "" or animation_player == null or not animation_player.has_animation(clip):
		return 0.0
	return animation_player.get_animation(clip).length


func _apply_slide_clips() -> void:
	var blend_tree: AnimationNodeBlendTree = weapon_animation_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null:
		return
	_set_node_clip(blend_tree, NODE_CLOSE_BOLT, ClipResolver.ROLE_SLIDE_CLOSED)
	_set_node_clip(blend_tree, NODE_OPEN_BOLT, ClipResolver.ROLE_SLIDE_OPEN)


func _set_node_clip(blend_tree: AnimationNodeBlendTree, node_name: StringName, role: StringName) -> void:
	var clip: String = _clips.get(role, "")
	if clip == "" or not blend_tree.has_node(node_name):
		return
	var anim_node: AnimationNodeAnimation = blend_tree.get_node(node_name) as AnimationNodeAnimation
	if anim_node != null and anim_node.animation != StringName(clip):
		anim_node.animation = StringName(clip)


## The ActionLayer applies every bone EXCEPT the slide bone(s), so the animators' body
## bone names do not matter and an action clip can never fight the code-driven slide.
## Returns the slide bones that were found.
func _apply_action_filter() -> PackedStringArray:
	var skeleton: Skeleton3D = _find_skeleton()
	if skeleton == null:
		push_warning("WeaponAnimation: no Skeleton3D found under the AnimationTree root node.")
		return PackedStringArray()

	var bones: PackedStringArray = PackedStringArray()
	for i: int in skeleton.get_bone_count():
		bones.append(skeleton.get_bone_name(i))

	var explicit: PackedStringArray = clip_map.slide_bones if clip_map != null else PackedStringArray()
	var slide_bones: PackedStringArray = ClipResolver.resolve_slide_bones(bones, explicit)
	if slide_bones.is_empty():
		return slide_bones # keep the filter authored in the scene

	var layer: AnimationNodeOneShot = _action_layer()
	var root: Node = weapon_animation_tree.get_node_or_null(weapon_animation_tree.root_node)
	if layer == null or root == null:
		return slide_bones

	var skeleton_path: String = String(root.get_path_to(skeleton))
	var filters: Array = []
	for bone: String in bones:
		if not slide_bones.has(bone):
			filters.append("%s:%s" % [skeleton_path, bone])
	layer.set("filters", filters)
	layer.filter_enabled = true
	return slide_bones


func _find_skeleton() -> Skeleton3D:
	var root: Node = weapon_animation_tree.get_node_or_null(weapon_animation_tree.root_node)
	if root == null:
		return null
	var found: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	return found[0] as Skeleton3D


func _report(lines: PackedStringArray, critical_missing: PackedStringArray, no_slide_bone: bool, available: PackedStringArray) -> void:
	var owner_name: String = String(get_parent().name) if get_parent() != null else String(name)
	if OS.is_debug_build():
		print("[WeaponAnimation] name mapping for ", owner_name, "\n", "\n".join(lines))
	# Unfinished action clips are expected while animations are work in progress: they only
	# print. Missing slide clips or bones break the code-driven slide, so those warn.
	if not critical_missing.is_empty() or no_slide_bone:
		push_warning("WeaponAnimation (%s): slide setup incomplete. Missing: %s%s. Clips in this model: %s" % [
			owner_name, ", ".join(critical_missing), " + slide bone" if no_slide_bone else "", ", ".join(available)])
#endregion


#region Actions (reload / rack / equip)
## Plays an action's clip through the ActionLayer. Returns false when the weapon has no
## clip for that role yet: the visual is skipped, gameplay timing is unaffected.
## `speed` scales the clip (1.0 = authored speed).
func play_action(def: ActionDef, speed: float = 1.0) -> bool:
	if weapon_animation_tree == null or def == null:
		return false

	var role: StringName = def.get_clip_role()
	var clip: String = get_clip(role)
	if clip == "":
		_note_missing_role(role)
		return false

	var blend_tree: AnimationNodeBlendTree = weapon_animation_tree.tree_root as AnimationNodeBlendTree
	var layer: AnimationNodeOneShot = _action_layer()
	if blend_tree == null or layer == null or not blend_tree.has_node(NODE_ACTION_CLIP):
		push_warning("WeaponAnimation: the tree has no ActionClip / ActionLayer nodes.")
		return false

	var clip_node: AnimationNodeAnimation = blend_tree.get_node(NODE_ACTION_CLIP) as AnimationNodeAnimation
	if clip_node == null:
		return false

	clip_node.animation = StringName(clip)
	layer.fadein_time = def.fade_in
	layer.fadeout_time = def.fade_out
	set_action_speed(speed)
	weapon_animation_tree.set(action_request_param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


## Fade the action out (if its clip is still playing) and reset the playback speed.
func end_action() -> void:
	if weapon_animation_tree == null:
		return
	set_action_speed(1.0)
	weapon_animation_tree.set(action_request_param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func set_action_speed(speed: float) -> void:
	if weapon_animation_tree == null:
		return
	if weapon_animation_tree.get(action_speed_param) == null:
		return # tree has no ActionSpeed node
	weapon_animation_tree.set(action_speed_param, clampf(speed, 0.05, 100.0))


func get_action_def(id: StringName) -> ActionDef:
	for def: ActionDef in actions:
		if def != null and def.id == id:
			return def
	return null


func _action_layer() -> AnimationNodeOneShot:
	var blend_tree: AnimationNodeBlendTree = weapon_animation_tree.tree_root as AnimationNodeBlendTree
	if blend_tree == null or not blend_tree.has_node(NODE_ACTION_LAYER):
		return null
	return blend_tree.get_node(NODE_ACTION_LAYER) as AnimationNodeOneShot


func _note_missing_role(role: StringName) -> void:
	if _warned_roles.has(role):
		return
	_warned_roles[role] = true
	print("[WeaponAnimation] no clip for role '", role, "' yet: its visual is skipped (gameplay timing still runs).")
#endregion


#region Code-driven slide
## Written every frame by SlideDriver. 0 = closed, 1 = open.
func set_slide_value(value: float) -> void:
	if weapon_animation_tree == null:
		return
	weapon_animation_tree.set(slide_blend_param, value)


## Deprecated: instant pose change. The animated slide now comes from SlideDriver.
func set_bolt_position(is_open: bool) -> void:
	set_slide_value(1.0 if is_open else 0.0)
#endregion


#region Compatibility wrappers (old callers keep working)
func play_animation(animation_name: String) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot play animation.")
		return

	match animation_name.to_lower():
		"fire":
			pass # legacy: the slide kick is code-driven now
		"reload":
			play_action(_def_or_default(&"loaded_reload"))
		"rack":
			play_action(_def_or_default(&"rack"))
		"equip":
			play_action(_def_or_default(&"equip"))
		"idle":
			end_action()
		"empty":
			set_bolt_position(true)
		"loaded":
			set_bolt_position(false)
		_:
			print("Animation name not recognized: ", animation_name)


func reload_weapon_animation(reload_type: String = "empty_reload") -> void:
	var id: StringName = &"empty_reload" if reload_type.to_lower().contains("empty") else &"loaded_reload"
	play_action(_def_or_default(id))


func set_trigger_pressed(is_pressed: bool) -> void:
	if not weapon_animation_tree:
		print("AnimationTree is not assigned. Cannot set trigger state.")
		return
	var target: float = 1.0 if is_pressed else 0.0
	weapon_animation_tree.set("parameters/TriggerBlend/blend_amount", target)


## Length of a clip. Accepts the old action strings ("empty_reload", "loaded_reload",
## "Rack", "Equip") or a literal clip name.
func get_animation_length(animation_name: String) -> float:
	var role: StringName = &""
	match animation_name.to_lower():
		"empty_reload":
			role = ClipResolver.ROLE_RELOAD_EMPTY
		"loaded_reload", "reload":
			role = ClipResolver.ROLE_RELOAD_LOADED
		"rack":
			role = ClipResolver.ROLE_RACK
		"equip":
			role = ClipResolver.ROLE_EQUIP

	if role != &"":
		return get_clip_length(role)

	if animation_player != null and animation_player.has_animation(animation_name):
		return animation_player.get_animation(animation_name).length
	return 0.0


func _def_or_default(id: StringName) -> ActionDef:
	var def: ActionDef = get_action_def(id)
	return def if def != null else ActionDef.make_default(id)
#endregion