# Prone + omni-directional dolphin dive: notes

Not run in Godot (no engine in my sandbox). Open `player.tscn` once, let Godot generate the `.uid` files, and check the Output panel for script errors.

## 1. Input (project.godot is not a scene, so I did not touch it)
Add in Project Settings > Input Map an action named `move_prone` (suggested key: Z), or paste this into the `[input]` section:

```
move_prone={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":122,"location":0,"echo":false,"script":null)
]
}
```

## 2. How it plays
- Press prone while standing or crouching: go prone (slow crawl, low collider, low camera).
- Press prone again, or jump: stand up (crouch if there is no headroom). Crouch key: up to crouch.
- Press prone while sprinting, sliding, or in mid-air: dolphin dive. With WASD held it dives in that direction relative to where you face (forward, back, strafe, diagonals). With no input it dives where you face.
- You land into prone, carry a short landing slide, and a cooldown applies.
- WASD during the dive steers it only if `air_control` is above 0 (default 0.15).
- Jump, slide and sprint are blocked while prone or diving.

## 3. Tuning
All on the `Component/ProneDive` node (`ProneDiveComponent`) in the inspector, grouped: Prone, Allowed from, Launch, In the air, Landing, Feel, Weapon.
Also: `CameraController.prone_offset`, `StepHandler.prone_max_step_height`.

## 4. Skills / abilities (PlayerStats)
Read live on every use, so a skill can change them at any time. Missing keys are neutral.

| Key | Kind | Effect |
|---|---|---|
| `dive_speed` | multiplier | horizontal launch speed (and the speed cap) |
| `dive_height` | multiplier | upward launch speed |
| `dive_cooldown` | multiplier | cooldown (lower is better) |
| `dive_land_slide` | multiplier | landing slide time and carried speed |
| `dive_fall_damage` | multiplier | fall damage on dive landings |
| `prone_speed` | multiplier | crawl speed |
| `dive_air_control` | additive | added to `air_control` (clamped 0..1) |
| `dive_unlocked` | flag | enables the dive even if `dive_enabled` is off |
| `dive_from_air` / `dive_from_walk` | flag | allow those starts |
| `dive_no_cooldown` / `dive_no_fall_damage` | flag | removes cooldown / fall damage |
| `dive_shoot` | flag | `allows_shooting()` returns true |

Example: `stats.set_stats("dive_speed", 1.25)` and `stats.set_flag("dive_no_fall_damage", true)`.
Note: `PlayerStats.has_flag()` returns true for a flag set to `false` (it only checks the key exists), so the component reads `active_flags` directly.

Other systems can listen to `dive_started(direction)` and `dive_landed` on the component.

## 5. Patch for cam_effects.gd (I only had your uploaded files, so this is a snippet)
Add the variables near the other `_target_slide_*` ones:

```gdscript
var _dive_roll: float = 0.0
var _dive_pitch: float = 0.0
```

In `calculate_view_offset`, replace the slide FOV block with:

```gdscript
	var target_fov = _base_fov
	if enable_slide_effect and player.is_sliding:
		target_fov = slide_fov
	elif player.is_diving and player.prone_dive:
		target_fov = _base_fov + player.prone_dive.dive_fov_boost
```

and add this just before `position = offset`:

```gdscript
	# dive tilt (tunable on ProneDiveComponent)
	var dive_roll_t: float = 0.0
	var dive_pitch_t: float = 0.0
	if player.is_diving and player.prone_dive:
		var dv: Vector3 = player.prone_dive.dive_velocity
		if dv.length() > 0.1:
			var dn: Vector3 = dv.normalized()
			dive_roll_t = dn.dot(global_transform.basis.x) * deg_to_rad(player.prone_dive.cam_roll_degrees)
			dive_pitch_t = dn.dot(-global_transform.basis.z) * deg_to_rad(player.prone_dive.cam_pitch_degrees)
	_dive_roll = lerpf(_dive_roll, dive_roll_t, delta * fov_transition_speed)
	_dive_pitch = lerpf(_dive_pitch, dive_pitch_t, delta * fov_transition_speed)
	angles.z += _dive_roll
	angles.x += _dive_pitch
```

## 6. Things to check or know
- Camera height: `update_camera_height` was rewritten on top of a new `move_camera_to`, so it works from any height (prone to crouch used to be impossible). Side effect: the camera now settles at 0.5 at start instead of staying at the scene's 0.6138 until the first crouch.
- `player.tscn` has a delayed `OnSlideEnd` transition parented to the `Stance` compound state (not to `Sliding`) while `sliding_state.gd` also ends the slide itself. It may fire once about 0.8s after the scene starts. I left it alone; deleting it is probably safe.
- `is_crouching` stays true while prone, so the weapon animator uses the crouch pose until a prone pose exists. `weapon_controller.gd` is not wired to `allows_shooting()` yet.
- The prone collider is a small sphere (r 0.35) for robustness against wall clipping while turning; swap in a lying capsule later if you want a longer body.
- Tune the CamEffects tilt signs (`cam_roll_degrees`, `cam_pitch_degrees`) by feel; I followed the slide convention.
