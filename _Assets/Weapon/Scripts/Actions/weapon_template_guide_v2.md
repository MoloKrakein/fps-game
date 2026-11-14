# Weapon animation workflow v2 (state machine). Pistol = template

This replaces the first guide. `scenes/pistol_model.tscn` is the reference; to make
another weapon, duplicate it and follow section 5.

## 0. Install order

Copy into `res://_Assets/Weapon/Scripts/Actions/` (new folder):
`action_event.gd`, `action_def.gd`, `action_timeline.gd`, `slide_driver.gd`, `weapon_actions.gd`

Replace the existing files:
- `weapon_animation.gd` -> `res://_Assets/Weapon/Scripts/weapon_animation.gd`
- `weap_reloading_state.gd` -> `res://_Assets/Weapon/Scripts/States/weap_reloading_state.gd`

Then apply the edits in `weapon_controller_changes.md`.

**Before opening the scene:** add the `Idle` pose clip (section 4). If you renamed
`slide_driver.gd`, keep its `class_name SlideDriver`.

## 1. The tree in one picture

```
CloseBolt ─┐
           ├─ BoltPosition ───────────────────┐   slide pose (code writes 0..1)
OpenBolt ──┘                                  │
                                              ├─ BodyLayer ─ output
ActionStates ─ ActionSpeed ───────────────────┘   (Blend2, filtered to Body_2,
 (state machine) (TimeScale)                        Mags_2, dummy_2, always 1.0)
```

**BodyLayer** takes the three body bones from the action clips, and every other bone
(including the slide) from `BoltPosition`. So the action clips can never fight the slide.

**ActionStates** is one state machine:

```
          ┌──────────── Reload_Loaded
Idle ⇄ ───┼──────────── Reload_Empty
          ├──────────── Rack
          └──────────── Equip ──(auto, at clip end)──▶ Idle
```

- Code asks for a state: `begin_action(&"Reload_Empty", speed)`.
- When the timeline for that action finishes, code calls `end_action()`, which fades back to
  `Idle` and resets the speed to 1.0.
- **Equip** returns to Idle by itself when its clip ends.
- **ActionSpeed** scales whichever clip is playing, so skill speed-ups work for reload, rack
  and equip the same way.

Compared with the OneShot chain: no `ReloadBlend`, no three request parameters, no per-layer
filters, and a new action (inspect, jam clear) is one state plus two transitions.

## 2. Who owns what

| Thing | Owner |
|---|---|
| Slide / bolt position | **Code** (`SlideDriver` -> `BoltPosition/blend_amount`) |
| Reload, rack, equip body and magazine motion | **Baked clips** in `ActionStates` |
| When ammo, chamber and state change | **Timeline events** (`ActionDef`) |
| How long an action lasts | **Gameplay** (skill-adjusted time) |
| Resting pose | **`Idle` clip** |

The animation never decides game state. Time and events do.

## 3. Names the code depends on (do not rename)

| In the scene | Code uses |
|---|---|
| State names `Idle`, `Reload_Loaded`, `Reload_Empty`, `Rack`, `Equip` | `WeaponAnimation.STATE_*` |
| `ActionStates` | `parameters/ActionStates/playback` |
| `ActionSpeed` | `parameters/ActionSpeed/scale` |
| `BoltPosition` | `parameters/BoltPosition/blend_amount` (0 closed, 1 open) |

Clip nodes inside the state machine point at your Blender clips; their names are free.

## 4. Blender: the clips each weapon needs

| Clip (pistol names) | Keys | Notes |
|---|---|---|
| `Idle` | `Body_2`, `Mags_2`, `dummy_2` | The normal pose of the weapon. 2 identical frames. **New.** |
| `Reload` | body + magazine | Starts and ends on the Idle pose |
| `Reload_Empty` | body + magazine | Starts and ends on the Idle pose |
| `Rack` | body | Slide not keyed |
| `Equip` | body | Ends on the Idle pose. Slide not keyed |
| `Close_bolt`, `Open_bolt` | slide | One-frame poses, as before |

Clips that start and end on the Idle pose are what make the fades smooth.

## 5. Action events

An event is a name plus a fraction (0..1) of the action. They live in the `actions` list on
the `WeaponAnimation` node.

| Action id | Events | What the code does |
|---|---|---|
| `loaded_reload`, `empty_reload` | `mag_out` | hook for the dropped magazine (nothing yet) |
| | `mag_in` | ammo transfers here (also accepts `shell_in`) |
| `rack` | `pull` (0.0) | slide moves back |
| | `peak` (0.45) | live round ejects, chamber clears |
| | `release` (0.55) | slide closes, or stays open if the magazine is empty |
| | `closed` (1.0) | chamber feeds, UI updates, `onIdle` if newly loaded |

The pistol's reload fractions (0.30, 0.85) are placeholders. Real value:

```
fraction = (event_frame - clip_start_frame) / (clip_end_frame - clip_start_frame)
```

No `ActionDef` for an action? Rack falls back to the default timing above, and reloads
commit ammo when they finish.

## 6. Making a new weapon

1. Bake the clips in section 4.
2. Duplicate `pistol_model.tscn`, swap the `.glb`.
3. Fix the bone names in the **BodyLayer** filter (one place now; was three).
4. Point `CloseBolt`, `OpenBolt` and the five states' clip nodes at the new clips.
5. Set the `ActionDef` fractions.
6. Run the checklist in section 7.

**Variations:** per-bullet weapons need no change (duration is divided by capacity, name the
event `mag_in` or `shell_in`). A weapon with no slide just leaves `BoltPosition` at 0.

## 7. Test checklist

1. Start the game: no "Animation not found" spam (that means the `Idle` clip is missing).
2. Equip: plays, then settles into Idle by itself.
3. Reload: ammo changes at the magazine seat, and the weapon fades back to Idle.
4. Reload with a very large skill multiplier: ammo and state still correct, once.
5. Fire the last round: slide parks open. Reload: it stays open. Rack: it closes and chambers.
6. Rack with a live round: it ejects when the slide is fully back.
7. Switch weapons mid-rack: no half-open slide.
8. Spam fire on full auto: slide never freezes halfway.

## 8. Things I could not verify

I could not open the scene in Godot. I checked the file with a script (every resource
reference resolves, every blend input is connected, every state has a way in and out of
Idle). These parts need a real run in the editor:

- **Filtered BodyLayer.** It should give the three body bones to the action clips and every
  other bone to `BoltPosition`. If the slide jitters or the body bones stay frozen, this
  blend is the first place to look.
- **State machine under manual `advance()`.** I expect it to work, since `WeaponAnimation`
  already advances the tree itself, but test an equip first.
- **Rack speed changed.** The Rack clip now stretches to `rack_lockout_time` (0.5 s), where
  before it played at 1x. If the clip length differs a lot from 0.5 s it will look faster or
  slower than before.
- **Fade times** (0.10 in, 0.15 out for reloads, 0.05/0.10 for rack, 0.12 for equip) are
  starting values.
- **Crossfades scale with `ActionSpeed`.** At large speed-ups they get very short, which is
  fine for gameplay but may look abrupt.
