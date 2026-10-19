extends Node

# Where the player and the weapon pickups start, by loop (numbered as the player sees them: loop 1 = the first):
# - loop 1: where they are placed in the editor
# - every next loop: random markers from the "player_spawn" group; every pickup from its own
#   spawn_group (default "weapon_spawn")
# - surprise_loops: their own markers, "<prefix>_player_spawn" / "<prefix>_weapon_spawn"
#   (without them it falls back to the random ones)
# - no_weapon_loop: a random marker, and no weapons on the level at all (0 = no such loop)
# - loop_messages: the message between loops before that loop, instead of "KILL THEM ALL"
# A pickup with appears_from_loop later than the current loop, or with the loop in its
# absent_on_loops, is removed.
# "Until taken" pickups (announce, taken_spawn_group): see weapon_pickup.gd and get_announcement().

# loop -> prefix of its marker groups: 3 uses surprise_player_spawn / surprise_weapon_spawn...
@export var surprise_loops: Dictionary[int, String] = {3: "surprise", 5: "surprise2"}
@export var no_weapon_loop: int = 0
# loop -> the words shown before it; an "until taken" pickup's announce goes first
# (4: the second gun shows up — nobody can have taken it before, so it is said here too)
@export var loop_messages: Dictionary[int, PackedStringArray] = {
	4: PackedStringArray(["GRAB", "YOUR", "SECOND", "GUN"]),
	6: PackedStringArray(["FINISH", "ALL", "THEM"]),
}

# the "until taken" pickups of the level, kept here: the ones not on this loop are freed
var _announced: Array[Dictionary] = [] # {name, words, from_loop}

func _ready() -> void:
	add_to_group("level_spawner")
	var loop := RunState.loop + 1
	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		var words: PackedStringArray = pickup.get(&"announce") if &"announce" in pickup else PackedStringArray()
		if not words.is_empty():
			_announced.append({"name": String(pickup.name), "words": words,
				"from_loop": pickup.get(&"appears_from_loop")})

	var weapons: Array[Node] = []
	for pickup in get_tree().get_nodes_in_group("weapon_pickup"):
		var from_loop: int = pickup.get(&"appears_from_loop") if &"appears_from_loop" in pickup else 1
		var absent: Array = pickup.get(&"absent_on_loops") if &"absent_on_loops" in pickup else []
		if loop < from_loop or loop in absent:
			pickup.queue_free()
		else:
			weapons.append(pickup)

	if loop == 1:
		return

	var players := get_tree().get_nodes_in_group("player")

	if surprise_loops.has(loop):
		var prefix: String = surprise_loops[loop]
		if not _place(players, prefix + "_player_spawn"):
			push_warning("LevelSpawner: no \"%s_player_spawn\" markers, the player spawns randomly" % prefix)
			_place(players, "player_spawn")
		if not _place(weapons, prefix + "_weapon_spawn"):
			_place_weapons(weapons)
	else:
		_place(players, "player_spawn")
		_place_weapons(weapons)

	if loop == no_weapon_loop:
		for weapon in weapons:
			weapon.queue_free()

# the words for the message before the given loop: a pickup the player still hasn't taken that
# will be on that level, else that loop's own message; empty = the usual "KILL THEM ALL"
func get_announcement(loop: int) -> PackedStringArray:
	if loop != no_weapon_loop:
		for item in _announced:
			if loop >= item.from_loop and not RunState.was_taken(item.name):
				return item.words
	return loop_messages.get(loop, PackedStringArray())

# every pickup on a random marker of its own spawn_group (its taken_spawn_group once it was taken)
func _place_weapons(weapons: Array[Node]) -> void:
	var by_group := {}
	for weapon in weapons:
		var group: StringName = weapon.get(&"spawn_group") if &"spawn_group" in weapon else &"weapon_spawn"
		var taken_group: StringName = weapon.get(&"taken_spawn_group") if &"taken_spawn_group" in weapon else &""
		if taken_group != &"" and RunState.was_taken(weapon.name):
			group = taken_group
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
