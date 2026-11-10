# Bullet time: edits to existing scripts

New files (put them in `res://_Assets/Player/components/`):
`bullet_time.gd` (BulletTime), `player_time.gd` (PlayerTime). `player.tscn` already points at `bullet_time.gd`.

Rule of thumb: the world keeps the slowed engine delta, everything the player owns converts it back.
`PlayerTime.real(delta)` = gun, aim, camera. `PlayerTime.move(delta)` = movement.

## 1. Remove the old debug toggle
`_Assets/Weapon/Scripts/States/Aiming/weap_ads_state.gd` and `weap_canted_state.gd`:
delete the `# Toggle global slow-motion...` comment, the `var slowmo_enabled` line and the whole
`if not slowmo_enabled: Engine.time_scale = ... else: Engine.time_scale = 1.0` block.
Keep the `send_event("onCanted")` / `send_event("onADS")` line.

## 2. Player movement (`Scenes/Player/PlayerController.gd`)
First line of `_physics_process`:
```gdscript
func _physics_process(delta: float) -> void:
	delta = PlayerTime.move(delta)
```
Replace the single `move_and_slide()` call (the one after `var was_on_floor`):
```gdscript
	var move_factor: float = PlayerTime.move_factor()
	velocity *= move_factor
	move_and_slide()
	velocity /= move_factor
```
At the end of `_on_player_dead()`:
```gdscript
	var bullet_time: BulletTime = get_node_or_null("Component/BulletTime") as BulletTime
	if bullet_time != null:
		bullet_time.cancel_immediately()
```

## 3. Camera
`Scenes/Player/camera_controller.gd`, first line of `_process`:
```gdscript
	delta = PlayerTime.real(delta)
```
`_Assets/Player/cam_effects.gd`:
```gdscript
func _process(delta: float) -> void:
	calculate_view_offset(PlayerTime.real(delta))
```
and wrap the tweens so they keep real time:
`_screen_shake_tween = PlayerTime.real_tween(create_tween())`,
and in `_animate_fov` / `_change_fov`: `_fov_tween = PlayerTime.real_tween(create_tween())`.

## 4. Stance scripts (`_Assets/Player/States/`)
- `standing_state.gd`, `crouching_state.gd`: `update_camera_height(PlayerTime.real(delta), ...)`
- `prone_state.gd`, `diving_state.gd`: `cam.move_camera_to(PlayerTime.real(delta), ...)`
- `sliding_state.gd`: `_slide_timer -= PlayerTime.move(delta)` and
  `update_camera_height(PlayerTime.real(delta), -2)`

## 5. Weapon
`_Assets/Weapon/Scripts/weapon_controller.gd`:
- first line of `_process`: `delta = PlayerTime.real(delta)` (fixes fire rate, rack lockout,
  double-tap reload window and every spring in the animator at once)
- in `tween_weapon_to_position`: `aim_tween = PlayerTime.real_tween(create_tween())`

`_Assets/Weapon/Scripts/weapon_animation.gd`:
```gdscript
func _ready() -> void:
	if weapon_animation_tree == null:
		print("AnimationTree not assigned in WeaponAnimation script.")
	else:
		weapon_animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _process(delta: float) -> void:
	if weapon_animation_tree != null:
		weapon_animation_tree.advance(PlayerTime.real(delta))
```
and in `set_bolt_position`: `var bolt_tween = PlayerTime.real_tween(create_tween())`.

`_Assets/Weapon/Scripts/States/weap_reloading_state.gd`: the reload wait must be real time:
```gdscript
	await PlayerTime.real_timer(reload_time).timeout
```

Same one-line change (`delta = PlayerTime.real(delta)` as the first line of `_process` / `_physics_process`)
in the other player-owned weapon scripts: `weapon_wall_tuck.gd`, `weapon_mount.gd`, `cover_peek.gd`.

## 6. Projectiles (`_Assets/Weapon/Scripts/projectile.gd`)
Player bullets run in real time, enemy bullets stay slowed.
```gdscript
var real_time: bool = false
```
At the end of `setup(...)`:
```gdscript
	real_time = attacker != null and attacker.is_in_group("player")
	if real_time and trail_start_timer != null:
		trail_start_timer.ignore_time_scale = true
```
In `_physics_process`, replace the `end_position` line:
```gdscript
	var step: float = PlayerTime.real(delta) if real_time else delta
	var end_position = start_position + velocity * step
```
Hitscan weapons need no change.

## 7. Known follow-ups (not patched yet)
- `StateChart/Root/Stance/OnSlideEnd` has a 0.8 s delay. It runs on world time, so during bullet time it
  stretches. Check that `sliding_state.gd` ends the slide through `_slide_timer` first.
- Muzzle flash: any timer / tween there should be real time (`PlayerTime.real_timer`, `PlayerTime.real_tween`).
- `prone_dive_component.gd`: it receives the movement delta from PlayerController; check that it has no
  `_physics_process` or timers of its own.
- `grab_controller.gd`: a held prop is a slowed RigidBody, so it may lag behind the player's hand.
- Enemies: look for cooldowns using `Time.get_ticks_msec()` and frame-based `lerp(a, b, 0.1)`; neither slows down.
- HUD tweens / AnimationPlayers need `ignore_time_scale` or they crawl.
- Audio buses are not part of this step.

## Using it
By default, bullet time uses the existing `combat_alt_aim` action (mouse button 8) as a toggle,
preserving the old debug button. If that action is missing, it is registered with F as a fallback.
Tune on the BulletTime node: `world_time_scale`, `movement_ratio`, `toggle_mode`,
`ramp_in_time` / `ramp_out_time`, focus meter. Assign `effect_target` (the post-processing ColorRect) or put it
in the group `bullet_time_fx` to get desaturation, chromatic aberration and vignette.
