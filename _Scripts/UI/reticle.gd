extends CenterContainer

@export var DOT_RADIUS: float = 1.0
@export var DOT_COLOR: Color = Color(1, 0, 0, 1) # Red color

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# pass # Replace with function body.
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	draw_circle(Vector2.ZERO, DOT_RADIUS, DOT_COLOR)