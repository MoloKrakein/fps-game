class_name WeaponShooter extends RefCounted
## Everything that happens when a shot leaves the barrel: hitscan rays,
## projectiles, pellet spread, impact effects, damage and ejected casings.

const IMPACT_DECAL = preload("res://Scenes/debug/impact_node.tscn") # Replace with your actual path!
const IMPACT_LIFETIME: float = 0.5
var ctrl: WeaponController
var _casing_tube: CasingTube = CasingTube.new()


func _init(controller: WeaponController) -> void:
	ctrl = controller


#region Firing
func fire_hitscan() -> void:
	var weapon: Weapon = ctrl.current_weapon
	var muzzle: Node3D = ctrl.shoot_position
	if weapon == null or muzzle == null:
		return

	var space_state: PhysicsDirectSpaceState3D = muzzle.get_world_3d().direct_space_state
	var muzzle_basis: Basis = muzzle.global_transform.basis
	var from: Vector3 = muzzle.global_transform.origin + ctrl.shoot_position_offset
	var forward: Vector3 = -muzzle_basis.z
	var accuracy_spread: float = get_effective_spread()

	for i in range(weapon.pellet_count):
		var acc_x: float = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y: float = randf_range(-accuracy_spread, accuracy_spread)
		var direction: Vector3 = (forward + Vector3(acc_x, acc_y, 0)).normalized()
		var damage: float = weapon.get_calculated_damage()

		if weapon.pellet_count > 1:
			direction += _pellet_spread(muzzle_basis)
			damage = _damage_per_pellet()

		var to: Vector3 = from + direction * weapon.shoot_range
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			_spawn_impact_effect(result.position)
			_apply_damage_to_target(result.collider, damage)


func fire_projectile() -> void:
	var weapon: Weapon = ctrl.current_weapon
	var muzzle: Node3D = ctrl.shoot_position
	if weapon == null or muzzle == null:
		return

	var muzzle_basis: Basis = muzzle.global_transform.basis
	var forward: Vector3 = -muzzle_basis.z
	var accuracy_spread: float = (100.0 - weapon.accuracy) / 1000.0

	# TODO(check): this compounds into accuracy_modifier on every projectile shot,
	# and while dynamic_accuracy_spread is 0 it sets accuracy_modifier to 0 until
	# the next aim_hipfire()/aim_ads(). Hitscan weapons read it via get_effective_spread().
	ctrl.accuracy_modifier = ctrl.stance_accuracy_modifier * ctrl.accuracy_modifier * ctrl.dynamic_accuracy_spread * weapon.aim_accuracy_modifier

	for i in range(weapon.pellet_count):
		var projectile: Projectile = weapon.projectile_scene.instantiate() as Projectile
		ctrl.get_tree().current_scene.add_child(projectile)
		projectile.global_position = muzzle.global_position + ctrl.shoot_position_offset

		var pellet_forward: Vector3 = forward
		var damage: float = weapon.get_calculated_damage()

		if weapon.pellet_count > 1:
			pellet_forward += _pellet_spread(muzzle_basis)
			damage = _damage_per_pellet()

		var acc_x: float = randf_range(-accuracy_spread, accuracy_spread)
		var acc_y: float = randf_range(-accuracy_spread, accuracy_spread)
		var direction: Vector3 = pellet_forward + Vector3(acc_x, acc_y, 0) * muzzle_basis
		var projectile_velocity: Vector3 = direction * weapon.get_muzzle_velocity_mps()

		projectile.look_at(projectile.global_position + direction, Vector3.UP)
		projectile.setup(
			projectile_velocity,
			damage,
			ctrl.player,
			weapon.ammo_type == Weapon.WeaponAmmoType.EXPLOSIVE,
			weapon.explosion_radius,
			weapon.explosion_damage,
			weapon.explosion_falloff,
			weapon.explosion_force,
			weapon.armor_penetration
		)


## Extra random offset for multi-pellet weapons (shotguns).
func _pellet_spread(muzzle_basis: Basis) -> Vector3:
	var angle: float = ctrl.current_weapon.spread_angle
	var spread_x: float = randf_range(-angle, angle)
	var spread_y: float = randf_range(-angle, angle)
	return Vector3(spread_x, spread_y, 0) * muzzle_basis


func _damage_per_pellet() -> float:
	var weapon: Weapon = ctrl.current_weapon
	return (weapon.get_calculated_damage() / weapon.pellet_count) * 10
#endregion


#region Accuracy
func get_effective_spread() -> float:
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null:
		return 0.0

	# 1. Base spread from weapon (and attachments)
	var base_spread: float = (100.0 - weapon.get_calculated_accuracy()) / 1000.0

	# 2. Movement penalty
	var move_penalty: float = 1.0
	var player: PlayerController = ctrl.player
	if player != null:
		var speed: float = player.velocity.length()
		if not player.is_on_floor():
			move_penalty = 3.5 # In-air jump penalty
		elif speed > 5.0:
			move_penalty = 2.0 # Sprint penalty
		elif speed > 0.5:
			move_penalty = 1.3 # Walking penalty
	if ctrl.is_aiming:
		move_penalty *= 0.5 # Aiming reduces movement penalty

	# 3. Combine base, stance, skills, movement, and bloom
	var total_spread: float = (base_spread * ctrl.stance_accuracy_modifier * ctrl.accuracy_modifier * move_penalty) + ctrl.dynamic_accuracy_spread
	return maxf(0.0, total_spread * ctrl.spread_multiplier)
#endregion


#region Impact & damage
func _spawn_impact_effect(hit_position: Vector3) -> void:
	if IMPACT_DECAL:
		var marker: Node3D = IMPACT_DECAL.instantiate()
		ctrl.get_tree().current_scene.add_child(marker)
		marker.global_transform.origin = hit_position

		# Not a true object pool (it still frees the node), but far cheaper than building meshes per hit.
		ctrl.get_tree().create_timer(IMPACT_LIFETIME).timeout.connect(marker.queue_free)


func _apply_damage_to_target(target: Node3D, damage: float) -> void:
	if target == null or damage <= 0:
		return

	var health_component = target.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage, ctrl.owner)
#endregion


#region Casings
## casing_type: "empty" = spent casing, "alive" = unfired round (used when racking the slide).
func eject_casing(casing_type: String = "empty") -> void:
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null or ctrl.casing_position == null:
		return

	var profile: CasingEjectionProfile = weapon.casing_profile
	var count: int = 1
	if casing_type == "empty":
		count = _casing_tube.add_shot(profile)

	for index: int in range(count):
		_spawn_casing(weapon, casing_type, profile, index)


func flush_casing_tube() -> void:
	var weapon: Weapon = ctrl.current_weapon
	if weapon == null or ctrl.casing_position == null:
		_casing_tube.reset()
		return

	var count: int = _casing_tube.flush()
	for index: int in range(count):
		_spawn_casing(weapon, "empty", weapon.casing_profile, index)


func _spawn_casing(weapon: Weapon, casing_type: String,
		profile: CasingEjectionProfile, index: int) -> void:
	var casing_scene: PackedScene = null
	match casing_type:
		"empty":
			casing_scene = weapon.bullet_case_scene
		"alive":
			casing_scene = weapon.alive_bullet_scene

	if casing_scene == null:
		return

	var casing: BulletCasing = casing_scene.instantiate() as BulletCasing
	ctrl.get_tree().current_scene.add_child(casing)
	casing.global_transform = ctrl.casing_position.global_transform
	casing.scale = weapon.bullet_case_scale

	if profile != null:
		var inherited_velocity: Vector3 = Vector3.ZERO
		if ctrl.player != null:
			inherited_velocity = ctrl.player.velocity
		casing.eject_with_profile(ctrl.casing_position, profile, inherited_velocity, index)
		return

	# Read the basis AFTER scaling, as before.
	var right_dir: Vector3 = casing.global_transform.basis.x
	var up_dir: Vector3 = casing.global_transform.basis.y
	var forward_dir: Vector3 = -casing.global_transform.basis.z

	var eject_dir: Vector3 = (
		right_dir * randf_range(0.8, 1.2) +
		up_dir * randf_range(0.3, 0.6) +
		forward_dir * randf_range(-0.2, 0.2)
	).normalized()

	var linear_velocity: Vector3 = eject_dir * randf_range(2.0, 4.0) * 5.0
	if ctrl.player:
		linear_velocity += ctrl.player.velocity * 0.5

	var torque: Vector3 = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * randf_range(0.5, 1.5) * 10.0

	casing.eject(linear_velocity, torque)


#endregion
