extends Node

# Test hotkeys, only in a debug build (run from the editor), never in an exported game:
#   F1 — kill every enemy of the level (the final gate opens)
#   F2 — +POINTS points
#   F3 — the next loop (no upgrade, the points stay)
#   F4 — straight to the boss fight, with the weapons in hands

const POINTS := 500

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F1:
			_kill_all()
		KEY_F2:
			RunState.add_xp(POINTS)
		KEY_F3:
			if not RunState.in_final:
				RunState.complete_level(null)
				RunState.start_next_loop()
		KEY_F4:
			var player := get_tree().get_first_node_in_group("player")
			if player and not RunState.in_final:
				RunState.enter_final(player.get_owned_weapon_names())
		_:
			return
	get_viewport().set_input_as_handled()

func _kill_all() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.current_health > 0:
			health.take_damage(health.current_health + 1.0)
