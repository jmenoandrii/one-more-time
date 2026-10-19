extends CanvasLayer
class_name ScreenFade

# A level starts from black and fades in. ScreenFade.fade_in(self) from the level's _ready.

const LAYER := 50 # over the HUD and the menus

static var skip_next := false # set by the loop message: the next level starts with a hard cut

static func fade_in(level: Node, time: float = 0.5, hold: float = 0.05) -> void:
	if skip_next:
		skip_next = false
		return
	var fade := ScreenFade.new()
	fade.layer = LAYER
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.add_child(black)
	level.add_child.call_deferred(fade) # the level is still setting up its children in _ready

	var tween := level.create_tween()
	tween.tween_interval(hold)
	tween.tween_property(black, "modulate:a", 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(fade.queue_free)
