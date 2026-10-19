extends AudioStreamPlayer3D
class_name GoblinGrowl

# A goblin's growls: now and then while it is after the player, silent otherwise.
# Set up in the scene with Godot's own nodes:
# - stream: an AudioStreamRandomizer — several growls, random pitch / volume, no repeats in a row;
# - max_distance: how far it's heard;
# - the GrowlTimer child: the pause between growls (randomized here every time).
# The monster sets `active`; at most max_at_once goblins growl at the same time,
# and the ones too far to be heard don't take a place.

@export var interval: Vector2 = Vector2(6.0, 15.0) # random pause between growls, s
@export var alert_delay: Vector2 = Vector2(0.2, 1.0) # the first growl after it notices the player, s
@export var max_at_once: int = 3

static var _growling := 0 # goblins growling right now, over the whole level

@onready var _timer: Timer = $GrowlTimer

var active := false: set = set_active
var _counted := false # this one is among _growling

func _ready() -> void:
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	finished.connect(_release)

func _exit_tree() -> void:
	_release() # killed mid-growl

func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if not is_node_ready():
		return
	if active:
		_timer.start(randf_range(alert_delay.x, alert_delay.y))
	else:
		_timer.stop() # a growl already playing finishes

func _on_timer() -> void:
	if not active:
		return
	if not _counted and _growling < max_at_once and _is_audible():
		_growling += 1
		_counted = true
		play()
	_timer.start(randf_range(interval.x, interval.y))

func _release() -> void:
	if _counted:
		_growling -= 1
		_counted = false

func _is_audible() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or max_distance <= 0.0 \
		or camera.global_position.distance_to(global_position) <= max_distance
