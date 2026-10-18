extends Pickup

@export var weapon_name: String = "revolver"
# not on the level before this loop (1 = the first), see LevelSpawner
@export var appears_from_loop: int = 1
# its random spawn markers from the 2nd loop on; LevelSpawner falls back to "weapon_spawn" without them
@export var spawn_group: StringName = &"weapon_spawn"

func _pick_up(body: Node3D) -> bool:
	return body.has_method("pick_up_weapon") and body.pick_up_weapon(weapon_name)
