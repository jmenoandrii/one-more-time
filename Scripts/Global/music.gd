extends AudioStreamPlayer

@export var pause_volume_drop: float = 12.0
@export var fade_speed: float = 30.0

var _normal_db: float

func _ready() -> void:
	_normal_db = volume_db

func _process(delta: float) -> void:
	var target := _normal_db - pause_volume_drop if get_tree().paused else _normal_db
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 0, get_tree().paused)
	volume_db = move_toward(volume_db, target, fade_speed * delta)
