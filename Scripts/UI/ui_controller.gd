extends Node

# Pause on Esc. The HUD itself lives in hud.tscn (hud.gd).

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			GameEvents.unpause_pressed.emit()
		else:
			GameEvents.pause_pressed.emit()
