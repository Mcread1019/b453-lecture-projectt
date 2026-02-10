extends CharacterBody2D
class_name Billion

@export var color: Color = Color.WHITE
@export var base_index: int = 0  # Which base/color this billion belongs to

# Physics parameters
@export var max_speed: float = 200.0
@export var acceleration: float = 400.0
@export var deceleration_distance: float = 50.0  # Distance at which to start slowing down
@export var arrival_distance: float = 15.0  # Distance considered "arrived"
@export var mass: float = 1.0
@export var collision_radius: float = 6.0  # Effective radius with scale 0.5

# Arena boundaries
var arena_left: float = 80.0
var arena_right: float = 1070.0
var arena_top: float = 75.0
var arena_bottom: float = 565.0

# Current velocity for physics
var physics_velocity: Vector2 = Vector2.ZERO

func _ready():
	# Set up the visual appearance based on color
	update_visual_color()
	# Set z_index so billions appear behind flags
	z_index = 0

func _physics_process(delta: float):
	# Find target flag and apply movement
	var target_pos = _get_nearest_flag_position()

	if target_pos != Vector2.INF:
		_move_toward_flag(target_pos, delta)

	# Handle collisions with other billions (billiard ball physics)
	_handle_billion_collisions()

	# Apply velocity
	velocity = physics_velocity
	move_and_slide()

	# Clamp to arena bounds
	_clamp_to_arena()

func _get_nearest_flag_position() -> Vector2:
	var flags = get_tree().get_nodes_in_group("flags")
	var nearest_pos = Vector2.INF
	var nearest_dist = INF

	for flag in flags:
		if not is_instance_valid(flag):
			continue
		# Only target flags of the same base_index (color)
		if flag.base_index == base_index:
			var dist = global_position.distance_to(flag.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = flag.global_position

	return nearest_pos

func _move_toward_flag(target_pos: Vector2, delta: float):
	var direction = target_pos - global_position
	var distance = direction.length()

	if distance < 0.1:
		return

	direction = direction.normalized()

	# Calculate desired speed based on distance (deceleration when near)
	var desired_speed: float
	if distance < arrival_distance:
		# Very close - minimal movement
		desired_speed = 0.0
	elif distance < deceleration_distance:
		# Decelerate as we approach
		var t = (distance - arrival_distance) / (deceleration_distance - arrival_distance)
		desired_speed = max_speed * t
	else:
		# Full speed ahead
		desired_speed = max_speed

	# Calculate desired velocity
	var desired_velocity = direction * desired_speed

	# Apply acceleration toward desired velocity
	var velocity_diff = desired_velocity - physics_velocity
	var accel_this_frame = acceleration * delta

	if velocity_diff.length() <= accel_this_frame:
		physics_velocity = desired_velocity
	else:
		physics_velocity += velocity_diff.normalized() * accel_this_frame

func _handle_billion_collisions():
	var billions = get_tree().get_nodes_in_group("billions")

	for other in billions:
		if other == self or not is_instance_valid(other):
			continue

		var to_other = other.global_position - global_position
		var distance = to_other.length()
		var min_distance = collision_radius + other.collision_radius

		if distance < min_distance and distance > 0.001:
			# Collision detected - apply billiard ball physics
			var normal = to_other.normalized()

			# Separate the billions (push apart)
			var overlap = min_distance - distance
			var separation = normal * (overlap / 2.0 + 0.5)
			global_position -= separation
			other.global_position += separation

			# Elastic collision - exchange velocity components along collision normal
			var relative_velocity = physics_velocity - other.physics_velocity
			var velocity_along_normal = relative_velocity.dot(normal)

			# Only resolve if objects are moving toward each other
			if velocity_along_normal > 0:
				# Calculate impulse (assuming equal mass for simplicity)
				var impulse = velocity_along_normal * normal

				# Apply impulse to both billions
				physics_velocity -= impulse
				other.physics_velocity += impulse

func _clamp_to_arena():
	var clamped = false

	# Left boundary
	if global_position.x - collision_radius < arena_left:
		global_position.x = arena_left + collision_radius
		physics_velocity.x = abs(physics_velocity.x) * 0.5  # Bounce with damping
		clamped = true

	# Right boundary
	if global_position.x + collision_radius > arena_right:
		global_position.x = arena_right - collision_radius
		physics_velocity.x = -abs(physics_velocity.x) * 0.5
		clamped = true

	# Top boundary
	if global_position.y - collision_radius < arena_top:
		global_position.y = arena_top + collision_radius
		physics_velocity.y = abs(physics_velocity.y) * 0.5
		clamped = true

	# Bottom boundary
	if global_position.y + collision_radius > arena_bottom:
		global_position.y = arena_bottom - collision_radius
		physics_velocity.y = -abs(physics_velocity.y) * 0.5
		clamped = true

func set_billion_color(new_color: Color):
	color = new_color
	update_visual_color()

func set_base_index(index: int):
	base_index = index

func update_visual_color():
	# Update the Visual node's color if it exists and has the set_visual_color function
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_visual_color"):
			visual.set_visual_color(color)
