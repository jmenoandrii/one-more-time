extends Area3D

# Behind the final gate: the player walking in sees "FINISH HIM" and goes to the final battle,
# with the weapons in hands.
# The gate is closed until every enemy is dead, so the player can't reach it earlier.

var _used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _used or not body.is_in_group("player") or body.is_player_dead:
		return
	_used = true
	var weapons: PackedStringArray = body.get_owned_weapon_names()
	# in the root: it must outlive the level change, then cuts straight to the boss
	var message := LoopMessage.new()
	get_tree().root.add_child(message)
	await message.play(PackedStringArray(["FINISH", "HIM"]))
	message.close_after_scene_change()
	RunState.enter_final(weapons)
