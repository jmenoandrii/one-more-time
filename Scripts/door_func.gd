extends Node3D

# Door root sits on the hinge. The animation rotates the Hinge body (AnimatableBody3D) itself —
# its mesh and collision are offset by half the width, so the door swings around the hinge.
# (The body must be the animated node: if a parent moves it, sync_to_physics drifts it off.)

@export var is_open: bool = false
@export var interactable: bool = true

@export_group("Lock")
@export var required_key: String = "" # empty = no lock; otherwise the key_id of the key that opens it
@export var consume_key: bool = false # take the key from the player when the door gets unlocked

@export_group("Prompts")
# {key} is replaced with required_key
@export var open_text: String = "[E] Open"
@export var close_text: String = "[E] Close"
@export var locked_text: String = "Locked: need {key} key"
@export var unlock_text: String = "[E] Unlock"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer3D = $Open
@onready var close_sound: AudioStreamPlayer3D = $Close



func _ready() -> void:
	add_to_group("interactable")
	if is_open:
		# door placed open in the editor: jump straight to the open pose
		animation_player.play("door_open")
		animation_player.seek(animation_player.current_animation_length, true)

func is_locked() -> bool:
	return required_key != ""

func interact(interactor: Node) -> void:
	if not interactable or animation_player.is_playing():
		return
	
	if is_locked():
		if not _has_key(interactor):
			return
		if consume_key:
			interactor.remove_key(required_key)
		required_key = "" # unlocked for good
	
	is_open = not is_open
	if is_open:
		animation_player.play("door_open")
		open_sound.play()
		
	else:
		close_sound.play()
		animation_player.play_backwards("door_open")

func get_interact_text(interactor: Node = null) -> String:
	var text := close_text if is_open else open_text
	if is_locked():
		text = unlock_text if _has_key(interactor) else locked_text
	return text.replace("{key}", required_key)

func _has_key(interactor: Node) -> bool:
	return interactor != null and interactor.has_method("has_key") and interactor.has_key(required_key)
