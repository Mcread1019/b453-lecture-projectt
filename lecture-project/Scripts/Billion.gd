extends CharacterBody2D
class_name Billion

@export var color: Color = Color.WHITE
@export var move_speed: float = 100.0

func _ready():
	# Set up the visual appearance based on color
	update_visual_color()

func _physics_process(delta):
	# Basic movement logic 
	move_and_slide()

func set_billion_color(new_color: Color):
	color = new_color
	update_visual_color()

func update_visual_color():
	# Update the Visual node's color if it exists and has the set_visual_color function
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_visual_color"):
			visual.set_visual_color(color)
