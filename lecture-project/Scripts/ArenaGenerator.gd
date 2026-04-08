extends Node2D
class_name ArenaGenerator

# ─── Grid constants ───────────────────────────────────────────────────────────
const TILE_SIZE: int  = 64
const GRID_COLS: int  = 22
const GRID_ROWS: int  = 13

# ─── Grid data ────────────────────────────────────────────────────────────────
# grid[row][col] = true  →  traversable floor
#                = false →  solid wall
var grid: Array = []

# Each entry is a Rect2i(col, row, width, height) describing one obstacle block.
# Obstacle cells are floor tiles that have been filled with a solid block.
var obstacles: Array = []

var _floor_tex: Texture2D
var _wall_tex:  Texture2D

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("arena_generator")
	_floor_tex = load("res://kenney_top-down-shooter/PNG/Tiles/tile_93.png")
	_wall_tex  = load("res://kenney_top-down-shooter/PNG/Tiles/tile_08.png")

# Call this once from Level._ready() before spawning bases.
func generate() -> void:
	_init_grid()
	_place_rooms()
	_ensure_connectivity()
	_place_obstacles()
	queue_redraw()
	_build_collisions()

# ─── Generation ───────────────────────────────────────────────────────────────

func _init_grid() -> void:
	grid = []
	for _r in range(GRID_ROWS):
		var row: Array = []
		for _c in range(GRID_COLS):
			row.append(false)
		grid.append(row)

func _place_rooms() -> void:
	var num_rooms := randi_range(4, 7)
	var room_centers: Array = []

	for _i in range(num_rooms):
		var w := randi_range(6, 11)
		var h := randi_range(5, 7)
		# Leave a 1-tile border of solid wall around the whole grid.
		var col := randi_range(1, GRID_COLS - w - 1)
		var row := randi_range(1, GRID_ROWS - h - 1)

		for r in range(row, row + h):
			for c in range(col, col + w):
				grid[r][c] = true

		room_centers.append(Vector2i(col + w / 2, row + h / 2))

	# Sort by x so corridors run roughly left→right.
	room_centers.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x
	)

	# Connect each consecutive pair with a 2-tile-wide L-shaped corridor.
	for i in range(1, room_centers.size()):
		_carve_corridor(room_centers[i - 1], room_centers[i])

# Carve an L-shaped corridor (horizontal then vertical) between two grid points.
func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var step_x := 1 if to.x > from.x else -1
	var cx     := from.x
	while cx != to.x:
		_place_corridor_tile(cx, from.y, false)
		cx += step_x

	var step_y := 1 if to.y > from.y else -1
	var cy     := from.y
	while cy != to.y:
		_place_corridor_tile(to.x, cy, true)
		cy += step_y

	_place_corridor_tile(to.x, to.y, false)

# Place a 2-wide corridor tile at (col, row).
# If `vertical` is true the second tile is col+1, otherwise row+1.
func _place_corridor_tile(col: int, row: int, vertical: bool) -> void:
	for i in range(2):
		var c := col + (i if vertical else 0)
		var r := row + (0 if vertical else i)
		c = clampi(c, 1, GRID_COLS - 2)
		r = clampi(r, 1, GRID_ROWS - 2)
		grid[r][c] = true

# Flood-fill from the first floor tile; discard any unreachable floor tiles.
func _ensure_connectivity() -> void:
	var start := Vector2i(-1, -1)
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if grid[r][c]:
				start = Vector2i(c, r)
				break
		if start.x >= 0:
			break

	if start.x < 0:
		return  # Nothing to do.

	var visited: Array = []
	for _r in range(GRID_ROWS):
		var vr: Array = []
		for _c in range(GRID_COLS):
			vr.append(false)
		visited.append(vr)

	var queue: Array = [start]
	visited[start.y][start.x] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in dirs:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
				if grid[ny][nx] and not visited[ny][nx]:
					visited[ny][nx] = true
					queue.append(Vector2i(nx, ny))

	# Remove isolated floor tiles.
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if grid[r][c] and not visited[r][c]:
				grid[r][c] = false

# Place 2×1 or 1×2 obstacle blocks on valid floor tiles.
func _place_obstacles() -> void:
	obstacles = []
	var target := randi_range(3, 6)
	var attempts := 0

	while obstacles.size() < target and attempts < 300:
		attempts += 1

		var horiz := randf() > 0.5
		var ow    := 2 if horiz else 1
		var oh    := 1 if horiz else 2

		var col := randi_range(2, GRID_COLS - ow - 2)
		var row := randi_range(2, GRID_ROWS - oh - 2)

		# All cells must be floor.
		var all_floor := true
		for dr in range(oh):
			for dc in range(ow):
				if not grid[row + dr][col + dc]:
					all_floor = false
					break
		if not all_floor:
			continue

		# No overlap (+ 1-tile gap) with existing obstacles.
		var new_rect := Rect2i(col, row, ow, oh)
		var overlaps := false
		for obs: Rect2i in obstacles:
			if obs.grow(1).intersects(new_rect):
				overlaps = true
				break
		if overlaps:
			continue

		# Tentatively add the obstacle and verify full connectivity is preserved.
		obstacles.append(new_rect)
		if not _traversable_tiles_are_connected():
			obstacles.pop_back()
			continue

# ─── Rendering ────────────────────────────────────────────────────────────────

func _draw() -> void:
	if grid.is_empty() or not _floor_tex or not _wall_tex:
		return

	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var pos  := Vector2(c * TILE_SIZE, r * TILE_SIZE)
			var rect := Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))

			if _is_obstacle_cell(c, r):
				# Draw floor beneath, then the obstacle block on top.
				draw_texture_rect(_floor_tex, rect, false)
				draw_texture_rect(_wall_tex,  rect, false, Color(0.85, 0.85, 0.85))
			elif grid[r][c]:
				draw_texture_rect(_floor_tex, rect, false)
			else:
				draw_texture_rect(_wall_tex, rect, false)

# ─── Collision ────────────────────────────────────────────────────────────────

func _build_collisions() -> void:
	var wall_body := StaticBody2D.new()
	wall_body.name = "WallCollision"
	add_child(wall_body)

	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			var needs_col := false

			if not grid[r][c]:
				# Wall tile — only needs a collider if it touches a floor tile.
				for d: Vector2i in dirs:
					var nx: int = c + d.x
					var ny: int = r + d.y
					if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
						if grid[ny][nx]:
							needs_col = true
							break
			elif _is_obstacle_cell(c, r):
				# Obstacle tile — always needs a collider.
				needs_col = true

			if needs_col:
				var shape := CollisionShape2D.new()
				var rect  := RectangleShape2D.new()
				rect.size     = Vector2(TILE_SIZE, TILE_SIZE)
				shape.position = Vector2(
					c * TILE_SIZE + TILE_SIZE * 0.5,
					r * TILE_SIZE + TILE_SIZE * 0.5
				)
				shape.shape = rect
				wall_body.add_child(shape)

# ─── Internal helpers ─────────────────────────────────────────────────────────

# Returns true only when all traversable (floor, non-obstacle) tiles form a
# single connected component — used to validate obstacle placements.
func _traversable_tiles_are_connected() -> bool:
	# Find any traversable start tile.
	var start := Vector2i(-1, -1)
	var total  := 0
	for r in range(GRID_ROWS):
		for c in range(GRID_COLS):
			if grid[r][c] and not _is_obstacle_cell(c, r):
				total += 1
				if start.x < 0:
					start = Vector2i(c, r)

	if total == 0:
		return true  # Nothing to connect.

	# BFS from start.
	var visited := {}
	var queue: Array = [start]
	visited[start] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in dirs:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx >= 0 and nx < GRID_COLS and ny >= 0 and ny < GRID_ROWS:
				var np := Vector2i(nx, ny)
				if grid[ny][nx] and not _is_obstacle_cell(nx, ny) and not visited.has(np):
					visited[np] = true
					queue.append(np)

	return visited.size() == total

func _is_obstacle_cell(col: int, row: int) -> bool:
	for obs: Rect2i in obstacles:
		if obs.has_point(Vector2i(col, row)):
			return true
	return false

# ─── Public API ───────────────────────────────────────────────────────────────

## Returns true when `world_pos` sits on a traversable floor tile (not a wall
## and not an obstacle block).
func is_traversable_world(world_pos: Vector2) -> bool:
	var t := world_to_tile(world_pos)
	if t.x < 0 or t.x >= GRID_COLS or t.y < 0 or t.y >= GRID_ROWS:
		return false
	if not grid[t.y][t.x]:
		return false
	return not _is_obstacle_cell(t.x, t.y)

## Convert a world-space position to tile coordinates.
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)

## Return the world-space centre of a tile.
func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile.y * TILE_SIZE + TILE_SIZE * 0.5
	)

## Return world-space centres of all valid floor tiles (not walls, not
## obstacles) that are at least `margin` tiles away from the grid edge and have
## at least `clearance` tiles of floor in every direction (prevents bases from
## being placed right next to an internal wall).
func get_valid_floor_positions(margin: int = 2, clearance: int = 1) -> Array:
	var positions: Array = []
	for r in range(margin, GRID_ROWS - margin):
		for c in range(margin, GRID_COLS - margin):
			if not grid[r][c] or _is_obstacle_cell(c, r):
				continue
			# Every tile within `clearance` steps must also be floor.
			var clear := true
			for dr in range(-clearance, clearance + 1):
				for dc in range(-clearance, clearance + 1):
					var nr := r + dr
					var nc := c + dc
					if nr < 0 or nr >= GRID_ROWS or nc < 0 or nc >= GRID_COLS:
						clear = false
						break
					if not grid[nr][nc]:
						clear = false
						break
				if not clear:
					break
			if clear:
				positions.append(tile_to_world_center(Vector2i(c, r)))
	return positions

## Total pixel width of the grid.
func total_width() -> float:
	return GRID_COLS * TILE_SIZE

## Total pixel height of the grid.
func total_height() -> float:
	return GRID_ROWS * TILE_SIZE
