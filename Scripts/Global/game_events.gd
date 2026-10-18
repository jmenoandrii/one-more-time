extends Node

signal pause_pressed
signal unpause_pressed
signal sensitivity_changed(value: float)

# HUD
signal ammo_changed(current: int, maximum: int)
signal reserve_ammo_changed(amount: int)
signal weapon_unequipped
signal cylinders_changed(rounds: Array[int], animate: bool) # rounds per cylinder of the weapon in hands; animate = shot / reload, not a weapon switch
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) # empty = nothing to interact with
signal keys_changed(keys: Dictionary) # key_id -> Color
signal time_changed(time_left: float)
signal level_time_set(total: float) # the level's full time, sent before the first time_changed
signal xp_changed(current: int, delta: int)
signal enemy_hit(damage: float, is_crit: bool, killed: bool) # the player's bullet hit an enemy
signal enemy_killed
signal kill_streak(kills: int, bonus: int) # 2+ kills in a quick row, bonus = XP given for it

# Run
signal level_started # the level timer started: enemies wake up
var level_running := false # set by World; false until the timer starts
signal level_completed
signal player_died

#Sound
signal stamina_bar_picked
