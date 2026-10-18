extends Area3D
class_name StartTrigger

# Fires once, when the player first walks in (e.g. World starts the level timer on it).

signal activated

var _done := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	activated.emit()
