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

# Scene and tree changes

The AnimationTree is now one state machine instead of chained OneShots. Use the edited
`scenes/pistol_model.tscn` as the reference and read `weapon_template_guide.md`.

You must add one clip in Blender (or Godot) before opening the scene: a pose clip named
`Idle` that keys `Body_2`, `Mags_2` and `dummy_2` in their resting position (2 identical
frames is enough). Without it the tree prints "Animation not found: Idle" every frame.

The old `weapon_bolt_time` export on `WeaponAnimation` is gone. Godot drops the stale value
from the scene on the next save.

# Blender checklist

- Add the `Idle` pose clip (see above).
- Reload, rack and equip clips must not key the slide bone.
- Event fraction = (frame - clip_start) / (clip_end - clip_start).

# What to test, in order

1. Reload at several skill speeds (including a huge multiplier): ammo and state
   stay correct, `onReloadFinish` fires once.
2. Fire the last round: the slide parks open. Reload: it stays open. Rack: it closes
   and chambers.
3. Rack with a live round: it ejects when the slide is fully back.
4. Rack with a live round and an empty magazine: the slide stays open.
5. Switch weapons mid-rack and mid-fire: no stuck or half-open slide.
