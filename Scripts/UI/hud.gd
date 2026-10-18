extends CanvasLayer

# The in-game HUD, pixel art: laid out in art pixels under Root (a PixelRoot).
#
# bottom-left: keys, health, stamina (fades out while full) | bottom-right: reserve, cylinders
# top-left: level timer (ClockHUD) | center: crosshair, interact prompt, death message.
# The loop number is in the pause menu.

const KEY_ICON := preload("res://UI/HUD/key.png")

@export_group("Health")
@export var trail_delay: float = 0.35 # the white "lost health" part waits, then catches up
@export var trail_time: float = 0.4

@export_group("Stamina")
@export var stamina_hide_delay: float = 1.0 # after it's full again
@export var stamina_fade_time: float = 0.3

@export_group("XP")
@export var xp_count_time: float = 0.5 # the counter runs up to the new value
@export var xp_income_rise: float = 6.0 # "+N" floats up this far, art px
@export var xp_income_time: float = 0.9
@export var xp_gain_color: Color = Color(1.0, 0.76, 0.055)
@export var xp_loss_color: Color = Color(0.9, 0.2, 0.2)

@export_group("Reserve")
@export var reserve_empty_color: Color = Color(0.9, 0.2, 0.2)

# assigned in _enter_tree: the player sends the first values before this node's _ready
var health_fill: TextureProgressBar
var health_trail: TextureProgressBar
var health_label: Label
var stamina_row: Control
var stamina_fill: TextureProgressBar
var reserve: Control
var reserve_label: Label
var interact_label: Label
var keys_box: HBoxContainer
var death_label: Label
var xp_label: Label
var xp_income_label: Label

var _trail_tween: Tween
var _xp_tween: Tween
var _xp_income_tween: Tween
var _xp_shown := 0.0
var _xp_income_y := 0.0 # where "+N" starts, from the scene
var _xp_income_sum := 0 # gains in a quick row (a kill + its streak bonus) add up in one "+N"
var _stamina_tween: Tween
var _stamina_full := false

func _enter_tree() -> void:
	health_fill = %HealthFill
	health_trail = %HealthTrail
	health_label = %HealthLabel
	stamina_row = %StaminaRow
	stamina_fill = %StaminaFill
	reserve = %Reserve
	reserve_label = %ReserveLabel
	interact_label = %InteractLabel
	keys_box = %KeysContainer
	death_label = %DeathLabel
	xp_label = %ExLabel
	xp_income_label = %ExIncomeLabel
	xp_income_label.text = ""
	_set_xp_shown(RunState.xp) # the run's points carry over to the next loop

	GameEvents.health_changed.connect(_on_health_changed)
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.ammo_changed.connect(_on_ammo_changed)
	GameEvents.reserve_ammo_changed.connect(_on_reserve_ammo_changed)
	GameEvents.weapon_unequipped.connect(_on_weapon_unequipped)
	GameEvents.interact_prompt_changed.connect(_on_interact_prompt_changed)
	GameEvents.keys_changed.connect(_on_keys_changed)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.xp_changed.connect(_on_xp_changed)

func _ready() -> void:
	# after the PixelRoot has laid the labels out
	_xp_income_y = xp_income_label.position.y

func _on_health_changed(current: float, maximum: float) -> void:
	health_fill.max_value = maximum
	health_trail.max_value = maximum
	health_label.text = str(ceili(current))

	var lost := current < health_trail.value
	health_fill.value = current
	if _trail_tween:
		_trail_tween.kill()
	if lost:
		_trail_tween = create_tween()
		_trail_tween.tween_interval(trail_delay)
		_trail_tween.tween_property(health_trail, "value", current, trail_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		health_trail.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_fill.max_value = maximum
	stamina_fill.value = current

	var full := current >= maximum
	if full == _stamina_full:
		return
	_stamina_full = full
	if _stamina_tween:
		_stamina_tween.kill()
	_stamina_tween = create_tween()
	if full:
		_stamina_tween.tween_interval(stamina_hide_delay)
		_stamina_tween.tween_property(stamina_row, "modulate:a", 0.0, stamina_fade_time)
	else:
		_stamina_tween.tween_property(stamina_row, "modulate:a", 1.0, stamina_fade_time * 0.5)

# the rounds in the magazine are shown by the cylinders, here it only means a weapon is in hands
func _on_ammo_changed(_current: int, _maximum: int) -> void:
	reserve.visible = false

func _on_reserve_ammo_changed(amount: int) -> void:
	reserve_label.text = "x%d" % amount
	reserve_label.modulate = reserve_empty_color if amount == 0 else Color.WHITE

func _on_weapon_unequipped() -> void:
	reserve.visible = false

func _on_interact_prompt_changed(text: String) -> void:
	interact_label.visible = text != ""
	interact_label.text = text

func _on_keys_changed(keys: Dictionary) -> void:
	for child in keys_box.get_children():
		child.queue_free()
	for key_id in keys:
		var icon := TextureRect.new()
		icon.texture = KEY_ICON
		icon.modulate = keys[key_id] # the icon is white inside, the outline stays black
		icon.tooltip_text = key_id
		keys_box.add_child(icon)

func _on_player_died() -> void:
	death_label.visible = true

func _on_xp_changed(current: int, delta: int) -> void:
	if _xp_tween:
		_xp_tween.kill()
	if delta == 0: # a reset: no show
		_set_xp_shown(current)
		return
	
	# the counter runs up to the new value, punching and flashing
	var color := xp_gain_color if delta > 0 else xp_loss_color
	xp_label.pivot_offset = xp_label.size * 0.5
	xp_label.scale = Vector2.ONE * 1.25
	xp_label.modulate = color
	_xp_tween = create_tween().set_parallel()
	_xp_tween.tween_method(_set_xp_shown, _xp_shown, float(current), xp_count_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_xp_tween.tween_property(xp_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_xp_tween.tween_property(xp_label, "modulate", Color.WHITE, xp_count_time)
	
	# "+N" pops in under it and floats up while fading
	var still_shown := _xp_income_tween != null and _xp_income_tween.is_running()
	if still_shown and signi(delta) == signi(_xp_income_sum):
		_xp_income_sum += delta
	else:
		_xp_income_sum = delta
	xp_income_label.text = ("+%d" if _xp_income_sum > 0 else "%d") % _xp_income_sum
	xp_income_label.modulate = color
	xp_income_label.position.y = _xp_income_y
	xp_income_label.pivot_offset = xp_income_label.size * 0.5
	xp_income_label.scale = Vector2.ONE * 1.6
	if _xp_income_tween:
		_xp_income_tween.kill()
	_xp_income_tween = create_tween().set_parallel()
	_xp_income_tween.tween_property(xp_income_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_xp_income_tween.tween_property(xp_income_label, "position:y", _xp_income_y - xp_income_rise, xp_income_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_xp_income_tween.tween_property(xp_income_label, "modulate:a", 0.0, xp_income_time * 0.4).set_delay(xp_income_time * 0.6)

func _set_xp_shown(value: float) -> void:
	_xp_shown = value
	xp_label.text = "%d pts" % roundi(value)
