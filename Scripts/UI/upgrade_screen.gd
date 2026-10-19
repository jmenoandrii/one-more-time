extends CanvasLayer

# Shown when the level is finished: buy 1 of 3 upgrade cards with the run's points
# (click or keys 1-3) or skip and keep the points (SKIP / key 4); then the next loop starts.
# REROLL (key R) deals 3 new cards for points: REROLL_COST, then REROLL_STEP more every time.
# Cards the player can't afford yet are shown, but locked. The UI is built in code, in the HUD's pixel style:
# laid out in art pixels under a PixelRoot, the cards are PixelButtons.

const THEME := preload("res://UI/HUD/hud_theme.tres")
const CARD_SIZE := Vector2(100, 140) # art px
const CARD_PADDING := 6 # art px between the frame and the text
const CARD_COLOR := Color(0.11, 0.08, 0.06) # solid, so the level doesn't show through
const HOVER_TILT := 4.0 # degrees, every other card the other way
const HOVER_SCALE := 1.06
const HOVER_TIME := 0.12
const APPEAR_TIME := 0.25 # sec per card
const APPEAR_STAGGER := 0.1 # sec between the cards
const CHOICE_KEYS := [KEY_1, KEY_2, KEY_3]
const SKIP_KEY := KEY_4
const REROLL_KEY := KEY_R
const REROLL_COST := 5 # the first reroll on this screen
const REROLL_STEP := 10 # every next one costs this much more
const RED := Color(0.9, 0.2, 0.2)
const DIM_COLOR := Color(1, 1, 1, 0.5)
const GOLD := Color(1.0, 0.76, 0.055)

var _choices: Array[UpgradeData] = []
var _cards: Array[Button] = []
var _accepting := false # off while the cards appear, so a held click doesn't pick one
var _chosen := false
var _reroll_cost := REROLL_COST
var _skip_button: PixelButton
var _reroll_button: PixelButton

@onready var _title := Label.new()
@onready var _subtitle := Label.new()
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

	var root := PixelRoot.new()
	root.theme = THEME
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)

	_title.add_theme_font_size_override("font_size", 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", GOLD)
	column.add_child(_subtitle)

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	column.add_child(gap)

	_cards_box.add_theme_constant_override("separation", 8)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_reroll_button = _make_button()
	_reroll_button.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	_reroll_button.pressed.connect(_reroll)
	buttons.add_child(_reroll_button)
	_skip_button = _make_button()
	_skip_button.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	_skip_button.pressed.connect(_choose.bind(null))
	buttons.add_child(_skip_button)

func _open() -> void:
	if visible: # the exit and the level timer can both finish the level
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_title.text = "LOOP %d COMPLETE" % (RunState.loop + 1)
	_reroll_cost = REROLL_COST
	visible = true
	_deal()
	var tween := create_tween().set_parallel()
	for button in [_reroll_button, _skip_button]:
		tween.tween_property(button, "modulate:a", 1.0, APPEAR_TIME)

# 3 cards in place of the ones on the table (if any)
func _deal() -> void:
	_accepting = false
	for card in _cards:
		card.get_parent().queue_free() # the holder
	_cards.clear()

	_choices = RunState.roll_choices()
	var affordable := _choices.any(RunState.can_afford)
	if _choices.is_empty(): # every card is maxed
		_subtitle.text = "EVERYTHING IS MAXED"
	elif affordable:
		_subtitle.text = "BUY AN UPGRADE: %d PTS" % RunState.xp
	else:
		_subtitle.text = "NOT ENOUGH POINTS: %d PTS" % RunState.xp
	for i in _choices.size():
		_cards.append(_make_card(_choices[i], i))
	for card in _cards:
		_cards_box.add_child(card.get_parent()) # the holder: the box would reset a tilt of the card itself

	# skip = keep the points for later; just "continue" when there is nothing to buy
	_skip_button.text = "[4] SKIP" if affordable else "CONTINUE"
	_reroll_button.text = "[R] REROLL %d" % _reroll_cost
	_reroll_button.disabled = _choices.is_empty() or RunState.xp < _reroll_cost
	_appear()

func _reroll() -> void:
	if not _accepting or _chosen or _reroll_button.disabled:
		return
	if not RunState.spend_xp(_reroll_cost):
		return
	_reroll_cost += REROLL_STEP
	_deal()

# a card inside a holder: the holder takes the place in the row, the card tilts freely in it
func _make_card(upgrade: UpgradeData, index: int) -> Button:
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var card := _make_button()
	card.background_color = CARD_COLOR
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE * 0.5
	card.pressed.connect(_choose.bind(upgrade))
	var price := RunState.get_price(upgrade)
	var affordable := RunState.can_afford(upgrade)
	card.disabled = not affordable
	holder.add_child(card)
	
	if affordable:
		var tilt := deg_to_rad(HOVER_TILT if index % 2 == 0 else -HOVER_TILT)
		card.mouse_entered.connect(_hover.bind(card, tilt, HOVER_SCALE))
		card.mouse_exited.connect(_hover.bind(card, 0.0, 1.0))
	
	# fixed margins: the labels wrap inside the card instead of stretching it
	var inset := PixelButton.BORDER + CARD_PADDING
	var box := VBoxContainer.new()
	box.position = Vector2(inset, inset)
	box.size = CARD_SIZE - Vector2(inset, inset) * 2
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var width := box.size.x
	
	box.add_child(_make_label("[%d]" % (index + 1), DIM_COLOR, width))
	if upgrade.icon:
		var icon := TextureRect.new()
		icon.texture = upgrade.icon
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	box.add_child(_make_label(upgrade.title.to_upper(), Color.WHITE, width))
	box.add_child(_make_label(upgrade.description, DIM_COLOR, width))
	var stacks := RunState.get_stacks(upgrade)
	box.add_child(_make_label("LV %d/%d" % [stacks + 1, upgrade.max_stacks], GOLD, width))
	box.add_child(_make_label("%d PTS" % price, GOLD if affordable else RED, width))
	if not affordable:
		box.modulate = DIM_COLOR
	return card

func _hover(card: Control, tilt: float, card_scale: float) -> void:
	if not _accepting:
		return
	var tween := card.create_tween().set_parallel()
	tween.tween_property(card, "rotation", tilt, HOVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE * card_scale, HOVER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_button() -> PixelButton:
	var button := PixelButton.new()
	button.focus_mode = Control.FOCUS_NONE
	button.modulate.a = 0.0
	return button

# width > 0: wraps at that width (without it a wrapping label stretches its container instead)
func _make_label(text: String, color := Color.WHITE, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	if width > 0.0:
		label.custom_minimum_size.x = width
	return label

func _appear() -> void:
	var tween := create_tween().set_parallel()
	for i in _cards.size():
		tween.tween_property(_cards[i], "modulate:a", 1.0, APPEAR_TIME).set_delay(i * APPEAR_STAGGER)
	await tween.finished
	_accepting = true

# a pickup the player has to be told about (the second gun) beats "KILL THEM ALL"
func _next_loop_words() -> PackedStringArray:
	var spawner := get_tree().get_first_node_in_group("level_spawner")
	if spawner and spawner.has_method("get_announcement"):
		return spawner.get_announcement(RunState.loop + 1) # complete_level has already moved the loop on
	return PackedStringArray()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# no pause menu over the choice
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if _accepting and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == SKIP_KEY:
			get_viewport().set_input_as_handled()
			_choose(null)
			return
		if event.physical_keycode == REROLL_KEY:
			get_viewport().set_input_as_handled()
			_reroll()
			return
		var index := CHOICE_KEYS.find(event.physical_keycode)
		if index != -1 and index < _choices.size() and RunState.can_afford(_choices[index]):
			get_viewport().set_input_as_handled()
			_choose(_choices[index])

func _choose(upgrade: UpgradeData) -> void:
	if not _accepting or _chosen:
		return
	_chosen = true
	RunState.complete_level(upgrade) # saved now, so quitting during the message keeps the choice
	visible = false
	# in the root, not in the level: it must outlive the level reload
	var message := LoopMessage.new()
	get_tree().root.add_child(message)
	await message.play(_next_loop_words())
	message.close_after_scene_change()
	RunState.start_next_loop()
