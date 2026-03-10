extends Node2D
class_name BillionVisual


@export var color: Color = Color.WHITE
@export var outer_radius: float = 18.0
@export var inner_radius: float = 12.0
@export var small_radius: float = 5.0
@export var small_offset: Vector2 = Vector2(0, 18)
@export var ring_thickness: float = 2.0

# Health visual parameters
var health_ratio: float = 1.0  # 0.0 to 1.0
@export var min_health_radius_ratio: float = 0.3  # Minimum size is 30% of max

# Base-specific parameters (for radial bars)
@export var is_base_visual: bool = false
var xp_ratio: float = 0.0  # 0.0 to 1.0
@export var health_bar_thickness: float = 5.0
@export var xp_bar_thickness: float = 4.0
@export var health_bar_radius: float = 48.0  # Outer radial health bar
@export var xp_bar_radius: float = 42.0  # Inner radial XP bar

func _ready():
	queue_redraw()

func _draw():
	if is_base_visual:
		_draw_base()
	else:
		_draw_billion()

func _draw_billion():
	# Calculate health-based inner radius
	# Inner circle scales between min_health_radius_ratio * inner_radius and inner_radius
	var min_radius = inner_radius * min_health_radius_ratio
	var max_radius = inner_radius
	var current_inner_radius = min_radius + (max_radius - min_radius) * health_ratio

	# Only draw white outer circle if damaged (health_ratio < 1.0)
	if health_ratio < 1.0:
		# White outer circle (containing circle for health visualization)
		draw_circle(Vector2.ZERO, outer_radius, Color.WHITE)
		# Colored inner circle (represents current health)
		draw_circle(Vector2.ZERO, current_inner_radius, color)
	else:
		# Full health - just draw the colored circle at full size
		draw_circle(Vector2.ZERO, outer_radius, color)

	# Small dark center circle
	var center_radius = 4.0
	draw_circle(Vector2.ZERO, center_radius, Color(0.1, 0.1, 0.15))

	# Small indicator/trailing circle
	draw_circle(small_offset, small_radius, color)

func _draw_base():
	# Draw main base circle (white outer, colored inner)
	draw_circle(Vector2.ZERO, outer_radius, Color.WHITE)
	draw_circle(Vector2.ZERO, inner_radius, color)

	# Dark center
	var center_radius = 8.0
	draw_circle(Vector2.ZERO, center_radius, Color(0.15, 0.15, 0.2))

	# Draw radial health bar (outer, colored - depletes clockwise from top)
	# Health bar starts full (TAU) and depletes as health decreases
	if health_ratio > 0.0:
		var health_angle = TAU * health_ratio
		# Start from top (-PI/2) and go clockwise
		var start_angle = -PI / 2
		var end_angle = start_angle + health_angle
		draw_arc(Vector2.ZERO, health_bar_radius, start_angle, end_angle, 64,
			color, health_bar_thickness, true)

	# Draw radial XP bar (inner, white - fills clockwise from top)
	# XP bar starts empty and fills as XP increases
	if xp_ratio > 0.0:
		var xp_angle = TAU * xp_ratio
		# Start from top (-PI/2) and go clockwise
		var start_angle = -PI / 2
		var end_angle = start_angle + xp_angle
		draw_arc(Vector2.ZERO, xp_bar_radius, start_angle, end_angle, 64,
			Color.WHITE, xp_bar_thickness, true)

func set_visual_color(new_color: Color):
	color = new_color
	queue_redraw()

func set_health_ratio(ratio: float):
	health_ratio = clamp(ratio, 0.0, 1.0)
	queue_redraw()

func set_xp_ratio(ratio: float):
	xp_ratio = clamp(ratio, 0.0, 1.0)
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
