extends CanvasLayer

# The boss's health on top of the screen, in the HUD's pixel style. Hidden until the boss reports
# its health. Children (edit them in the scene): %BossName, %BossFill, %BossTrail (the white
# "lost health" part that waits, then catches up).

@export var trail_delay: float = 0.35
@export var trail_time: float = 0.4

@onready var _fill: TextureProgressBar = %BossFill
@onready var _trail: TextureProgressBar = %BossTrail
@onready var _root: Control = $Root

var _trail_tween: Tween

func _enter_tree() -> void:
	# connected before the boss's _ready sends the first value
	GameEvents.boss_health_changed.connect(_on_boss_health_changed)
	GameEvents.boss_defeated.connect(_on_boss_defeated)

func _ready() -> void:
	_root.visible = false

func _on_boss_health_changed(current: float, maximum: float) -> void:
	if not is_node_ready():
		await ready
	_root.visible = true
	_fill.max_value = maximum
	_trail.max_value = maximum
	var lost := current < _trail.value
	_fill.value = current
	if _trail_tween:
		_trail_tween.kill()
	if lost:
		_trail_tween = create_tween()
		_trail_tween.tween_interval(trail_delay)
		_trail_tween.tween_property(_trail, "value", current, trail_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_trail.value = current

func _on_boss_defeated() -> void:
	_root.visible = false
