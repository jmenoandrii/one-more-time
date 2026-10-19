extends Node3D

# The final battle: the boss in an arena. No timer, the fight starts right away.
# A death here goes on with the next loop on the normal level; the boss's death wins the run
# (both handled by RunState, the win screen by VictoryScreen).

func _ready() -> void:
	GameEvents.level_running = true
	ScreenFade.fade_in(self)
