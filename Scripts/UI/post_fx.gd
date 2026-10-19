extends Node

# Screen effects of a level (Scenes/post_fx.tscn, put it under the level's UI):
# - PSX: under the HUD, over the 3D view — low resolution, limited palette with dithering, vignette;
# - VHS: over everything, optional (the pause menu toggles Settings.vhs_enabled).
# Their looks are the ShaderMaterials of the PSX/Screen and VHS/Screen nodes.

@onready var _vhs: CanvasLayer = $VHS

func _ready() -> void:
	_apply()
	GameEvents.vhs_changed.connect(_apply.unbind(1))

func _apply() -> void:
	_vhs.visible = Settings.vhs_enabled
