extends Node

func _enter_tree() -> void:
	GameEvents.time_changed.connect(_on_timer_changed)
  
const TIMER_LABEL := "HUD/TimerLabel"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			GameEvents.unpause_pressed.emit()
		else:
			GameEvents.pause_pressed.emit()
      
      
func _on_timer_changed(time_left: float) -> void:
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	
	_set_text(TIMER_LABEL, "%02d:%02d" % [minutes, seconds])
