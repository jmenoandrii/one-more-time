extends Node3D

@export var start_trigger: Node3D # the level timer starts when this StartTrigger fires; empty = right away
# level time by the upgrades bought this run: x = upgrades + 1 (1 = none yet), y = seconds;
# past the last point the last value holds. Empty = LevelTimer's wait_time
@export var time_by_upgrades: Curve
# loops that ignore the curve: loop (1 = the first) -> seconds
@export var time_overrides: Dictionary[int, float] = {6: 20.0}

# kills in a quick row give bonus points ("DOUBLE KILL"...)
@export_group("Kill Streak")
@export var streak_window: float = 3.0 # max seconds between kills that keep the streak going
@export var streak_bonus: Array[int] = [5, 10, 20, 35, 50] # points for 2, 3, 4, 5 kills; the last one repeats for longer streaks

@onready var round_timer: Timer = $LevelTimer

var _streak := 0
var _last_kill_ms := -1000000

func _ready() -> void:
	GameEvents.level_running = false # enemies wait for the timer
	var loop := RunState.loop + 1
	if time_overrides.has(loop):
		round_timer.wait_time = maxf(1.0, time_overrides[loop])
	elif time_by_upgrades:
		round_timer.wait_time = maxf(1.0, time_by_upgrades.sample(RunState.get_upgrade_count() + 1))

	# the HUD shows the full time until the timer starts
	GameEvents.level_time_set.emit(round_timer.wait_time)
	GameEvents.time_changed.emit(round_timer.wait_time)
	if start_trigger and start_trigger.has_signal("activated"):
		start_trigger.connect(&"activated", _start_level, CONNECT_ONE_SHOT)
	else:
		_start_level()

	GameEvents.enemy_killed.connect(_on_enemy_killed)

func _start_level() -> void:
	round_timer.start()
	GameEvents.level_running = true
	GameEvents.level_started.emit()

func _process(_delta: float) -> void:
	if not round_timer.is_stopped():
		GameEvents.time_changed.emit(round_timer.time_left)

func _on_enemy_killed() -> void:
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

func _on_level_timer_timeout() -> void:
	print("Time is end")
	GameEvents.level_completed.emit()
