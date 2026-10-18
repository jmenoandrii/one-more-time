extends Control
class_name ClockHUD

# Level timer in the HUD: a pixel stopwatch whose face darkens clockwise as the time goes,
# with the seconds left as one number on it. Hidden until the level timer starts, then drops in
# from above onto its place. Under warning_time the number turns red and the clock jumps
# on a spring every second. Laid out in art pixels, meant to live under a PixelRoot.
#
# Children (edit them in the scene): Body — moved / scaled by the jumps, pivot at its bottom;
# Body/Icon — the clock, its ShaderMaterial darkens the face; Body/Number — the seconds left.

@export var warning_time: float = 15.0 # sec left when the clock turns red and starts jumping
@export var warning_color: Color = Color(0.9, 0.2, 0.2)

@export_group("Jump")
@export var jump_height: float = 6.0 # art px
@export var spring_stiffness: float = 300.0 # higher = faster bounce
@export var spring_damping: float = 10.0 # lower = more wobble
@export var squash: float = 0.25 # stretch while flying up, squash when landing

@export_group("Drop In")
@export var drop_from: float = 50.0 # starts this far above its place, art px
@export var drop_stiffness: float = 200.0
@export var drop_damping: float = 14.0

@onready var _body: Control = $Body
@onready var _number: Label = $Body/Number
@onready var _material: ShaderMaterial = $Body/Icon.material

var _number_color: Color # the Number's color from the scene, restored after the warning
var _total := 0.0
var _last_second := -1
var _offset := 0.0 # vertical, art px; < 0 = up
var _velocity := 0.0
var _stiffness := 0.0
var _damping := 0.0

func _enter_tree() -> void:
	# connected before the level's _ready sends the first values
	GameEvents.level_time_set.connect(_on_level_time_set)
	GameEvents.time_changed.connect(_on_time_changed)
	GameEvents.level_started.connect(_on_level_started)

func _ready() -> void:
	_number_color = _number.get_theme_color("font_color")
	visible = false
	set_process(false)

func _on_level_time_set(total: float) -> void:
	_total = total
	_last_second = -1

func _on_level_started() -> void:
	visible = true
	_offset = -drop_from
	_velocity = 0.0
	_set_spring(drop_stiffness, drop_damping)
	_apply()

func _on_time_changed(time_left: float) -> void:
	if not is_node_ready():
		return
	var seconds := ceili(time_left) # 0 only when the time is really up
	_number.text = str(seconds)
	_material.set_shader_parameter(&"progress", 1.0 - time_left / _total if _total > 0.0 else 0.0)

	var warning := time_left <= warning_time and time_left > 0.0
	_number.add_theme_color_override("font_color", warning_color if warning else _number_color)

	# one jump per second while in the warning (not on the very first value)
	if visible and warning and seconds != _last_second and _last_second != -1:
		_jump()
	_last_second = seconds

func _jump() -> void:
	# for a damped spring the peak is about speed / sqrt(stiffness)
	_velocity = -jump_height * sqrt(spring_stiffness)
	_set_spring(spring_stiffness, spring_damping)

func _set_spring(stiffness: float, damping: float) -> void:
	_stiffness = stiffness
	_damping = damping
	set_process(true)

func _process(delta: float) -> void:
	_velocity += (-_stiffness * _offset - _damping * _velocity) * delta
	_offset += _velocity * delta
	_apply()

	if absf(_offset) < 0.05 and absf(_velocity) < 0.5:
		_offset = 0.0
		_velocity = 0.0
		_apply()
		set_process(false)

func _apply() -> void:
	# taller while flying (either way), flatter while pressed below its place after a landing
	var stretch: float
	if _offset > 0.0:
		stretch = -clampf(_offset / (jump_height * 0.5), 0.0, 1.0) * squash
	else:
		stretch = clampf(absf(_velocity) / (jump_height * sqrt(spring_stiffness)), 0.0, 1.0) * squash
	_body.scale = Vector2(1.0 - stretch * 0.5, 1.0 + stretch)
	_body.position.y = roundf(_offset) # whole art pixels, stays crisp
