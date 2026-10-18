extends CanvasLayer

# Shown when the level is finished: pick 1 of 3 upgrade cards (click or keys 1-3),
# then the level starts again with it. The UI is built in code.

const CARD_SIZE := Vector2(260, 340)
const APPEAR_TIME := 0.25 # sec per card
const APPEAR_STAGGER := 0.1 # sec between the cards
const CHOICE_KEYS := [KEY_1, KEY_2, KEY_3]

var _choices: Array[UpgradeData] = []
var _cards: Array[Button] = []
var _accepting := false # off while the cards appear, so a held click doesn't pick one
var _chosen := false

@onready var _title := Label.new()
@onready var _cards_box := HBoxContainer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	GameEvents.level_completed.connect(_open)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	center.add_child(column)

	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_cards_box.add_theme_constant_override("separation", 24)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards_box)

func _open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_title.text = "LOOP %d COMPLETE\nCHOOSE AN UPGRADE" % (RunState.loop + 1)
	_choices = RunState.roll_choices()
	for i in _choices.size():
		_cards.append(_make_card(_choices[i], i))
	if _choices.is_empty(): # every card is maxed
		_title.text = "LOOP %d COMPLETE\nEVERYTHING IS MAXED" % (RunState.loop + 1)
		_cards.append(_make_continue_button())
	for card in _cards:
		_cards_box.add_child(card)

	visible = true
	_appear()

func _make_card(upgrade: UpgradeData, index: int) -> Button:
	var card := _make_button()
	card.pressed.connect(_choose.bind(upgrade))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	box.add_child(_make_label("[%d]" % (index + 1), 18, Color(1, 1, 1, 0.5)))
	if upgrade.icon:
		var icon := TextureRect.new()
		icon.texture = upgrade.icon
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	box.add_child(_make_label(upgrade.title, 28))
	var description := _make_label(upgrade.description, 18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var stacks := RunState.get_stacks(upgrade)
	box.add_child(_make_label("Level %d / %d" % [stacks + 1, upgrade.max_stacks], 18, Color(1, 0.85, 0.3)))
	return card

func _make_continue_button() -> Button:
	var button := _make_button()
	button.custom_minimum_size = Vector2(CARD_SIZE.x, 80)
	button.text = "Continue"
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(_choose.bind(null))
	return button

func _make_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.modulate.a = 0.0
	return button

func _make_label(text: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _appear() -> void:
	var tween := create_tween().set_parallel()
	for i in _cards.size():
		tween.tween_property(_cards[i], "modulate:a", 1.0, APPEAR_TIME).set_delay(i * APPEAR_STAGGER)
	await tween.finished
	_accepting = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# no pause menu over the choice
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if _accepting and event is InputEventKey and event.pressed and not event.echo:
		var index := CHOICE_KEYS.find(event.physical_keycode)
		if index != -1 and index < _choices.size():
			get_viewport().set_input_as_handled()
			_choose(_choices[index])

func _choose(upgrade: UpgradeData) -> void:
	if not _accepting or _chosen:
		return
	_chosen = true
	RunState.complete_level(upgrade)
