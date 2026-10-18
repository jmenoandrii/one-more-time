extends Node

# Where the player and the weapon pickups start, by loop (numbered as the player sees them: loop 1 = the first):
# - loop 1: where they are placed in the editor
# - every next loop: random markers from the "player_spawn" group; every pickup from its own
#   spawn_group (default "weapon_spawn")
# - surprise_loop: their own markers, "surprise_player_spawn" / "surprise_weapon_spawn"
#   (without them it falls back to the random ones)
# - no_weapon_loop: a random marker, and no weapons on the level at all
# A pickup with appears_from_loop later than the current loop is removed.

@export var surprise_loop: int = 3
@export var no_weapon_loop: int = 6

func _ready() -> void:
	var loop := RunState.loop + 1

	var weapons: Array[Node] = []
	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		var from_loop: int = pickup.get(&"appears_from_loop") if &"appears_from_loop" in pickup else 1
		if loop < from_loop:
			pickup.queue_free()
		else:
			weapons.append(pickup)

	if loop == 1:
		return

	var players := get_tree().get_nodes_in_group("player")

	if loop == surprise_loop:
		if not _place(players, "surprise_player_spawn"):
			push_warning("LevelSpawner: no \"surprise_player_spawn\" markers, the player spawns randomly")
			_place(players, "player_spawn")
		if not _place(weapons, "surprise_weapon_spawn"):
			_place_weapons(weapons)
	else:
		_place(players, "player_spawn")
		_place_weapons(weapons)

	if loop == no_weapon_loop:
		for weapon in weapons:
			weapon.queue_free()

# every pickup on a random marker of its own spawn_group
func _place_weapons(weapons: Array[Node]) -> void:
	var by_group := {}
	for weapon in weapons:
		var group: StringName = weapon.get(&"spawn_group") if &"spawn_group" in weapon else &"weapon_spawn"
		if not by_group.has(group):
			var list: Array[Node] = []
			by_group[group] = list
		by_group[group].append(weapon)
	for group in by_group:
		if not _place(by_group[group], group):
			push_warning("LevelSpawner: no \"%s\" markers, using \"weapon_spawn\"" % group)
			_place(by_group[group], "weapon_spawn")

# puts the nodes on random markers of the group, one per marker; false if the group is empty
func _place(nodes: Array[Node], spawn_group: StringName) -> bool:
	var spawns := get_tree().get_nodes_in_group(spawn_group)
	if spawns.is_empty():
		return false
	spawns.shuffle()
	for i in min(nodes.size(), spawns.size()):
		(nodes[i] as Node3D).global_transform = (spawns[i] as Node3D).global_transform
	return true
