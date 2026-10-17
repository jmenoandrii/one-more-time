extends Node

const PATH := "user://settings.cfg"

var mouse_sensitivity := 4.0

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
