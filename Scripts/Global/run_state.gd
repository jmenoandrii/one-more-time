extends Node

# The run: which loop it is and which upgrades were taken.
# Lives outside the scene, so it survives the level restart, and is saved to disk.
# Finishing the level adds an upgrade and starts the next loop; a death wipes the whole run.

const PATH := "user://run.cfg"
const UPGRADES_DIR := "res://Upgrades/"
const CHOICES_COUNT := 3
const DEATH_RESTART_DELAY := 2.5 # sec

var loop: int = 0 # 0 = the first pass of the run
var upgrades: Dictionary = {} # upgrade id -> stacks
var pool: Array[UpgradeData] = []
var _by_id: Dictionary = {} # upgrade id -> UpgradeData
var xp: int = 0

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
	_restart_level()

func reset_run() -> void:
	loop = 0
	upgrades.clear()
	xp = 0
	GameEvents.xp_changed.emit(xp, 0)
	save_run()

func _on_player_died() -> void:
	reset_run() # right away, so quitting during the death screen doesn't keep the run
	await get_tree().create_timer(DEATH_RESTART_DELAY).timeout
	_restart_level()

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

func save_run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "loop", loop)
	cfg.set_value("run", "upgrades", upgrades)
	cfg.set_value("run", "xp", xp)
	cfg.save(PATH)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	# not saved here: the save holds the points from the loop's start, like the loop itself,
	# so quitting mid-level and replaying the loop can't farm points
	GameEvents.xp_changed.emit(xp, amount)
