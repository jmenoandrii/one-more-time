extends Node3D

@onready var round_timer: Timer = $LevelTimer

func _process(_delta: float) -> void:
	if not round_timer.is_stopped():
		GameEvents.time_changed.emit(round_timer.time_left)

func _on_level_timer_timeout() -> void:
	print("Time is end")
	GameEvents.level_completed.emit()
