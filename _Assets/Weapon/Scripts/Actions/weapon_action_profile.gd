class_name WeaponActionProfile extends Resource
## How a weapon's action behaves: whether it cycles itself after a shot, what an empty
## reload needs, and the optional "active reload" timing window.
## Assign one to Weapon.action_profile. A weapon with no profile behaves as before
## (automatic action, slide locks open when empty, no active reload).
##
## Recipes
##   Pistol / AR-15 style   AUTOMATIC + BOLT_CATCH      (active reload optional)
##   MP5 / G3 style         AUTOMATIC + CHARGING_HANDLE (active reload optional)
##   Pump shotgun           MANUAL                       (reload is per shell, no active reload)
##   Bolt-action sniper     MANUAL                       (active reload optional)
##   Open-bolt SMG          AUTOMATIC + Weapon.is_open_bolt (no rack needed, profile not needed)

enum CycleMode {
	## Gas / blowback action: feeds the next round by itself after every shot.
	AUTOMATIC,
	## Pump or bolt action: after every shot the player must rack to eject the fired case
	## and chamber the next round. Until then the weapon cannot fire.
	MANUAL,
}

enum EmptyReloadStyle {
	## The slide locks open on the last round and stays open through the reload (pistols, AR-15).
	## The slide is released by hitting the active reload window, or by racking afterwards.
	BOLT_CATCH,
	## The bolt stays closed on an empty gun (MP5, G3). After the reload the charging handle
	## must be racked, or hit in the active reload window, to chamber a round.
	CHARGING_HANDLE,
}

enum OpenBoltMode {
	## Realistic: the bolt must be racked open (cocked) before the gun can fire. It stays open
	## while rounds remain and slams shut on the last round, so an emptied gun needs a rack.
	COCKED,
	## The old behaviour: always ready, never needs a rack.
	ALWAYS_READY,
}

enum ReloadWithClosedBolt {
	## The bolt must be racked open first. The reload key does nothing (and shows a hint) until then.
	BLOCKED,
	## The reload key racks the bolt open by itself, then reloads.
	AUTO_RACK,
	## Reloading is allowed, but the bolt is still closed afterwards and needs a rack
	## (or a hit in the active reload window) before the gun can fire.
	RELOAD_THEN_RACK,
}

@export var cycle_mode: CycleMode = CycleMode.AUTOMATIC
## Only matters for AUTOMATIC weapons.
@export var empty_reload_style: EmptyReloadStyle = EmptyReloadStyle.BOLT_CATCH

@export_group("Open-bolt weapons (Weapon.is_open_bolt)")
@export var open_bolt_mode: OpenBoltMode = OpenBoltMode.COCKED
## What the reload key does while the bolt is closed (an emptied gun, or a fresh uncocked one).
@export var reload_with_closed_bolt: ReloadWithClosedBolt = ReloadWithClosedBolt.BLOCKED

@export_group("Aiming down sights while reloading")
## While aiming down sights (ADS or canted aim), a reload keeps the weapon near the aim: the clip's
## movement of the weapon BODY bone is scaled down by the two values below, instead of carrying the
## whole weapon out of the aim. The other bones (magazine, bolt, handles) animate normally.
## Works best when those bones are children of the body bone. Decided when the reload starts.
@export var ads_reload_enabled: bool = false
## The same for racking (pump, bolt-action, charging handle).
@export var ads_rack_enabled: bool = false
## How much of the clip's body MOVEMENT is kept. 0 = body frozen at the aim, 1 = the full clip.
@export_range(0.0, 1.0, 0.01) var ads_body_position_scale: float = 0.25
## How much of the clip's body ROTATION is kept. Keeping more rotation than movement avoids a stiff look.
@export_range(0.0, 1.0, 0.01) var ads_body_rotation_scale: float = 0.6
## Pull the camera FOV back toward the hip FOV by this fraction while the action plays
## (0 = keep the ADS FOV, 0.25 = a quarter of the way back). Needs the cam_effects.gd edit.
@export_range(0.0, 1.0, 0.01) var ads_fov_blend: float = 0.25

@export_group("Quick reload (double-tap reload)")
## Quick reload dumps the magazine. It uses the weapon's quick reload clip, or its empty reload
## clip when it has none. This scales its duration (1.0 = same as the clip).
@export_range(0.1, 3.0, 0.05) var quick_reload_time_multiplier: float = 1.0

@export_group("Rack / pump / bolt")
## Seconds a rack takes. 0 = use WeaponController.rack_lockout_time.
@export_range(0.0, 3.0, 0.01, "suffix:s") var rack_time: float = 0.0
## Charging-handle guns (MP5, G3): the first rack pulls the bolt back and HOLDS it there. The player
## reloads with the bolt held open, then presses rack again to let it go forward and chamber a round.
## Off: a rack pulls and releases in one go. Only for AUTOMATIC weapons.
@export var rack_holds_bolt_open: bool = false

@export_group("Active reload")
## Pressing the rack key while the new magazine goes in chambers the round right away and
## plays the rest of the reload faster. Missing the window means racking by hand afterwards.
## Only applies to reloads from an empty chamber, never to shell-by-shell reloads.
@export var active_reload_enabled: bool = false
## How long BEFORE the magazine is seated a press already counts (it is applied when the
## magazine seats). Real seconds, not scaled by reload speed skills.
@export_range(0.0, 1.0, 0.01, "suffix:s") var active_early_seconds: float = 0.25
## How long AFTER the magazine is seated the window stays open.
@export_range(0.0, 2.0, 0.01, "suffix:s") var active_late_seconds: float = 0.35
## Playback speed of the rest of the reload after a hit. A very high value (for example 100)
## ends the reload almost at once, with the fade-out smoothing the cut.
@export_range(1.0, 100.0, 0.1) var active_speedup: float = 2.5
## Seconds the slide takes to cycle during a hit.
@export_range(0.02, 1.0, 0.01, "suffix:s") var active_rack_time: float = 0.14


## Does an open-bolt weapon need to be cocked (racked) before it can fire?
func cocks_open_bolt() -> bool:
	return open_bolt_mode == OpenBoltMode.COCKED


func is_manual_cycle() -> bool:
	return cycle_mode == CycleMode.MANUAL


## Does the slide lock open when the chamber is empty?
func locks_open_when_empty() -> bool:
	return cycle_mode == CycleMode.AUTOMATIC and empty_reload_style == EmptyReloadStyle.BOLT_CATCH


## Does a rack / hit have to PULL the slide back (and release it), as opposed to just
## releasing a slide that is already locked open?
func rack_pulls_slide() -> bool:
	return not locks_open_when_empty()