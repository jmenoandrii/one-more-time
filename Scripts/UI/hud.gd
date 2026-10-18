extends CanvasLayer

# The in-game HUD, pixel art: laid out in art pixels under Root (a PixelRoot).
#
# bottom-left: keys, health, stamina (fades out while full) | bottom-right: reserve, cylinders
# top-center: level timer | center: crosshair, interact prompt, death message.
# The loop number is in the pause menu.

const KEY_ICON := preload("res://UI/HUD/key.png")

@export_group("Health")
@export var trail_delay: float = 0.35 # the white "lost health" part waits, then catches up
@export var trail_time: float = 0.4

@export_group("Stamina")
@export var stamina_hide_delay: float = 1.0 # after it's full again
@export var stamina_fade_time: float = 0.3

@export_group("Timer")
@export var timer_warning_time: float = 10.0 # sec left when the timer turns red
@export var timer_warning_color: Color = Color(0.9, 0.2, 0.2)

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
var timer_label: Label

var _trail_tween: Tween
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
	timer_label = %TimerLabel

	GameEvents.health_changed.connect(_on_health_changed)
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.ammo_changed.connect(_on_ammo_changed)
	GameEvents.reserve_ammo_changed.connect(_on_reserve_ammo_changed)
	GameEvents.weapon_unequipped.connect(_on_weapon_unequipped)
	GameEvents.interact_prompt_changed.connect(_on_interact_prompt_changed)
	GameEvents.keys_changed.connect(_on_keys_changed)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.time_changed.connect(_on_time_changed)

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
	reserve.visible = true

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

func _on_time_changed(time_left: float) -> void:
	var seconds := ceili(time_left) # 0:00 only when the time is really up
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.modulate = timer_warning_color if time_left <= timer_warning_time else Color.WHITE
