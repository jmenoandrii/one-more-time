extends Control

const WORLD_SCENE_PATH = "res://Scenes/main.tscn"

@onready var cursor: Label = $CursorLabel
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	for btn in vbox.get_children():
		if btn is Button:
			btn.flat = true 
			
			btn.focus_entered.connect(_on_button_focused.bind(btn))
			
			if btn.name == "PlayButton":
				btn.pressed.connect(_on_play_pressed)
			if btn.name == "CreditsButton":
				pass
			elif btn.name == "QuitButton":
				btn.pressed.connect(_on_quit_pressed)
	
	if vbox.get_child_count() > 0:
		await get_tree().process_frame
		vbox.get_child(0).grab_focus()
	
func _on_button_focused(btn: Button) -> void:
	cursor.global_position.y = btn.global_position.y + (btn.size.y - cursor.size.y) / 2.0 + 20
	cursor.global_position.x = btn.global_position.x - 30
	
func _process(_delta: float) -> void:
	# Математичний трюк для термінального мигання курсора (альфа-канал від 0 до 1)
	cursor.modulate.a = (sin(Time.get_ticks_msec() * 0.008) + 1.0) / 2.0

func _on_play_pressed() -> void:
	RunState.reset_run()
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_credits_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
