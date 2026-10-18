extends Control

const WORLD_SCENE_PATH = "res://Scenes/main.tscn"

@onready var cursor: Label = $"../CursorLabel"
@onready var vbox: VBoxContainer = $"../ControlMenu/MarginContainer/VBoxContainer"

@onready var control_menu: Control = $"../ControlMenu"
@onready var control_credits: Control = $"../ControlCredits"
@onready var credits_back_button: Button = $"../ControlCredits/CreditsVBox/BackButton"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	for btn in vbox.get_children():
		if btn is Button:
			btn.flat = true 
			
			btn.focus_entered.connect(_on_button_focused.bind(btn))
			
			if btn.name == "PlayButton":
				btn.pressed.connect(_on_play_pressed)
				btn.ready.connect(btn.grab_focus())
			if btn.name == "CreditsButton":
				btn.pressed.connect(_on_credits_pressed)
			elif btn.name == "QuitButton":
				btn.pressed.connect(_on_quit_pressed)
	
	credits_back_button.focus_entered.connect(_on_button_focused.bind(credits_back_button))
	credits_back_button.pressed.connect(_on_credits_back_btn_pressed)
	
	control_credits.visible = false
	control_menu.visible = true
	
func _on_button_focused(btn: Button) -> void:
	cursor.global_position.y = btn.global_position.y + (btn.size.y - cursor.size.y) / 2.0 + 20
	cursor.global_position.x = btn.global_position.x - 30
	
func _process(_delta: float) -> void:
	cursor.modulate.a = (sin(Time.get_ticks_msec() * 0.008) + 1.0) / 2.0

func _on_play_pressed() -> void:
	RunState.reset_run()
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_credits_pressed() -> void:
	control_menu.visible = false
	control_credits.visible = true
	credits_back_button.grab_focus()

func _on_credits_back_btn_pressed() -> void:
	control_credits.visible = false
	control_menu.visible = true
	if vbox.get_child_count() > 0:
		vbox.get_child(0).grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
