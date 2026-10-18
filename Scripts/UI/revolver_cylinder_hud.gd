extends TextureRect

# One revolver cylinder in the HUD: one texture per loaded round count (textures[0] = empty .. [6] = full).
# Driven by revolver_cylinders_hud.gd. A shot spins it one chamber counter-clockwise and pulses it,
# a reloaded round spins it one chamber back.
#
# How the textures are drawn: the chamber at the top fires next, the loaded rounds go clockwise
# from it (5 rounds = every chamber but the one left of the top).
# The spin swaps the texture right away and starts it turned by one chamber, so the rounds
# stay where they were, then turns it back to 0° — at rest the pixel art is never rotated.

@export var textures: Array[Texture2D] = []
@export var chambers: int = 6

@export_group("Spin")
@export var spin_time: float = 0.12
@export var spin_snap_degrees: float = 0.0 # > 0: turns in steps of this angle, chunkier for pixel art

@export_group("Pulse")
@export var pulse_scale: float = 1.2
@export var pulse_in_time: float = 0.04
@export var pulse_out_time: float = 0.12

var _rounds := -1 # -1 = nothing shown yet
var _spin_tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art: no blur when scaled or turned
	resized.connect(_center_pivot)
	_center_pivot()

func _center_pivot() -> void:
	pivot_offset = size / 2.0

# animate = false for a weapon switch: just show the count
func set_rounds(rounds: int, animate: bool) -> void:
	var old := _rounds
	_rounds = rounds
	if not textures.is_empty():
		# more rounds than textures (extended mag) -> stays full until it fits
		texture = textures[clampi(rounds, 0, textures.size() - 1)]

	if not animate or old == -1:
		return
	if rounds < old: # shot
		_spin(1.0)
		_pulse()
	elif rounds > old: # reload
		_spin(-1.0)

# direction 1 = clockwise start, turns back counter-clockwise (2D rotation is clockwise on screen)
func _spin(direction: float) -> void:
	if _spin_tween:
		_spin_tween.kill()
	_spin_tween = create_tween()
	_spin_tween.tween_method(_set_spin, direction * 360.0 / chambers, 0.0, spin_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_spin(degrees: float) -> void:
	if spin_snap_degrees > 0.0:
		degrees = snappedf(degrees, spin_snap_degrees)
	rotation_degrees = degrees

func _pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * pulse_scale, pulse_in_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, pulse_out_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
