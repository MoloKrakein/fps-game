class_name NormalEnemy
extends BaseEnemy
## Zombie-style enemy. All AI (perception, squad movement, shooting, traversal, death flow) lives
## in BaseEnemy; this script only adds the AnimationTree, active-ragdoll hit reactions and the
## death ragdoll.

@export_group("Animation")
@export var animation_player: AnimationPlayer
@export var anim_tree: AnimationTree
@export var ledge_raycast: RayCast3D
## Optional AnimationTree state for the legs while staggering (falls back to Idle).
@export var stagger_anim_state: StringName = &""

@export_group("Ragdoll")
@export var ragdoll_skeleton: PhysicalBoneSimulator3D
@export var stumble_bone: PhysicalBone3D
@export var collision_shape: CollisionShape3D
## Child node that runs the stagger / fall. One is created at runtime if this is left empty.
@export var active_ragdoll_controller: ActiveRagdollStumbleController

@export_group("Stumble")
@export var stumble_state: StateChartState
## Minimum raw damage that triggers any hit reaction.
@export var stumble_threshold: float = 35.0
## Raw damage that gives the strongest reaction (a full fall).
@export var stumble_heavy_threshold: float = 80.0
## Velocity change in m/s (not an impulse).
@export var stumble_force: float = 8.0
## Seconds of stumble immunity after recovering, so the enemy can't be stun-locked.
@export var stumble_cooldown: float = 1.5
## A headshot reacts at least this strongly (0..1), even if the damage alone would not.
@export var headshot_stumble_intensity: float = 0.45
## Added to the reaction when a leg is hit, so shot legs buckle.
@export var leg_hit_intensity_bonus: float = 0.35

var anim_tree_state: AnimationNodeStateMachinePlayback
var is_stumbling: bool = false
var pending_stumble_direction: Vector3 = Vector3.ZERO
var pending_stumble_intensity: float = 0.0
var pending_stumble_hit_position: Vector3 = Vector3.INF
var stumble_cooldown_left: float = 0.0


#region Lifecycle

func _ready() -> void:
	super._ready()
	anim_tree_state = anim_tree["parameters/playback"]
	_setup_active_ragdoll()
	if stumble_state:
		stumble_state.state_entered.connect(_on_stumble_state_entered)


func _physics_process(delta: float) -> void:
	stumble_cooldown_left = maxf(stumble_cooldown_left - delta, 0.0)
	super(delta)


func _setup_active_ragdoll() -> void:
	if active_ragdoll_controller == null:
		if ragdoll_skeleton == null:
			push_warning("NormalEnemy: no ragdoll_skeleton set, hit reactions are disabled.")
			return
		active_ragdoll_controller = ActiveRagdollStumbleController.new()
		active_ragdoll_controller.name = &"ActiveRagdollStumbleController"
		active_ragdoll_controller.actor = self
		active_ragdoll_controller.ragdoll_skeleton = ragdoll_skeleton
		active_ragdoll_controller.stumble_bone = stumble_bone
		active_ragdoll_controller.anim_tree = anim_tree
		active_ragdoll_controller.collision_shape = collision_shape
		add_child(active_ragdoll_controller)
	active_ragdoll_controller.recovered.connect(_on_stumble_recovered)

#endregion


#region BaseEnemy hooks

func is_incapacitated() -> bool:
	return super.is_incapacitated() or is_stumbling


func _on_idle(_delta: float) -> void:
	if anim_tree_state and anim_tree_state.get_current_node() != "Idle":
		anim_tree_state.travel("Idle")


func _on_combat_state(_delta: float) -> void:
	if anim_tree_state and anim_tree_state.get_current_node() != "Follow":
		anim_tree_state.travel("Follow")


func _update_animation() -> void:
	update_blends()


func update_blends() -> void:
	var move_amount: float = remap(velocity.length(), 0.0, follow_speed, 0.0, 1.0)
	anim_tree["parameters/Follow/IdleRunBlend/blend_position"] = move_amount


func _on_death_started() -> void:
	is_stumbling = false
	if active_ragdoll_controller:
		active_ragdoll_controller.cancel_for_death()


func _disable_root_collision() -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", true)


func _on_death_ragdoll() -> void:
	# Stop the AnimationTree from forcing poses, then let every bone take over.
	if anim_tree:
		anim_tree.active = false
	if ragdoll_skeleton:
		ragdoll_skeleton.influence = 1.0
		ragdoll_skeleton.active = true
		ragdoll_skeleton.physical_bones_start_simulation()

#endregion


#region Stumble / active ragdoll

func _on_damage_received(info: DamageInfo, applied_damage: float) -> void:
	super(info, applied_damage) # alert + remember where the shot came from
	if is_dead or active_ragdoll_controller == null or health_component.current_health <= 0.0:
		return
	if info.raw_damage < stumble_threshold:
		return

	var intensity: float = clampf(
		inverse_lerp(stumble_threshold, maxf(stumble_heavy_threshold, stumble_threshold + 0.01), info.raw_damage),
		0.0, 1.0
	)
	if info.is_headshot:
		intensity = maxf(intensity, headshot_stumble_intensity)
	if info.get_meta(&"hit_leg", false):
		intensity = clampf(intensity + leg_hit_intensity_bonus, 0.0, 1.0)
	var direction: Vector3 = _get_stumble_direction(info)
	var hit_position: Vector3 = _get_hit_position(info)

	# Already reeling: feed the hit straight into the ragdoll (it may escalate to a full fall).
	if is_stumbling:
		active_ragdoll_controller.add_hit(direction, stumble_force, intensity, hit_position)
		return

	if stumble_cooldown_left > 0.0:
		return

	pending_stumble_direction = direction
	pending_stumble_intensity = intensity
	pending_stumble_hit_position = hit_position
	state_chart.send_event("toStumble")


func _get_hit_position(info: DamageInfo) -> Vector3:
	# EnemyHitbox fills impact_position with the exact point the bullet landed on.
	if info.impact_position != Vector3.ZERO:
		return info.impact_position
	return Vector3.INF


func _get_stumble_direction(info: DamageInfo) -> Vector3:
	var impact_direction: Vector3 = info.impact_direction
	if info.attacker is Node3D:
		var attacker: Node3D = info.attacker as Node3D
		var direction_from_attacker: Vector3 = global_position - attacker.global_position
		if direction_from_attacker.length_squared() > 0.001:
			impact_direction = direction_from_attacker
	impact_direction.y = 0.0
	if impact_direction.length_squared() <= 0.001:
		return -global_transform.basis.z # model faces +Z, so fall back to "backwards"
	return impact_direction.normalized()


func _on_stumble_state_entered() -> void:
	if is_dead or is_stumbling or not active_ragdoll_controller:
		return

	if not active_ragdoll_controller.can_begin():
		state_chart.send_event("toFollow")
		return

	is_stumbling = true
	_cancel_vault()
	reset_navigation()
	_play_stagger_legs()
	active_ragdoll_controller.begin(
		pending_stumble_direction,
		stumble_force,
		pending_stumble_intensity,
		pending_stumble_hit_position
	)


func _play_stagger_legs() -> void:
	if not anim_tree_state:
		return
	var state_name: StringName = &"Idle"
	var machine: AnimationNodeStateMachine = anim_tree.tree_root as AnimationNodeStateMachine
	if stagger_anim_state != &"" and machine and machine.has_node(stagger_anim_state):
		state_name = stagger_anim_state
	if anim_tree_state.get_current_node() != state_name:
		anim_tree_state.travel(state_name)


func _on_stumble_recovered() -> void:
	if is_dead:
		return

	is_stumbling = false
	stumble_cooldown_left = stumble_cooldown
	# If we were mid-air/vaulting when hit, traversal_state would otherwise stay stuck and
	# the follow state would early-out forever.
	traversal_state = TraversalState.GROUND
	order.clear()
	reset_navigation()
	state_chart.send_event("toFollow")

#endregion
