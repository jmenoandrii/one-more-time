extends Control
class_name PixelRoot

# Root of a pixel-art UI: its children are laid out in art pixels, and it's scaled up by a whole
# number and sized to the screen, so textures, nine-patches and the pixel font stay crisp.

@export var pixel_scale: int = 3

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	scale = Vector2.ONE * pixel_scale
	size = get_viewport().get_visible_rect().size / pixel_scale
