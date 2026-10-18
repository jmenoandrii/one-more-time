extends Node

signal pause_pressed
signal unpause_pressed
signal sensitivity_changed(value: float)

# HUD
signal ammo_changed(current: int, maximum: int)
signal reserve_ammo_changed(amount: int)
signal weapon_unequipped
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal interact_prompt_changed(text: String) # empty = nothing to interact with
signal keys_changed(keys: Dictionary) # key_id -> Color

# Run
signal level_completed
signal player_died
