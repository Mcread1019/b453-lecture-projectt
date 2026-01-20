extends Node2D
class_name BillionVisual


@export var color: Color = Color.WHITE
@export var outer_radius: float = 18.0  
@export var inner_radius: float = 12.0  
@export var small_radius: float = 5.0   
@export var small_offset: Vector2 = Vector2(0, 18) 
@export var ring_thickness: float = 2.0  

func _ready():
	queue_redraw()

func _draw():
	# Outer ring (hollow circle)
	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 32, 
		color.lightened(0.3), ring_thickness, true)
	
	# Inner filled circle
	draw_circle(Vector2.ZERO, inner_radius, color)
	
	# Small indicator/trailing circle
	draw_circle(small_offset, small_radius, color)

func set_visual_color(new_color: Color):
	color = new_color
	queue_redraw()

# Alternative version with outline on inner circle
func _draw_with_outline():
	# Outer ring
	draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 32, 
		color.lightened(0.3), ring_thickness, true)
	
	# Inner circle with darker outline
	draw_circle(Vector2.ZERO, inner_radius, color)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 32, 
		color.darkened(0.3), 2.0, true)
	
	# Small circle
	draw_circle(small_offset, small_radius, color)


## BASE VISUAL VERSION
## For bases, use larger sizes:

func draw_base_visual():
	var base_outer = 40.0
	var base_inner = 30.0
	var base_small = 12.0
	
	# Outer ring
	draw_arc(Vector2.ZERO, base_outer, 0, TAU, 48, 
		color.lightened(0.2), 4.0, true)
	
	# Inner circle
	draw_circle(Vector2.ZERO, base_inner, color)
	
	# Small indicator
	draw_circle(Vector2(0, base_outer + 8), base_small, color)
