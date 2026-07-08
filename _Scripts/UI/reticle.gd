@tool
extends Control

@export var DOT_RADIUS: float = 30.0 : set = set_dot_radius
@export var DOT_COLOR: Color = Color(1, 0, 0, 1) : set = set_crosshair_color
@export var DOT_OPACITY: float = 1.0 : set = set_dot_opacity
@export var DOT_SCALE: float = 1.0 : set = set_dot_scale
@export var GAP_ANGLE: float = 10.0 : set = set_gap_angle # Angle in degrees between each dot
@export var SEGMENTS: int = 36 : set = set_segments # Number of segments to draw the circle
@export var THICKNESS: float = 2.0 : set = set_thickness  # Thickness of the circle outline
# @export var SEGMENT_RADIUS: float = 1.0 : set = set_segments_radius # Radius of each segment
@export var CENTER_DOT_RADIUS: float = 3.0 : set = set_center_dot_radius # Radius of the center dot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# pass # Replace with function body.
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	# draw_circle(Vector2.ZERO, DOT_RADIUS, DOT_COLOR)
	draw_circle_crosshair()

func draw_circle_crosshair():
	var gap_rad = deg_to_rad(GAP_ANGLE)

	var arc_segments = [
		# Top right arc
		[3 * PI / 2 + gap_rad / 2, 2 * PI - gap_rad / 2],
		# Bottom right arc
		[0 + gap_rad / 2, PI / 2 - gap_rad / 2],
		# Bottom left arc
		[PI / 2 + gap_rad / 2, PI - gap_rad / 2],
		# Top left arc
		[PI + gap_rad / 2, 3 * PI / 2 - gap_rad / 2]
	]

	for arc in arc_segments:
		var start_angle = arc[0]
		var end_angle = arc[1]

		var points = []
		var angle_step = (end_angle - start_angle) / SEGMENTS

		for i in range(SEGMENTS + 1):
			var angle = start_angle + i * angle_step
			var point = Vector2(cos(angle), sin(angle)) * DOT_RADIUS * sin(GAP_ANGLE / 2) * DOT_SCALE
			points.append(point)

			if points.size() > 1:
				draw_polyline(points, DOT_COLOR, THICKNESS, true)
	# center dot
	draw_circle(Vector2.ZERO, CENTER_DOT_RADIUS * DOT_SCALE, DOT_COLOR)
	#


func update_crosshair():
	queue_redraw()

func set_dot_radius(radius: float) -> void:
	DOT_RADIUS = radius
	update_crosshair()

func set_crosshair_color(color: Color) -> void:
	DOT_COLOR = color
	update_crosshair()

func set_dot_opacity(opacity: float) -> void:
	DOT_OPACITY = opacity
	update_crosshair()

func set_dot_scale(scale: float) -> void:
	DOT_SCALE = scale
	update_crosshair()

func set_gap_angle(angle: float) -> void:
	GAP_ANGLE = angle
	update_crosshair()

func set_segments(segments: int) -> void:
	SEGMENTS = segments
	update_crosshair()

func set_thickness(thickness: float) -> void:
	THICKNESS = thickness
	update_crosshair()

# func set_segments_radius(radius: float) -> void:
# 	SEGMENT_RADIUS = radius
# 	update_crosshair()

func set_center_dot_radius(radius: float) -> void:
	CENTER_DOT_RADIUS = radius
	update_crosshair()

