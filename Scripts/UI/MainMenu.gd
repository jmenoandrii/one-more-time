extends Control

const WORLD_SCENE_PATH = "res://Scenes/main.tscn"

@onready var cursor: Label = $"../CursorLabel"
@onready var vbox: VBoxContainer = $"../ControlMenu/MarginContainer/VBoxContainer"

@onready var control_menu: Control = $"../ControlMenu"
@onready var control_credits: Control = $"../ControlCredits"
@onready var control_settings: Control =$"../ControlSettings"

@onready var credits_back_button: Button = $"../ControlCredits/CreditsVBox/BackButton"
@onready var settings_back_button: Button = $"../ControlSettings/VBoxContainer/BackButton"

@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_fill: Range = %SensitivityFill
@onready var sens_value_label: Label = %SensitivityLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	for btn in vbox.get_children():
		if btn is Button:
			btn.flat = true 
			
			btn.focus_entered.connect(_on_button_focused.bind(btn))
			
			if btn.name == "PlayButton":
				btn.pressed.connect(_on_play_pressed)
			if btn.name == "CreditsButton":
				btn.pressed.connect(_on_credits_pressed)
			elif btn.name == "SettingsButton":
				btn.pressed.connect(_on_settings_pressed)
			elif btn.name == "QuitButton":
				btn.pressed.connect(_on_quit_pressed)
	
	credits_back_button.focus_entered.connect(_on_button_focused.bind(credits_back_button))
	credits_back_button.pressed.connect(_on_credits_back_btn_pressed)
	
	settings_back_button.focus_entered.connect(_on_button_focused.bind(settings_back_button))
	settings_back_button.pressed.connect(_on_settings_back_btn_pressed)
	
	
	sensitivity_slider.value = Settings.mouse_sensitivity
	sensitivity_fill.min_value = sensitivity_slider.min_value
	sensitivity_fill.max_value = sensitivity_slider.max_value
	_on_sens_slider_changed(sensitivity_slider.value)
	sensitivity_slider.value_changed.connect(_on_sens_slider_changed)

	
	_show_control_menu(control_menu)
	
	if vbox.get_child_count() > 0:
		await get_tree().process_frame
		vbox.get_child(0).grab_focus()
	
func _on_button_focused(btn: Button) -> void:
	cursor.global_position.y = btn.global_position.y + (btn.size.y - cursor.size.y) / 2.0 + 20
	cursor.global_position.x = btn.global_position.x - 30
	
func _process(_delta: float) -> void:
	cursor.modulate.a = (sin(Time.get_ticks_msec() * 0.008) + 1.0) / 2.0

func _on_play_pressed() -> void:
	RunState.reset_run()
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_credits_pressed() -> void:
	_show_control_menu(control_credits)
	
	await get_tree().process_frame
	credits_back_button.grab_focus()

func _on_settings_pressed() -> void:
	_show_control_menu(control_settings)
	
	await get_tree().process_frame
	settings_back_button.grab_focus()

func _on_credits_back_btn_pressed() -> void:
	_show_control_menu(control_menu)
	
	await get_tree().process_frame
	if vbox.get_child_count() > 0:
		vbox.get_child(0).grab_focus()

func _on_settings_back_btn_pressed() -> void:
	Settings.save_settings()
	
	_show_control_menu(control_menu)
	
	await get_tree().process_frame
	if vbox.get_child_count() > 0:
		vbox.get_child(0).grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_control_menu(menu: Control):
	control_menu.visible = false
	control_credits.visible = false
	control_settings.visible = false
	menu.visible = true

func _on_sens_slider_changed(value: float) -> void:
	sensitivity_fill.value = value
	sens_value_label.text = "Sensitivity %.1f" % value
	Settings.mouse_sensitivity = value
