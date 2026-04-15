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

# Minimum centre-to-centre distance between any two bases.
# Equals the base turret fire range so no base starts within firing range
# of an opposing turret.
const MIN_BASE_SEPARATION: float = 300.0

# Flags for each base (max 2 flags per base)
var base_flags: Array = [[], [], [], []]  # Array of arrays, one per base

# Drag state
var dragging_flag: Flag = null
var drag_base_index: int = -1

# Portal state
var _portals: Array = []
var _portal_timer: float = 0.0
const PORTAL_SPAWN_INTERVAL: float = 30.0
const MIN_PORTAL_SEPARATION: float = 200.0
const MIN_PORTAL_BASE_DISTANCE: float = 150.0

# Procedural arena generator (created in _ready before bases spawn)
var arena_gen: ArenaGenerator = null

func _ready():
	# Build the arena first so bases can be placed on valid floor tiles.
	arena_gen = ArenaGenerator.new()
	add_child(arena_gen)
	arena_gen.generate()

	# Camera centred on the arena, zoomed out to show the full grid.
	var camera := Camera2D.new()
	camera.position = Vector2(
		ArenaGenerator.GRID_COLS * ArenaGenerator.TILE_SIZE * 0.5,
		ArenaGenerator.GRID_ROWS * ArenaGenerator.TILE_SIZE * 0.5
	)
	camera.zoom = Vector2(0.82, 0.82)
	add_child(camera)

	spawn_bases()

# Returns four Vector2 positions on valid arena floor tiles that satisfy the
# minimum base-separation constraint, using rejection sampling.
func generate_base_positions() -> Array:
	# clearance=2 ensures 160 px of floor in every direction from a base centre,
	# which is enough for the spawn orbit (51 px) so billions never get trapped
	# between the base edge and a wall.  Fall back to clearance=1 if the arena
	# happened to generate very few deep-interior tiles.
	var floor_positions: Array = arena_gen.get_valid_floor_positions(2, 2)
	if floor_positions.size() < 4:
		floor_positions = arena_gen.get_valid_floor_positions(2, 1)

	if floor_positions.is_empty():
		push_warning("ArenaGenerator returned no valid floor positions; using defaults.")
		return [Vector2(200, 200), Vector2(900, 200), Vector2(200, 500), Vector2(900, 500)]

	var max_restarts:      int = 200
	var max_attempts_each: int = 2000

	for _restart in range(max_restarts):
		var positions: Array = []
		var all_placed := true

		for _i in range(4):
			var placed := false
			for _attempt in range(max_attempts_each):
				var candidate: Vector2 = floor_positions[randi() % floor_positions.size()]
				var valid := true
				for existing in positions:
					if candidate.distance_to(existing) < MIN_BASE_SEPARATION:
						valid = false
						break
				if valid:
					positions.append(candidate)
					placed = true
					break

			if not placed:
				all_placed = false
				break

		if all_placed:
			return positions

	# Fallback: pick the most spread-out positions we can find.
	push_warning("Base placement: MIN_BASE_SEPARATION could not be satisfied; using best effort.")
	floor_positions.shuffle()
	var result: Array = []
	for pos: Vector2 in floor_positions:
		if result.size() >= 4:
			break
		var ok := true
		for existing in result:
			if pos.distance_to(existing) < MIN_BASE_SEPARATION * 0.5:
				ok = false
				break
		if ok:
			result.append(pos)

	while result.size() < 4 and result.size() < floor_positions.size():
		result.append(floor_positions[result.size()])

	return result

func spawn_bases():
	var base_positions: Array = generate_base_positions()

	for i in range(4):
		if not base_scene:
			push_error("Base scene not assigned!")
			return

		var base = base_scene.instantiate() as Base
		base.global_position = base_positions[i]
		base.base_color = base_colors[i]
		base.base_index = i  # Set the base index so billions know which flags to follow
		base.billion_scene = billion_scene
		base.add_to_group("bases")

		add_child(base)

		# Apply the color after adding to tree
		base.set_base_color(base_colors[i])

func _process(delta: float) -> void:
	_portal_timer += delta
	if _portal_timer >= PORTAL_SPAWN_INTERVAL:
		_portal_timer = 0.0
		_spawn_portals()

func _spawn_portals() -> void:
	# Free existing portals.
	for p in _portals:
		if is_instance_valid(p):
			p.queue_free()
	_portals.clear()

	var positions: Array = _get_portal_positions()
	if positions.size() < 4:
		push_warning("Not enough valid positions for portals; skipping spawn.")
		return

	# Create 4 portals.
	for i in range(4):
		var portal: Portal = Portal.new()
		portal.global_position = positions[i]
		add_child(portal)
		_portals.append(portal)

	# Link in pairs: 0↔1 and 2↔3.
	_portals[0].linked_portal = _portals[1]
	_portals[1].linked_portal = _portals[0]
	_portals[2].linked_portal = _portals[3]
	_portals[3].linked_portal = _portals[2]

func _get_portal_positions() -> Array:
	if not arena_gen:
		return []

	var candidates: Array = arena_gen.get_valid_floor_positions(2, 1)
	candidates.shuffle()

	# Gather current base positions for distance filtering.
	var base_positions: Array = []
	for b in get_tree().get_nodes_in_group("bases"):
		if is_instance_valid(b):
			base_positions.append(b.global_position)

	var chosen: Array = []
	for pos: Vector2 in candidates:
		if chosen.size() >= 4:
			break

		# Must be far enough from other chosen portals.
		var ok := true
		for cp: Vector2 in chosen:
			if pos.distance_to(cp) < MIN_PORTAL_SEPARATION:
				ok = false
				break
		if not ok:
			continue

		# Must be far enough from all bases.
		for bp: Vector2 in base_positions:
			if pos.distance_to(bp) < MIN_PORTAL_BASE_DISTANCE:
				ok = false
				break
		if not ok:
			continue

		chosen.append(pos)

	return chosen

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
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_handle_middle_click(mouse_pos)

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

func _handle_middle_click(mouse_pos: Vector2):
	# Middle-click applies damage to the clicked billion (for testing)
	var clicked_billion = _get_billion_at_position(mouse_pos)
	if clicked_billion:
		clicked_billion.take_damage(20.0)  # Apply 20 damage per click

func _get_billion_at_position(pos: Vector2) -> Billion:
	var billions = get_tree().get_nodes_in_group("billions")
	for billion in billions:
		if not is_instance_valid(billion):
			continue
		var distance = pos.distance_to(billion.global_position)
		# Use collision_radius for click detection
		if distance <= billion.collision_radius * 2:  # *2 for easier clicking
			return billion
	return null
