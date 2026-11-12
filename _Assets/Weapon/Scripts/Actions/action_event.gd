class_name ActionEvent extends Resource
## A named moment inside an action, stored as a 0..1 fraction of the action's
## duration, so it lands at the same relative point at any playback speed.
##
## Getting the fraction from Blender:
##   fraction = (event_frame - clip_start_frame) / (clip_end_frame - clip_start_frame)

@export var event_name: StringName = &""
@export_range(0.0, 1.0, 0.001) var fraction: float = 0.0
