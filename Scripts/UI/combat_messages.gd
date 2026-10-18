extends Control
class_name CombatMessages

# Combat feedback in the HUD: a crit hit pops up next to the crosshair and floats away,
# kill streaks (counted by World) are announced with their bonus ("DOUBLE KILL +5").
#
# Children (edit them in the scene): CritLabel — the look of one crit popup (hidden template,
# duplicated for every crit, so several can be on screen); StreakLabel — the multi-kill announcement.

@export_group("Crit")
@export var crit_text: String = "CRIT! %d" # %d = the damage
@export var crit_jitter: Vector2 = Vector2(6, 3) # random shift of every popup, art px
@export var crit_rise: float = 14.0 # how far it floats up, art px
@export var crit_time: float = 0.7

@export_group("Kill Streak")
# for 2, 3, 4... kills in a row; the last one repeats for longer streaks
@export var streak_names: PackedStringArray = ["DOUBLE KILL", "TRIPLE KILL", "QUAD KILL", "PENTA KILL", "RAMPAGE"]
@export var bonus_text: String = " +%d" # added after the name when the streak gives points
@export var streak_hold: float = 1.2 # on screen before fading, s
@export var streak_fade: float = 0.4

@onready var _crit_template: Label = $CritLabel
@onready var _streak_label: Label = $StreakLabel

var _streak_tween: Tween

func _ready() -> void:
	_crit_template.visible = false
	_streak_label.visible = false
	GameEvents.enemy_hit.connect(_on_enemy_hit)
	GameEvents.kill_streak.connect(_on_kill_streak)

func _on_enemy_hit(damage: float, is_crit: bool, _killed: bool) -> void:
	if not is_crit:
		return
	var label := _crit_template.duplicate() as Label
	label.text = crit_text % roundi(damage) if "%d" in crit_text else crit_text
	add_child(label)
	label.visible = true
	label.position += Vector2(randf_range(-crit_jitter.x, crit_jitter.x), randf_range(-crit_jitter.y, crit_jitter.y))
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.6

	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - crit_rise, crit_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, crit_time * 0.4).set_delay(crit_time * 0.6)
	tween.tween_callback(label.queue_free)

func _on_kill_streak(kills: int, bonus: int) -> void:
	if streak_names.is_empty():
		return
	_streak_label.text = streak_names[mini(kills - 2, streak_names.size() - 1)]
	if bonus > 0:
		_streak_label.text += bonus_text % bonus
	_streak_label.visible = true
	_streak_label.modulate.a = 1.0
	_streak_label.pivot_offset = _streak_label.size * 0.5
	_streak_label.scale = Vector2.ONE * 2.0

	if _streak_tween:
		_streak_tween.kill()
	_streak_tween = create_tween()
	_streak_tween.tween_property(_streak_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_streak_tween.tween_interval(streak_hold)
	_streak_tween.tween_property(_streak_label, "modulate:a", 0.0, streak_fade)
	_streak_tween.tween_callback(_streak_label.hide)
