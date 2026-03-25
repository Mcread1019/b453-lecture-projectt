extends CharacterBody2D
class_name Billion

@export var color: Color = Color.WHITE
@export var base_index: int = 0  # Which base/color this billion belongs to

# Health parameters (overridden by rank in _ready)
var max_health: float = 20.0
var current_health: float = 20.0

# Rank parameters (set before adding to tree via set_rank)
var billion_rank: int = 1
var blaster_damage: float = 4.0  # Scales with rank

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

# Turret
var turret_sprite: Sprite2D

# Firing parameters
@export var fire_interval: float = 1.5  # Seconds between shots (different from base spawn interval)
@export var fire_range: float = 250.0  # Max distance to target before firing
var fire_timer: float = 0.0
var blaster_scene: PackedScene

func _ready():
	# Compute health and damage from rank
	max_health = _get_health_for_rank(billion_rank)
	current_health = max_health
	blaster_damage = _get_damage_for_rank(billion_rank)

	# Set up the visual appearance based on color
	update_visual_color()
	update_health_visual()
	# Set z_index so billions appear behind flags
	z_index = 0
	# Set up turret
	_setup_turret()
	# Load blaster scene
	blaster_scene = load("res://Scene/Blaster.tscn")
	# Randomize initial fire timer so not all billions fire at once
	fire_timer = randf() * fire_interval

func _get_health_for_rank(r: int) -> float:
	return r * 20.0

func _get_damage_for_rank(r: int) -> float:
	return r * 4.0

func _setup_turret():
	turret_sprite = Sprite2D.new()
	turret_sprite.texture = load("res://kenney_pirate-pack/PNG/Default size/Ship parts/cannonMobile.png")
	# Scale turret to be visible, barrel should stick out from the billion circle
	turret_sprite.scale = Vector2(0.85, 0.85)
	# Offset turret so barrel extends past the billion edge
	turret_sprite.offset = Vector2(turret_sprite.texture.get_width() * 0.45, 0)
	add_child(turret_sprite)

func _physics_process(delta: float):
	# Find target flag and apply movement
	var target_pos = _get_nearest_flag_position()

	if target_pos != Vector2.INF:
		_move_toward_flag(target_pos, delta)

	# Handle collisions with other billions (billiard ball physics)
	_handle_billion_collisions()

	# Handle collisions with bases
	_handle_base_collisions()

	# Apply velocity
	velocity = physics_velocity
	move_and_slide()

	# Clamp to arena bounds
	_clamp_to_arena()

	# Update turret rotation to point at nearest opponent
	_update_turret_rotation()

	# Handle firing
	_handle_firing(delta)

func _handle_firing(delta: float):
	fire_timer -= delta
	if fire_timer > 0.0:
		return

	var nearest_target = _get_nearest_target()
	if not nearest_target:
		return

	var dist_to_target = global_position.distance_to(nearest_target.global_position)
	if dist_to_target > fire_range:
		return

	# Fire!
	fire_timer = fire_interval
	_fire_blaster(nearest_target)

func _fire_blaster(target: Node2D):
	if not blaster_scene:
		return

	# Calculate turret barrel end position in global space
	var turret_angle = turret_sprite.rotation
	var barrel_length = turret_sprite.texture.get_width() * 0.45 * turret_sprite.scale.x
	# Account for the billion's own scale (0.5)
	var barrel_offset = Vector2(cos(turret_angle), sin(turret_angle)) * barrel_length * scale.x
	var spawn_pos = global_position + barrel_offset

	# Direction from billion to target
	var fire_direction = (target.global_position - global_position).normalized()

	var blaster = blaster_scene.instantiate() as Blaster
	get_tree().current_scene.add_child(blaster)
	blaster.setup(spawn_pos, fire_direction, color, base_index, blaster_damage)

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

func _handle_base_collisions():
	var bases = get_tree().get_nodes_in_group("bases")
	var base_radius = 40.0  # Base collision radius

	for base in bases:
		if not is_instance_valid(base):
			continue

		var to_billion = global_position - base.global_position
		var distance = to_billion.length()
		var min_distance = base_radius + collision_radius

		if distance < min_distance and distance > 0.001:
			# Collision with base - push billion outward
			var normal = to_billion.normalized()

			# Push billion out of base
			var overlap = min_distance - distance
			global_position += normal * (overlap + 1.0)

			# Reflect velocity off the base (bounce)
			var velocity_toward_base = physics_velocity.dot(-normal)
			if velocity_toward_base > 0:
				physics_velocity += normal * velocity_toward_base * 1.5  # Bounce with some force

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

func _update_turret_rotation():
	if not turret_sprite:
		return

	var nearest_target = _get_nearest_target()
	if nearest_target:
		# Calculate angle from this billion to the nearest target
		var direction = nearest_target.global_position - global_position
		turret_sprite.rotation = direction.angle()

func _get_nearest_opponent() -> Billion:
	# Legacy function - returns nearest opponent billion only
	var billions = get_tree().get_nodes_in_group("billions")
	var nearest: Billion = null
	var nearest_dist: float = INF

	for other in billions:
		if other == self or not is_instance_valid(other):
			continue
		# Opponent = different base_index
		if other.base_index == base_index:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other

	return nearest

func _get_nearest_target() -> Node2D:
	# Returns nearest opponent (billion OR base), whichever is closer
	var nearest_target: Node2D = null
	var nearest_dist: float = INF

	# Check opponent billions
	var billions = get_tree().get_nodes_in_group("billions")
	for other in billions:
		if other == self or not is_instance_valid(other):
			continue
		if other.base_index == base_index:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = other

	# Check opponent bases
	var bases = get_tree().get_nodes_in_group("bases")
	for other_base in bases:
		if not is_instance_valid(other_base):
			continue
		if other_base.base_index == base_index:
			continue
		var dist = global_position.distance_to(other_base.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = other_base

	return nearest_target

func set_billion_color(new_color: Color):
	color = new_color
	update_visual_color()

func set_base_index(index: int):
	base_index = index

func set_rank(new_rank: int):
	billion_rank = new_rank
	# If already in the tree, update stats immediately; otherwise _ready() will do it
	if is_inside_tree():
		max_health = _get_health_for_rank(billion_rank)
		current_health = max_health
		blaster_damage = _get_damage_for_rank(billion_rank)
		update_health_visual()
	if has_node("Visual"):
		get_node("Visual").set_rank(new_rank)

func update_visual_color():
	# Update the Visual node's color if it exists and has the set_visual_color function
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_visual_color"):
			visual.set_visual_color(color)

func take_damage(amount: float):
	current_health -= amount
	update_health_visual()

	if current_health <= 0:
		die()

func die():
	# Remove from the billions group and destroy
	remove_from_group("billions")
	queue_free()

func update_health_visual():
	# Update the Visual node's health ratio if it exists
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_health_ratio"):
			var ratio = clamp(current_health / max_health, 0.0, 1.0)
			visual.set_health_ratio(ratio)

func get_health_ratio() -> float:
	return clamp(current_health / max_health, 0.0, 1.0)
