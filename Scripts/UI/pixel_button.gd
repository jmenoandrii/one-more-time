extends Button
class_name PixelButton

# Menu button in the HUD's pixel style: the bar frame around it, the bar fill inside it
# on hover (dark gold) and press (gold). Meant to live under a PixelRoot.
# The frame and the fill are internal children drawn behind the button's text,
# so children added to the button (an upgrade card's content) still draw on top.

const FRAME := preload("res://UI/HUD/bar_frame.png")
const FILL := preload("res://UI/HUD/bar_fill.png")
const BORDER := 3 # frame thickness, art px

@export var hover_color: Color = Color(0.45, 0.33, 0.02)
@export var pressed_color: Color = Color(1.0, 0.76, 0.055)
@export var pressed_font_color: Color = Color.BLACK

var _frame: NinePatchRect
var _fill: NinePatchRect

func _init() -> void:
	# the look comes from the frame and the fill, the padding keeps the text off the frame
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(BORDER + 2)
		add_theme_stylebox_override(state, empty)

	# frame first: its see-through dark inside would darken the fill otherwise
	_frame = _make_patch(FRAME, BORDER, BORDER, 0)
	_fill = _make_patch(FILL, 0, 1, BORDER)
	_fill.visible = false

	# deferred: the draw mode is updated after these signals
	for s in [&"mouse_entered", &"mouse_exited", &"button_down", &"button_up"]:
		connect(s, func() -> void: _update_fill.call_deferred())

func _ready() -> void:
	add_theme_color_override("font_pressed_color", pressed_font_color)
	add_theme_color_override("font_hover_pressed_color", pressed_font_color)

func _notification(what: int) -> void:
	# a menu hidden under the cursor never gets mouse_exited
	if what == NOTIFICATION_VISIBILITY_CHANGED and _fill:
		_update_fill.call_deferred()

func _make_patch(texture: Texture2D, margin_x: int, margin_y: int, inset: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = texture
	patch.patch_margin_left = margin_x
	patch.patch_margin_right = margin_x
	patch.patch_margin_top = margin_y
	patch.patch_margin_bottom = margin_y
	patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, inset)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.show_behind_parent = true
	add_child(patch, false, Node.INTERNAL_MODE_FRONT)
	return patch

func _update_fill() -> void:
	match get_draw_mode():
		DRAW_HOVER:
			_fill.visible = true
			_fill.modulate = hover_color
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			_fill.visible = true
			_fill.modulate = pressed_color
		_:
			_fill.visible = false
	_frame.modulate = Color(1, 1, 1, 0.5) if disabled else Color.WHITE
