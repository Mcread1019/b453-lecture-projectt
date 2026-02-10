extends Node2D
class_name Flag

@export var flag_color: Color = Color.WHITE
@export var base_index: int = 0  # Which base this flag belongs to

# Flag textures for each color
var flag_textures = {
	"green": "res://kenney_platformer-art-deluxe/Base pack/Items/flagGreen.png",
	"yellow": "res://kenney_platformer-art-deluxe/Base pack/Items/flagYellow.png",
	"red": "res://kenney_platformer-art-deluxe/Base pack/Items/flagRed.png",
	"blue": "res://kenney_platformer-art-deluxe/Base pack/Items/flagBlue.png"
}

var sprite: Sprite2D
var is_being_dragged: bool = false
var drag_target: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("flags")
	# Set z_index so flags appear in front of billions
	z_index = 1
	_setup_sprite()

func _setup_sprite():
	sprite = Sprite2D.new()
	add_child(sprite)
	_update_texture()
	# Offset so position references the bottom of the flag post
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2)

func _update_texture():
	var texture_path = _get_texture_for_color()
	sprite.texture = load(texture_path)

func _get_texture_for_color() -> String:
	# Determine which texture to use based on base_index
	match base_index:
		0:
			return flag_textures["green"]
		1:
			return flag_textures["yellow"]
		2:
			return flag_textures["red"]
		3:
			return flag_textures["blue"]
		_:
			return flag_textures["green"]

func set_flag_color(new_color: Color, new_base_index: int):
	flag_color = new_color
	base_index = new_base_index
	if sprite:
		_update_texture()
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2)

func start_drag(target_pos: Vector2):
	is_being_dragged = true
	drag_target = target_pos
	queue_redraw()

func update_drag(target_pos: Vector2):
	drag_target = target_pos
	queue_redraw()

func end_drag():
	is_being_dragged = false
	queue_redraw()

func _draw():
	# Draw a line from flag to mouse position while dragging
	if is_being_dragged:
		var line_end = drag_target - global_position
		draw_line(Vector2.ZERO, line_end, flag_color, 3.0)

func get_click_radius() -> float:
	# Return a reasonable click detection radius
	if sprite and sprite.texture:
		return max(sprite.texture.get_width(), sprite.texture.get_height()) / 2
	return 20.0
