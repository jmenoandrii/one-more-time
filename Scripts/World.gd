extends Node3D

# the level timer starts when the player walks into any of these StartTriggers; none = right away
@export var start_triggers: Array[Node3D] = []
# level time by the upgrades bought this run: x = upgrades + 1 (1 = none yet), y = seconds;
# past the last point the last value holds. Empty = LevelTimer's wait_time
@export var time_by_upgrades: Curve
# loops that ignore the curve: loop (1 = the first) -> seconds
@export var time_overrides: Dictionary[int, float] = {4: 60.0}
# only on the first loop (a tutorial sign, a starting door...): from the 2nd loop on they are removed
@export var first_loop_only: Array[Node] = []

# loop 1 only: when the player opens this door, the game stops for "KILL THEM ALL"
@export var intro_gate: Node3D

# every enemy of the level dead: the timer stops, a loud sound, and this gate opens the way to the final battle
@export_group("Final")
@export var final_gate: Node3D # a door (door_func.gd), keep it not interactable
@export var final_gate_sound: AudioStreamPlayer # non-positional, so it's heard across the whole level

# kills in a quick row give bonus points ("DOUBLE KILL"...)
@export_group("Kill Streak")
@export var streak_window: float = 3.0 # max seconds between kills that keep the streak going
@export var streak_bonus: Array[int] = [5, 10, 20, 35, 50] # points for 2, 3, 4, 5 kills; the last one repeats for longer streaks

@onready var round_timer: Timer = $LevelTimer

var _streak := 0
var _last_kill_ms := -1000000
var _final_unlocked := false

func _ready() -> void:
	GameEvents.level_running = false # enemies wait for the timer
	ScreenFade.fade_in(self)
	if RunState.loop == 0 and intro_gate and intro_gate.has_signal("opened"):
		intro_gate.connect(&"opened", _show_intro_message, CONNECT_ONE_SHOT)
	if RunState.loop > 0:
		for node in first_loop_only:
			if node:
				node.queue_free()
	var loop := RunState.loop + 1
	if time_overrides.has(loop):
		round_timer.wait_time = maxf(1.0, time_overrides[loop])
	elif time_by_upgrades:
		round_timer.wait_time = maxf(1.0, time_by_upgrades.sample(RunState.get_upgrade_count() + 1))

	# the HUD shows the full time until the timer starts
	GameEvents.level_time_set.emit(round_timer.wait_time)
	GameEvents.time_changed.emit(round_timer.wait_time)
	var waiting := false
	for trigger in start_triggers:
		# a trigger removed by first_loop_only doesn't count
		if trigger and not trigger.is_queued_for_deletion() and trigger.has_signal("activated"):
			trigger.connect(&"activated", _start_level, CONNECT_ONE_SHOT)
			waiting = true
	if not waiting:
		_start_level()

	GameEvents.enemy_killed.connect(_on_enemy_killed)

# the world goes on under it: the gate keeps opening, so it's almost up when the words are over
func _show_intro_message() -> void:
	var message := LoopMessage.new()
	add_child(message)
	await message.play(PackedStringArray(["KILL", "THEM", "ALL"]))
	message.close()

func _start_level() -> void:
	if GameEvents.level_running: # another trigger already started it
		return
	round_timer.start()
	GameEvents.level_running = true
	GameEvents.level_started.emit()

func _process(_delta: float) -> void:
	if not round_timer.is_stopped():
		GameEvents.time_changed.emit(round_timer.time_left)

func _on_enemy_killed() -> void:
	_check_final.call_deferred() # after the killed enemy has left the group
	var now := Time.get_ticks_msec()
	_streak = _streak + 1 if now - _last_kill_ms <= streak_window * 1000.0 else 1
	_last_kill_ms = now
	if _streak < 2:
		return
	var bonus := 0
	if not streak_bonus.is_empty():
		bonus = streak_bonus[mini(_streak - 2, streak_bonus.size() - 1)]
	RunState.add_xp(bonus)
	GameEvents.kill_streak.emit(_streak, bonus)

func _check_final() -> void:
	if _final_unlocked:
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_queued_for_deletion():
			return
	_final_unlocked = true
	round_timer.stop() # no hurry now: the loop doesn't end while the player walks to the gate
	if final_gate_sound:
		final_gate_sound.play()
	if final_gate and final_gate.has_method("open_by_script"):
		final_gate.open_by_script()
	GameEvents.final_unlocked.emit()

func _on_level_timer_timeout() -> void:
	print("Time is end")
	GameEvents.level_completed.emit()
