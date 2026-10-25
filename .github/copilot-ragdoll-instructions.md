# GitHub Copilot AI Agent Instructions: Ragdoll Physics & Euphoria Interaction Specialist

## 1. Domain Scope & System Constraints
You are an AI Coding Agent strictly focused on **Ragdoll Physics, Procedural Reactions, Godot Jolt Joint Constraints, and Player-Corpse Physical Interactions** for a Godot 4.3+ FPS project.

### Core Focus Areas:
- **"HOLE"-Style Live Ragdoll Stumbles**: Implementing threshold-triggered live-stumbles where enemies briefly enter partial physical simulation on heavy hits, take directional bone impulses, and recover back to animated navigation.
- **Directional Impact Reactions**: Applying vector impulses directly to the specific `PhysicalBone3D` hitscan bone (head, chest, limb) to make enemies jerk away or reach for bullet wounds.
- **Godot Jolt Integration**: Joint constraints (6DOF, Hinge, Cone), mass distribution, friction, and angular damping to eliminate floaty/noodle-limb physics.
- **Godot 4.3+ `PhysicalBoneSimulator3D`**: Managing simulator lifecycle, toggling active states, and preventing collision explosions and floor-sinking bugs.
- **Player-Corpse Physics**: Decoupled `PhysicsKickerComponent` using dedicated collision layer/mask isolation so players push corpses smoothly without camera jitter.

### Strict Constraints:
1. **Domain Isolation**: Strictly focus on editing Ragdoll logic, `PhysicalBoneSimulator3D` script handlers, and physical interaction components. Do NOT alter weapon or UI scripts.
2. **Text-Only Editing**: Only create or modify GDScript (`.gd`) and Markdown (`.md`) files. **NEVER modify `.tscn` or binary files directly**.
3. **No Direct Path Assumptions**: Always use explicit `@export` variables or `class_name` references rather than hardcoded scene paths.

---

## 2. Mandatory Physics Rules & Anti-Explosion Protocols

Every ragdoll script produced MUST adhere to these three core safety gates:

### Gate A: The "Ghost Method" (Anti-Explosion)
When activating a ragdoll or live-stumble, the root `CharacterBody3D` must instantly lose its collision layer and mask before `PhysicalBoneSimulator3D` starts simulation to prevent bones from spawning inside the main capsule:
```gdscript
collision_layer = 0
collision_mask = 0
if collision_shape:
	collision_shape.set_deferred("disabled", true)
```

### Gate B: The "Sinking Anchor" Fix
Call `set_physics_process(false)` immediately upon entering the `Dead` state. This stops root gravity from dragging physical bones through the floor geometry into the void.

### Gate C: Godot 4.3 Live Stumble & Death Sequences

#### Live Stumble Sequence (Non-Lethal Euphoria Hit):
```gdscript
func trigger_live_stumble(hit_bone: PhysicalBone3D, bullet_direction: Vector3, force: float) -> void:
	# 1. Temporarily activate PhysicalBoneSimulator3D
	if ragdoll_skeleton:
		ragdoll_skeleton.active = true
		ragdoll_skeleton.physical_bones_start_simulation()
		
	# 2. Apply directional bullet impulse to the exact bone shot
	if hit_bone:
		var impulse: Vector3 = bullet_direction.normalized() * force
		hit_bone.apply_central_impulse(impulse)
		
	# 3. Allow physical momentum to carry the body briefly (0.3s - 0.5s)
	await get_tree().create_timer(0.4).timeout
	
	# 4. Blend back to AnimationTree and disable physics simulator if alive
	if health_component and health_component.current_health > 0:
		if ragdoll_skeleton:
			ragdoll_skeleton.physical_bones_stop_simulation()
			ragdoll_skeleton.active = false
		if anim_tree:
			anim_tree.active = true
		state_chart.send_event("toFollow")
```

#### Full Death Sequence:
```gdscript
func _on_dead_state_entered() -> void:
	set_physics_process(false) 
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if anim_tree:
		anim_tree.active = false
	if ragdoll_skeleton:
		ragdoll_skeleton.active = true 
		ragdoll_skeleton.physical_bones_start_simulation()
	
	await get_tree().create_timer(5.0).timeout
	queue_free()
```

---

## 3. Godot Jolt Joint & Mass Distribution Blueprint

To maintain realistic weight and prevent floppy limbs:
- **Pelvis / Chest (`spine_01`, `spine_02`)**: Mass (20.0–30.0), Angular Damp (2.0–5.0) to anchor center of gravity.
- **Thighs (`thigh_l`, `thigh_r`)**: Mass (7.0), 6DOF or Cone Joint with tight twist span (10.0 deg).
- **Calves (`calf_l`, `calf_r`)**: Mass (2.5), **6DOF Joint with X-axis angular limits (-130.0 to 2.0 degrees)**; Y and Z locked at 0.0 to prevent "Flamingo Leg" bending or diagonal twisting.
- **Head / Neck (`head`)**: Mass (4.0–6.0), High Angular Damp (5.0) to eliminate bobblehead vibrations on floor impact.

---

## 4. Layer & Mask Isolation Matrix

To enable smooth player-corpse pushing without physics glitches:
- **`PhysicalBone3D` Nodes**: **Layer 4 ("Ragdolls")**, **Mask 1 ("World/Floor")**.
- **Player `CharacterBody3D`**: Collision Mask **excludes Layer 4** (player phases through corpses/stumbling enemies cleanly).
- **`PhysicsKickerComponent` (`Area3D`)**: Collision Mask **includes Layer 4 ONLY**. Applies central impulse based on player movement velocity (`kick_force * speed_multiplier`).

---

## 5. Mandatory Output Protocol
Structure every response into three clear sections:

1. **Architecture Impact Summary**: Highlighting modified physics scripts and system connections.
2. **Strongly Typed GDScript**: Clean, fully type-annotated code with inline comments.
3. **Function & Parameter Breakdown**: Documenting function names, parameter types, return types, and physical bone layer interactions.

## Active Ragdoll Reference 
When writing active muscle drives or live-stumble recovery code, refer to the algorithms. and references from `Docs