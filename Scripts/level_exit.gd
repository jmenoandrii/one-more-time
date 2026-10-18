extends Area3D

# The end of the level: the player walking in finishes the loop, the upgrade choice comes next.

var _reached := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _reached or not body.is_in_group("player") or body.is_player_dead:
		return
	_reached = true
	GameEvents.level_completed.emit()
