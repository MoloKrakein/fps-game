class_name ActionDef extends Resource
## Describes one weapon action (reload, rack...) and the events inside it.
## Lives in WeaponAnimation.actions, so it is stored per weapon model and
## survives re-importing the Blender file.
##
## ids used by WeaponActions:
##   &"empty_reload"  events: mag_out, mag_in   (mag_in may also be named shell_in)
##   &"loaded_reload" events: mag_out, mag_in
##   &"rack"          events: pull, peak, release, closed
## Any action without a def falls back to the defaults in WeaponActions.

@export var id: StringName = &""
@export var events: Array[ActionEvent] = []
