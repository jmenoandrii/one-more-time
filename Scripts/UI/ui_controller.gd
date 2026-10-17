extends Node

# HUD labels are looked up when used, so scenes without some of them still work
const AMMO_LABEL := "HUD/AmmoLabel"
const RESERVE_AMMO_LABEL := "HUD/reserveAmmo"
const HEALTH_LABEL := "HUD/HealthLabel"
const STAMINA_LABEL := "HUD/StaminaLabel"
const INTERACT_LABEL := "HUD/InteractLabel"
const KEYS_BOX := "HUD/KeysContainer"
const KEY_ICON := preload("res://UI/Key_white.png")

func _enter_tree() -> void:
	# connect before the player's _ready, which sends the initial values
	GameEvents.ammo_changed.connect(_on_ammo_changed)
	GameEvents.reserve_ammo_changed.connect(_on_reserve_ammo_changed)
	GameEvents.weapon_unequipped.connect(_on_weapon_unequipped)
	GameEvents.health_changed.connect(_on_health_changed)
	GameEvents.stamina_changed.connect(_on_stamina_changed)
	GameEvents.interact_prompt_changed.connect(_on_interact_prompt_changed)
	GameEvents.keys_changed.connect(_on_keys_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			GameEvents.unpause_pressed.emit()
		else:
			GameEvents.pause_pressed.emit()

func _on_ammo_changed(current: int, maximum: int) -> void:
	_set_text(AMMO_LABEL, "%d / %d" % [current, maximum])

func _on_reserve_ammo_changed(amount: int) -> void:
	_set_text(RESERVE_AMMO_LABEL, str(amount))

func _on_weapon_unequipped() -> void:
	_set_text(AMMO_LABEL, "")
	_set_text(RESERVE_AMMO_LABEL, "")

func _on_health_changed(current: float, maximum: float) -> void:
	_set_text(HEALTH_LABEL, "%d / %d" % [current, maximum])

func _on_stamina_changed(current: float, maximum: float) -> void:
	_set_text(STAMINA_LABEL, "%d / %d" % [current, maximum])

func _set_text(path: String, text: String) -> void:
	var label := get_node_or_null(path) as Label
	if label:
		label.text = text

func _on_interact_prompt_changed(text: String) -> void:
	var label := get_node_or_null(INTERACT_LABEL) as Label
	if label == null:
		return
	label.visible = text != ""
	label.text = text

func _on_keys_changed(keys: Dictionary) -> void:
	var box := get_node_or_null(KEYS_BOX) as HBoxContainer
	if box == null:
		return
	for child in box.get_children():
		child.queue_free()
	for key_id in keys:
		var icon := TextureRect.new()
		icon.texture = KEY_ICON
		icon.modulate = keys[key_id]
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = key_id
		box.add_child(icon)
