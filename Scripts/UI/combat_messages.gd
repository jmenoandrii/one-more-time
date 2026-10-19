extends Control
class_name CombatMessages

# Combat feedback in the HUD: a crit hit pops up next to the crosshair and floats away,
# kill streaks (counted by World) are announced with their bonus ("DOUBLE KILL +5").
#
# Children (edit them in the scene): CritLabel — the look of one crit popup (hidden template,
# duplicated for every crit, so several can be on screen); StreakLabel — the multi-kill announcement;
# StreakSound — plays the announcer line (its pitch_scale / volume are set there).
# The announcer also speaks when the player dies and when every enemy is dead; a new line cuts
# the one playing (one voice, like the combos). On a death the death label shows what is said:
# the run is lost — or, in the boss fight, the run goes on with the next loop.

@export_group("Crit")
@export var crit_text: String = "CRIT! %d" # %d = the damage
@export var crit_jitter: Vector2 = Vector2(6, 3) # random shift of every popup, art px
@export var crit_rise: float = 14.0 # how far it floats up, art px
@export var crit_time: float = 0.7

@export_group("Kill Streak")
# for 2, 3, 4... kills in a row; the last one repeats for longer streaks
@export var streak_names: PackedStringArray = ["DOUBLE KILL", "TRIPLE KILL", "UNSTOPPABLE", "DOMINATING", "RAMPAGE"]
# announcer lines, in the same order as streak_names
@export var streak_sounds: Array[AudioStream] = []
@export var bonus_text: String = " +%d" # added after the name when the streak gives points
@export var streak_hold: float = 1.2 # on screen before fading, s
@export var streak_fade: float = 0.4

@export_group("Announcer")
@export var death_label: Label # the big text on a death; gets the line said
@export var death_sounds: Array[AudioStream] = [] # one at random when the player dies
@export var death_ambient: AudioStream
@export var death_texts: PackedStringArray = ["ANNIHILATION", "GAME OVER"] # in the same order as death_sounds
@export var death_subtitle: String = "the run is lost"
@export var final_death_sound: AudioStream # a death in the boss fight: the run goes on
@export var final_death_text: String = "ONE MORE TIME"
@export var final_death_subtitle: String = "the loop goes on"
@export var all_killed_sound: AudioStream # every enemy of the level is dead (the final gate opens)
@export var win_sound: AudioStream
@export var win_ambient: AudioStream

@onready var _crit_template: Label = $CritLabel
@onready var _streak_label: Label = $StreakLabel
@onready var _streak_sound: AudioStreamPlayer = $StreakSound
@onready var _ambient: AudioStreamPlayer = $Ambient

var _streak_tween: Tween

func _ready() -> void:
	
	_crit_template.visible = false
	_streak_label.visible = false
	GameEvents.enemy_hit.connect(_on_enemy_hit)
	GameEvents.kill_streak.connect(_on_kill_streak)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.final_unlocked.connect(_announce.bind(all_killed_sound))
	GameEvents.boss_defeated.connect(_on_player_win)

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

func _on_player_win() -> void:
	_ambient.stream = win_ambient
	_ambient.play()
	_announce(win_sound)
		
func _on_player_died() -> void:
	var text: String
	var subtitle: String
	_ambient.stream = death_ambient
	_ambient.play()
	if RunState.in_final:
		_announce(final_death_sound)
		text = final_death_text
		subtitle = final_death_subtitle
	else:
		var index := randi() % maxi(death_sounds.size(), 1)
		if index < death_sounds.size():
			_announce(death_sounds[index])
		text = death_texts[index] if index < death_texts.size() else "YOU DIED"
		subtitle = death_subtitle
	if death_label:
		death_label.text = "%s
%s" % [text, subtitle] if subtitle != "" else text
		_pop(death_label) # stays: the level restarts under it

func _announce(sound: AudioStream) -> void:
	if sound == null:
		return
	_streak_sound.stream = sound
	_streak_sound.play()
	

func _on_kill_streak(kills: int, bonus: int) -> void:
	if streak_names.is_empty():
		return
	var index := mini(kills - 2, streak_names.size() - 1)
	_streak_label.text = streak_names[index]
	if index < streak_sounds.size() and streak_sounds[index]:
		_streak_sound.stream = streak_sounds[index]
		_streak_sound.play()
	if bonus > 0:
		_streak_label.text += bonus_text % bonus
	if _streak_tween:
		_streak_tween.kill()
	_streak_tween = _pop(_streak_label)
	_streak_tween.tween_interval(streak_hold)
	_streak_tween.tween_property(_streak_label, "modulate:a", 0.0, streak_fade)
	_streak_tween.tween_callback(_streak_label.hide)

# the announcement look: shown twice its size, it snaps down to it with a little overshoot.
# Returns the tween, to add the rest of the show after it
func _pop(label: Label) -> Tween:
	label.visible = true
	label.modulate.a = 1.0
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 2.0
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween
