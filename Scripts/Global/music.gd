extends AudioStreamPlayer

# Background music (autoload). While the game is paused and while the level timer hasn't started
# (the player hasn't gone through the gate yet), the music and the enemies' sounds go quieter
# and muffled: the "Music" and "Enemy" buses switch on their LowPassFilter.

const MUFFLED_BUSES: PackedStringArray = ["Music", "Enemy"]

@export var pause_volume_drop: float = 12.0 # dB quieter while muffled (music)
@export var enemy_volume_drop: float = 8.0 # dB quieter while muffled (the Enemy bus)
@export var fade_speed: float = 30.0 # dB per second

var _normal_db: float
var _enemy_bus_db := 0.0 # the Enemy bus volume from the bus layout

func _ready() -> void:
	_normal_db = volume_db
	var enemy_bus := AudioServer.get_bus_index("Enemy")
	if enemy_bus != -1:
		_enemy_bus_db = AudioServer.get_bus_volume_db(enemy_bus)

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
