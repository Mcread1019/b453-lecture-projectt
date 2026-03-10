extends Node2D
class_name Base

@export var base_color: Color = Color.WHITE
@export var spawn_interval: float = 3.0
@export var spawn_radius: float = 51.0
@export var billion_scene: PackedScene
@export var base_index: int = 0  # Index of this base (0-3)

# Turret parameters
@export var turret_rotation_speed: float = 2.0  # Radians per second
@export var turret_fire_interval: float = 2.0  # Different from billion fire interval (1.5)
@export var turret_fire_range: float = 400.0  # Range to start firing

# Health parameters
@export var max_health: float = 500.0
var current_health: float = 500.0
@export var collision_radius: float = 40.0  # For blaster collision detection

# Experience parameters
@export var xp_threshold: float = 100.0  # XP needed to rank up
var current_xp: float = 0.0
@export var xp_per_kill: float = 25.0  # XP gained when killing an opponent billion

var spawn_timer: Timer
var spawned_billions: Array[Billion] = []

# Turret
var turret_sprite: Sprite2D
var turret_current_rotation: float = 0.0
var turret_fire_timer: float = 0.0
var base_blaster_scene: PackedScene

func _ready():
	# Initialize health
	current_health = max_health

	# Set up visual appearance
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_visual_color"):
			visual.set_visual_color(base_color)

	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

	# Set up turret
	_setup_turret()

	# Load base blaster scene
	base_blaster_scene = load("res://Scene/BaseBlaster.tscn")

	# Randomize initial fire timer
	turret_fire_timer = randf() * turret_fire_interval

	# Update visual bars
	_update_health_visual()
	_update_xp_visual()

func _setup_turret():
	turret_sprite = Sprite2D.new()
	turret_sprite.texture = load("res://kenney_tower-defense-top-down/PNG/Default size/towerDefense_tile203.png")
	# Scale turret to fit on the base
	turret_sprite.scale = Vector2(1.2, 1.2)
	# The turret image points up, so we need to offset rotation by -PI/2 to make 0 = right
	# Offset so barrel extends past the base edge
	turret_sprite.offset = Vector2(0, -turret_sprite.texture.get_height() * 0.3)
	add_child(turret_sprite)
	# Set z_index so turret appears above base visual
	turret_sprite.z_index = 1

func _process(delta: float):
	_update_turret_rotation(delta)
	_handle_turret_firing(delta)

func _update_turret_rotation(delta: float):
	if not turret_sprite:
		return

	var nearest_opponent = _get_nearest_opponent_billion()
	if not nearest_opponent:
		return

	# Calculate target angle (turret image points up, so subtract PI/2)
	var direction = nearest_opponent.global_position - global_position
	var target_angle = direction.angle() + PI / 2  # Adjust because turret points up

	# Calculate angle difference
	var angle_diff = wrapf(target_angle - turret_current_rotation, -PI, PI)

	# Rotate at fixed speed toward target
	var max_rotation = turret_rotation_speed * delta
	if abs(angle_diff) <= max_rotation:
		turret_current_rotation = target_angle
	else:
		turret_current_rotation += sign(angle_diff) * max_rotation

	turret_sprite.rotation = turret_current_rotation

func _get_nearest_opponent_billion() -> Billion:
	var billions = get_tree().get_nodes_in_group("billions")
	var nearest: Billion = null
	var nearest_dist: float = INF

	for billion in billions:
		if not is_instance_valid(billion):
			continue
		# Opponent = different base_index
		if billion.base_index == base_index:
			continue
		var dist = global_position.distance_to(billion.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = billion

	return nearest

func _handle_turret_firing(delta: float):
	turret_fire_timer -= delta
	if turret_fire_timer > 0.0:
		return

	var nearest_opponent = _get_nearest_opponent_billion()
	if not nearest_opponent:
		return

	var dist_to_opponent = global_position.distance_to(nearest_opponent.global_position)
	if dist_to_opponent > turret_fire_range:
		return

	# Fire!
	turret_fire_timer = turret_fire_interval
	_fire_base_blaster(nearest_opponent)

func _fire_base_blaster(target: Billion):
	if not base_blaster_scene:
		return

	# Calculate turret barrel end position
	# Turret image points up, rotated by turret_current_rotation
	# The barrel direction is turret_current_rotation - PI/2 (to convert from "up" to actual direction)
	var fire_angle = turret_current_rotation - PI / 2
	var barrel_length = turret_sprite.texture.get_height() * 0.3 * turret_sprite.scale.y
	var barrel_offset = Vector2(cos(fire_angle), sin(fire_angle)) * barrel_length
	var spawn_pos = global_position + barrel_offset

	# Direction from base to target
	var fire_direction = (target.global_position - global_position).normalized()

	var blaster = base_blaster_scene.instantiate() as BaseBlaster
	get_tree().current_scene.add_child(blaster)
	blaster.setup(spawn_pos, fire_direction, base_color, base_index)

func _on_spawn_timer_timeout():
	spawn_billion()

func spawn_billion():
	if not billion_scene:
		push_error("No billion scene assigned to base!")
		return

	var spawn_position = find_valid_spawn_position()
	if spawn_position == Vector2.ZERO:
		print("Could not find valid spawn position")
		return

	var billion = billion_scene.instantiate() as Billion
	billion.global_position = spawn_position
	billion.set_billion_color(base_color)
	billion.set_base_index(base_index)  # Set the base index so billion knows which flags to follow

	# Add to the parent (level) instead of to the base itself
	get_parent().add_child(billion)

	billion.add_to_group("billions")

	spawned_billions.append(billion)

func find_valid_spawn_position() -> Vector2:
	var max_attempts = 20
	var spawn_distance = spawn_radius
	
	for attempt in range(max_attempts):
		# Generate random angle
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * spawn_distance
		var test_position = global_position + offset
		
		# Check if position is valid (not overlapping)
		if is_position_valid(test_position):
			return test_position
	
	# If no valid position found, return zero vector
	return Vector2.ZERO

func is_position_valid(test_pos: Vector2) -> bool:
	var check_radius = 1.0  # Smaller radius for tight clustering
	
	# Define arena boundaries 
	
	var arena_left = 80    
	var arena_right = 1070  
	var arena_top = 75     
	var arena_bottom = 565   
	
	# Check if position is within arena bounds
	if test_pos.x < arena_left or test_pos.x > arena_right:
		return false
	if test_pos.y < arena_top or test_pos.y > arena_bottom:
		return false
	
	# Check against other bases
	var bases = get_tree().get_nodes_in_group("bases")
	
	for base in bases:
		if base != self:
			var distance = test_pos.distance_to(base.global_position)
			if distance < check_radius + 60.0:  # Keep bases clear
				return false
	
	# Check against existing billions
	var billions = get_tree().get_nodes_in_group("billions")
	
	for billion in billions:
		var distance = test_pos.distance_to(billion.global_position)
		# Minimal spacing - billions can touch (barely prevents overlap)
		if distance < 20.0:  # Just enough to prevent exact overlapping
			return false
	
	return true

func set_base_color(new_color: Color):
	base_color = new_color
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_visual_color"):
			visual.set_visual_color(base_color)

func take_damage(amount: float):
	current_health -= amount
	_update_health_visual()

	if current_health <= 0:
		die()

func die():
	# Stop spawning
	if spawn_timer:
		spawn_timer.stop()

	# Remove from bases group and destroy
	remove_from_group("bases")
	queue_free()

func add_xp(amount: float):
	current_xp += amount
	_update_xp_visual()
	# Note: rank up logic could be added here in the future

func get_health_ratio() -> float:
	return clamp(current_health / max_health, 0.0, 1.0)

func get_xp_ratio() -> float:
	return clamp(current_xp / xp_threshold, 0.0, 1.0)

func _update_health_visual():
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_health_ratio"):
			visual.set_health_ratio(get_health_ratio())

func _update_xp_visual():
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual.has_method("set_xp_ratio"):
			visual.set_xp_ratio(get_xp_ratio())
