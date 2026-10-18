extends CanvasLayer

# Shown when the boss is dead: "YOU WIN" with the run's loops and points, then a new run
# (button or Enter / Space). In the HUD's pixel style, built in code like the upgrade screen.

const THEME := preload("res://UI/HUD/hud_theme.tres")
const GOLD := Color(1.0, 0.76, 0.055)
const DIM_COLOR := Color(1, 1, 1, 0.5)

@export var delay: float = 1.5 # after the boss dies, before the screen shows
@export var fade_time: float = 0.6

var _accepting := false
var _done := false
var _panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameEvents.boss_defeated.connect(_open)

func _open() -> void:
	# taken now: the run is reset when the player leaves this screen
	var loops := RunState.loop + 1
	var points := RunState.xp
	await get_tree().create_timer(delay).timeout

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build(loops, points)
	visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, fade_time)
	await tween.finished
	_accepting = true

func _build(loops: int, points: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := PixelRoot.new()
	root.theme = THEME
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	_panel = column

	column.add_child(_label("YOU WIN", GOLD, 18))
	column.add_child(_label("THE GOBLIN KING IS DEAD", DIM_COLOR))
	column.add_child(_label("LOOPS: %d" % loops))
	column.add_child(_label("POINTS: %d" % points))

	var button := PixelButton.new()
	button.text = "NEW RUN"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(84, 0)
	button.pressed.connect(_new_run)
	column.add_child(button)

func _label(text: String, color := Color.WHITE, font_size := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"): # no pause menu over it
		get_viewport().set_input_as_handled()
	elif _accepting and (event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_new_run()

func _new_run() -> void:
	if not _accepting or _done:
		return
	_done = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	RunState.win_run()
