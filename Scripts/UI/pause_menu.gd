extends CanvasLayer

# Pause menu, in the HUD's pixel style: the loop number, the upgrades taken this run,
# mouse sensitivity, resume / exit.

const GOLD := Color(1.0, 0.76, 0.055)
const DIM_COLOR := Color(1, 1, 1, 0.5)

@onready var loop_label: Label = %LoopLabel
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var resume_button: Button = %ResumeButton
@onready var exit_button: Button = %ExitButton
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var sensitivity_fill: Range = %SensitivityFill
@onready var sensitivity_label: Label = %SensitivityLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	get_tree().paused = false

	# the bar under the slider shows its value like the HUD bars
	sensitivity_fill.min_value = sensitivity_slider.min_value
	sensitivity_fill.max_value = sensitivity_slider.max_value
	sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	_show_sensitivity(Settings.mouse_sensitivity)

	resume_button.pressed.connect(_on_resume_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_slider_value_changed)

	GameEvents.pause_pressed.connect(_on_pause_pressed)
	GameEvents.unpause_pressed.connect(_on_unpause_pressed)

func _on_pause_pressed() -> void:
	_show_run()
	visible = true
	get_tree().paused = true

func _on_unpause_pressed() -> void:
	resume_button.release_focus()
	sensitivity_slider.release_focus()
	visible = false
	get_tree().paused = false

func _show_run() -> void:
	loop_label.text = "LOOP %d" % (RunState.loop + 1)

	for child in upgrades_list.get_children():
		child.queue_free()
	# from the pool, not the save: a saved id whose card file is gone is skipped
	var shown := 0
	for upgrade in RunState.pool:
		var stacks := RunState.get_stacks(upgrade)
		if stacks > 0:
			upgrades_list.add_child(_make_row(upgrade.title, "x%d" % stacks))
			shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "NONE YET"
		none.add_theme_color_override("font_color", DIM_COLOR)
		upgrades_list.add_child(none)

func _make_row(title: String, stacks: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var stacks_label := Label.new()
	stacks_label.text = stacks
	stacks_label.add_theme_color_override("font_color", GOLD)
	row.add_child(stacks_label)
	return row

func _show_sensitivity(value: float) -> void:
	sensitivity_fill.value = value
	sensitivity_label.text = "SENSITIVITY %.1f" % value

func _on_resume_button_pressed() -> void:
	GameEvents.unpause_pressed.emit()

func _on_exit_button_pressed() -> void:
	Settings.save_settings()
	get_tree().quit()

func _on_sensitivity_slider_value_changed(value: float) -> void:
	_show_sensitivity(value)
	Settings.mouse_sensitivity = value
	GameEvents.sensitivity_changed.emit(value)
