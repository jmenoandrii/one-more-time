extends Node

# Where the player and the weapon pickups start, by loop (numbered as the player sees them: loop 1 = the first):
# - loop 1: where they are placed in the editor
# - every next loop: random markers from the "player_spawn" / "weapon_spawn" groups
# - surprise_loop: their own markers, "surprise_player_spawn" / "surprise_weapon_spawn"
#   (without them it falls back to the random ones)
# - no_weapon_loop: a random marker, and no weapons on the level at all

@export var surprise_loop: int = 3
@export var no_weapon_loop: int = 6

func _ready() -> void:
	var loop := RunState.loop + 1
	if loop == 1:
		return

	var players := get_tree().get_nodes_in_group("player")
	var weapons := get_tree().get_nodes_in_group("weapon_pickup")

	if loop == surprise_loop:
		if not _place(players, "surprise_player_spawn"):
			push_warning("LevelSpawner: no \"surprise_player_spawn\" markers, the player spawns randomly")
			_place(players, "player_spawn")
		if not _place(weapons, "surprise_weapon_spawn"):
			_place(weapons, "weapon_spawn")
	else:
		_place(players, "player_spawn")
		_place(weapons, "weapon_spawn")

	if loop == no_weapon_loop:
		for weapon in weapons:
			weapon.queue_free()

# puts the nodes on random markers of the group, one per marker; false if the group is empty
func _place(nodes: Array[Node], spawn_group: StringName) -> bool:
	var spawns := get_tree().get_nodes_in_group(spawn_group)
	if spawns.is_empty():
		return false
	spawns.shuffle()
	for i in min(nodes.size(), spawns.size()):
		(nodes[i] as Node3D).global_transform = (spawns[i] as Node3D).global_transform
	return true
