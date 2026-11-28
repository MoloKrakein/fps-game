class_name ViewmodelClipFix extends Node
## Keeps the first-person weapon (and everything attached to it) drawn in front of level geometry.
##
## The weapon is a normal 3D object under the camera, so it is depth-tested against the level.
## BaseMaterial3D has a built-in fix: "Z Clip Scale" squeezes an object's depth range towards the
## camera. Spatial shaders have the same thing as the built-in `Z_CLIP_SCALE` (Godot 4.5+).
## Only depth changes, so shape, lighting, shadows and view-space maths stay the same.
##
## IMPORTANT: every piece of the viewmodel must use the SAME value. A squashed part always wins the
## depth test against an un-squashed part, so a half-patched weapon hides its own scope lens, red
## dot glass, muzzle flash and smear. This script therefore patches:
##   - MeshInstance3D surfaces, material_override and material_overlay
##   - GPUParticles3D (material_override, or the draw pass material)
##   - StandardMaterial3D / ORMMaterial3D: use_z_clip_scale + z_clip_scale
##   - ShaderMaterial: sets the shader's `z_clip_scale` uniform, IF the shader has one
##     (see shader_patches.md: add one line to each custom viewmodel shader)
## Every patched material is a per-mesh COPY, shared resources (world pickups, casings) stay as is.
##
## Setup: add this as a Node anywhere under the player (for example under "Component").
## Keep WeaponWallTuck: this is only visual, it does not stop you shooting through a wall.

@export var enabled: bool = true
## Smaller = closer to the camera. Start at 0.1. Lower it if the weapon still clips a wall,
## raise it if parts of the weapon start to flicker against each other.
@export_range(0.005, 1.0, 0.005) var z_clip_scale: float = 0.1
## Optional: render the weapon with its own FOV (StandardMaterial3D only). Leave OFF if your
## sight alignment / ADS zoom relies on the camera FOV.
@export var use_fov_override: bool = false
@export_range(30.0, 120.0, 1.0) var fov_override: float = 75.0
## How often the weapon is re-checked for materials that were assigned late (muzzle VFX, smear...).
@export var rescan_interval: float = 0.5
## Prints a warning for custom shaders that have no `z_clip_scale` uniform (once per shader).
@export var debug: bool = false

const _META := &"_viewmodel_clip_patched"
const _UNIFORM := &"z_clip_scale"

var _root: Node3D
var _timer: float = 0.0
var _uniform_cache: Dictionary = {}   # Shader -> bool
var _warned: Dictionary = {}          # Shader -> true


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.weapon_controller == null:
		push_warning("ViewmodelClipFix: could not find the player / weapon controller.")
		return
	# The weapon models live under the weapon camera.
	_root = player.weapon_controller.camera
	if _root == null:
		push_warning("ViewmodelClipFix: weapon controller has no camera.")
		return
	get_tree().node_added.connect(_on_node_added)
	_scan()


func _process(delta: float) -> void:
	if not enabled or _root == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = rescan_interval
		_scan()


func _scan() -> void:
	for node: Node in _root.find_children("*", "GeometryInstance3D", true, false):
		_patch_geometry(node)


func _on_node_added(node: Node) -> void:
	if not enabled or _root == null or not (node is GeometryInstance3D):
		return
	if _root.is_ancestor_of(node):
		# Wait until the node's own _ready (and any VFX setup) has run.
		_patch_geometry.call_deferred(node)


func _patch_geometry(node: Node) -> void:
	var geometry := node as GeometryInstance3D
	if geometry == null or not is_instance_valid(geometry):
		return
	if geometry.material_override != null:
		geometry.material_override = _patch_material(geometry.material_override)
	if geometry.material_overlay != null:
		geometry.material_overlay = _patch_material(geometry.material_overlay)

	if geometry is MeshInstance3D:
		_patch_surfaces(geometry as MeshInstance3D)
	elif geometry is GPUParticles3D:
		_patch_particles(geometry as GPUParticles3D)


func _patch_surfaces(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface in range(mesh.get_surface_count()):
		var current: Material = mesh_instance.get_surface_override_material(surface)
		if current != null and current.has_meta(_META):
			continue
		var source: Material = current if current != null else mesh.surface_get_material(surface)
		if source == null:
			continue
		var patched := _patch_material(source)
		if patched != source:
			mesh_instance.set_surface_override_material(surface, patched)


## Particles draw their quad with the draw pass material. Put a patched copy on material_override.
func _patch_particles(particles: GPUParticles3D) -> void:
	if particles.material_override != null:
		return   # already handled by _patch_geometry
	for index in range(particles.draw_passes):
		var mesh := particles.get_draw_pass_mesh(index)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var source := mesh.surface_get_material(0)
		if source == null:
			continue
		var patched := _patch_material(source)
		if patched != source:
			particles.material_override = patched
		return


## Returns a patched COPY of the material (the original resource is left alone), or the same
## material if it is already patched or cannot be patched.
func _patch_material(source: Material) -> Material:
	if source.has_meta(_META):
		return source

	if source is BaseMaterial3D:
		var copy := source.duplicate() as BaseMaterial3D
		copy.use_z_clip_scale = true
		copy.z_clip_scale = z_clip_scale
		if use_fov_override:
			copy.use_fov_override = true
			copy.fov_override = fov_override
		if copy.next_pass != null:
			copy.next_pass = _patch_material(copy.next_pass)
		copy.set_meta(_META, true)
		return copy

	if source is ShaderMaterial:
		var shader_material := source as ShaderMaterial
		if shader_material.shader != null and _has_z_clip_uniform(shader_material.shader):
			var copy := shader_material.duplicate() as ShaderMaterial
			copy.set_shader_parameter(_UNIFORM, z_clip_scale)
			if copy.next_pass != null:
				copy.next_pass = _patch_material(copy.next_pass)
			copy.set_meta(_META, true)
			return copy
		if debug and shader_material.shader != null and not _warned.has(shader_material.shader):
			_warned[shader_material.shader] = true
			push_warning("ViewmodelClipFix: shader '%s' has no 'z_clip_scale' uniform, so it " \
					% shader_material.shader.resource_path \
					+ "will be hidden behind the squashed weapon. See shader_patches.md.")
	return source


func _has_z_clip_uniform(shader: Shader) -> bool:
	if _uniform_cache.has(shader):
		return _uniform_cache[shader]
	var found := false
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if StringName(uniform.get("name", "")) == _UNIFORM:
			found = true
			break
	_uniform_cache[shader] = found
	return found