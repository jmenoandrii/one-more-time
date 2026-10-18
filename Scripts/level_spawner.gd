extends Node

# From the 2nd loop on, the player and the weapon pickups start somewhere else:
# the player at a random Marker3D of the "player_spawn" group, every weapon pickup
# at its own random marker of "weapon_spawn". The first loop keeps the scene's positions.
# Must come after the player and the pickups in the scene tree, so they are ready.

func _ready() -> void:
	if RunState.loop == 0:
		return
	_place(get_tree().get_nodes_in_group("player"), "player_spawn")
	_place(get_tree().get_nodes_in_group("weapon_pickup"), "weapon_spawn")

func _place(nodes: Array[Node], spawn_group: StringName) -> void:
	var spawns := get_tree().get_nodes_in_group(spawn_group)
	spawns.shuffle()
	for i in min(nodes.size(), spawns.size()):
		(nodes[i] as Node3D).global_transform = (spawns[i] as Node3D).global_transform
