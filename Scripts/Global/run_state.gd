extends Node

# The run: which loop it is and which upgrades were taken.
# Lives outside the scene, so it survives the level restart, and is saved to disk.
# Finishing the level adds an upgrade and starts the next loop; a death wipes the whole run.
# The final battle (its own scene): a death there is not the end, the run goes on with the next loop
# on the normal level; beating the boss wins the run and starts a new one.

const PATH := "user://run.cfg"
const UPGRADES_DIR := "res://Upgrades/"
const CHOICES_COUNT := 3
const DEATH_RESTART_DELAY := 2.5 # sec
const FINAL_SCENE := "res://Scenes/final_battle.tscn"

var loop: int = 0 # 0 = the first pass of the run
var upgrades: Dictionary = {} # upgrade id -> stacks
var pool: Array[UpgradeData] = []
var _by_id: Dictionary = {} # upgrade id -> UpgradeData
var xp: int = 0
var taken: Dictionary = {} # pickup name -> true: "until taken" pickups the player has already got this run
var in_final := false # not saved: quitting during the final replays the loop
var carried_weapons: PackedStringArray = [] # weapon names the player brings into the final
var _level_scene := "" # the normal level, to come back to from the final

func _enter_tree() -> void:
	# loaded here, not in _ready: on the game's start the whole tree gets _enter_tree before
	# any _ready, and the level's nodes (the HUD) already read the run in their _enter_tree
	_load_pool()
	load_run()

func _ready() -> void:
	GameEvents.player_died.connect(_on_player_died)

func _load_pool() -> void:
	# list_directory also sees the remapped resources of an exported build
	for file in ResourceLoader.list_directory(UPGRADES_DIR):
		if not file.ends_with(".tres"):
			continue
		var upgrade := load(UPGRADES_DIR + file) as UpgradeData
		if upgrade == null:
			continue
		upgrade.id = file.get_basename()
		pool.append(upgrade)
		_by_id[upgrade.id] = upgrade

# base value of a stat with all taken upgrades applied: (base + flats) * mults
func get_stat(stat: String, base: float) -> float:
	var flat := 0.0
	var mult := 1.0
	for id in upgrades:
		var upgrade: UpgradeData = _by_id.get(id)
		if upgrade == null or upgrade.stat != stat:
			continue
		var stacks: int = upgrades[id]
		flat += upgrade.flat * stacks
		mult *= pow(upgrade.mult, stacks)
	return (base + flat) * mult

func get_stacks(upgrade: UpgradeData) -> int:
	return upgrades.get(upgrade.id, 0)

# every level of every upgrade bought this run
func get_upgrade_count() -> int:
	var count := 0
	for id in upgrades:
		count += upgrades[id]
	return count

# points for the next level of the upgrade
func get_price(upgrade: UpgradeData) -> int:
	return roundi(upgrade.cost * pow(upgrade.cost_growth, get_stacks(upgrade)))

# points spent on something other than an upgrade (a reroll); false if there aren't enough.
# Not saved by itself: the save happens when the loop is completed, like the points earned
func spend_xp(amount: int) -> bool:
	if xp < amount:
		return false
	xp -= amount
	GameEvents.xp_changed.emit(xp, -amount)
	return true

func can_afford(upgrade: UpgradeData) -> bool:
	return xp >= get_price(upgrade)

# up to CHOICES_COUNT different cards, not maxed yet, picked by weight
func roll_choices() -> Array[UpgradeData]:
	var candidates := pool.filter(func(u: UpgradeData) -> bool: return get_stacks(u) < u.max_stacks)
	var result: Array[UpgradeData] = []
	while result.size() < CHOICES_COUNT and not candidates.is_empty():
		var total := 0.0
		for u in candidates:
			total += u.weight
		var roll := randf() * total
		for i in candidates.size():
			roll -= candidates[i].weight
			if roll <= 0.0 or i == candidates.size() - 1:
				result.append(candidates.pop_at(i))
				break
	return result

# upgrade = the bought card, paid with points; null = skipped (or nothing left to buy)
func complete_level(upgrade: UpgradeData) -> void:
	if upgrade and can_afford(upgrade):
		var price := get_price(upgrade)
		xp -= price
		upgrades[upgrade.id] = get_stacks(upgrade) + 1
		GameEvents.xp_changed.emit(xp, -price)
	loop += 1
	save_run()

# after the loop message: the level starts again as the next loop
func start_next_loop() -> void:
	_restart_level()

func reset_run() -> void:
	loop = 0
	upgrades.clear()
	taken.clear()
	xp = 0
	GameEvents.xp_changed.emit(xp, 0)
	save_run()

func _on_player_died() -> void:
	if in_final:
		# lost the boss fight: the run goes on, the next loop on the normal level
		loop += 1
		save_run()
		await get_tree().create_timer(DEATH_RESTART_DELAY).timeout
		_leave_final()
		return
	reset_run() # right away, so quitting during the death screen doesn't keep the run
	await get_tree().create_timer(DEATH_RESTART_DELAY).timeout
	_restart_level()

# the gate is open and the player walked through: on to the boss with the weapons in hands
func enter_final(weapons: PackedStringArray) -> void:
	in_final = true
	carried_weapons = weapons
	_level_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file.call_deferred(FINAL_SCENE)

# the boss is dead: a new run from the first loop
func win_run() -> void:
	reset_run()
	_leave_final()

func _leave_final() -> void:
	in_final = false
	carried_weapons = []
	get_tree().paused = false
	var level := _level_scene
	if level == "":
		level = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(level)

func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func load_run() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	loop = cfg.get_value("run", "loop", 0)
	upgrades = cfg.get_value("run", "upgrades", {})
	xp = cfg.get_value("run", "xp", 0)
	taken = cfg.get_value("run", "taken", {})

func save_run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "loop", loop)
	cfg.set_value("run", "upgrades", upgrades)
	cfg.set_value("run", "xp", xp)
	cfg.set_value("run", "taken", taken)
	cfg.save(PATH)

# saved with the loop, like the points
func mark_taken(pickup_name: String) -> void:
	taken[pickup_name] = true

func was_taken(pickup_name: String) -> bool:
	return taken.has(pickup_name)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	# not saved here: the save holds the points from the loop's start, like the loop itself,
	# so quitting mid-level and replaying the loop can't farm points
	GameEvents.xp_changed.emit(xp, amount)
