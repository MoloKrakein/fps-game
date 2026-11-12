# weapon_controller.gd changes

Seven small edits. Everything else in the controller stays as it is.

## 1. New component (region "State", next to the other components)

```gdscript
var animator: WeaponProceduralAnimator
var shooter: WeaponShooter
var reload: WeaponReload
var attachments: WeaponAttachments
var actions: WeaponActions          # NEW
```

## 2. `_init()`

```gdscript
func _init() -> void:
	animator = WeaponProceduralAnimator.new(self)
	shooter = WeaponShooter.new(self)
	reload = WeaponReload.new(self)
	attachments = WeaponAttachments.new(self)
	actions = WeaponActions.new(self)   # NEW
	attachments.changed.connect(_refresh_muzzle_effects)
```

## 3. `_process()`

```gdscript
	reload.process(delta)
	actions.process(delta)              # NEW (delta is already PlayerTime.real)
	animator.apply_offsets(delta)
```

## 4. `initialize_weapon_data()` (the model may spawn before the data exists)

```gdscript
func initialize_weapon_data(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return

	active_weapon_data = weapon_data
	_sync_cached_state_from_active_data()
	_set_and_persist_fire_mode(_resolve_initial_fire_mode_for_weapon_data())
	actions.sync_slide_to_chamber()     # NEW
```

## 5. `_cycle_weapon()`: replace the Loaded/Empty animation call

```gdscript
	if current_weapon.is_open_bolt:
		active_weapon_data.ammo_in_magazine = maxi(active_weapon_data.ammo_in_magazine - 1, 0)
		active_weapon_data.is_loaded = active_weapon_data.ammo_in_magazine > 0
	else:
		_feed_chamber()

	actions.on_shot_cycled()            # REPLACES: _play_animation("Loaded" if ... else "Empty")
	update_weapon_ui()
```

## 6. `rack_slide()`: replace the whole function

Ejecting and feeding now happen on the rack timeline events, not on keypress.

```gdscript
func rack_slide() -> void:
	if current_weapon == null or active_weapon_data == null:
		return
	if is_reloading or _rack_timer > 0.0 or current_weapon.is_open_bolt:
		return

	if not active_weapon_data.is_loaded and active_weapon_data.ammo_in_magazine <= 0:
		return

	actions.start_rack()                # eject at "peak", feed at "closed", onIdle if newly loaded
	_rack_timer = rack_lockout_time
	fire_timer = maxf(fire_timer, rack_lockout_time)
	reset_trigger()
```

## 7. Model binding and switching

In `_bind_model_nodes()`, after the WeaponAnimation lookup:

```gdscript
	weapon_animation_player = model.get_node_or_null("WeaponAnimation") as WeaponAnimation
	if weapon_animation_player == null:
		print("WeaponAnimation node not found in the weapon model.")
	else:
		weapon_animation_player.play_animation("Equip")
	actions.bind_animation(weapon_animation_player)   # NEW (also runs when it is null)
```

In `switch_weapon()`, right after the guard clause and before `current_weapon = ...`:

```gdscript
	if is_reloading or weapon_data == null or weapon_data.weapon == null:
		return

	actions.on_weapon_switching()       # NEW
	shooter.flush_casing_tube()
```

---

# Scene (.tscn) changes for the pistol

1. **ReloadTimeScale node.** In the AnimationTree, add an `AnimationNodeTimeScale`
   named `ReloadTimeScale` between `ReloadBlend` (Blend2 output) and the
   `ReloadOneShot` shot input. Its parameter becomes
   `parameters/ReloadTimeScale/scale`. Until it exists, reloads play at 1x and
   nothing breaks.
2. **Rack filter.** Remove `Slider_2` from the `RackOneShot` filter list (the code
   owns the slide now). Keep `Body_2`.
3. **Equip filter.** Equip is currently unfiltered, so it keys every bone including
   the slide. Switch it to filtered and include every bone except `Slider_2`.
4. **WeaponAnimation node.** Optional `actions` list on the `WeaponAnimation` node.
   Without it, rack uses the defaults in `WeaponActions._get_def()`
   (pull 0.0, peak 0.45, release 0.55, closed 1.0) and reloads commit ammo when
   they finish, which is the old behaviour. To get ammo on the visible frame, add
   an `ActionDef` with id `empty_reload` / `loaded_reload` and a `mag_in` event.
5. The old `weapon_bolt_time` export on `WeaponAnimation` is gone. Godot drops the
   stale value from the scene on the next save.

# Blender checklist

- Reload and equip clips must not key the slide bone.
- Event fraction = (frame - clip_start) / (clip_end - clip_start).

# What to test, in order

1. Reload at several skill speeds (including a huge multiplier): ammo and state
   stay correct, `onReloadFinish` fires once.
2. Fire the last round: the slide parks open. Reload: it stays open. Rack: it closes
   and chambers.
3. Rack with a live round: it ejects when the slide is fully back.
4. Rack with a live round and an empty magazine: the slide stays open.
5. Switch weapons mid-rack and mid-fire: no stuck or half-open slide.
