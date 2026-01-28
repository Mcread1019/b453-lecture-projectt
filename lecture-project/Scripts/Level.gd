extends Node2D

@export var base_scene: PackedScene
@export var billion_scene: PackedScene
@export var flag_scene: PackedScene

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

# Flags for each base (max 2 flags per base)
var base_flags: Array = [[], [], [], []]  # Array of arrays, one per base

# Drag state
var dragging_flag: Flag = null
var drag_base_index: int = -1

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

func _input(event: InputEvent):
	# Determine which base is being controlled based on key held
	var base_index = _get_active_base_index()

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		var mouse_pos = get_global_mouse_position()

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_mouse_down(base_index, mouse_pos)
			else:
				_handle_mouse_up(base_index, mouse_pos)

	elif event is InputEventMouseMotion:
		if dragging_flag:
			var mouse_pos = get_global_mouse_position()
			dragging_flag.update_drag(mouse_pos)

func _get_active_base_index() -> int:
	# Check which number key is held to determine base
	# 1 = Green (base 0), 2 = Yellow (base 1), 3 = Red (base 2), 4 = Blue (base 3)
	if Input.is_key_pressed(KEY_1):
		return 0
	elif Input.is_key_pressed(KEY_2):
		return 1
	elif Input.is_key_pressed(KEY_3):
		return 2
	elif Input.is_key_pressed(KEY_4):
		return 3
	# Default: no base selected, return -1
	return -1

func _handle_mouse_down(base_index: int, mouse_pos: Vector2):
	if base_index < 0 or base_index > 3:
		return  # No valid base selected

	# Check if clicking on an existing flag of this base
	var clicked_flag = _get_flag_at_position(base_index, mouse_pos)

	if clicked_flag:
		# Start dragging this flag (click and drag behavior)
		dragging_flag = clicked_flag
		drag_base_index = base_index
		dragging_flag.start_drag(mouse_pos)
	else:
		# Place or move a flag
		var flags = base_flags[base_index]

		if flags.size() < 2:
			# Place a new flag (first or second flag)
			_place_flag(base_index, mouse_pos)
		else:
			# Move the nearest flag immediately to this position
			var nearest_flag = _get_nearest_flag(base_index, mouse_pos)
			if nearest_flag:
				nearest_flag.global_position = mouse_pos

func _handle_mouse_up(base_index: int, mouse_pos: Vector2):
	if dragging_flag:
		dragging_flag.end_drag()
		dragging_flag.global_position = mouse_pos
		dragging_flag = null
		drag_base_index = -1

func _get_flag_at_position(base_index: int, pos: Vector2) -> Flag:
	var flags = base_flags[base_index]
	for flag in flags:
		if not is_instance_valid(flag):
			continue
		var distance = pos.distance_to(flag.global_position)
		if distance <= flag.get_click_radius():
			return flag
	return null

func _get_nearest_flag(base_index: int, pos: Vector2) -> Flag:
	var flags = base_flags[base_index]
	var nearest: Flag = null
	var nearest_dist: float = INF

	for flag in flags:
		if not is_instance_valid(flag):
			continue
		var dist = pos.distance_to(flag.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = flag

	return nearest

func _place_flag(base_index: int, pos: Vector2):
	if not flag_scene:
		push_error("Flag scene not assigned!")
		return

	var flag = flag_scene.instantiate() as Flag
	flag.global_position = pos
	flag.set_flag_color(base_colors[base_index], base_index)

	add_child(flag)
	base_flags[base_index].append(flag)
