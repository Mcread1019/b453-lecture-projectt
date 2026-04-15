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

# Rank parameters
var rank: int = 1
var spike_rotation: float = 0.0

# Class badge
var billion_class: String = ""
var _bullet_sprite: Sprite2D = null

func _ready():
	queue_redraw()

func _process(delta: float):
	if not is_base_visual and rank > 0:
		# Rotate spikes faster at higher ranks
		spike_rotation += delta * (0.5 + (rank - 1) * 0.35)
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

	# Draw rank spikes rotating around the billion
	_draw_rank_spikes()

	# Draw class badge (sniper hat / tank armor ring)
	_draw_class_badge()

func _draw_rank_spikes():
	if rank <= 0:
		return

	var spike_orbit = outer_radius + 5.0
	var spike_length = 9.0
	var spike_half_width = 3.0

	for i in range(rank):
		var angle = spike_rotation + (TAU / rank) * i
		var cos_a = cos(angle)
		var sin_a = sin(angle)

		# Base center of spike (at orbit radius)
		var base_center = Vector2(cos_a, sin_a) * spike_orbit

		# Tip of spike (further out)
		var tip = Vector2(cos_a, sin_a) * (spike_orbit + spike_length)

		# Left and right base points (perpendicular to spike direction)
		var perp = Vector2(-sin_a, cos_a) * spike_half_width
		var left = base_center + perp
		var right = base_center - perp

		# Draw spike as a filled triangle
		draw_colored_polygon([left, tip, right], color)

func _draw_class_badge() -> void:
	match billion_class:
		"sniper":
			# Top-hat sitting on the crown of the circle.
			var hat_dark := Color(0.12, 0.08, 0.04)
			var top := -(outer_radius + 1.0)
			# Brim — wide flat band
			draw_rect(Rect2(-13.0, top - 3.0, 26.0, 4.0), hat_dark)
			# Crown — narrower tall block
			draw_rect(Rect2(-8.0, top - 16.0, 16.0, 14.0), hat_dark)
			# Highlight stripe on crown
			draw_rect(Rect2(-8.0, top - 6.0, 16.0, 2.0),
				Color(0.35, 0.25, 0.12))
		"tank":
			# Extra thick armor ring around the outside.
			draw_arc(Vector2.ZERO, outer_radius + 5.0, 0.0, TAU, 48,
				color.darkened(0.4), 4.0)

func _draw_base():
	# Draw main base circle (white outer, colored inner)
	draw_circle(Vector2.ZERO, outer_radius, Color.WHITE)
	draw_circle(Vector2.ZERO, inner_radius, color)

	# Dark center
	var center_radius = 8.0
	draw_circle(Vector2.ZERO, center_radius, Color(0.15, 0.15, 0.2))

	# Draw radial health bar (outer, colored - depletes clockwise from top)
	if health_ratio > 0.0:
		var health_angle = TAU * health_ratio
		var start_angle = -PI / 2
		var end_angle = start_angle + health_angle
		draw_arc(Vector2.ZERO, health_bar_radius, start_angle, end_angle, 64,
			color, health_bar_thickness, true)

	# Draw radial XP bar (inner, white - fills clockwise from top)
	if xp_ratio > 0.0:
		var xp_angle = TAU * xp_ratio
		var start_angle = -PI / 2
		var end_angle = start_angle + xp_angle
		draw_arc(Vector2.ZERO, xp_bar_radius, start_angle, end_angle, 64,
			Color.WHITE, xp_bar_thickness, true)


func _draw_rank_on_base():
	# White circle backdrop for readability
	draw_circle(Vector2.ZERO, 12.0, Color.WHITE)

	# Draw rank number using fallback font
	var font = ThemeDB.fallback_font
	var font_size = 14
	var rank_text = str(rank)
	var string_size = font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = Vector2(-string_size.x / 2.0, string_size.y / 4.0)
	draw_string(font, text_pos, rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)

## Called by Billion._setup_class_visual() to configure the badge.
func setup_class_visual(class_str: String) -> void:
	billion_class = class_str
	# Gunner gets a cannonball sprite sitting on top of the circle.
	if class_str == "gunner":
		_bullet_sprite = Sprite2D.new()
		_bullet_sprite.texture = load(
			"res://kenney_pirate-pack/PNG/Default size/Ship parts/cannonBall.png"
		)
		# Scale up the 10×10 sprite so it reads at the unit's zoom level.
		_bullet_sprite.scale   = Vector2(3.0, 3.0)
		_bullet_sprite.position = Vector2(0, -(outer_radius + 10))
		_bullet_sprite.z_index  = 3
		add_child(_bullet_sprite)
	queue_redraw()

func set_visual_color(new_color: Color):
	color = new_color
	queue_redraw()

func set_health_ratio(ratio: float):
	health_ratio = clamp(ratio, 0.0, 1.0)
	queue_redraw()

func set_xp_ratio(ratio: float):
	xp_ratio = clamp(ratio, 0.0, 1.0)
	queue_redraw()

func set_rank(new_rank: int):
	rank = new_rank
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
