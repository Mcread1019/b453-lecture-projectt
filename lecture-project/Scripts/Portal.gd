extends Node2D
class_name Portal

# ─── Constants ────────────────────────────────────────────────────────────────
const PORTAL_RADIUS:  float = 36.0   # Visual + interaction radius (px)
const CAPTURE_TIME:   float = 10.0   # Seconds a team must hold to capture
const TELEPORT_TIME:  float = 10.0   # Seconds a captured-team billion must stand to teleport

# ─── State ────────────────────────────────────────────────────────────────────
enum State { INERT, CAPTURED }
var state: State = State.INERT

var owner_base_index: int   = -1
var owner_color:      Color = Color.GRAY

## The other portal in this pair; set by Level after spawning.
var linked_portal: Portal = null

# ─── Capture tracking ─────────────────────────────────────────────────────────
var _capture_index:   int   = -1     # base_index of color currently filling the bar
var _capture_progress: float = 0.0   # seconds elapsed for current capturer
var _capture_color:   Color = Color.WHITE  # cached color for _draw

# ─── Teleport tracking ────────────────────────────────────────────────────────
# Keys = Billion instance_id (int), values = seconds spent standing in portal
var _teleport_timers: Dictionary = {}

# ─── Animation ────────────────────────────────────────────────────────────────
var _spin: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_spin += delta * 1.8
	_update_capture(delta)
	_update_teleports(delta)
	queue_redraw()

# ─── Capture logic ────────────────────────────────────────────────────────────

func _update_capture(delta: float) -> void:
	if state == State.CAPTURED:
		return

	# Count how many billions of each team are inside the circle.
	var counts: Dictionary = {}   # base_index (int) → count (int)
	for b in get_tree().get_nodes_in_group("billions"):
		if not is_instance_valid(b):
			continue
		if global_position.distance_to(b.global_position) <= PORTAL_RADIUS:
			var bi: int = b.base_index
			counts[bi] = counts.get(bi, 0) + 1

	if counts.is_empty():
		# No one inside — slowly decay the progress bar.
		_capture_progress = maxf(0.0, _capture_progress - delta * 0.5)
		return

	if counts.size() > 1:
		# Contested — freeze.
		return

	# Exactly one team inside.
	var ci: int = counts.keys()[0]
	if ci != _capture_index:
		# Different team took over — reset.
		_capture_index    = ci
		_capture_progress = 0.0
		_capture_color    = _color_for_base(ci)
	else:
		_capture_progress += delta
		if _capture_progress >= CAPTURE_TIME:
			_do_capture(ci)

func _do_capture(base_idx: int) -> void:
	state              = State.CAPTURED
	owner_base_index   = base_idx
	owner_color        = _color_for_base(base_idx)
	_capture_progress  = CAPTURE_TIME

# ─── Teleport logic ───────────────────────────────────────────────────────────

func _update_teleports(delta: float) -> void:
	if state != State.CAPTURED:
		return
	if not is_instance_valid(linked_portal):
		return

	# Gather which billions of the owning team are inside right now.
	var inside: Dictionary = {}   # instance_id → Billion
	for b in get_tree().get_nodes_in_group("billions"):
		if not is_instance_valid(b):
			continue
		if b.base_index != owner_base_index:
			continue
		if global_position.distance_to(b.global_position) > PORTAL_RADIUS:
			continue
		inside[b.get_instance_id()] = b

	# Advance timers for billions in range.
	for bid: int in inside:
		var b: Billion = inside[bid]
		var prev: float = _teleport_timers.get(bid, 0.0)
		prev += delta
		if prev >= TELEPORT_TIME:
			# Teleport!
			b.global_position = linked_portal.global_position
			b.reset_physics_velocity()
			_teleport_timers.erase(bid)
		else:
			_teleport_timers[bid] = prev

	# Remove timers for billions that stepped out.
	for bid: int in _teleport_timers.keys():
		if not inside.has(bid):
			_teleport_timers.erase(bid)

# ─── Rendering ────────────────────────────────────────────────────────────────

func _draw() -> void:
	match state:
		State.INERT:    _draw_inert()
		State.CAPTURED: _draw_captured()

func _draw_inert() -> void:
	var ring_col := Color(0.6, 0.6, 0.7, 0.75)
	# Dashed outer ring
	draw_arc(Vector2.ZERO, PORTAL_RADIUS, 0.0, TAU, 64, ring_col, 2.5)
	# Inner cross
	var arm := PORTAL_RADIUS * 0.45
	draw_line(Vector2(-arm, 0), Vector2(arm, 0),  ring_col, 1.5)
	draw_line(Vector2(0, -arm), Vector2(0, arm),  ring_col, 1.5)

	# Capture progress arc (shows as a team-colored fill arc).
	if _capture_progress > 0.0 and _capture_index >= 0:
		var ang := TAU * (_capture_progress / CAPTURE_TIME)
		draw_arc(Vector2.ZERO, PORTAL_RADIUS, -PI * 0.5,
			-PI * 0.5 + ang, 64, _capture_color, 5.0)

func _draw_captured() -> void:
	var c := owner_color

	# Filled semi-transparent interior.
	draw_circle(Vector2.ZERO, PORTAL_RADIUS - 2.0, Color(c.r, c.g, c.b, 0.18))

	# Solid outer ring.
	draw_arc(Vector2.ZERO, PORTAL_RADIUS, 0.0, TAU, 64, c, 3.5)

	# Three spinning inner orbs.
	var orb_r := PORTAL_RADIUS * 0.45
	for i in range(3):
		var ang := _spin + (TAU / 3.0) * i
		draw_circle(Vector2(cos(ang), sin(ang)) * orb_r, 5.0, c)

	# Teleport progress arcs (one per billion currently standing inside).
	for bid: int in _teleport_timers:
		var prog: float = _teleport_timers[bid] / TELEPORT_TIME
		draw_arc(Vector2.ZERO, PORTAL_RADIUS - 7.0,
			-PI * 0.5, -PI * 0.5 + TAU * prog, 48, Color.WHITE, 3.5)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _color_for_base(base_idx: int) -> Color:
	for b in get_tree().get_nodes_in_group("bases"):
		if is_instance_valid(b) and b.base_index == base_idx:
			return b.base_color
	return Color.WHITE
