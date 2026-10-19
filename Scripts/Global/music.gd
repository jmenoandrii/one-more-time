extends AudioStreamPlayer

# Background music (autoload). The tracks are the ones in the scene's AudioStreamPlaylist; one of
# them plays (looping through random others when it ends), and every new run switches to another
# one once the run's level has loaded. While the game is paused and while the level timer hasn't started
# (the player hasn't gone through the gate yet), the music and the enemies' sounds go quieter
# and muffled: the "Music" and "Enemy" buses switch on their LowPassFilter.

const MUFFLED_BUSES: PackedStringArray = ["Music", "Enemy"]

@export var pause_volume_drop: float = 12.0 # dB quieter while muffled (music)
@export var enemy_volume_drop: float = 8.0 # dB quieter while muffled (the Enemy bus)
@export var fade_speed: float = 30.0 # dB per second

var _normal_db: float
var _tracks: Array[AudioStream] = []
var _switch_pending := false # a new run began: change the track when its level is loaded
var _enemy_bus_db := 0.0 # the Enemy bus volume from the bus layout

func _ready() -> void:
	_normal_db = volume_db
	# the playlist only lists the tracks; which one plays is chosen here
	if stream is AudioStreamPlaylist:
		var playlist := stream as AudioStreamPlaylist
		for i in playlist.stream_count:
			if playlist.get_list_stream(i):
				_tracks.append(playlist.get_list_stream(i))
	finished.connect(_play_another)
	GameEvents.run_started.connect(func() -> void: _switch_pending = true)
	get_tree().scene_changed.connect(_on_scene_changed)
	_play_another()
	var enemy_bus := AudioServer.get_bus_index("Enemy")
	if enemy_bus != -1:
		_enemy_bus_db = AudioServer.get_bus_volume_db(enemy_bus)

func _on_scene_changed() -> void:
	if _switch_pending:
		_switch_pending = false
		_play_another()

# a random track, not the one playing now
func _play_another() -> void:
	if _tracks.is_empty():
		return
	var choices := _tracks.filter(func(track: AudioStream) -> bool: return track != stream)
	stream = (choices if not choices.is_empty() else _tracks).pick_random()
	play()

func _process(delta: float) -> void:
	var muffled := get_tree().paused or not GameEvents.level_running
	var target := _normal_db - pause_volume_drop if muffled else _normal_db
	volume_db = move_toward(volume_db, target, fade_speed * delta)

	for bus_name in MUFFLED_BUSES:
		_set_low_pass(AudioServer.get_bus_index(bus_name), muffled)

	var enemy_bus := AudioServer.get_bus_index("Enemy")
	if enemy_bus != -1:
		var enemy_target := _enemy_bus_db - enemy_volume_drop if muffled else _enemy_bus_db
		var current := AudioServer.get_bus_volume_db(enemy_bus)
		AudioServer.set_bus_volume_db(enemy_bus, move_toward(current, enemy_target, fade_speed * delta))

# the bus's LowPassFilter on / off; no such bus or filter = nothing (just quieter)
func _set_low_pass(bus: int, on: bool) -> void:
	if bus == -1:
		return
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(bus, i, on)
