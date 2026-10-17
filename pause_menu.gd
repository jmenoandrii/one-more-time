extends CanvasLayer

@onready var resume_button: Button = $ResumeButton
@onready var sensitivity_slider: HSlider = $SensitivitySlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false
	sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)

	GameEvents.pause_pressed.connect(_on_pause_pressed)
	GameEvents.unpause_pressed.connect(_on_unpause_pressed)
		
func _on_pause_pressed() -> void:
	visible = true
	get_tree().paused = true

func _on_unpause_pressed() -> void:
	resume_button.release_focus()
	visible = false
	get_tree().paused = false

func _on_resume_button_pressed() -> void:
	GameEvents.unpause_pressed.emit()

func _on_exit_button_pressed() -> void:
	Settings.save_settings()
	get_tree().quit()

func _on_sensitivity_slider_value_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	GameEvents.sensitivity_changed.emit(value)
