extends Pickup

@export var weapon_name: String = "revolver"
# not on the level before this loop (1 = the first), see LevelSpawner
@export var appears_from_loop: int = 1
# not on the level on these loops either (e.g. 4: only the second gun is there, to be found)
@export var absent_on_loops: Array[int] = []
# its random spawn markers from the 2nd loop on; LevelSpawner falls back to "weapon_spawn" without them
@export var spawn_group: StringName = &"weapon_spawn"

# A pickup the player has to be told about (the second gun): until it's taken once in the run,
# the message between loops is these words on every loop it's on the level; after that it spawns
# at taken_spawn_group instead (empty = still spawn_group). Remembered by its node name.
@export_group("Until Taken")
@export var announce: PackedStringArray = []
@export var taken_spawn_group: StringName = &""

func _pick_up(body: Node3D) -> bool:
	if not body.has_method("pick_up_weapon") or not body.pick_up_weapon(weapon_name):
		return false
	RunState.mark_taken(name)
	return true
