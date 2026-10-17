extends Node

var door_is_close := false
var collider
@onready var raycast: RayCast3D = $raycast
@onready var animation_player: AnimationPlayer = $"../Door/AnimationPlayer"
@onready var label: Label = $"../Control/Label"

func _process(delta: float) -> void:
	if raycast.is_colliding():
		label.text = "Press [E] to interact"
		collider = raycast.get_collider()
		if collider.name == "Door" and Input.is_action_just_pressed("interact"):
			if not door_is_close and not animation_player.is_playing():
				animation_player.play("door_open")
				door_is_close = true
			elif door_is_close and not animation_player.is_playing():
				animation_player.play("door_close")
				door_is_close = false
	else:
		label.text = ""
