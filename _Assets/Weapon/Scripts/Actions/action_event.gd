class_name ActionEvent extends Resource
## A named moment inside an action, stored as a 0..1 fraction of the action's
## duration, so it lands at the same relative point at any playback speed.
##
## Getting the fraction from Blender:
##   fraction = (event_frame - clip_start_frame) / (clip_end_frame - clip_start_frame)

@export var event_name: StringName = &""
@export_range(0.0, 1.0, 0.001) var fraction: float = 0.0

@export_group("Part visibility")
## Names of nodes in the weapon model to SHOW when this event fires (for example a dummy
## magazine that is hidden the rest of the time). Looked up by node name anywhere under
## the model root.
@export var show_parts: PackedStringArray = PackedStringArray()
## Names of nodes to HIDE when this event fires (for example the real magazine while the
## dummy one is being swapped in).
@export var hide_parts: PackedStringArray = PackedStringArray()
## Whatever an action changed is put back to its original visibility when the action
## ends or is cancelled, so a swap can never get stuck.