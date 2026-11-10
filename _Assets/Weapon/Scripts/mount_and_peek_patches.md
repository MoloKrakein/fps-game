# Patches: peek-over fix + weapon mount hooks

All snippets are small edits to existing files. Line anchors are the lines as they are on `main` today.

---
## A. Peek-over fix (why it "worked" in debug but showed nothing)

`CamEffects._process` ends with `position = offset` every frame. It runs AFTER
`CameraController._process` (child after parent), so it overwrites the position that
`CameraController._apply_peek()` just set. The tilt (rotation on the rig) survives; the sideways /
upward displacement never reaches the screen.

**Check first** (one line, e.g. at the end of `CoverPeek._process`):
```gdscript
if debug: print($"../../CameraController/Cam".position)   # adjust the path
```
Standing still it should print about `(0, 0, 0)`. If it prints `(0, -0.14, -0.6)` this patch is not needed.

### A1. `_Assets/Player/cam_effects.gd` (last two lines of `calculate_view_offset`)
```gdscript
	# was: position = offset
	var rig := get_parent() as CameraController
	position = offset + (rig.get_peek_cam_offset() if rig != null else Vector3.ZERO)
	rotation = angles
```

### A2. `Scenes/Player/camera_controller.gd`
Replace `_apply_peek()` and `get_base_eye_position()`, add `get_peek_cam_offset()`:
```gdscript
## Peek displacement for the camera, in the rig's local space. CamEffects adds it to its own position.
func get_peek_cam_offset() -> Vector3:
	return transform.basis.inverse() * _peek_offset

## CamEffects keeps the camera at the rig origin, so that IS the eye.
func get_base_eye_position() -> Vector3:
	return global_position

func _apply_peek() -> void:
	rotation.z = _peek_roll
```
Also move the `_apply_peek()` call in `_process` to the END of `_process` (after the mouse rotation),
so it uses this frame's pitch.

---
## B. Weapon mount hooks

### B1. `_Assets/Weapon/Scripts/weapon_controller.gd`
Next to `var accuracy_modifier`:
```gdscript
# Set by WeaponMount (all 1.0 = no change)
var recoil_multiplier: float = 1.0
var spread_multiplier: float = 1.0
var sway_multiplier: float = 1.0
```
In `_apply_recoil()`, after the `if is_aiming:` block:
```gdscript
		pitch *= recoil_multiplier
		yaw *= recoil_multiplier
		camera.add_weapon_recoil(pitch, yaw, current_weapon.recoil_cam_roll * recoil_multiplier)
		camera.add_fov_punch(current_weapon.recoil_fov_punch * recoil_multiplier)
```
(replace the two existing `camera.add_...` lines with these)

### B2. `_Assets/Weapon/Scripts/weapon_procedural_animator.gd`
`add_recoil()`, after `strength *= running_aim_multiplier`:
```gdscript
	strength *= ctrl.recoil_multiplier
```
`_update_idle_sway()`, after `amplitude *= _running_aim_multiplier(weapon.running_aim_sway_multiplier)`:
```gdscript
	amplitude *= ctrl.sway_multiplier
```
`_update_look_sway()` and `_update_look_rotation()`, change both
`var rate60: Vector2 = _look_rate / 60.0` to:
```gdscript
	var rate60: Vector2 = _look_rate / 60.0 * ctrl.sway_multiplier
```

### B3. `_Assets/Weapon/Scripts/weapon_shooter.gd`
End of `get_effective_spread()`:
```gdscript
	return maxf(0.0, total_spread * ctrl.spread_multiplier)
```

### B4. `Scenes/Player/camera_controller.gd` (view arc while mounted)
Variables:
```gdscript
var _limit_active: bool = false
var _limit_yaw_center: float = 0.0
var _limit_yaw_half: float = 0.0
var _limit_pitch_min: float = 0.0
var _limit_pitch_max: float = 0.0
```
Functions:
```gdscript
## Locks the view to an arc around where the player is looking right now (radians).
func set_view_limits(yaw_half: float, pitch_down: float, pitch_up: float) -> void:
	_limit_active = true
	_limit_yaw_center = _rotation.y
	_limit_yaw_half = yaw_half
	_limit_pitch_min = maxf(_rotation.x - pitch_down, deg_to_rad(tilt_low_limit))
	_limit_pitch_max = minf(_rotation.x + pitch_up, deg_to_rad(tilt_high_limit))

func clear_view_limits() -> void:
	_limit_active = false
```
In `update_camera_rotation`, right after the existing `_rotation.x = clamp(...)` line:
```gdscript
	if _limit_active:
		_rotation.y = _limit_yaw_center + clampf(wrapf(_rotation.y - _limit_yaw_center, -PI, PI), -_limit_yaw_half, _limit_yaw_half)
		_rotation.x = clampf(_rotation.x, _limit_pitch_min, _limit_pitch_max)
```

### B5. Scene
Add `weapon_mount.gd` to `_Assets/Weapon/Scripts/` and add a plain `Node` named `WeaponMount` under
`PlayerController/Component` with that script (editor: Component > Add Child Node > Node > attach script).

Optional cleanup: the `CoverPeek` node still has `cover_mask = 3` and `camera_radius = 99.0` in
`player.tscn`. Both properties no longer exist in cover_peek v3 and are ignored; they disappear next
time the scene is saved.

### B6. Keys
`weapon_mount` is registered at runtime on X if missing. Q/E are still shared with drop / use.
