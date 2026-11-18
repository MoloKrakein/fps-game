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
##
## USED AS A COMPONENT: instance weapon_animation_rig.tscn under the weapon model root and
## name it "WeaponAnimation". With auto_wire on (default) it finds the model's
## AnimationPlayer and skeleton itself and gives the weapon its own copy of the tree.
## The only per-weapon data is `actions` and, optionally, `clip_map`.

## Node names inside the AnimationTree (part of the scene contract).
const NODE_CLOSE_BOLT: StringName = &"CloseBolt"
const NODE_OPEN_BOLT: StringName = &"OpenBolt"
const NODE_ACTION_CLIP: StringName = &"ActionClip"
const NODE_ACTION_LAYER: StringName = &"ActionLayer"

@export_category("Wiring")
## On: find the model's AnimationPlayer and point the tree at it (no paths to set).
## Off: use the tree / player assigned in the scene, as a hand-wired weapon does.
@export var auto_wire: bool = true
## Found automatically as the "AnimationTree" child when empty.
@export var weapon_animation_tree: AnimationTree
## Found automatically under the model root when empty.
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
## True while the ActionLayer shot is playing or fading out.
@export var action_active_param: String = "parameters/ActionLayer/active"

@export_category("Body motion and physics")
## How fast the ADS body scaling eases in and out.
@export_range(0.0, 1.0, 0.01, "suffix:s") var body_damping_blend_time: float = 0.12
## Influence of spring bone physics (a SpringBoneSimulator3D under the skeleton) while an action
## plays. 1 = unchanged. Lower it to calm jiggle during reloads.
@export_range(0.0, 1.0, 0.01) var action_physics_influence: float = 1.0

## role -> resolved clip name ("" = not found)
var _clips: Dictionary = {}
var _warned_roles: Dictionary = {}
var _skeleton: Skeleton3D
var _body_bones: PackedStringArray = PackedStringArray()
var _body_bone_idx: PackedInt32Array = PackedInt32Array()
var _damp_pos: float = 1.0         # body movement kept while scaling is fully on (1 = no change)
var _damp_rot: float = 1.0         # body rotation kept
var _damp_requested: bool = false  # the current action asked for body scaling
var _damp_blend: float = 0.0       # 0 = clip as authored, 1 = fully scaled
var _physics_nodes: Array[SkeletonModifier3D] = []
var _physics_blend: float = 1.0
var _part_cache: Dictionary = {}     # part name -> Node3D (or null)
var _part_original: Dictionary = {}  # Node3D -> visibility before the action changed it
var _warned_parts: Dictionary = {}


func _ready() -> void:
	if auto_wire:
		_auto_wire()
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")
		return
	if auto_wire:
		_make_tree_unique()
	weapon_animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	resolve_names()


func _process(delta: float) -> void:
	if weapon_animation_tree == null:
		return
	var dt: float = PlayerTime.real(delta)
	weapon_animation_tree.advance(dt)

	# advance() has just written the animated pose into the skeleton, so what follows adjusts
	# that pose before it is drawn.
	var active: bool = bool(weapon_animation_tree.get(action_active_param))
	_update_body_scaling(dt, active)
	_update_physics_influence(dt, active)


#region Component wiring
## Finds the AnimationTree child and the model's AnimationPlayer, and points the tree at them.
func _auto_wire() -> void:
	if weapon_animation_tree == null:
		weapon_animation_tree = find_child("AnimationTree", false, false) as AnimationTree
	if weapon_animation_tree == null:
		push_warning("WeaponAnimation: no AnimationTree child found. Instance weapon_animation_rig.tscn.")
		return

	if animation_player == null:
		animation_player = _find_animation_player()
	if animation_player == null:
		push_warning("WeaponAnimation: no AnimationPlayer found under the weapon model.")
		return

	# Track paths are relative to the player's root node, so the tree must use the same one.
	var anim_root: Node = animation_player.get_node_or_null(animation_player.root_node)
	if anim_root != null:
		weapon_animation_tree.root_node = weapon_animation_tree.get_path_to(anim_root)
	weapon_animation_tree.anim_player = weapon_animation_tree.get_path_to(animation_player)


## The first AnimationPlayer under the model root (the rig's parent) that has clips.
func _find_animation_player() -> AnimationPlayer:
	var model_root: Node = get_parent()
	if model_root == null:
		return null
	var first: AnimationPlayer = null
	for node: Node in model_root.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = node as AnimationPlayer
		if first == null:
			first = player
		if not player.get_animation_list().is_empty():
			return player
	return first


## Every weapon gets its own copy of the tree, so two weapons alive at once (held, dropped,
## held by an enemy) never share and overwrite each other's clip names and fades.
func _make_tree_unique() -> void:
	var original: AnimationRootNode = weapon_animation_tree.tree_root
	if original == null:
		return
	var copy: AnimationRootNode = original.duplicate(true) as AnimationRootNode
	if copy == null:
		return
	weapon_animation_tree.tree_root = copy

	# Sanity check: the nodes we write to at runtime must not be shared with the original.
	var a: AnimationNodeBlendTree = original as AnimationNodeBlendTree
	var b: AnimationNodeBlendTree = copy as AnimationNodeBlendTree
	if a != null and b != null and a.has_node(NODE_ACTION_LAYER) and b.has_node(NODE_ACTION_LAYER):
		if a.get_node(NODE_ACTION_LAYER) == b.get_node(NODE_ACTION_LAYER):
			push_warning("WeaponAnimation: the tree copy still shares nodes with the original. Two weapons alive at once may overwrite each other's clips.")
#endregion


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
	var roles: Array[StringName] = []
	roles.append_array(ClipResolver.ALL_ROLES)
	roles.append_array(ClipResolver.OPTIONAL_ROLES)
	for role: StringName in roles:
		var explicit: String = clip_map.get_explicit(role) if clip_map != null else ""
		var clip: String = ClipResolver.resolve_clip(role, available, explicit)
		_clips[role] = clip

		if clip == "" and ClipResolver.OPTIONAL_ROLES.has(role):
			lines.append("  %s -> uses the %s clip" % [String(role).rpad(14), ClipResolver.ROLE_FALLBACKS.get(role, "")])
		elif clip == "":
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

	if _body_bones.is_empty():
		lines.append("  body bones     -> none found (ADS reload pinning unavailable)")
	else:
		var explicit_body: bool = clip_map != null and not clip_map.body_bones.is_empty()
		lines.append("  body bones     -> %s (%s)" % [", ".join(_body_bones), "clip_map" if explicit_body else "auto"])
	if not _physics_nodes.is_empty():
		lines.append("  physics        -> %d spring bone simulator(s) under the skeleton" % _physics_nodes.size())

	_report(lines, critical_missing, slide_bones.is_empty(), available)


## The clip for a role. A role with no clip of its own uses its fallback (quick reload -> empty reload).
func get_clip(role: StringName) -> String:
	var clip: String = _clips.get(role, "")
	if clip == "" and ClipResolver.ROLE_FALLBACKS.has(role):
		return get_clip(ClipResolver.ROLE_FALLBACKS[role])
	return clip


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
	var layer: AnimationNodeOneShot = _action_layer()
	if slide_bones.is_empty():
		# No slide bone to protect: let the actions drive every bone so they still show.
		if layer != null:
			layer.filter_enabled = false
		return slide_bones

	var root: Node = weapon_animation_tree.get_node_or_null(weapon_animation_tree.root_node)
	if layer == null or root == null:
		return slide_bones

	var skeleton_path: String = String(root.get_path_to(skeleton))
	var filters: Array = []
	for bone: String in bones:
		if not slide_bones.has(bone):
			filters.append("%s:%s" % [skeleton_path, bone])

	# The weapon body / root bone(s), remembered so their motion can be scaled during an ADS reload.
	var root_bones: PackedStringArray = PackedStringArray()
	for i: int in skeleton.get_bone_count():
		if skeleton.get_bone_parent(i) == -1:
			root_bones.append(skeleton.get_bone_name(i))
	var explicit_body: PackedStringArray = clip_map.body_bones if clip_map != null else PackedStringArray()
	_body_bones = ClipResolver.resolve_body_bones(bones, explicit_body, slide_bones, root_bones)
	_skeleton = skeleton
	_body_bone_idx.clear()
	for bone: String in _body_bones:
		var idx: int = skeleton.find_bone(bone)
		if idx >= 0:
			_body_bone_idx.append(idx)

	# Spring bone physics under the skeleton, so it can be calmed while an action plays.
	_physics_nodes.clear()
	for node: Node in skeleton.find_children("*", "SkeletonModifier3D", true, false):
		if node.get_class() == "SpringBoneSimulator3D":
			_physics_nodes.append(node as SkeletonModifier3D)
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
## `body_motion` scales the clip's movement (x) and rotation (y) of the weapon body bone, for
## reloads while aiming down sights. Vector2.ONE leaves the clip as authored.
func play_action(def: ActionDef, speed: float = 1.0, body_motion: Vector2 = Vector2.ONE) -> bool:
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
	_damp_pos = body_motion.x
	_damp_rot = body_motion.y
	_damp_requested = body_motion.x < 1.0 or body_motion.y < 1.0
	set_action_speed(speed)
	weapon_animation_tree.set(action_request_param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


## Fade the action out (if its clip is still playing) and reset the playback speed.
func end_action() -> void:
	if weapon_animation_tree == null:
		return
	set_action_speed(1.0)
	weapon_animation_tree.set(action_request_param, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## Scales the clip's movement and rotation of the body bone(s) around their rest pose. The weapon
## model is already placed at the aim by the procedural stance, so scaling the body's own motion
## keeps the weapon near the aim while the other bones animate normally. Eases in and out.
func _update_body_scaling(dt: float, active: bool) -> void:
	var target: float = 1.0 if (active and _damp_requested) else 0.0
	var step: float = dt / maxf(body_damping_blend_time, 0.001)
	_damp_blend = move_toward(_damp_blend, target, step)
	if _damp_blend <= 0.0001 or _skeleton == null:
		return

	var pos_scale: float = lerpf(1.0, _damp_pos, _damp_blend)
	var rot_scale: float = lerpf(1.0, _damp_rot, _damp_blend)
	for idx: int in _body_bone_idx:
		var rest: Transform3D = _skeleton.get_bone_rest(idx)
		var rest_pos: Vector3 = rest.origin
		var rest_rot: Quaternion = rest.basis.get_rotation_quaternion()
		var pos: Vector3 = _skeleton.get_bone_pose_position(idx)
		var rot: Quaternion = _skeleton.get_bone_pose_rotation(idx)
		_skeleton.set_bone_pose_position(idx, rest_pos + (pos - rest_pos) * pos_scale)
		_skeleton.set_bone_pose_rotation(idx, rest_rot.slerp(rot, rot_scale))


## Calms spring bone physics while an action plays (action_physics_influence).
func _update_physics_influence(dt: float, active: bool) -> void:
	if _physics_nodes.is_empty():
		return
	var target: float = action_physics_influence if active else 1.0
	_physics_blend = move_toward(_physics_blend, target, dt * 6.0)
	for node: SkeletonModifier3D in _physics_nodes:
		if is_instance_valid(node):
			node.influence = _physics_blend


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


#region Part visibility
## Show / hide named nodes of the weapon model (for example a dummy magazine). The original
## visibility of every touched node is remembered and put back by restore_parts().
func set_parts_visible(show_names: PackedStringArray, hide_names: PackedStringArray) -> void:
	_set_parts(show_names, true)
	_set_parts(hide_names, false)


func restore_parts() -> void:
	for key: Variant in _part_original.keys():
		if is_instance_valid(key):
			(key as Node3D).visible = _part_original[key]
	_part_original.clear()


func _set_parts(part_names: PackedStringArray, make_visible: bool) -> void:
	for part_name: String in part_names:
		var node: Node3D = _find_part(part_name)
		if node == null:
			continue
		if not _part_original.has(node):
			_part_original[node] = node.visible
		node.visible = make_visible


func _find_part(part_name: String) -> Node3D:
	if _part_cache.has(part_name):
		return _part_cache[part_name]

	var found: Node3D = null
	var model_root: Node = get_parent()
	if model_root != null:
		found = model_root.find_child(part_name, true, false) as Node3D
	if found == null and not _warned_parts.has(part_name):
		_warned_parts[part_name] = true
		push_warning("WeaponAnimation: no part named '%s' under the weapon model (check the name in the ActionEvent)." % part_name)
	_part_cache[part_name] = found
	return found
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
		"quick_reload":
			role = ClipResolver.ROLE_RELOAD_QUICK
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
