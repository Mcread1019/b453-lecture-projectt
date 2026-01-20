extends Node2D

@export var base_scene: PackedScene
@export var billion_scene: PackedScene

# Colors for the four bases
var base_colors = [
	Color(0.3, 0.8, 0.3),  # Green
	Color(0.8, 0.7, 0.2),  # Yellow/Gold
	Color(0.8, 0.3, 0.3),  # Red
	Color(0.3, 0.5, 0.9),  # Blue
]

# Positions for the four bases (adjusted for sprite-based arena)
var base_positions = [
	Vector2(250, 180),   # Top-left area
	Vector2(900, 180),   # Top-right area
	Vector2(250, 460),   # Bottom-left area
	Vector2(900, 460),   # Bottom-right area
]

func _ready():
	spawn_bases()

func spawn_bases():
	for i in range(4):
		if not base_scene:
			push_error("Base scene not assigned!")
			return
		
		var base = base_scene.instantiate() as Base
		base.global_position = base_positions[i]
		base.base_color = base_colors[i]
		base.billion_scene = billion_scene
		base.add_to_group("bases")
		
		add_child(base)
		
		# Apply the color after adding to tree
		base.set_base_color(base_colors[i])
