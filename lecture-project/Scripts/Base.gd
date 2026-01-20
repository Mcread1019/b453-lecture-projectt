extends Node2D
class_name Base

@export var base_color: Color = Color.WHITE
@export var spawn_interval: float = 3.0
@export var spawn_radius: float = 51.0  
@export var billion_scene: PackedScene

var spawn_timer: Timer
var spawned_billions: Array[Billion] = []

func _ready():
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
