extends Node2D
class_name Blaster

@export var speed: float = 350.0
@export var max_distance: float = 300.0
@export var damage: float = 15.0
@export var shot_radius: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var shot_color: Color = Color.WHITE
var owner_base_index: int = -1
var distance_traveled: float = 0.0

# Arena boundaries
var arena_left: float = 80.0
var arena_right: float = 1070.0
var arena_top: float = 75.0
var arena_bottom: float = 565.0

func _ready():
	add_to_group("blasters")
	z_index = 0

func _physics_process(delta: float):
	# Move in the set direction
	var move_amount = direction * speed * delta
	global_position += move_amount
	distance_traveled += move_amount.length()

	# Check max distance
	if distance_traveled >= max_distance:
		queue_free()
		return

	# Check wall collisions
	if _is_outside_arena():
		queue_free()
		return

	# Check collisions with opposing billions
	_check_billion_collisions()

func _is_outside_arena() -> bool:
	return (global_position.x < arena_left or
			global_position.x > arena_right or
			global_position.y < arena_top or
			global_position.y > arena_bottom)

func _check_billion_collisions():
	var billions = get_tree().get_nodes_in_group("billions")

	for billion in billions:
		if not is_instance_valid(billion):
			continue
		# Pass through same-team billions
		if billion.base_index == owner_base_index:
			continue
		# Check collision with opposing billion
		var distance = global_position.distance_to(billion.global_position)
		if distance <= billion.collision_radius + shot_radius:
			# Damage the billion and destroy the blaster
			billion.take_damage(damage)
			queue_free()
			return

func setup(pos: Vector2, dir: Vector2, col: Color, base_idx: int):
	global_position = pos
	direction = dir.normalized()
	shot_color = col
	owner_base_index = base_idx
	rotation = direction.angle()

func _draw():
	# Draw the blaster shot as a small colored elongated shape
	var trail_length = 8.0
	var trail_dir = Vector2(-trail_length, 0)  # Trail behind (local space, shot points right)

	# Main shot circle
	draw_circle(Vector2.ZERO, shot_radius, shot_color)

	# Bright center
	draw_circle(Vector2.ZERO, shot_radius * 0.5, shot_color.lightened(0.5))

	# Trail
	draw_line(trail_dir, Vector2.ZERO, shot_color.darkened(0.2), shot_radius * 1.5)
