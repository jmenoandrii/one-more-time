extends Area3D

# Behind the final gate: the player walking in goes to the final battle, with the weapons in hands.
# The gate is closed until every enemy is dead, so the player can't reach it earlier.

var _used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("player") or body.is_player_dead:
		return
	_used = true
	RunState.enter_final(body.get_owned_weapon_names())
