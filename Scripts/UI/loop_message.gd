extends CanvasLayer
class_name LoopMessage

# Between two loops: three words slammed on the screen one by one, SUPERHOT style
# ("KILL" / "THEM" / "ALL"...), each with a flash and a hit; the music is fully muted meanwhile.
# Rarely one of the rare messages comes instead. play() returns when the words are over, the screen
# still black: then either close() (the game goes on) or close_after_scene_change() (between loops:
# it lives in the root, so it covers the level reload and fades out over the new level).
# Built in code in the HUD's pixel style; works while the game is paused.

const THEME := preload("res://UI/HUD/hud_theme.tres")
const WORD_SOUND := preload("res://Sounds/UI/word_hit.wav")

const COMMON := ["KILL", "THEM", "ALL"]
const RARE := [["ONE", "MORE", "TIME"], ["DONT", "LOOK", "BACK"], ["I", "LOVE", "BORSCH"]]
const RARE_CHANCE := 0.03 # each rare message

const WORD_TIME := 0.5 # s on screen per word
const REPEATS := 2 # the three words go round this many times
const SLAM_SCALE := 1.7 # a word starts this big and slams down to its size
const SLAM_TIME := 0.07
const FADE_OUT := 0.25
const FONT_SIZE := 40 # art px
const CLOSE_TIME := 0.1 # the black goes away almost at once (0 = a hard cut)

var _word: Label
var _dim: ColorRect
var _flash: ColorRect
var _sound: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()

# words: what to show; empty = KILL THEM ALL, or rarely one of the rare messages
func play(words: PackedStringArray = []) -> void:
	if words.is_empty():
		words = _pick_words()
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, true)

	for i in REPEATS:
		for word in words:
			_show(word)
			await get_tree().create_timer(WORD_TIME, true, false, true).timeout

	var tween := create_tween()
	tween.tween_property(_word, "modulate:a", 0.0, FADE_OUT)
	await tween.finished
	if _sound.playing: # the last hit rings out instead of being cut
		await _sound.finished

# the black fades out, the music comes back
func close(time: float = CLOSE_TIME) -> void:
	if time > 0.0:
		var tween := create_tween()
		tween.tween_property(_dim, "modulate:a", 0.0, time)
		await tween.finished
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_mute(music_bus, false)
	queue_free()

# stays black while the level reloads, then cuts straight to the new one
func close_after_scene_change() -> void:
	ScreenFade.skip_next = true # the new level doesn't fade in on its own: a hard cut
	await get_tree().scene_changed
	close(0.0)

func _input(event: InputEvent) -> void:
	# no pause menu over it: it would unpause the game in the middle of the message
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _pick_words() -> PackedStringArray:
	var roll := randf()
	for i in RARE.size():
		if roll < RARE_CHANCE * (i + 1):
			return PackedStringArray(RARE[i])
	return PackedStringArray(COMMON)

func _show(word: String) -> void:
	_word.text = word
	_word.pivot_offset = _word.size * 0.5
	_word.scale = Vector2.ONE * SLAM_SCALE
	_word.rotation = deg_to_rad(randf_range(-3.0, 3.0))
	_word.modulate.a = 1.0
	_flash.modulate.a = 0.5
	_sound.play()

	var tween := create_tween().set_parallel()
	tween.tween_property(_word, "scale", Vector2.ONE, SLAM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.2)

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color.BLACK
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	var root := PixelRoot.new()
	root.theme = THEME
	add_child(root)

	_word = Label.new()
	_word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.add_theme_font_size_override("font_size", FONT_SIZE)
	_word.modulate.a = 0.0
	root.add_child(_word)

	_sound = AudioStreamPlayer.new()
	_sound.stream = WORD_SOUND
	add_child(_sound)
